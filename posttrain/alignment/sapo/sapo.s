import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "posttrain/alignment/ppo/ppo.s"
struct sapo_config {
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    kl_coeff: f32
    gamma: f32
    gae_lambda: f32
    tau: f32
    use_smooth_clipping: bool
    advantage_epsilon: f32
    normalize_advantages: bool
    use_value_loss: bool
    value_loss_coeff: f32
}

struct sapo_trainer {
    config: sapo_config
    policy_model: *model
    value_model: *model
    reference_model: *model
    optimizer: *optimizer
    step_count: i64
    advantage_stats: AdvantageStats
}

struct advantage_stats {
    mean: f32
    std: f32
    max_abs: f32
    history: []f32
}

func new_sapo_trainer(
    sapo_config config,
    *model policy,
    *model value,
    *model reference
) -> SAPOTrainer {
    let params = policy.parameters()
    if config.use_value_loss {
        params = params + value.parameters()
    }
    let optimizer = adamw_optimizer(params, config.learning_rate)
    return sapo_trainer{
        config: config,
        policy_model: policy,
        value_model: value,
        reference_model: reference,
        optimizer: optimizer,
        step_count: 0,
        advantage_stats: AdvantageStats{
            mean: 0.0,
            std: 1.0,
            max_abs: 1.0,
            history: [],
        },
    }
}

func (sapo_trainer* trainer) smooth_clip(Tensor x, f32 lower, f32 upper) -> Tensor {
    let tau = trainer.config.tau
    let lower_weight = sigmoid((x - lower) / tau)
    let upper_weight = sigmoid((upper - x) / tau)
    let smooth_clipped = x * lower_weight * upper_weight +
                         lower * (1.0 - lower_weight) +
                         upper * (1.0 - upper_weight)
    return smooth_clipped
}

func (sapo_trainer* trainer) compute_smooth_surrogate(
    Tensor ratio,
    Tensor advantage
) -> Tensor {
    if trainer.config.use_smooth_clipping {
        let clipped_ratio = trainer.smooth_clip(ratio, 0.8, 1.2)
        return clipped_ratio * advantage
    } else {
        let tau = trainer.config.tau
        let unclipped = ratio * advantage
        let clipped = clamp(ratio, 0.8, 1.2) * advantage
        let weight = sigmoid((ratio - 1.0) / tau)
        let smooth_obj = weight * unclipped + (1.0 - weight) * clipped
        return smooth_obj
    }
}

func (sapo_trainer* trainer) compute_gae(
    []tensor rewards,
    []tensor values,
    []tensor dones
) -> ([]tensor, []tensor) {
    let batch_size = rewards.len()
    let advantages: []tensor = []
    let returns: []tensor = []
    for b in 0..batch_size {
        let seq_len = rewards[b].shape[0]
        let seq_advantages = tensor_zeros([seq_len])
        let seq_returns = tensor_zeros([seq_len])
        let gae: f32 = 0.0
        let next_value: f32 = 0.0
        for t in (seq_len - 1)..0 by -1 {
            let reward = rewards[b][t].item()
            let value = values[b][t].item()
            let done = dones[b][t].item()
            let delta = reward + trainer.config.gamma * next_value * (1.0 - done) - value
            gae = delta + trainer.config.gamma * trainer.config.gae_lambda * (1.0 - done) * gae
            seq_advantages[t] = tensor_scalar(gae)
            seq_returns[t] = tensor_scalar(gae + value)
            next_value = value
        }
        advantages.push(seq_advantages)
        returns.push(seq_returns)
    }
    return advantages, returns
}

func (sapo_trainer* trainer) normalize_advantages([]tensor advantages) -> []tensor {
    if !trainer.config.normalize_advantages {
        return advantages
    }
    let all_advantages: []f32 = []
    for adv in advantages {
        for i in 0..adv.numel() {
            all_advantages.push(adv.flatten()[i].item())
        }
    }
    trainer.advantage_stats.mean = compute_mean(all_advantages)
    trainer.advantage_stats.std = compute_std(all_advantages, trainer.advantage_stats.mean)
    let max_abs: f32 = 0.0
    for v in all_advantages {
        if abs(v) > max_abs {
            max_abs = abs(v)
        }
    }
    trainer.advantage_stats.max_abs = max_abs
    let normalized: []tensor = []
    for adv in advantages {
        let norm_adv = (adv - trainer.advantage_stats.mean) /
                       (trainer.advantage_stats.std + trainer.config.advantage_epsilon)
        normalized.push(norm_adv)
    }
    return normalized
}

