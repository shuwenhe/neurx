import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "posttrain/alignment/ppo/ppo.s"
struct gmpo_config {
    clip_epsilon: f32
    value_clip_epsilon: f32
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    kl_coeff: f32
    gamma: f32
    gae_lambda: f32
    num_rewards: i32
    use_geometric_mean: bool
    epsilon: f32
    reward_normalization: bool
    min_reward_value: f32
}

struct gmpo_trainer {
    config: GMPOConfig
    policy_model: *model
    value_model: *model
    reference_model: *model
    optimizer: *optimizer
    reward_statistics: []reward_stats
    step_count: i64
}

struct reward_stats {
    mean: f32
    std: f32
    min: f32
    max: f32
    history: []f32
}

func new_gmpo_trainer(
    config: GMPOConfig,
    policy: *model,
    value: *model,
    reference: *model
) -> GMPOTrainer {
    let optimizer = adamw_optimizer(
        policy.parameters() + value.parameters(),
        config.learning_rate
    )
    let reward_statistics: []reward_stats = []
    for i in 0..config.num_rewards {
        reward_statistics.push(reward_stats{
            mean: 0.0,
            std: 1.0,
            min: f32.MAX,
            max: f32.MIN,
            history: [],
        })
    }
    return gmpo_trainer{
        config: config,
        policy_model: policy,
        value_model: value,
        reference_model: reference,
        optimizer: optimizer,
        reward_statistics: reward_statistics,
        step_count: 0,
    }
}

func (trainer: *gmpo_trainer) compute_geometric_mean(rewards: []f32) -> f32 {
    if rewards.len() == 0 {
        return 0.0
    }
    let shifted_rewards: []f32 = []
    for r in rewards {
        let shifted = max(r, trainer.config.min_reward_value) + trainer.config.epsilon
        shifted_rewards.push(shifted)
    }
    let log_sum: f32 = 0.0
    for r in shifted_rewards {
        log_sum += log(r)
    }
    let geometric_mean = exp(log_sum / f32(shifted_rewards.len()))
    return geometric_mean - trainer.config.epsilon
}

func compute_arithmetic_mean(rewards: []f32) -> f32 {
    if rewards.len() == 0 {
        return 0.0
    }
    let sum: f32 = 0.0
    for r in rewards {
        sum += r
    }
    return sum / f32(rewards.len())
}

func (trainer: *gmpo_trainer) update_reward_statistics(
    multi_rewards: [][]f32
) {
    for reward_idx in 0..trainer.config.num_rewards {
        let values: []f32 = []
        for batch_idx in 0..multi_rewards.len() {
            if reward_idx < multi_rewards[batch_idx].len() {
                values.push(multi_rewards[batch_idx][reward_idx])
            }
        }
        if values.len() == 0 {
            continue
        }
        let stats = &trainer.reward_statistics[reward_idx]
        for v in values {
            stats.history.push(v)
        }
        if stats.history.len() > 1000 {
            stats.history = stats.history[stats.history.len() - 1000..]
        }
        for v in values {
            if v < stats.min {
                stats.min = v
            }
            if v > stats.max {
                stats.max = v
            }
        }
        if stats.history.len() > 0 {
            stats.mean = compute_mean(stats.history)
            stats.std = compute_std(stats.history, stats.mean)
        }
    }
}

func (trainer: *gmpo_trainer) normalize_rewards(
    multi_rewards: [][]f32
) -> [][]f32 {
    if !trainer.config.reward_normalization {
        return multi_rewards
    }
    let normalized: [][]f32 = []
    for batch_idx in 0..multi_rewards.len() {
        let batch_rewards = multi_rewards[batch_idx]
        let normalized_batch: []f32 = []
        for reward_idx in 0..batch_rewards.len() {
            let stats = trainer.reward_statistics[reward_idx]
            let normalized_value = (batch_rewards[reward_idx] - stats.mean) /
                                   (stats.std + trainer.config.epsilon)
            normalized_batch.push(normalized_value)
        }
        normalized.push(normalized_batch)
    }
    return normalized
}

func (trainer: *gmpo_trainer) combine_rewards(multi_rewards: []f32) -> f32 {
    if trainer.config.use_geometric_mean {
        return trainer.compute_geometric_mean(multi_rewards)
    } else {
        return compute_arithmetic_mean(multi_rewards)
    }
}

func (trainer: *gmpo_trainer) compute_gae(
    rewards: []tensor,
    values: []tensor,
    dones: []tensor
) -> ([]tensor, []tensor) {
    let batch_size = rewards.len()
    let advantages: []tensor = []
    let returns: []tensor = []
    for b in 0..batch_size {
        let seq_len = rewards[b].shape[0]
        let num_rewards = rewards[b].shape[1]
        let seq_advantages = tensor_zeros([seq_len])
        let seq_returns = tensor_zeros([seq_len])
        let gae: f32 = 0.0
        let next_value: f32 = 0.0
        for t in (seq_len - 1)..0 by -1 {
            let multi_reward: []f32 = []
            for r_idx in 0..num_rewards {
                multi_reward.push(rewards[b][t, r_idx].item())
            }
            let combined_reward = trainer.combine_rewards(multi_reward)
            let value = values[b][t].item()
            let done = dones[b][t].item()
            let delta = combined_reward +
                       trainer.config.gamma * next_value * (1.0 - done) -
                       value
            gae = delta +
                  trainer.config.gamma * trainer.config.gae_lambda *
                  (1.0 - done) * gae
            seq_advantages[t] = tensor_scalar(gae)
            seq_returns[t] = tensor_scalar(gae + value)
            next_value = value
        }
        advantages.push(seq_advantages)
        returns.push(seq_returns)
    }
    return advantages, returns
}

