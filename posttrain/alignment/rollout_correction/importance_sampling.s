import "tensor/tensor.s"
import "posttrain/alignment/rollout_correction/config.s"
struct ISWeights {
    weights: Tensor
    level: ISAggregationLevel
    is_clipped: Tensor
    clip_fraction: f32
    mean_weight: f32
    max_weight: f32
    min_weight: f32
}
func compute_token_is_weights(
    new_log_probs: Tensor,
    rollout_log_probs: Tensor,
    threshold: ISThreshold,
    response_mask: Tensor
) -> ISWeights {
    let batch_size = new_log_probs.shape[0]
    let seq_len = new_log_probs.shape[1]
    let log_ratio = new_log_probs - rollout_log_probs
    let ratio = exp(log_ratio)
    let clipped_weights: Tensor
    let is_clipped: Tensor
    if threshold.is_icepop {
        let below_lower = (ratio < threshold.lower).to_float()
        let above_upper = (ratio > threshold.upper).to_float()
        let outside_range = below_lower + above_upper
        clipped_weights = ratio * (1.0 - outside_range)
        is_clipped = outside_range.to_bool()
    } else {
        clipped_weights = clamp(ratio, threshold.lower, threshold.upper)
        is_clipped = ((ratio < threshold.lower) | (ratio > threshold.upper))
    }
    clipped_weights = clipped_weights * response_mask
    let valid_count = response_mask.sum()
    let clip_fraction = (is_clipped.to_float() * response_mask).sum() / (valid_count + 1e-8)
    let masked_weights = clipped_weights * response_mask
    let mean_weight = masked_weights.sum() / (valid_count + 1e-8)
    let max_weight = masked_weights.max()
    let min_weight = masked_weights.min()
    return ISWeights{
        weights: clipped_weights,
        level: ISAggregationLevel.TOKEN,
        is_clipped: is_clipped,
        clip_fraction: clip_fraction.item(),
        mean_weight: mean_weight.item(),
        max_weight: max_weight.item(),
        min_weight: min_weight.item(),
    }
}
func compute_sequence_is_weights(
    new_log_probs: Tensor,
    rollout_log_probs: Tensor,
    threshold: ISThreshold,
    response_mask: Tensor
) -> ISWeights {
    let batch_size = new_log_probs.shape[0]
    let seq_len = new_log_probs.shape[1]
    let log_ratio = new_log_probs - rollout_log_probs
    let masked_log_ratio = log_ratio * response_mask
    let seq_log_ratio = masked_log_ratio.sum(dim: 1)
    let seq_ratio = exp(seq_log_ratio)
    let clipped_weights: Tensor
    let is_clipped: Tensor
    if threshold.is_icepop {
        let below_lower = (seq_ratio < threshold.lower).to_float()
        let above_upper = (seq_ratio > threshold.upper).to_float()
        let outside_range = below_lower + above_upper
        clipped_weights = seq_ratio * (1.0 - outside_range)
        is_clipped = outside_range.to_bool()
    } else {
        clipped_weights = clamp(seq_ratio, threshold.lower, threshold.upper)
        is_clipped = ((seq_ratio < threshold.lower) | (seq_ratio > threshold.upper))
    }
    let clip_fraction = is_clipped.to_float().mean()
    let mean_weight = clipped_weights.mean()
    let max_weight = clipped_weights.max()
    let min_weight = clipped_weights.min()
    return ISWeights{
        weights: clipped_weights,
        level: ISAggregationLevel.SEQUENCE,
        is_clipped: is_clipped,
        clip_fraction: clip_fraction.item(),
        mean_weight: mean_weight.item(),
        max_weight: max_weight.item(),
        min_weight: min_weight.item(),
    }
}
func batch_normalize_is_weights(is_weights: ISWeights) -> ISWeights {
    let normalized_weights: Tensor
    if is_weights.level == ISAggregationLevel.TOKEN {
        let mean = is_weights.weights.mean()
        normalized_weights = is_weights.weights / (mean + 1e-8)
    } else if is_weights.level == ISAggregationLevel.SEQUENCE {
        let mean = is_weights.weights.mean()
        normalized_weights = is_weights.weights / (mean + 1e-8)
    } else {
        normalized_weights = is_weights.weights
    }
    return ISWeights{
        weights: normalized_weights,
        level: is_weights.level,
        is_clipped: is_weights.is_clipped,
        clip_fraction: is_weights.clip_fraction,
        mean_weight: 1.0,
        max_weight: is_weights.max_weight,
        min_weight: is_weights.min_weight,
    }
}
func compute_is_weights(
    new_log_probs: Tensor,
    rollout_log_probs: Tensor,
    old_log_probs: Tensor,
    config: RolloutCorrectionConfig,
    response_mask: Tensor
) -> ISWeights {
    let reference_log_probs: Tensor
    if config.bypass_mode {
        reference_log_probs = rollout_log_probs
    } else {
        reference_log_probs = old_log_probs
    }
    let is_weights: ISWeights
    match config.is_level {
        ISAggregationLevel.NONE => {
            let weights = tensor_ones_like(new_log_probs)
            is_weights = ISWeights{
                weights: weights,
                level: ISAggregationLevel.NONE,
                is_clipped: tensor_zeros_like(new_log_probs).to_bool(),
                clip_fraction: 0.0,
                mean_weight: 1.0,
                max_weight: 1.0,
                min_weight: 1.0,
            }
        },
        ISAggregationLevel.TOKEN => {
            is_weights = compute_token_is_weights(
                new_log_probs,
                reference_log_probs,
                config.is_threshold,
                response_mask
            )
        },
        ISAggregationLevel.SEQUENCE => {
            is_weights = compute_sequence_is_weights(
                new_log_probs,
                reference_log_probs,
                config.is_threshold,
                response_mask
            )
        }
    }
    if config.is_batch_normalize && config.is_level != ISAggregationLevel.NONE {
        is_weights = batch_normalize_is_weights(is_weights)
    }
    return is_weights
}
func apply_is_weights_to_loss(
    loss: Tensor,
    is_weights: ISWeights,
    response_mask: Tensor
) -> Tensor {
    if is_weights.level == ISAggregationLevel.TOKEN {
        return loss * is_weights.weights * response_mask
    } else if is_weights.level == ISAggregationLevel.SEQUENCE {
        let batch_size = loss.shape[0]
        let seq_len = loss.shape[1]
        let expanded_weights = is_weights.weights.unsqueeze(1).expand([batch_size, seq_len])
        return loss * expanded_weights * response_mask
    } else {
        return loss * response_mask
    }
}
func apply_is_weights_to_advantages(
    advantages: Tensor,
    is_weights: ISWeights,
    response_mask: Tensor
) -> Tensor {
    return apply_is_weights_to_loss(advantages, is_weights, response_mask)
}
func compute_is_statistics(is_weights: ISWeights) -> map[string]f32 {
    let stats = map[string]f32{}
    stats["is_mean"] = is_weights.mean_weight
    stats["is_max"] = is_weights.max_weight
    stats["is_min"] = is_weights.min_weight
    stats["is_clip_fraction"] = is_weights.clip_fraction
    return stats
}
func clamp(x: Tensor, min_val: f32, max_val: f32) -> Tensor {
    return maximum(minimum(x, max_val), min_val)
}
