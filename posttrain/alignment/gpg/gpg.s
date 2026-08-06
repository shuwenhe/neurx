import "tensor/tensor.s"
import "optimizer/optimizer.s"

struct gpg_config {
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    group_size: i32
    use_baseline: bool
    baseline_type: string
    ema_alpha: f32
    advantage_normalization: bool
    reward_scaling: f32
    entropy_coeff: f32
    l2_reg_coeff: f32
}

struct gpg_trainer {
    config: GPGConfig
    policy_model: *model
    optimizer: *optimizer
    ema_baseline: f32
    step_count: i64
    reward_history: []f32
}

func new_gpg_trainer(config: GPGConfig, policy: *model) -> GPGTrainer {
    let optimizer = adamw_optimizer(policy.parameters(), config.learning_rate)
    return gpg_trainer{
        config: config,
        policy_model: policy,
        optimizer: optimizer,
        ema_baseline: 0.0,
        step_count: 0,
        reward_history: [],
    }
}

func (trainer: *gpg_trainer) generate_group(prompt: Tensor) -> ([]tensor, []tensor) {
    let responses: []tensor = []
    let log_probs_list: []tensor = []
    for i in 0..trainer.config.group_size {
        let response, log_probs = trainer.policy_model.generate(
            prompt,
            temperature: 1.0,
            return_log_probs: true
        )
        responses.push(response)
        log_probs_list.push(log_probs)
    }
    return responses, log_probs_list
}

func (trainer: *gpg_trainer) compute_baseline(rewards: []f32) -> f32 {
    match trainer.config.baseline_type {
        "group_mean" => {
            return compute_mean(rewards)
        },
        "ema" => {
            let current_mean = compute_mean(rewards)
            trainer.ema_baseline = trainer.config.ema_alpha * current_mean +
                                  (1.0 - trainer.config.ema_alpha) * trainer.ema_baseline
            return trainer.ema_baseline
        },
        _ => {
            return 0.0
        }
    }
}

func (trainer: *gpg_trainer) compute_advantages(rewards: []f32) -> []f32 {
    let baseline = trainer.compute_baseline(rewards)
    let scaled_rewards: []f32 = []
    for r in rewards {
        scaled_rewards.push(r * trainer.config.reward_scaling)
    }
    let advantages: []f32 = []
    for r in scaled_rewards {
        advantages.push(r - baseline)
    }
    if trainer.config.advantage_normalization {
        let adv_mean = compute_mean(advantages)
        let adv_std = compute_std(advantages, adv_mean)
        let normalized: []f32 = []
        for adv in advantages {
            normalized.push((adv - adv_mean) / (adv_std + 1e-8))
        }
        return normalized
    }
    return advantages
}

func (trainer: *gpg_trainer) compute_entropy(logits: Tensor) -> Tensor {
    let probs = softmax(logits, dim: -1)
    let log_probs = log_softmax(logits, dim: -1)
    let entropy = -(probs * log_probs).sum(dim: -1).mean()
    return entropy
}

func (trainer: *gpg_trainer) train_step_group(
    prompt: Tensor,
    responses: []tensor,
    rewards: []f32
) -> (f32, f32) {
    let advantages = trainer.compute_advantages(rewards)
    let total_policy_loss: f32 = 0.0
    let total_entropy: f32 = 0.0
    let num_updates = 0
    for epoch in 0..trainer.config.num_epochs {
        for i in 0..responses.len() {
            let input = concat(prompt, responses[i])
            let logits = trainer.policy_model.forward(input)
            let log_probs = log_softmax(logits, dim: -1)
            let policy_loss = -advantages[i] * log_probs.sum()
            let entropy = trainer.compute_entropy(logits)
            let l2_reg = tensor_zeros([1])
            if trainer.config.l2_reg_coeff > 0.0 {
                for param in trainer.policy_model.parameters() {
                    l2_reg = l2_reg + param.pow(2).sum()
                }
                l2_reg = l2_reg * trainer.config.l2_reg_coeff
            }
            let loss = policy_loss -
                      trainer.config.entropy_coeff * entropy +
                      l2_reg
            loss.backward()
            total_policy_loss += policy_loss.item()
            total_entropy += entropy.item()
            num_updates += 1
        }
        clip_grad_norm(trainer.policy_model.parameters(), trainer.config.max_grad_norm)
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
    }
    return (
        total_policy_loss / f32(num_updates),
        total_entropy / f32(num_updates)
    )
}

func (trainer: *gpg_trainer) train(train_data: DataLoader) -> []f32 {
    let policy_losses: []f32 = []
    for batch in train_data {
        for i in 0..batch.prompts.len() {
            let prompt = batch.prompts[i]
            let responses, _ = trainer.generate_group(prompt)
            let rewards: []f32 = []
            for response in responses {
                let reward = compute_reward(prompt, response)
                rewards.push(reward)
                trainer.reward_history.push(reward)
            }
            let policy_loss, entropy = trainer.train_step_group(
                prompt,
                responses,
                rewards
            )
            policy_losses.push(policy_loss)
            trainer.step_count += 1
            if trainer.step_count % 10 == 0 {
                let avg_reward = compute_mean(rewards)
                println(f"Step {trainer.step_count}:")
                println(f"  Policy Loss = {policy_loss:.4f}, " +
                       f"Entropy = {entropy:.4f}")
                println(f"  Group Reward: mean={avg_reward:.4f}")
                if trainer.config.baseline_type == "ema" {
                    println(f"  EMA Baseline = {trainer.ema_baseline:.4f}")
                }
            }
        }
    }
    return policy_losses
}

func (trainer: *gpg_trainer) get_statistics() -> (f32, f32, f32) {
    if trainer.reward_history.len() == 0 {
        return 0.0, 0.0, 0.0
    }
    if trainer.reward_history.len() > 1000 {
        trainer.reward_history = trainer.reward_history[trainer.reward_history.len() - 1000..]
    }
    let mean_reward = compute_mean(trainer.reward_history)
    let std_reward = compute_std(trainer.reward_history, mean_reward)
    let max_reward = trainer.reward_history[0]
    for r in trainer.reward_history {
        if r > max_reward {
            max_reward = r
        }
    }
    return mean_reward, std_reward, max_reward
}

func compute_reward(prompt: Tensor, response: Tensor) -> f32 {
    return random_uniform(-1.0, 1.0)
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

func random_uniform(min_val: f32, max_val: f32) -> f32 {
    return (min_val + max_val) / 2.0
}
