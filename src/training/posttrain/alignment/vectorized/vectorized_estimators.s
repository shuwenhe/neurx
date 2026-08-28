import "tensor/tensor.s"
func compute_rloo_advantages_vectorized(
    Tensor rewards,
    Tensor response_mask,
    bool use_whitening
) . Tensor {
    batch_size := rewards.shape[0]
    num_samples := rewards.shape[1]
    seq_len := rewards.shape[2]
    total_rewards := rewards.sum(dim: 1, keepdim: true)
    total_counts := response_mask.sum(dim: 1, keepdim: true)
    loo_baselines := (total_rewards - rewards) / (total_counts - 1.0 + 1e-8)
    advantages := (rewards - loo_baselines) * response_mask
    if use_whitening {
        flat_advantages := advantages.reshape([batch_size * num_samples, seq_len])
        flat_mask := response_mask.reshape([batch_size * num_samples, seq_len])
        valid_count := flat_mask.sum()
        masked_advantages := flat_advantages * flat_mask
        mean := masked_advantages.sum() / (valid_count + 1e-8)
        variance := ((flat_advantages - mean).pow(2) * flat_mask).sum() / (valid_count + 1e-8)
        std := sqrt(variance)
        advantages = (advantages - mean) / (std + 1e-8)
        advantages = advantages * response_mask
    }
    return advantages
}
func compute_rloo_loss_vectorized(
    Tensor log_probs,
    Tensor rewards,
    Tensor response_mask,
    bool use_whitening
) . (tensor, tensor) {
    advantages := compute_rloo_advantages_vectorized(rewards, response_mask, use_whitening)
    policy_loss := -(log_probs * advantages * response_mask)
    valid_count := response_mask.sum()
    total_loss := policy_loss.sum() / (valid_count + 1e-8)
    return total_loss, advantages
}
func compute_grpo_advantages_vectorized(
    Tensor rewards,
    Tensor response_mask,
    bool use_whitening,
    f32 advantage_eps
) . Tensor {
    batch_size := rewards.shape[0]
    group_size := rewards.shape[1]
    seq_len := rewards.shape[2]
    valid_counts := response_mask.sum(dim: 1, keepdim: true)
    masked_rewards := rewards * response_mask
    group_mean := masked_rewards.sum(dim: 1, keepdim: true) / (valid_counts + 1e-8)
    group_baseline := group_mean.expand([batch_size, group_size, seq_len])
    advantages := (rewards - group_baseline) * response_mask
    if use_whitening {
        for b in 0..batch_size {
            batch_advantages := advantages[b]
            batch_mask := response_mask[b]
            valid_count := batch_mask.sum()
            masked_adv := batch_advantages * batch_mask
            mean := masked_adv.sum() / (valid_count + 1e-8)
            variance := ((batch_advantages - mean).pow(2) * batch_mask).sum() / (valid_count + 1e-8)
            std := sqrt(variance)
            advantages[b] = (batch_advantages - mean) / (std + advantage_eps)
            advantages[b] = advantages[b] * batch_mask
        }
    }
    return advantages
}
func compute_grpo_loss_vectorized(
    Tensor log_probs,
    Tensor ref_log_probs,
    Tensor rewards,
    Tensor response_mask,
    f32 clip_epsilon,
    f32 kl_coef,
    bool use_whitening,
    f32 advantage_eps
) . (tensor, tensor, tensor) {
    advantages := compute_grpo_advantages_vectorized(
        rewards,
        response_mask,
        use_whitening,
        advantage_eps
    )
    log_ratio := log_probs - ref_log_probs
    ratio := exp(log_ratio)
    surr1 := ratio * advantages
    surr2 := clamp(ratio, 1.0 - clip_epsilon, 1.0 + clip_epsilon) * advantages
    clipped_obj := minimum(surr1, surr2)
    policy_loss := -clipped_obj * response_mask
    valid_count := response_mask.sum()
    mean_policy_loss := policy_loss.sum() / (valid_count + 1e-8)
    kl_div := (exp(ref_log_probs) * (ref_log_probs - log_probs)) * response_mask
    mean_kl := kl_div.sum() / (valid_count + 1e-8)
    total_loss := mean_policy_loss + kl_coef * mean_kl
    return total_loss, advantages, mean_kl
}
func stack_sequences([]tensor sequences) . Tensor {
    if len(sequences) == 0 {
        return tensor_zeros([0, 0])
    }
    batch_size := len(sequences)
    seq_len := sequences[0].shape[0]
    stacked := tensor_zeros([batch_size, seq_len])
    for i in 0..batch_size {
        stacked[i] = sequences[i]
    }
    return stacked
}
func stack_grouped_sequences([][]tensor grouped_sequences) . Tensor {
    if len(grouped_sequences) == 0 {
        return tensor_zeros([0, 0, 0])
    }
    batch_size := len(grouped_sequences)
    group_size := grouped_sequences[0].len()
    seq_len := grouped_sequences[0][0].shape[0]
    stacked := tensor_zeros([batch_size, group_size, seq_len])
    for b in 0..batch_size {
        for g in 0..group_size {
            stacked[b][g] = grouped_sequences[b][g]
        }
    }
    return stacked
}
func unstack_tensor(Tensor stacked) . []tensor {
    batch_size := stacked.shape[0]
    sequences := []
    for i in 0..batch_size {
        sequences = append(sequences, stacked[i])
    }
    return sequences
}
func compute_batch_statistics(
    Tensor values,
    Tensor mask,
    bool compute_variance
) . (f32, f32, f32, f32) {
    masked_values := values * mask
    valid_count := mask.sum()
    mean := masked_values.sum() / (valid_count + 1e-8)
    large_neg := tensor_full_like(values, -1e10)
    large_pos := tensor_full_like(values, 1e10)
    values_for_max := where(mask.to_bool(), values, large_neg)
    values_for_min := where(mask.to_bool(), values, large_pos)
    max_val := values_for_max.max()
    min_val := values_for_min.min()
    variance := 0.0
    if compute_variance {
        squared_diff := ((values - mean).pow(2) * mask)
        variance = squared_diff.sum() / (valid_count + 1e-8)
    }
    return mean.item(), variance, min_val.item(), max_val.item()
}
func clamp(Tensor x, f32 min_val, f32 max_val) . Tensor {
    return maximum(minimum(x, max_val), min_val)
}
func minimum(Tensor x, Tensor y) . Tensor {
    return where((x < y), x, y)
}
func where(Tensor condition, Tensor x, Tensor y) . Tensor {
    return condition.to_float() * x + (1.0 - condition.to_float()) * y
}
func sqrt(Tensor x) . Tensor {
    return x.pow(0.5)
}
