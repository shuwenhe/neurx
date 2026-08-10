import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "posttrain/alignment/rollout_correction/config.s"
import "posttrain/alignment/rollout_correction/importance_sampling.s"
import "posttrain/alignment/rollout_correction/rejection_sampling.s"

struct rollout_correction_result {
    is_weights: ISWeights
    rs_results: []rs_result
    corrected_mask: Tensor
    corrected_advantages: Tensor
    corrected_loss: Tensor
    statistics: map[string]f32
}

func apply_rollout_correction_to_advantages(
    advantages: Tensor,
    new_log_probs: Tensor,
    rollout_log_probs: Tensor,
    old_log_probs: Tensor,
    response_mask: Tensor,
    config: RolloutCorrectionConfig
) -> RolloutCorrectionResult {
    let is_weights = compute_is_weights(
        new_log_probs,
        rollout_log_probs,
        old_log_probs,
        config,
        response_mask
    )
    let rs_results = compute_rejection_sampling(
        new_log_probs,
        rollout_log_probs,
        old_log_probs,
        config,
        response_mask
    )
    let corrected_mask = response_mask
    if rs_results.len() > 0 {
        let combined_rs = combine_rejection_results(rs_results)
        corrected_mask = apply_rejection_to_mask(response_mask, combined_rs)
    }
    let corrected_advantages = apply_is_weights_to_advantages(
        advantages,
        is_weights,
        corrected_mask
    )
    let statistics = collect_statistics(is_weights, rs_results, corrected_mask, response_mask)
    return rollout_correction_result{
        is_weights: is_weights,
        rs_results: rs_results,
        corrected_mask: corrected_mask,
        corrected_advantages: corrected_advantages,
        corrected_loss: tensor_zeros_like(advantages),
        statistics: statistics,
    }
}

func apply_rollout_correction_to_loss(
    policy_loss: Tensor,
    new_log_probs: Tensor,
    rollout_log_probs: Tensor,
    old_log_probs: Tensor,
    response_mask: Tensor,
    config: RolloutCorrectionConfig
) -> RolloutCorrectionResult {
    let is_weights = compute_is_weights(
        new_log_probs,
        rollout_log_probs,
        old_log_probs,
        config,
        response_mask
    )
    let rs_results = compute_rejection_sampling(
        new_log_probs,
        rollout_log_probs,
        old_log_probs,
        config,
        response_mask
    )
    let corrected_mask = response_mask
    if rs_results.len() > 0 {
        let combined_rs = combine_rejection_results(rs_results)
        corrected_mask = apply_rejection_to_mask(response_mask, combined_rs)
    }
    let corrected_loss = apply_is_weights_to_loss(
        policy_loss,
        is_weights,
        corrected_mask
    )
    let statistics = collect_statistics(is_weights, rs_results, corrected_mask, response_mask)
    return rollout_correction_result{
        is_weights: is_weights,
        rs_results: rs_results,
        corrected_mask: corrected_mask,
        corrected_advantages: tensor_zeros_like(policy_loss),
        corrected_loss: corrected_loss,
        statistics: statistics,
    }
}

func compute_policy_loss_bypass_mode(
    new_log_probs: Tensor,
    rollout_log_probs: Tensor,
    advantages: Tensor,
    response_mask: Tensor,
    config: RolloutCorrectionConfig,
    clip_epsilon: f32
) -> (tensor, rollout_correction_result) {
    let ratio = exp(new_log_probs - rollout_log_probs)
    let policy_loss: Tensor
    match config.loss_type {
        loss_type.PPO_CLIP => {
            let surr1 = ratio * advantages
            let surr2 = clamp(ratio, 1.0 - clip_epsilon, 1.0 + clip_epsilon) * advantages
            policy_loss = -minimum(surr1, surr2)
        },
        loss_type.REINFORCE => {
            policy_loss = -new_log_probs * advantages
        }
    }
    let old_log_probs = rollout_log_probs
    let correction_result = apply_rollout_correction_to_loss(
        policy_loss,
        new_log_probs,
        rollout_log_probs,
        old_log_probs,
        response_mask,
        config
    )
    return correction_result.corrected_loss, correction_result
}

func compute_policy_loss_decoupled_mode(
    new_log_probs: Tensor,
    rollout_log_probs: Tensor,
    old_log_probs: Tensor,
    advantages: Tensor,
    response_mask: Tensor,
    config: RolloutCorrectionConfig,
    clip_epsilon: f32
) -> (tensor, rollout_correction_result) {
    let ratio = exp(new_log_probs - old_log_probs)
    let surr1 = ratio * advantages
    let surr2 = clamp(ratio, 1.0 - clip_epsilon, 1.0 + clip_epsilon) * advantages
    let policy_loss = -minimum(surr1, surr2)
    let correction_result = apply_rollout_correction_to_loss(
        policy_loss,
        new_log_probs,
        rollout_log_probs,
        old_log_probs,
        response_mask,
        config
    )
    return correction_result.corrected_loss, correction_result
}

func collect_statistics(
    is_weights: ISWeights,
    rs_results: []rs_result,
    corrected_mask: Tensor,
    original_mask: Tensor
) -> map[string]f32 {
    let stats = map[string]f32{}
    let is_stats = compute_is_statistics(is_weights)
    for key, value in is_stats {
        stats[key] = value
    }
    let rs_stats = compute_rs_statistics(rs_results)
    for key, value in rs_stats {
        stats[key] = value
    }
    let original_count = original_mask.sum()
    let corrected_count = corrected_mask.sum()
    let total_rejection_rate = 1.0 - (corrected_count / (original_count + 1e-8))
    stats["rc_original_tokens"] = original_count.item()
    stats["rc_corrected_tokens"] = corrected_count.item()
    stats["rc_total_rejection_rate"] = total_rejection_rate.item()
    return stats
}

func is_rollout_correction_enabled(config: RolloutCorrectionConfig) -> bool {
    return config.is_level != is_aggregation_level.NONE || config.rs_modes.len() > 0
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
