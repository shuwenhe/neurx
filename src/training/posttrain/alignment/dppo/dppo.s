import "tensor/tensor.s"
import "src/training/optimizer/optimizer.s"
import "src/training/posttrain/alignment/ppo/ppo.s"
struct dppo_config {
    f32 learning_rate
    i32 num_epochs
    f32 max_grad_norm
    f32 gamma
    f32 gae_lambda
    string divergence_type
    f32 epsilon
    bool use_adaptive_epsilon
    f32 target_kl
    f32 epsilon_decay
    f32 epsilon_min
    f32 epsilon_max
    bool use_value_loss
    f32 value_loss_coeff
    f32 value_clip_epsilon
}

struct dppo_trainer {
    dppo_config config
    *model policy_model
    *model value_model
    *model reference_model
    *optimizer optimizer
    f32 current_epsilon
    kl_history: []f32
    i64 step_count
}

func new_dppo_trainer(
    dppo_config config,
    *model policy,
    *model value,
    *model reference
) . DPPOTrainer {
    params := policy.parameters()
    if config.use_value_loss {
        params = params + value.parameters()
    }
    optimizer := adamw_optimizer(params, config.learning_rate)
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
) . Tensor {
    epsilon := 1e-8
    p_new := clamp(new_probs, epsilon, 1.0 - epsilon)
    p_old := clamp(old_probs, epsilon, 1.0 - epsilon)
    kl := p_new * log(p_new / p_old) +
             (1.0 - p_new) * log((1.0 - p_new) / (1.0 - p_old))
    ratio := p_new / p_old
    kl_violation := (kl > trainer.current_epsilon).to_float()
    constrained_ratio := ratio * (1.0 - kl_violation) +
                           1.0 * kl_violation
    return constrained_ratio * advantage
}

func (dppo_trainer* trainer) compute_binary_tv_constraint(
    Tensor new_probs,
    Tensor old_probs,
    Tensor advantage
) . Tensor {
    tv := abs(new_probs - old_probs)
    tv_violation := (tv > trainer.current_epsilon).to_float()
    ratio := new_probs / (old_probs + 1e-8)
    constrained_ratio := ratio * (1.0 - tv_violation) +
                           1.0 * tv_violation
    return constrained_ratio * advantage
}

func (dppo_trainer* trainer) compute_constrained_objective(
    Tensor new_log_probs,
    Tensor old_log_probs,
    Tensor advantage
) . Tensor {
    new_probs := exp(new_log_probs)
    old_probs := exp(old_log_probs)
    constrained_obj := Tensor()
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
            ratio := exp(new_log_probs - old_log_probs)
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
    trainer.kl_history = append(trainer.kl_history, current_kl)
    if len(trainer.kl_history) > 100 {
        trainer.kl_history = trainer.kl_history[len(trainer.kl_history) - 100..]
    }
    avg_kl := compute_mean(trainer.kl_history)
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
) . ([]tensor, []tensor) {
    batch_size := len(rewards)
    advantages := []
    returns := []
    for b in 0..batch_size {
        seq_len := rewards[b].shape[0]
        seq_advantages := tensor_zeros([seq_len])
        seq_returns := tensor_zeros([seq_len])
        gae := 0.0
        next_value := 0.0
        for t in (seq_len - 1)..0 by -1 {
            reward := rewards[b][t].item()
            value := values[b][t].item()
            done := dones[b][t].item()
            delta := reward + trainer.config.gamma * next_value * (1.0 - done) - value
            gae = delta + trainer.config.gamma * trainer.config.gae_lambda * (1.0 - done) * gae
            seq_advantages[t] = tensor_scalar(gae)
            seq_returns[t] = tensor_scalar(gae + value)
            next_value = value
        }
        advantages = append(advantages, seq_advantages)
        returns = append(returns, seq_returns)
    }
    return advantages, returns
}

