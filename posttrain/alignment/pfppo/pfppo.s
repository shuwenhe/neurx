import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "posttrain/alignment/ppo/ppo.s"
struct pfppo_config {
    clip_epsilon: f32
    value_clip_epsilon: f32
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    kl_coeff: f32
    gamma: f32
    gae_lambda: f32
    replay_buffer_size: i32
    reward_threshold: f32
    reward_percentile: f32
    use_reward_filtering: bool
    reuse_count: i32
    buffer_sample_ratio: f32
}

struct experience {
    prompt: tensor
    response: tensor
    log_probs: tensor
    values: tensor
    rewards: tensor
    advantages: tensor
    returns: tensor
    done: bool
    timestep: i32
}

struct replay_buffer {
    capacity: i32
    experiences: []experience
    rewards: []f32
    current_size: i32
    insertion_index: i32
}
func new_replay_buffer(capacity: i32) -> replay_buffer {
    return replay_buffer{
        capacity: capacity,
        experiences: [],
        rewards: [],
        current_size: 0,
        insertion_index: 0,
    }
}

func (buffer: *replay_buffer) add(exp: experience, reward: f32) {
    if buffer.current_size < buffer.capacity {
        buffer.experiences.push(exp)
        buffer.rewards.push(reward)
        buffer.current_size += 1
    } else {
        buffer.experiences[buffer.insertion_index] = exp
        buffer.rewards[buffer.insertion_index] = reward
    }
    buffer.insertion_index = (buffer.insertion_index + 1) % buffer.capacity
}

func (buffer: *replay_buffer) sample(n: i32) -> []experience {
    if buffer.current_size == 0 {
        return []
    }
    let sample_size = min(n, buffer.current_size)
    let sampled: []experience = []
    for i in 0..sample_size {
        let idx = random_int(0, buffer.current_size)
        sampled.push(buffer.experiences[idx])
    }
    return sampled
}

func (buffer: *replay_buffer) filter_by_reward(threshold: f32, percentile: f32) {
    if buffer.current_size == 0 {
        return
    }
    let actual_threshold = threshold
    if percentile > 0.0 {
        let sorted_rewards = buffer.rewards[..buffer.current_size].clone()
        sorted_rewards.sort()
        let percentile_idx = i32((100.0 - percentile) / 100.0 * f32(sorted_rewards.len()))
        actual_threshold = sorted_rewards[percentile_idx]
    }
    let filtered_exps: []experience = []
    let filtered_rewards: []f32 = []
    for i in 0..buffer.current_size {
        if buffer.rewards[i] >= actual_threshold {
            filtered_exps.push(buffer.experiences[i])
            filtered_rewards.push(buffer.rewards[i])
        }
    }
    buffer.experiences = filtered_exps
    buffer.rewards = filtered_rewards
    buffer.current_size = filtered_exps.len()
    buffer.insertion_index = 0
}

func (buffer: *replay_buffer) get_statistics() -> (f32, f32, f32) {
    if buffer.current_size == 0 {
        return 0.0, 0.0, 0.0
    }
    let mean = compute_mean(buffer.rewards[..buffer.current_size])
    let std = compute_std(buffer.rewards[..buffer.current_size], mean)
    let max_reward = buffer.rewards[0]
    for r in buffer.rewards[..buffer.current_size] {
        if r > max_reward {
            max_reward = r
        }
    }
    return mean, std, max_reward
}

struct pfppo_trainer {
    config: pfppo_config
    policy_model: *Model
    value_model: *Model
    reference_model: *Model
    optimizer: *Optimizer
    replay_buffer: replay_buffer
    reuse_counts: map[i32]i32
    filtered_count: i32
    total_count: i32
}

func new_pfppo_trainer(
    config: pfppo_config,
    policy: *Model,
    value: *Model,
    reference: *Model
) -> pfppo_trainer {
    let optimizer = adamw_optimizer(
        policy.parameters() + value.parameters(),
        config.learning_rate
    )
    let buffer = new_replay_buffer(config.replay_buffer_size)
    return pfppo_trainer{
        config: config,
        policy_model: policy,
        value_model: value,
        reference_model: reference,
        optimizer: optimizer,
        replay_buffer: buffer,
        reuse_counts: {},
        filtered_count: 0,
        total_count: 0,
    }
}

func (trainer: *pfppo_trainer) collect_experiences(prompts: []tensor) -> []experience {
    let experiences: []experience = []
    for prompt in prompts {
        let response, log_probs = trainer.policy_model.generate(
            prompt,
            temperature: 1.0,
            return_log_probs: true
        )
        let input = concat(prompt, response)
        let values = trainer.value_model.forward(input)
        let reward = compute_reward(prompt, response)
        let exp = experience{
            prompt: prompt,
            response: response,
            log_probs: log_probs,
            values: values,
            rewards: tensor_full([response.shape[0]], reward),
            advantages: tensor_zeros([response.shape[0]]),
            returns: tensor_zeros([response.shape[0]]),
            done: true,
            timestep: trainer.total_count,
        }
        experiences.push(exp)
        trainer.total_count += 1
        if trainer.config.use_reward_filtering {
            if reward >= trainer.config.reward_threshold {
                trainer.replay_buffer.add(exp, reward)
            } else {
                trainer.filtered_count += 1
            }
        } else {
            trainer.replay_buffer.add(exp, reward)
        }
    }
    return experiences
}

