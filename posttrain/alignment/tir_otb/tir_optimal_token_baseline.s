import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "posttrain/alignment/rollout_correction/config.s"
import "posttrain/alignment/rollout_correction/importance_sampling.s"
struct tir_optimal_token_baseline_config {
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    gamma: f32
    is_threshold: f32
    use_is_batch_normalize: bool
    baseline_ema_alpha: f32
    use_position_baseline: bool
    use_learned_baseline: bool
    use_whitening: bool
    compute_variance_reduction: bool
    use_clipping: bool
    clip_epsilon: f32
    entropy_coeff: f32
}

struct tir_optimal_token_baseline_trainer {
    config: TIROptimalTokenBaselineConfig
    policy_model: *model
    value_model: *model
    reference_model: *model
    optimizer: *optimizer
    value_optimizer: *optimizer
    token_baselines: map[i64]f32
    position_baselines: map[i64]f32
    variance_before: f32
    variance_after: f32
    variance_reduction_ratio: f32
    is_weight_stats: ISWeightStats
    step_count: i64
}

struct is_weight_stats {
    mean: f32
    std: f32
    min: f32
    max: f32
    clip_fraction: f32
}

func new_tir_otb_trainer(
    config: TIROptimalTokenBaselineConfig,
    policy: *model,
    value: *model,
    reference: *model
) -> TIROptimalTokenBaselineTrainer {
    let optimizer = adamw_optimizer(policy.parameters(), config.learning_rate)
    let value_optimizer: *optimizer = nil
    if config.use_learned_baseline {
        value_optimizer = adamw_optimizer(value.parameters(), config.learning_rate * 0.1)
    }
    return tir_optimal_token_baseline_trainer{
        config: config,
        policy_model: policy,
        value_model: value,
        reference_model: reference,
        optimizer: optimizer,
        value_optimizer: value_optimizer,
        token_baselines: {},
        position_baselines: {},
        variance_before: 0.0,
        variance_after: 0.0,
        variance_reduction_ratio: 0.0,
        is_weight_stats: ISWeightStats{
            mean: 1.0,
            std: 0.0,
            min: 1.0,
            max: 1.0,
            clip_fraction: 0.0,
        },
        step_count: 0,
    }
}

func (trainer: *tir_optimal_token_baseline_trainer) compute_tir_token_baseline(
    tokens: Tensor,
    rewards: Tensor,
    is_weights: Tensor,
    positions: Tensor
) -> Tensor {
    let batch_size = tokens.shape[0]
    let seq_len = tokens.shape[1]
    let baselines = tensor_zeros([batch_size, seq_len])
    for b in 0..batch_size {
        for t in 0..seq_len {
            let token_id = tokens[b][t].item_i64()
            let position = positions[b][t].item_i64()
            let reward = rewards[b][t].item()
            let is_weight = is_weights[b][t].item()
            let weighted_reward = reward * is_weight
            let key: i64
            if trainer.config.use_position_baseline {
                key = position
            } else {
                key = token_id
            }
            if key in trainer.token_baselines {
                let old_baseline = trainer.token_baselines[key]
                let new_baseline = trainer.config.baseline_ema_alpha * weighted_reward +
                                 (1.0 - trainer.config.baseline_ema_alpha) * old_baseline
                trainer.token_baselines[key] = new_baseline
                baselines[b][t] = tensor_scalar(new_baseline)
            } else {
                trainer.token_baselines[key] = weighted_reward
                baselines[b][t] = tensor_scalar(weighted_reward)
            }
        }
    }
    return baselines
}

func (trainer: *tir_optimal_token_baseline_trainer) compute_tir_advantages(
    tokens: Tensor,
    rewards: Tensor,
    is_weights: Tensor,
    positions: Tensor
) -> Tensor {
    let baselines: Tensor
    if trainer.config.use_learned_baseline {
        baselines = trainer.value_model.forward(tokens)
    } else {
        baselines = trainer.compute_tir_token_baseline(tokens, rewards, is_weights, positions)
    }
    if trainer.config.compute_variance_reduction {
        trainer.variance_before = compute_variance_tensor(rewards)
    }
    let advantages = (rewards - baselines) * is_weights
    if trainer.config.compute_variance_reduction {
        trainer.variance_after = compute_variance_tensor(advantages)
        trainer.variance_reduction_ratio =
            (trainer.variance_before - trainer.variance_after) /
            (trainer.variance_before + 1e-8)
    }
    if trainer.config.use_whitening {
        let adv_mean = advantages.mean()
        let adv_std = advantages.std()
        advantages = (advantages - adv_mean) / (adv_std + 1e-8)
    }
    return advantages
}