func (dppo_trainer* trainer) train_step(
    []tensor prompts,
    []tensor responses,
    []tensor rewards
) . (f32, f32, f32) {
    batch_size := len(prompts)
    inputs := []
    for i in 0..batch_size {
        inputs = append(inputs, concat(prompts[i], responses[i]))
    }
    values := []
    if trainer.config.use_value_loss {
        for input in inputs {
            value := trainer.value_model.forward(input)
            values = append(values, value)
        }
    } else {
        for i in 0..batch_size {
            values = append(values, tensor_zeros([responses[i].shape[0]]))
        }
    }
    dones := []
    for resp in responses {
        seq_len := resp.shape[0]
        done := tensor_zeros([seq_len])
        done[-1] = tensor_scalar(1.0)
        dones = append(dones, done)
    }
    advantages, returns  := trainer.compute_gae(rewards, values, dones)
    all_advantages := []
    for adv in advantages {
        for i in 0..adv.numel() {
            all_advantages = append(all_advantages, adv.flatten()[i].item())
        }
    }
    adv_mean := compute_mean(all_advantages)
    adv_std := compute_std(all_advantages, adv_mean)
    normalized_advantages := []
    for adv in advantages {
        norm_adv := (adv - adv_mean) / (adv_std + 1e-8)
        normalized_advantages = append(normalized_advantages, norm_adv)
    }
    old_log_probs := []
    for input in inputs {
        logits := trainer.policy_model.forward(input)
        log_probs := log_softmax(logits, dim: -1)
        old_log_probs = append(old_log_probs, log_probs)
    }
    total_policy_loss := 0.0
    total_value_loss := 0.0
    total_kl := 0.0
    num_updates := 0
    for epoch in 0..trainer.config.num_epochs {
        for i in 0..batch_size {
            logits := trainer.policy_model.forward(inputs[i])
            new_log_probs := log_softmax(logits, dim: -1)
            constrained_obj := trainer.compute_constrained_objective(
                new_log_probs,
                old_log_probs[i],
                normalized_advantages[i]
            )
            policy_loss := -constrained_obj.mean()
            value_loss := tensor_zeros([1])
            if trainer.config.use_value_loss {
                new_values := trainer.value_model.forward(inputs[i])
                value_pred_clipped := values[i] + clamp(
                    new_values - values[i],
                    -trainer.config.value_clip_epsilon,
                    trainer.config.value_clip_epsilon
                )
                value_loss1 := (new_values - returns[i]).pow(2)
                value_loss2 := (value_pred_clipped - returns[i]).pow(2)
                value_loss = maximum(value_loss1, value_loss2).mean()
            }
            kl := (exp(old_log_probs[i]) *
                     (old_log_probs[i] - new_log_probs)).sum()
            loss := policy_loss +
                      trainer.config.value_loss_coeff * value_loss
            loss.backward()
            total_policy_loss += policy_loss.item()
            total_value_loss += value_loss.item()
            total_kl += kl.item()
            num_updates += 1
        }
        params := trainer.policy_model.parameters()
        if trainer.config.use_value_loss {
            params = params + trainer.value_model.parameters()
        }
        clip_grad_norm(params, trainer.config.max_grad_norm)
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
    }
    avg_kl := total_kl / f32(num_updates)
    trainer.update_adaptive_epsilon(avg_kl)
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        avg_kl
    )
}

func (dppo_trainer* trainer) train(DataLoader train_data) . ([]f32, []f32) {
    policy_losses := []
    value_losses := []
    for batch in train_data {
        policy_loss, value_loss, kl  := trainer.train_step(
            batch.prompts,
            batch.responses,
            batch.rewards
        )
        policy_losses = append(policy_losses, policy_loss)
        value_losses = append(value_losses, value_loss)
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

func compute_mean([]f32 values) . f32 {
    if len(values) == 0 {
        return 0.0
    }
    sum := 0.0
    for v in values {
        sum += v
    }
    return sum / f32(len(values))
}

func compute_std([]f32 values, f32 mean) . f32 {
    if len(values) == 0 {
        return 1.0
    }
    sum_sq := 0.0
    for v in values {
        sum_sq += (v - mean) * (v - mean)
    }
    return sqrt(sum_sq / f32(len(values)))
}

func clamp(Tensor x, f32 min_val, f32 max_val) . Tensor {
    return maximum(minimum(x, max_val), min_val)
}
