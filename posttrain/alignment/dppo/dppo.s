import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "posttrain/alignment/ppo/ppo.s"

struct dppo_config {
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    gamma: f32
    gae_lambda: f32
    divergence_type: string
    epsilon: f32
    use_adaptive_epsilon: bool
    target_kl: f32
    epsilon_decay: f32
    epsilon_min: f32
    epsilon_max: f32
    use_value_loss: bool
    value_loss_coeff: f32
    value_clip_epsilon: f32
}

struct dppo_trainer {
    config: dppo_config
    policy_model: *model
    value_model: *model
    reference_model: *model
    optimizer: *optimizer
    current_epsilon: f32
    kl_history: []f32
    step_count: i64
}

func new_dppo_trainer(
    dppo_config config,
    *model policy,
    *model value,
    *model reference
) -> DPPOTrainer {
    let params = policy.parameters()
    if config.use_value_loss {
        params = params + value.parameters()
    }
    let optimizer = adamw_optimizer(params, config.learning_rate)
    return dppo_trainer{
        config: config,
        policy_model: policy,
        value_model: value,
        reference_model: reference,
        optimizer: optimizer,
        current_epsilon: config.epsilon,
        kl_history: [],
        step_count: 0,
    }
}

func (dppo_trainer* trainer) compute_binary_kl_constraint(
    Tensor new_probs,
    Tensor old_probs,
    Tensor advantage
) -> Tensor {
    let epsilon = 1e-8
    let p_new = clamp(new_probs, epsilon, 1.0 - epsilon)
    let p_old = clamp(old_probs, epsilon, 1.0 - epsilon)
    let kl = p_new * log(p_new / p_old) +
             (1.0 - p_new) * log((1.0 - p_new) / (1.0 - p_old))
    let ratio = p_new / p_old
    let kl_violation = (kl > trainer.current_epsilon).to_float()
    let constrained_ratio = ratio * (1.0 - kl_violation) +
                           1.0 * kl_violation
    return constrained_ratio * advantage
}

func (dppo_trainer* trainer) compute_binary_tv_constraint(
    Tensor new_probs,
    Tensor old_probs,
    Tensor advantage
) -> Tensor {
    let tv = abs(new_probs - old_probs)
    let tv_violation = (tv > trainer.current_epsilon).to_float()
    let ratio = new_probs / (old_probs + 1e-8)
    let constrained_ratio = ratio * (1.0 - tv_violation) +
                           1.0 * tv_violation
    return constrained_ratio * advantage
}

func (dppo_trainer* trainer) compute_constrained_objective(
    Tensor new_log_probs,
    Tensor old_log_probs,
    Tensor advantage
) -> Tensor {
    let new_probs = exp(new_log_probs)
    let old_probs = exp(old_log_probs)
    let constrained_obj: Tensor
    match trainer.config.divergence_type {
        "binary_kl" => {
            constrained_obj = trainer.compute_binary_kl_constraint(
                new_probs,
                old_probs,
                advantage
            )
        },
        "binary_tv" => {
            constrained_obj = trainer.compute_binary_tv_constraint(
                new_probs,
                old_probs,
                advantage
            )
        },
        _ => {
            let ratio = exp(new_log_probs - old_log_probs)
            constrained_obj = clamp(
                ratio,
                1.0 - trainer.current_epsilon,
                1.0 + trainer.current_epsilon
            ) * advantage
        }
    }
    return constrained_obj
}

func (dppo_trainer* trainer) update_adaptive_epsilon(f32 current_kl) {
    if !trainer.config.use_adaptive_epsilon {
        return
    }
    trainer.kl_history.push(current_kl)
    if trainer.kl_history.len() > 100 {
        trainer.kl_history = trainer.kl_history[trainer.kl_history.len() - 100..]
    }
    let avg_kl = compute_mean(trainer.kl_history)
    if avg_kl > trainer.config.target_kl * 1.5 {
        trainer.current_epsilon *= trainer.config.epsilon_decay
    } else if avg_kl < trainer.config.target_kl * 0.5 {
        trainer.current_epsilon /= trainer.config.epsilon_decay
    }
    trainer.current_epsilon = clamp(
        trainer.current_epsilon,
        trainer.config.epsilon_min,
        trainer.config.epsilon_max
    )
}

func (dppo_trainer* trainer) compute_gae(
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

func (dppo_trainer* trainer) train_step(
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
    let old_log_probs: []tensor = []
    for input in inputs {
        let logits = trainer.policy_model.forward(input)
        let log_probs = log_softmax(logits, dim: -1)
        old_log_probs.push(log_probs)
    }
    let total_policy_loss: f32 = 0.0
    let total_value_loss: f32 = 0.0
    let total_kl: f32 = 0.0
    let num_updates = 0
    for epoch in 0..trainer.config.num_epochs {
        for i in 0..batch_size {
            let logits = trainer.policy_model.forward(inputs[i])
            let new_log_probs = log_softmax(logits, dim: -1)
            let constrained_obj = trainer.compute_constrained_objective(
                new_log_probs,
                old_log_probs[i],
                normalized_advantages[i]
            )
            let policy_loss = -constrained_obj.mean()
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
            let kl = (exp(old_log_probs[i]) *
                     (old_log_probs[i] - new_log_probs)).sum()
            let loss = policy_loss +
                      trainer.config.value_loss_coeff * value_loss
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
    trainer.update_adaptive_epsilon(avg_kl)
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        avg_kl
    )
}

func (dppo_trainer* trainer) train(DataLoader train_data) -> ([]f32, []f32) {
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
            println(f"Step {trainer.step_count} ({trainer.config.divergence_type}):")
            println(f"  Policy Loss = {policy_loss:.4f}, " +
                   f"Value Loss = {value_loss:.4f}, " +
                   f"KL = {kl:.4f}")
            println(f"  Current epsilon = {trainer.current_epsilon:.6f}")
        }
    }
    return policy_losses, value_losses
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

func clamp(Tensor x, f32 min_val, f32 max_val) -> Tensor {
    return maximum(minimum(x, max_val), min_val)
}
