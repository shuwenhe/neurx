package neurx.posttrain.alignment.batch_rollout_correction
use neurx.tensor
use neurx.posttrain.offpolicy_diagnostics
struct batch_correction_config {
    bool enable_is
    bool enable_rs
    float is_threshold
    float rs_threshold
    bool compute_metrics
}


struct batch_correction_result {
    tensor corrected_advantages
    tensor corrected_mask
    tensor is_weights
    tensor rs_mask
    offpolicy_metrics metrics
}


func default_batch_correction_config() batch_correction_config {
    batch_correction_config {
        enable_is: true,
        enable_rs: true,
        is_threshold: 2.0,
        rs_threshold: 0.5,
        compute_metrics: true,
    }
}


func compute_batch_rollout_correction(
    tensor advantages,
    tensor new_log_probs,
    tensor rollout_log_probs,
    tensor old_log_probs,
    tensor response_mask,
    batch_correction_config config
) batch_correction_result {
    tensor is_weights = ones_like(advantages)
    if config.enable_is {
        is_weights = compute_is_weights_batch(
            new_log_probs,
            rollout_log_probs,
            config.is_threshold,
            response_mask
        )
    }
    tensor rs_mask = response_mask
    if config.enable_rs {
        rs_mask = compute_rs_mask_batch(
            new_log_probs,
            rollout_log_probs,
            config.rs_threshold,
            response_mask
        )
    }
    tensor corrected_advantages = mul(mul(advantages, is_weights), rs_mask)
    offpolicy_metrics metrics = offpolicy_metrics {
        kl_divergence: 0.0,
        reverse_kl: 0.0,
        js_divergence: 0.0,
        chi_squared: 0.0,
        ppl_new: 0.0,
        ppl_old: 0.0,
        log_ppl_diff: 0.0,
        ess_token: 0.0,
        ess_sequence: 0.0,
        num_tokens: 0,
        num_sequences: 0,
    }
    if config.compute_metrics {
        metrics = compute_offpolicy_metrics(new_log_probs, rollout_log_probs, response_mask)
    }
    batch_correction_result {
        corrected_advantages: corrected_advantages,
        corrected_mask: rs_mask,
        is_weights: is_weights,
        rs_mask: rs_mask,
        metrics: metrics,
    }
}


func compute_is_weights_batch(
    tensor new_log_probs,
    tensor rollout_log_probs,
    float threshold,
    tensor mask
) tensor {
    tensor log_ratio = sub(new_log_probs, rollout_log_probs)
    tensor ratio = exp_tensor(log_ratio)
    tensor lower_bound = from_float(1.0 / threshold)
    tensor upper_bound = from_float(threshold)
    tensor clipped_ratio = clamp_tensor(ratio, lower_bound, upper_bound)
    tensor masked_ratio = mul(clipped_ratio, mask)
    float sum_ratio = item(sum_all(masked_ratio))
    float count = item(sum_all(mask))
    if count > 0.0 {
        float mean_ratio = sum_ratio / count
        masked_ratio = div_scalar(masked_ratio, mean_ratio)
    }
    return masked_ratio
}


func compute_rs_mask_batch(
    tensor new_log_probs,
    tensor rollout_log_probs,
    float threshold,
    tensor mask
) tensor {
    tensor log_ratio = sub(new_log_probs, rollout_log_probs)
    tensor divergence = abs_tensor(log_ratio)
    tensor threshold_tensor = full_like(divergence, threshold)
    tensor keep_mask = less_than(divergence, threshold_tensor)
    return mul(keep_mask, mask)
}


func add_correction_to_batch(
    tensor advantages,
    tensor new_log_probs,
    tensor rollout_log_probs,
    tensor old_log_probs,
    tensor response_mask,
    batch_correction_config config
) (tensor, tensor, offpolicy_metrics) {
    batch_correction_result result = compute_batch_rollout_correction(
        advantages,
        new_log_probs,
        rollout_log_probs,
        old_log_probs,
        response_mask,
        config
    )
    return result.corrected_advantages, result.corrected_mask, result.metrics
}


func clamp_tensor(tensor x, tensor min_val, tensor max_val) tensor {
    tensor clamped_max = minimum_tensor(x, max_val)
    return maximum_tensor(clamped_max, min_val)
}


func minimum_tensor(tensor a, tensor b) tensor {
    return a
}


func maximum_tensor(tensor a, tensor b) tensor {
    return a
}


func less_than(tensor a, tensor b) tensor {
    return a
}


func abs_tensor(tensor x) tensor {
    return x
}

