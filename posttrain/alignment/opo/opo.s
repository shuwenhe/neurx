import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "posttrain/alignment/ppo/ppo.s"

struct opo_config {
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    gamma: f32
    gae_lambda: f32
    target_kl: f32
    kl_tolerance: f32
    use_adaptive_lr: bool
    lr_decay_factor: f32
    lr_growth_factor: f32
    advantage_weighting: string
    temperature: f32
    clip_weight_range: f32
    use_value_loss: bool
    value_loss_coeff: f32
    value_clip_epsilon: f32
    entropy_coeff: f32
}

struct opo_trainer {
    config: opo_config
    policy_model: *model
    value_model: *model
    reference_model: *model
    optimizer: *optimizer
    current_lr: f32
    kl_history: []f32
    step_count: i64
}

func new_opo_trainer(
    config: opo_config,
    policy: *model,
    value: *model,
    reference: *model
) -> OPOTrainer {
    let params = policy.parameters()
    if config.use_value_loss {
        params = params + value.parameters()
    }
    let optimizer = adamw_optimizer(params, config.learning_rate)
    return opo_trainer{
        config: config,
        policy_model: policy,
        value_model: value,
        reference_model: reference,
        optimizer: optimizer,
        current_lr: config.learning_rate,
        kl_history: [],
        step_count: 0,
    }
}

func (trainer: *opo_trainer) compute_advantage_weights(advantages: Tensor) -> Tensor {
    match trainer.config.advantage_weighting {
        "optimal" => {
            let weights = exp(advantages / trainer.config.temperature)
            let sum_weights = weights.sum()
            return weights / (sum_weights + 1e-8)
        },
        "softmax" => {
            return softmax(advantages / trainer.config.temperature, dim: -1)
        },
        "exp" => {
            let weights = exp(advantages / trainer.config.temperature)
            if trainer.config.clip_weight_range > 0.0 {
                let mean_weight = weights.mean()
                let min_weight = mean_weight / trainer.config.clip_weight_range
                let max_weight = mean_weight * trainer.config.clip_weight_range
                return clamp(weights, min_weight.item(), max_weight.item())
            }
            return weights
        },
        "linear" => {
            let min_adv = advantages.min()
            return advantages - min_adv + 1.0
        },
        _ => {
            return tensor_ones_like(advantages)
        }
    }
}

func (trainer: *opo_trainer) compute_optimal_objective(
    new_log_probs: Tensor,
    ref_log_probs: Tensor,
    advantage: Tensor,
    weights: Tensor
) -> Tensor {
    let log_ratio = new_log_probs - ref_log_probs
    let weighted_advantage = weights * advantage
    let objective = log_ratio * weighted_advantage
    return objective
}

func (trainer: *opo_trainer) adapt_learning_rate(kl: f32) {
    if !trainer.config.use_adaptive_lr {
        return
    }
    trainer.kl_history.push(kl)
    if trainer.kl_history.len() > 20 {
        trainer.kl_history = trainer.kl_history[trainer.kl_history.len() - 20..]
    }
    let avg_kl = compute_mean(trainer.kl_history)
    if avg_kl > trainer.config.target_kl * (1.0 + trainer.config.kl_tolerance) {
        trainer.current_lr *= trainer.config.lr_decay_factor
    } else if avg_kl < trainer.config.target_kl * (1.0 - trainer.config.kl_tolerance) {
        trainer.current_lr *= trainer.config.lr_growth_factor
    }
    let min_lr = trainer.config.learning_rate * 0.01
    let max_lr = trainer.config.learning_rate * 10.0
    trainer.current_lr = clamp_scalar(trainer.current_lr, min_lr, max_lr)
    trainer.optimizer.set_learning_rate(trainer.current_lr)
}