func (trainer: *tir_optimal_token_baseline_trainer) train_step(
    prompts: []tensor,
    responses: []tensor,
    rollout_log_probs: []tensor,
    rewards: []tensor
) -> (f32, f32, f32, f32) {
    let batch_size = prompts.len()
    let inputs: []tensor = []
    let all_tokens: []tensor = []
    let positions: []tensor = []
    for i in 0..batch_size {
        let input = concat(prompts[i], responses[i])
        inputs.push(input)
        all_tokens.push(responses[i])
        let seq_len = responses[i].shape[0]
        let pos = tensor_arange(seq_len)
        positions.push(pos)
    }
    let ref_log_probs: []tensor = []
    for input in inputs {
        let logits = trainer.reference_model.forward(input)
        let log_probs = log_softmax(logits, dim: -1)
        ref_log_probs.push(log_probs)
    }
    let total_policy_loss: f32 = 0.0
    let total_value_loss: f32 = 0.0
    let total_entropy: f32 = 0.0
    let total_is_weight: f32 = 0.0
    let num_updates = 0
    for epoch in 0..trainer.config.num_epochs {
        for i in 0..batch_size {
            let logits = trainer.policy_model.forward(inputs[i])
            let new_log_probs = log_softmax(logits, dim: -1)
            let log_ratio = new_log_probs - ref_log_probs[i]
            let ratio = exp(log_ratio)
            let is_weights = clamp(ratio, 1.0 / trainer.config.is_threshold, trainer.config.is_threshold)
            if trainer.config.use_is_batch_normalize {
                let mean_weight = is_weights.mean()
                is_weights = is_weights / (mean_weight + 1e-8)
            }
            trainer.update_is_weight_stats(is_weights)
            let advantages = trainer.compute_tir_advantages(
                all_tokens[i],
                rewards[i],
                is_weights,
                positions[i]
            )
            let policy_obj: Tensor
            if trainer.config.use_clipping {
                let old_log_probs = rollout_log_probs[i]
                let ratio = exp(new_log_probs - old_log_probs)
                let surr1 = ratio * advantages
                let surr2 = clamp(ratio, 1.0 - trainer.config.clip_epsilon, 1.0 + trainer.config.clip_epsilon) * advantages
                policy_obj = minimum(surr1, surr2)
            } else {
                policy_obj = new_log_probs * advantages
            }
            let policy_loss = -policy_obj.mean()
            let probs = exp(new_log_probs)
            let entropy = -(probs * new_log_probs).sum()
            let value_loss = tensor_zeros([1])
            if trainer.config.use_learned_baseline {
                let predicted_values = trainer.value_model.forward(all_tokens[i])
                value_loss = (predicted_values - rewards[i]).pow(2).mean()
            }
            let loss = policy_loss - trainer.config.entropy_coeff * entropy
            loss.backward()
            if trainer.config.use_learned_baseline {
                value_loss.backward()
            }
            total_policy_loss += policy_loss.item()
            total_value_loss += value_loss.item()
            total_entropy += entropy.item()
            total_is_weight += is_weights.mean().item()
            num_updates += 1
        }
        clip_grad_norm(trainer.policy_model.parameters(), trainer.config.max_grad_norm)
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
        if trainer.config.use_learned_baseline {
            clip_grad_norm(trainer.value_model.parameters(), trainer.config.max_grad_norm)
            trainer.value_optimizer.step()
            trainer.value_optimizer.zero_grad()
        }
    }
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        total_entropy / f32(num_updates),
        total_is_weight / f32(num_updates)
    )
}

func (trainer: *tir_optimal_token_baseline_trainer) update_is_weight_stats(is_weights: Tensor) {
    let values = is_weights.flatten()
    trainer.is_weight_stats.mean = values.mean().item()
    trainer.is_weight_stats.std = values.std().item()
    trainer.is_weight_stats.min = values.min().item()
    trainer.is_weight_stats.max = values.max().item()
    let clipped = ((is_weights < 1.0 / trainer.config.is_threshold) |
                   (is_weights > trainer.config.is_threshold)).to_float()
    trainer.is_weight_stats.clip_fraction = clipped.mean().item()
}

func (trainer: *tir_optimal_token_baseline_trainer) get_variance_reduction() -> f32 {
    return trainer.variance_reduction_ratio
}

func compute_variance_tensor(x: Tensor) -> f32 {
    let mean = x.mean()
    let variance = (x - mean).pow(2).mean()
    return variance.item()
}

func clamp(x: Tensor, min_val: f32, max_val: f32) -> Tensor {
    return maximum(minimum(x, max_val), min_val)
}

func minimum(x: Tensor, y: Tensor) -> Tensor {
    return where((x < y), x, y)
}

func where(condition: Tensor, x: Tensor, y: Tensor) -> Tensor {
    return condition.to_float() * x + (1.0 - condition.to_float()) * y
}

