import "tensor/tensor.s"
import "src/training/posttrain/alignment/rollout_correction/config.s"
struct rs_result {
    Tensor rejection_mask
    Tensor rejection_scores
    f32 rejection_rate
    f32 mean_score
    f32 max_score
}

func compute_k1_divergence(
    Tensor new_log_probs,
    Tensor rollout_log_probs
) . Tensor {
    log_ratio := new_log_probs - rollout_log_probs
    ratio := exp(log_ratio)
    neg_log_r := -log(clamp(ratio, 1e-10, 1e10))
    return neg_log_r
}

func compute_k2_divergence(
    Tensor new_log_probs,
    Tensor rollout_log_probs
) . Tensor {
    log_ratio := new_log_probs - rollout_log_probs
    return 0.5 * (log_ratio * log_ratio)
}

func compute_k3_divergence(
    Tensor new_log_probs,
    Tensor rollout_log_probs
) . Tensor {
    log_ratio := new_log_probs - rollout_log_probs
    ratio := exp(log_ratio)
    return ratio - 1.0 - log_ratio
}

func compute_token_rejection(
    Tensor new_log_probs,
    Tensor rollout_log_probs,
    RejectionMode mode,
    RSThreshold threshold,
    Tensor response_mask
) . RSResult {
    divergence := Tensor()
    match mode {
        rejection_mode.TOKEN_K1 => {
            divergence = compute_k1_divergence(new_log_probs, rollout_log_probs)
        },
        rejection_mode.TOKEN_K2 => {
            divergence = compute_k2_divergence(new_log_probs, rollout_log_probs)
        },
        rejection_mode.TOKEN_K3 => {
            divergence = compute_k3_divergence(new_log_probs, rollout_log_probs)
        },
        _ => {
            panic("Invalid token-level rejection mode")
        }
    }
    masked_divergence := divergence * response_mask
    rejection_mask := Tensor()
    if mode == rejection_mode.TOKEN_K1 {
        ratio := exp(new_log_probs - rollout_log_probs)
        rejection_mask = ((ratio < threshold.lower) | (ratio > threshold.upper))
    } else {
        rejection_mask = (masked_divergence > threshold.upper)
    }
    valid_count := response_mask.sum()
    rejection_rate := (rejection_mask.to_float() * response_mask).sum() / (valid_count + 1e-8)
    mean_score := masked_divergence.sum() / (valid_count + 1e-8)
    max_score := masked_divergence.max()
    return rs_result{
        rejection_mask: rejection_mask,
        rejection_scores: masked_divergence,
        rejection_rate: rejection_rate.item(),
        mean_score: mean_score.item(),
        max_score: max_score.item(),
    }
}

func compute_sequence_rejection(
    Tensor new_log_probs,
    Tensor rollout_log_probs,
    RejectionMode mode,
    RSThreshold threshold,
    Tensor response_mask
) . RSResult {
    batch_size := new_log_probs.shape[0]
    seq_len := new_log_probs.shape[1]
    token_divergence := Tensor()
    match mode {
        rejection_mode.SEQ_SUM_K1 | rejection_mode.SEQ_MEAN_K1 | rejection_mode.SEQ_MAX_K2 => {
            if mode == rejection_mode.SEQ_MEAN_K1 {
                token_divergence = compute_k1_divergence(new_log_probs, rollout_log_probs)
            } else {
                token_divergence = compute_k1_divergence(new_log_probs, rollout_log_probs)
            }
        },
        rejection_mode.SEQ_SUM_K2 | rejection_mode.SEQ_MEAN_K2 | rejection_mode.SEQ_MAX_K2 => {
            token_divergence = compute_k2_divergence(new_log_probs, rollout_log_probs)
        },
        rejection_mode.SEQ_SUM_K3 | rejection_mode.SEQ_MEAN_K3 | rejection_mode.SEQ_MAX_K3 => {
            token_divergence = compute_k3_divergence(new_log_probs, rollout_log_probs)
        },
        _ => {
            panic("Invalid sequence-level rejection mode")
        }
    }
    masked_divergence := token_divergence * response_mask
    seq_divergence := Tensor()
    match mode {
        rejection_mode.SEQ_SUM_K1 | rejection_mode.SEQ_SUM_K2 | rejection_mode.SEQ_SUM_K3 => {
            seq_divergence = masked_divergence.sum(dim: 1)
        },
        rejection_mode.SEQ_MEAN_K1 | rejection_mode.SEQ_MEAN_K2 | rejection_mode.SEQ_MEAN_K3 => {
            seq_len_per_sample := response_mask.sum(dim: 1)
            seq_divergence = masked_divergence.sum(dim: 1) / (seq_len_per_sample + 1e-8)
        },
        rejection_mode.SEQ_MAX_K2 | rejection_mode.SEQ_MAX_K3 => {
            large_neg := tensor_full_like(masked_divergence, -1e10)
            divergence_for_max := where(response_mask.to_bool(), masked_divergence, large_neg)
            seq_divergence = divergence_for_max.max(dim: 1)
        },
        _ => {
            seq_divergence = tensor_zeros([batch_size])
        }
    }
    rejection_mask := Tensor()
    if mode == rejection_mode.SEQ_MEAN_K1 || mode == rejection_mode.SEQ_SUM_K1 {
        log_ratio_sum := (new_log_probs - rollout_log_probs) * response_mask
        seq_log_ratio := log_ratio_sum.sum(dim: 1) / (response_mask.sum(dim: 1) + 1e-8)
        ratio := exp(seq_log_ratio)
        rejection_mask = ((ratio < threshold.lower) | (ratio > threshold.upper))
    } else {
        rejection_mask = (seq_divergence > threshold.upper)
    }
    expanded_rejection_mask := rejection_mask.unsqueeze(1).expand([batch_size, seq_len])
    rejection_rate := rejection_mask.to_float().mean()
    mean_score := seq_divergence.mean()
    max_score := seq_divergence.max()
    return rs_result{
        rejection_mask: expanded_rejection_mask,
        rejection_scores: seq_divergence,
        rejection_rate: rejection_rate.item(),
        mean_score: mean_score.item(),
        max_score: max_score.item(),
    }
}