func (trainer: *opo_trainer) compute_gae(
    rewards: []tensor,
    values: []tensor,
    dones: []tensor
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

func (trainer: *opo_trainer) train_step(
    prompts: []tensor,
    responses: []tensor,
    rewards: []tensor
) -> (f32, f32, f32) {
    let batch_size = prompts.len()
    let inputs: []tensor = []
    for i in 0..batch_size {
        inputs.push(concat(prompts[i], responses[i]))
    }
    let values: []tensor = []
    if trainer.config.use_value_loss {
        for input in inputs {
            let value = trainer.value_model.forward(input)
            values.push(value)
        }
    } else {
        for i in 0..batch_size {
            values.push(tensor_zeros([responses[i].shape[0]]))
        }
    }
    let dones: []tensor = []
    for resp in responses {
        let seq_len = resp.shape[0]
        let done = tensor_zeros([seq_len])
        done[-1] = tensor_scalar(1.0)
        dones.push(done)
    }
    let advantages, returns = trainer.compute_gae(rewards, values, dones)
    let all_advantages: []f32 = []
    for adv in advantages {
        for i in 0..adv.numel() {
            all_advantages.push(adv.flatten()[i].item())
        }
    }
    let adv_mean = compute_mean(all_advantages)
    let adv_std = compute_std(all_advantages, adv_mean)
    let normalized_advantages: []tensor = []
    for adv in advantages {
        let norm_adv = (adv - adv_mean) / (adv_std + 1e-8)
        normalized_advantages.push(norm_adv)
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
            let weights = trainer.compute_advantage_weights(normalized_advantages[i])
            let optimal_obj = trainer.compute_optimal_objective(
                new_log_probs,
                ref_log_probs[i],
                normalized_advantages[i],
                weights
            )
            let policy_loss = -optimal_obj.mean()
            let value_loss = tensor_zeros([1])
            if trainer.config.use_value_loss {
                let new_values = trainer.value_model.forward(inputs[i])
                let value_pred_clipped = values[i] + clamp(
                    new_values - values[i],
                    -trainer.config.value_clip_epsilon,
                    trainer.config.value_clip_epsilon
                )
                let value_loss1 = (new_values - returns[i]).pow(2)
                let value_loss2 = (value_pred_clipped - returns[i]).pow(2)
                value_loss = maximum(value_loss1, value_loss2).mean()
            }
            let entropy = -(exp(new_log_probs) * new_log_probs).sum()
            let kl = (exp(ref_log_probs[i]) *
                     (ref_log_probs[i] - new_log_probs)).sum()
            let loss = policy_loss +
                      trainer.config.value_loss_coeff * value_loss -
                      trainer.config.entropy_coeff * entropy
            loss.backward()
            total_policy_loss += policy_loss.item()
            total_value_loss += value_loss.item()
            total_kl += kl.item()
            num_updates += 1
        }
        let params = trainer.policy_model.parameters()
        if trainer.config.use_value_loss {
            params = params + trainer.value_model.parameters()
        }
        clip_grad_norm(params, trainer.config.max_grad_norm)
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
    }
    let avg_kl = total_kl / f32(num_updates)
    trainer.adapt_learning_rate(avg_kl)
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        avg_kl
    )
}

func (trainer: *opo_trainer) train(train_data: DataLoader) -> ([]f32, []f32) {
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
            println(f"Step {trainer.step_count} (OPO {trainer.config.advantage_weighting}):")
            println(f"  Policy Loss = {policy_loss:.4f}, " +
                   f"Value Loss = {value_loss:.4f}, " +
                   f"KL = {kl:.4f}")
            if trainer.config.use_adaptive_lr {
                println(f"  Current LR = {trainer.current_lr:.6f}")
            }
        }
    }
    return policy_losses, value_losses
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

func clamp(x: Tensor, min_val: f32, max_val: f32) -> Tensor {
    return maximum(minimum(x, max_val), min_val)
}

func clamp_scalar(x: f32, min_val: f32, max_val: f32) -> f32 {
    if x < min_val {
        return min_val
    }
    if x > max_val {
        return max_val
    }
    return x
}
