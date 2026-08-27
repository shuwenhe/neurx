import "tensor/tensor.s"
import "src/training/optimizer/optimizer.s"
import "src/training/posttrain/alignment/ppo/ppo.s"

struct cispo_config {
    f32 learning_rate
    i32 num_epochs
    f32 max_grad_norm
    f32 gamma
    f32 gae_lambda
    f32 clip_epsilon_positive
    f32 clip_epsilon_negative
    f32 is_clip_lower
    f32 is_clip_upper
    bool use_is_weights
    f32 is_epsilon
    bool use_value_loss
    f32 value_loss_coeff
    f32 value_clip_epsilon
    f32 kl_coeff
}

struct cispo_trainer {
    cispo_config config
    *model policy_model
    *model value_model
    *model reference_model
    *optimizer optimizer
    behavior_log_probs: []tensor
    i64 step_count
    ISWeightStats is_weight_stats
}

struct is_weight_stats {
    f32 mean
    f32 std
    f32 min
    f32 max
    f32 clipped_ratio
}

func new_cispo_trainer(
    cispo_config config,
    *model policy,
    *model value,
    *model reference
) . CISPOTrainer {
    params := policy.parameters()
    if config.use_value_loss {
        params = params + value.parameters()
    }
    optimizer := adamw_optimizer(params, config.learning_rate)
    return cispo_trainer{
        config: config,
        policy_model: policy,
        value_model: value,
        reference_model: reference,
        optimizer: optimizer,
        behavior_log_probs: [],
        step_count: 0,
        is_weight_stats: ISWeightStats{
            mean: 1.0,
            std: 0.0,
            min: 1.0,
            max: 1.0,
            clipped_ratio: 0.0,
        },
    }
}

func (cispo_trainer* trainer) compute_is_weights(
    []tensor new_log_probs,
    []tensor behavior_log_probs
) . []tensor {
    is_weights := []
    for i in len(0..new_log_probs) {
        log_ratio := new_log_probs[i] - behavior_log_probs[i]
        ratio := exp(log_ratio)
        clipped_ratio := clamp(
            ratio,
            trainer.config.is_clip_lower,
            trainer.config.is_clip_upper
        )
        is_weights = append(is_weights, clipped_ratio)
    }
    trainer.update_is_weight_stats(is_weights)
    return is_weights
}

func (cispo_trainer* trainer) update_is_weight_stats([]tensor is_weights) {
    values := []
    clipped_count := 0
    total_count := 0
    for weight in is_weights {
        for i in 0..weight.numel() {
            val := weight.flatten()[i].item()
            values = append(values, val)
            total_count += 1
            if val <= trainer.config.is_clip_lower ||
               val >= trainer.config.is_clip_upper {
                clipped_count += 1
            }
        }
    }
    if len(values) == 0 {
        return
    }
    trainer.is_weight_stats.mean = compute_mean(values)
    trainer.is_weight_stats.std = compute_std(values, trainer.is_weight_stats.mean)
    trainer.is_weight_stats.min = values[0]
    trainer.is_weight_stats.max = values[0]
    for v in values {
        if v < trainer.is_weight_stats.min {
            trainer.is_weight_stats.min = v
        }
        if v > trainer.is_weight_stats.max {
            trainer.is_weight_stats.max = v
        }
    }
    trainer.is_weight_stats.clipped_ratio = f32(clipped_count) / f32(total_count)
}

func (cispo_trainer* trainer) compute_cispo_objective(
    Tensor ratio,
    Tensor advantage,
    Tensor is_weight
) . Tensor {
    positive_mask := (advantage > 0.0).to_float()
    negative_mask := (advantage <= 0.0).to_float()
    clip_pos_lower := 1.0 - trainer.config.clip_epsilon_positive
    clip_pos_upper := 1.0 + trainer.config.clip_epsilon_positive
    clipped_ratio_pos := clamp(ratio, clip_pos_lower, clip_pos_upper)
    clip_neg_lower := 1.0 - trainer.config.clip_epsilon_negative
    clip_neg_upper := 1.0 + trainer.config.clip_epsilon_negative
    clipped_ratio_neg := clamp(ratio, clip_neg_lower, clip_neg_upper)
    clipped_ratio := clipped_ratio_pos * positive_mask +
                        clipped_ratio_neg * negative_mask
    surr1 := ratio * advantage
    surr2 := clipped_ratio * advantage
    clipped_obj := minimum(surr1, surr2)
    weighted_obj := Tensor()
    if trainer.config.use_is_weights {
        weighted_obj = is_weight * clipped_obj
    } else {
        weighted_obj = clipped_obj
    }
    return weighted_obj
}

func (cispo_trainer* trainer) compute_gae(
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

func (cispo_trainer* trainer) train_step(
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
    behavior_log_probs := []
    for input in inputs {
        logits := trainer.policy_model.forward(input)
        log_probs := log_softmax(logits, dim: -1)
        behavior_log_probs = append(behavior_log_probs, log_probs)
    }
    ref_log_probs := []
    for input in inputs {
        logits := trainer.reference_model.forward(input)
        log_probs := log_softmax(logits, dim: -1)
        ref_log_probs = append(ref_log_probs, log_probs)
    }
    total_policy_loss := 0.0
    total_value_loss := 0.0
    total_kl := 0.0
    num_updates := 0
    for epoch in 0..trainer.config.num_epochs {
        for i in 0..batch_size {
            logits := trainer.policy_model.forward(inputs[i])
            new_log_probs := log_softmax(logits, dim: -1)
            ratio := exp(new_log_probs - behavior_log_probs[i])
            is_weight := tensor_ones_like(ratio)
            if trainer.config.use_is_weights {
                is_weights_batch := trainer.compute_is_weights(
                    [new_log_probs],
                    [behavior_log_probs[i]]
                )
                is_weight = is_weights_batch[0]
            }
            cispo_obj := trainer.compute_cispo_objective(
                ratio,
                normalized_advantages[i],
                is_weight
            )
            policy_loss := -cispo_obj.mean()
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
            kl := (exp(ref_log_probs[i]) *
                     (ref_log_probs[i] - new_log_probs)).sum()
            loss := policy_loss +
                      trainer.config.value_loss_coeff * value_loss +
                      trainer.config.kl_coeff * kl
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
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        total_kl / f32(num_updates)
    )
}

func (cispo_trainer* trainer) train(DataLoader train_data) . ([]f32, []f32) {
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
            println(f"Step {trainer.step_count}:")
            println(f"  Policy Loss = {policy_loss:.4f}, " +
                   f"Value Loss = {value_loss:.4f}, " +
                   f"KL = {kl:.4f}")
            if trainer.config.use_is_weights {
                println(f"  IS Weight Stats: " +
                       f"mean={trainer.is_weight_stats.mean:.4f}, " +
                       f"std={trainer.is_weight_stats.std:.4f}, " +
                       f"clipped={trainer.is_weight_stats.clipped_ratio:.2%}")
            }
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