func (trainer: *pfppo_trainer) compute_gae(experiences: []experience) {
    for exp in experiences {
        let T = exp.rewards.shape[0]
        let advantages = tensor_zeros([T])
        let returns = tensor_zeros([T])
        let gae: f32 = 0.0
        let next_value: f32 = 0.0
        for t in (T-1)..0 by -1 {
            let reward = exp.rewards[t].item()
            let value = exp.values[t].item()
            let delta = reward + trainer.config.gamma * next_value - value
            gae = delta + trainer.config.gamma * trainer.config.gae_lambda * gae
            advantages[t] = tensor_scalar(gae)
            returns[t] = tensor_scalar(gae + value)
            next_value = value
        }
        exp.advantages = advantages
        exp.returns = returns
    }
}

func (trainer: *pfppo_trainer) train_step(new_prompts: []tensor) -> (f32, f32, f32) {
    let new_experiences = trainer.collect_experiences(new_prompts)
    let buffer_sample_size = i32(
        f32(new_experiences.len()) * trainer.config.buffer_sample_ratio
    )
    let buffer_experiences = trainer.replay_buffer.sample(buffer_sample_size)
    let all_experiences = new_experiences + buffer_experiences
    trainer.compute_gae(all_experiences)
    let total_policy_loss: f32 = 0.0
    let total_value_loss: f32 = 0.0
    let total_kl: f32 = 0.0
    for epoch in 0..trainer.config.num_epochs {
        all_experiences.shuffle()
        for exp in all_experiences {
            let input = concat(exp.prompt, exp.response)
            let logits = trainer.policy_model.forward(input)
            let current_log_probs = log_softmax(logits, dim: -1)
            let current_values = trainer.value_model.forward(input)
            let ratio = exp((current_log_probs - exp.log_probs).sum())
            let surr1 = ratio * exp.advantages
            let surr2 = clamp(
                ratio,
                1.0 - trainer.config.clip_epsilon,
                1.0 + trainer.config.clip_epsilon
            ) * exp.advantages
            let policy_loss = -minimum(surr1, surr2).mean()
            let value_pred_clipped = exp.values + clamp(
                current_values - exp.values,
                -trainer.config.value_clip_epsilon,
                trainer.config.value_clip_epsilon
            )
            let value_loss1 = (current_values - exp.returns).pow(2)
            let value_loss2 = (value_pred_clipped - exp.returns).pow(2)
            let value_loss = maximum(value_loss1, value_loss2).mean()
            let ref_logits = trainer.reference_model.forward(input)
            let ref_log_probs = log_softmax(ref_logits, dim: -1)
            let kl = (exp(ref_log_probs) * (ref_log_probs - current_log_probs)).sum()
            let loss = policy_loss + 0.5 * value_loss + trainer.config.kl_coeff * kl
            loss.backward()
            total_policy_loss += policy_loss.item()
            total_value_loss += value_loss.item()
            total_kl += kl.item()
        }
        clip_grad_norm(
            trainer.policy_model.parameters() + trainer.value_model.parameters(),
            trainer.config.max_grad_norm
        )
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
    }
    if trainer.total_count % 1000 == 0 {
        trainer.replay_buffer.filter_by_reward(
            trainer.config.reward_threshold,
            trainer.config.reward_percentile
        )
    }
    let num_updates = all_experiences.len() * trainer.config.num_epochs
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        total_kl / f32(num_updates)
    )
}

func (trainer: *pfppo_trainer) train(train_data: DataLoader) -> ([]f32, []f32) {
    let policy_losses: []f32 = []
    let value_losses: []f32 = []
    for batch in train_data {
        let policy_loss, value_loss, kl = trainer.train_step(batch.prompts)
        policy_losses.push(policy_loss)
        value_losses.push(value_loss)
        if policy_losses.len() % 10 == 0 {
            let buf_mean, buf_std, buf_max = trainer.replay_buffer.get_statistics()
            println(f"Step {policy_losses.len()}: " +
                   f"Policy Loss = {policy_loss:.4f}, " +
                   f"Value Loss = {value_loss:.4f}, " +
                   f"KL = {kl:.4f}")
            println(f"  Buffer: size={trainer.replay_buffer.current_size}, " +
                   f"mean_reward={buf_mean:.4f}, " +
                   f"std={buf_std:.4f}, " +
                   f"max={buf_max:.4f}")
            println(f"  Filtered: {trainer.filtered_count}/{trainer.total_count}")
        }
    }
    return policy_losses, value_losses
}

func compute_reward(prompt: tensor, response: tensor) -> f32 {
    return random_uniform(-1.0, 1.0)
}