func compute_rejection_sampling(
    Tensor new_log_probs,
    Tensor rollout_log_probs,
    Tensor old_log_probs,
    RolloutCorrectionConfig config,
    Tensor response_mask
) . []rs_result {
    results := []
    if len(config.rs_modes) == 0 {
        return results
    }
    reference_log_probs := Tensor()
    if config.bypass_mode {
        reference_log_probs = rollout_log_probs
    } else {
        reference_log_probs = old_log_probs
    }
    for i in len(0..config.rs_modes) {
        mode := config.rs_modes[i]
        threshold := config.rs_thresholds[i]
        result := RSResult()
        match mode {
            rejection_mode.TOKEN_K1 | rejection_mode.TOKEN_K2 | rejection_mode.TOKEN_K3 => {
                result = compute_token_rejection(
                    new_log_probs,
                    reference_log_probs,
                    mode,
                    threshold,
                    response_mask
                )
            },
            _ => {
                result = compute_sequence_rejection(
                    new_log_probs,
                    reference_log_probs,
                    mode,
                    threshold,
                    response_mask
                )
            }
        }
        results = append(results, result)
    }
    return results
}

func combine_rejection_results([]rs_result results) . RSResult {
    if len(results) == 0 {
        return rs_result{
            rejection_mask: tensor_zeros([1, 1]).to_bool(),
            rejection_scores: tensor_zeros([1, 1]),
            rejection_rate: 0.0,
            mean_score: 0.0,
            max_score: 0.0,
        }
    }
    if len(results) == 1 {
        return results[0]
    }
    combined_mask := results[0].rejection_mask
    for i in len(1..results) {
        combined_mask = combined_mask | results[i].rejection_mask
    }
    total_rejection_rate := 0.0
    total_mean_score := 0.0
    max_score := results[0].max_score
    for result in results {
        total_rejection_rate += result.rejection_rate
        total_mean_score += result.mean_score
        if result.max_score > max_score {
            max_score = result.max_score
        }
    }
    return rs_result{
        rejection_mask: combined_mask,
        rejection_scores: results[0].rejection_scores,
        rejection_rate: combined_mask.to_float().mean().item(),
        mean_score: total_mean_score / f32(len(results)),
        max_score: max_score,
    }
}

func apply_rejection_to_mask(
    Tensor response_mask,
    RSResult rejection_result
) . Tensor {
    return response_mask * (1.0 - rejection_result.rejection_mask.to_float())
}

func compute_rs_statistics([]rs_result results) . map[string]f32 {
    stats := map[string]f32{}
    for i in len(0..results) {
        prefix := f"rs_mode_{i}"
        stats[prefix + "_rejection_rate"] = results[i].rejection_rate
        stats[prefix + "_mean_score"] = results[i].mean_score
        stats[prefix + "_max_score"] = results[i].max_score
    }
    if len(results) > 0 {
        combined := combine_rejection_results(results)
        stats["rs_combined_rejection_rate"] = combined.rejection_rate
    }
    return stats
}

func clamp(Tensor x, f32 min_val, f32 max_val) . Tensor {
    return maximum(minimum(x, max_val), min_val)
}

func where(Tensor condition, Tensor x, Tensor y) . Tensor {
    return condition.to_float() * x + (1.0 - condition.to_float()) * y
}