func (sapo_trainer* trainer) train_step(
    []tensor prompts,
    []tensor responses,
    []tensor rewards
) -> (f32, f32, f32) {
    let batch_size = prompts.len()
    let inputs: []tensor = []
    for i in 0..batch_size {
        inputs.push(concat(prompts[i], responses[i]))
    }
    let values: []tensor = []
    for input in inputs {
        let value = trainer.value_model.forward(input)
        values.push(value)
    }
    let dones: []tensor = []
    for resp in responses {
        let seq_len = resp.shape[0]
        let done = tensor_zeros([seq_len])
        done[-1] = tensor_scalar(1.0)
        dones.push(done)
    }
    let advantages, returns = trainer.compute_gae(rewards, values, dones)
    let normalized_advantages = trainer.normalize_advantages(advantages)
    let old_log_probs: []tensor = []
    for input in inputs {
        let logits = trainer.policy_model.forward(input)
        let log_probs = log_softmax(logits, dim: -1)
        old_log_probs.push(log_probs)
    }
    let ref_log_probs: []tensor = []
    for input in inputs {
        let logits = trainer.reference_model.forward(input)
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
            let ratio = exp(new_log_probs.sum() - old_log_probs[i].sum())
            let surrogate = trainer.compute_smooth_surrogate(
                ratio,
                normalized_advantages[i]
            )
            let policy_loss = -surrogate.mean()
            let value_loss = tensor_zeros([1])
            if trainer.config.use_value_loss {
                let new_values = trainer.value_model.forward(inputs[i])
                value_loss = (new_values - returns[i]).pow(2).mean()
            }
            let kl = (exp(ref_log_probs[i]) *
                     (ref_log_probs[i] - new_log_probs)).sum()
            let loss = policy_loss +
                      trainer.config.value_loss_coeff * value_loss +
                      trainer.config.kl_coeff * kl
            loss.backward()
            total_policy_loss += policy_loss.item()
            total_value_loss += value_loss.item()
            total_kl += kl.item()
            num_updates += 1
        }
        clip_grad_norm(
            trainer.policy_model.parameters() +
            (if trainer.config.use_value_loss { trainer.value_model.parameters() } else { [] }),
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

func (sapo_trainer* trainer) train(DataLoader train_data) -> ([]f32, []f32) {
    let policy_losses: []f32 = []
    let value_losses: []f32 = []
    for batch in train_data {
        let policy_loss, value_loss, kl = trainer.train_step(
            batch.prompts,
            batch.responses,
            batch.rewards
        )
        policy_losses.push(policy_loss)
        value_losses.push(value_loss)
        if trainer.step_count % 10 == 0 {
            println(f"Step {trainer.step_count}: " +
                   f"Policy Loss = {policy_loss:.4f}, " +
                   f"Value Loss = {value_loss:.4f}, " +
                   f"KL = {kl:.4f}")
            println(f"  Advantage Stats: mean={trainer.advantage_stats.mean:.4f}, " +
                   f"std={trainer.advantage_stats.std:.4f}, " +
                   f"max_abs={trainer.advantage_stats.max_abs:.4f}")
        }
    }
    return policy_losses, value_losses
}

func sigmoid(Tensor x) -> Tensor {
    return 1.0 / (1.0 + exp(-x))
}

func compute_mean([]f32 values) -> f32 {
    if values.len() == 0 {
        return 0.0
    }
    let sum: f32 = 0.0
    for v in values {
        sum += v
    }
    return sum / f32(values.len())
}

func compute_std([]f32 values, f32 mean) -> f32 {
    if values.len() == 0 {
        return 1.0
    }
    let sum_sq: f32 = 0.0
    for v in values {
        sum_sq += (v - mean) * (v - mean)
    }
    return sqrt(sum_sq / f32(values.len()))
}