func (trainer: *gmpo_trainer) train_step(
    prompts: []tensor,
    responses: []tensor,
    multi_rewards: [][]f32
) -> (f32, f32, f32) {
    let batch_size = prompts.len()
    trainer.update_reward_statistics(multi_rewards)
    let normalized_rewards = trainer.normalize_rewards(multi_rewards)
    let inputs: []tensor = []
    let reward_tensors: []tensor = []
    let done_tensors: []tensor = []
    for i in 0..batch_size {
        let input = concat(prompts[i], responses[i])
        inputs.push(input)
        let seq_len = responses[i].shape[0]
        let reward_tensor = tensor_zeros([seq_len, trainer.config.num_rewards])
        for t in 0..seq_len {
            for r_idx in 0..trainer.config.num_rewards {
                reward_tensor[t, r_idx] = tensor_scalar(normalized_rewards[i][r_idx])
            }
        }
        reward_tensors.push(reward_tensor)
        let done_tensor = tensor_zeros([seq_len])
        done_tensor[-1] = tensor_scalar(1.0)
        done_tensors.push(done_tensor)
    }
    let value_outputs: []tensor = []
    for input in inputs {
        let value = trainer.value_model.forward(input)
        value_outputs.push(value)
    }
    let advantages, returns = trainer.compute_gae(
        reward_tensors,
        value_outputs,
        done_tensors
    )
    let current_log_probs: []tensor = []
    for i in 0..batch_size {
        let logits = trainer.policy_model.forward(inputs[i])
        let log_probs = log_softmax(logits, dim: -1)
        current_log_probs.push(log_probs)
    }
    let ref_log_probs: []tensor = []
    for i in 0..batch_size {
        let logits = trainer.reference_model.forward(inputs[i])
        let log_probs = log_softmax(logits, dim: -1)
        ref_log_probs.push(log_probs)
    }
    let total_policy_loss: f32 = 0.0
    let total_value_loss: f32 = 0.0
    let total_kl: f32 = 0.0
    let num_updates = 0
    for epoch in 0..trainer.config.num_epochs {
        for i in 0..batch_size {
            let logits = trainer.policy_model.forward(inputs[i])
            let new_log_probs = log_softmax(logits, dim: -1)
            let new_values = trainer.value_model.forward(inputs[i])
            let ratio = exp(new_log_probs.sum() - current_log_probs[i].sum())
            let surr1 = ratio * advantages[i]
            let surr2 = clamp(
                ratio,
                1.0 - trainer.config.clip_epsilon,
                1.0 + trainer.config.clip_epsilon
            ) * advantages[i]
            let policy_loss = -minimum(surr1, surr2).mean()
            let value_pred_clipped = value_outputs[i] + clamp(
                new_values - value_outputs[i],
                -trainer.config.value_clip_epsilon,
                trainer.config.value_clip_epsilon
            )
            let value_loss1 = (new_values - returns[i]).pow(2)
            let value_loss2 = (value_pred_clipped - returns[i]).pow(2)
            let value_loss = maximum(value_loss1, value_loss2).mean()
            let kl = (exp(ref_log_probs[i]) *
                     (ref_log_probs[i] - new_log_probs)).sum()
            let loss = policy_loss + 0.5 * value_loss + trainer.config.kl_coeff * kl
            loss.backward()
            total_policy_loss += policy_loss.item()
            total_value_loss += value_loss.item()
            total_kl += kl.item()
            num_updates += 1
        }
        clip_grad_norm(
            trainer.policy_model.parameters() + trainer.value_model.parameters(),
            trainer.config.max_grad_norm
        )
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
    }
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        total_kl / f32(num_updates)
    )
}

func (trainer: *gmpo_trainer) train(train_data: DataLoader) -> ([]f32, []f32) {
    let policy_losses: []f32 = []
    let value_losses: []f32 = []
    for batch in train_data {
        let policy_loss, value_loss, kl = trainer.train_step(
            batch.prompts,
            batch.responses,
            batch.multi_rewards
        )
        policy_losses.push(policy_loss)
        value_losses.push(value_loss)
        if trainer.step_count % 10 == 0 {
            println(f"Step {trainer.step_count}: " +
                   f"Policy Loss = {policy_loss:.4f}, " +
                   f"Value Loss = {value_loss:.4f}, " +
                   f"KL = {kl:.4f}")
            trainer.print_reward_statistics()
        }
    }
    return policy_losses, value_losses
}

func (trainer: *gmpo_trainer) print_reward_statistics() {
    println("Reward Statistics (Geometric Mean):")
    for i in 0..trainer.config.num_rewards {
        let stats = trainer.reward_statistics[i]
        println(f"  Reward {i}: mean={stats.mean:.4f}, " +
               f"std={stats.std:.4f}, " +
               f"min={stats.min:.4f}, " +
               f"max={stats.max:.4f}")
    }
}

func compute_mean(values: []f32) -> f32 {
    if values.len() == 0 {
        return 0.0
    }
    let sum: f32 = 0.0
    for v in values {
        sum += v
    }
    return sum / f32(values.len())
}

func compute_std(values: []f32, mean: f32) -> f32 {
    if values.len() == 0 {
        return 1.0
    }
    let sum_sq: f32 = 0.0
    for v in values {
        sum_sq += (v - mean) * (v - mean)
    }
    return sqrt(sum_sq / f32(values.len()))
}
