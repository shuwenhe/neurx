import "tensor/tensor.s"
func compute_rloo_advantages_vectorized(
    rewards: Tensor,
    response_mask: Tensor,
    use_whitening: bool
) -> Tensor {
    let batch_size = rewards.shape[0]
    let num_samples = rewards.shape[1]
    let seq_len = rewards.shape[2]
    let total_rewards = rewards.sum(dim: 1, keepdim: true)
    let total_counts = response_mask.sum(dim: 1, keepdim: true)
    let loo_baselines = (total_rewards - rewards) / (total_counts - 1.0 + 1e-8)
    let advantages = (rewards - loo_baselines) * response_mask
    if use_whitening {
        let flat_advantages = advantages.reshape([batch_size * num_samples, seq_len])
        let flat_mask = response_mask.reshape([batch_size * num_samples, seq_len])
        let valid_count = flat_mask.sum()
        let masked_advantages = flat_advantages * flat_mask
        let mean = masked_advantages.sum() / (valid_count + 1e-8)
        let variance = ((flat_advantages - mean).pow(2) * flat_mask).sum() / (valid_count + 1e-8)
        let std = sqrt(variance)
        advantages = (advantages - mean) / (std + 1e-8)
        advantages = advantages * response_mask
    }
    return advantages
}


func compute_rloo_loss_vectorized(
    log_probs: Tensor,
    rewards: Tensor,
    response_mask: Tensor,
    use_whitening: bool
) -> (tensor, tensor) {
    let advantages = compute_rloo_advantages_vectorized(rewards, response_mask, use_whitening)
    let policy_loss = -(log_probs * advantages * response_mask)
    let valid_count = response_mask.sum()
    let total_loss = policy_loss.sum() / (valid_count + 1e-8)
    return total_loss, advantages
}


func compute_grpo_advantages_vectorized(
    rewards: Tensor,
    response_mask: Tensor,
    use_whitening: bool,
    advantage_eps: f32
) -> Tensor {
    let batch_size = rewards.shape[0]
    let group_size = rewards.shape[1]
    let seq_len = rewards.shape[2]
    let valid_counts = response_mask.sum(dim: 1, keepdim: true)
    let masked_rewards = rewards * response_mask
    let group_mean = masked_rewards.sum(dim: 1, keepdim: true) / (valid_counts + 1e-8)
    let group_baseline = group_mean.expand([batch_size, group_size, seq_len])
    let advantages = (rewards - group_baseline) * response_mask
    if use_whitening {
        for b in 0..batch_size {
            let batch_advantages = advantages[b]
            let batch_mask = response_mask[b]
            let valid_count = batch_mask.sum()
            let masked_adv = batch_advantages * batch_mask
            let mean = masked_adv.sum() / (valid_count + 1e-8)
            let variance = ((batch_advantages - mean).pow(2) * batch_mask).sum() / (valid_count + 1e-8)
            let std = sqrt(variance)
            advantages[b] = (batch_advantages - mean) / (std + advantage_eps)
            advantages[b] = advantages[b] * batch_mask
        }
    }
    return advantages
}


func compute_grpo_loss_vectorized(
    log_probs: Tensor,
    ref_log_probs: Tensor,
    rewards: Tensor,
    response_mask: Tensor,
    clip_epsilon: f32,
    kl_coef: f32,
    use_whitening: bool,
    advantage_eps: f32
) -> (tensor, tensor, tensor) {
    let advantages = compute_grpo_advantages_vectorized(
        rewards,
        response_mask,
        use_whitening,
        advantage_eps
    )
    let log_ratio = log_probs - ref_log_probs
    let ratio = exp(log_ratio)
    let surr1 = ratio * advantages
    let surr2 = clamp(ratio, 1.0 - clip_epsilon, 1.0 + clip_epsilon) * advantages
    let clipped_obj = minimum(surr1, surr2)
    let policy_loss = -clipped_obj * response_mask
    let valid_count = response_mask.sum()
    let mean_policy_loss = policy_loss.sum() / (valid_count + 1e-8)
    let kl_div = (exp(ref_log_probs) * (ref_log_probs - log_probs)) * response_mask
    let mean_kl = kl_div.sum() / (valid_count + 1e-8)
    let total_loss = mean_policy_loss + kl_coef * mean_kl
    return total_loss, advantages, mean_kl
}


func stack_sequences(sequences: []tensor) -> Tensor {
    if sequences.len() == 0 {
        return tensor_zeros([0, 0])
    }
    let batch_size = sequences.len()
    let seq_len = sequences[0].shape[0]
    let stacked = tensor_zeros([batch_size, seq_len])
    for i in 0..batch_size {
        stacked[i] = sequences[i]
    }
    return stacked
}


func stack_grouped_sequences(grouped_sequences: [][]tensor) -> Tensor {
    if grouped_sequences.len() == 0 {
        return tensor_zeros([0, 0, 0])
    }
    let batch_size = grouped_sequences.len()
    let group_size = grouped_sequences[0].len()
    let seq_len = grouped_sequences[0][0].shape[0]
    let stacked = tensor_zeros([batch_size, group_size, seq_len])
    for b in 0..batch_size {
        for g in 0..group_size {
            stacked[b][g] = grouped_sequences[b][g]
        }
    }
    return stacked
}


func unstack_tensor(stacked: Tensor) -> []tensor {
    let batch_size = stacked.shape[0]
    let sequences: []tensor = []
    for i in 0..batch_size {
        sequences.push(stacked[i])
    }
    return sequences
}


func compute_batch_statistics(
    values: Tensor,
    mask: Tensor,
    compute_variance: bool
) -> (f32, f32, f32, f32) {
    let masked_values = values * mask
    let valid_count = mask.sum()
    let mean = masked_values.sum() / (valid_count + 1e-8)
    let large_neg = tensor_full_like(values, -1e10)
    let large_pos = tensor_full_like(values, 1e10)
    let values_for_max = where(mask.to_bool(), values, large_neg)
    let values_for_min = where(mask.to_bool(), values, large_pos)
    let max_val = values_for_max.max()
    let min_val = values_for_min.min()
    let variance: f32 = 0.0
    if compute_variance {
        let squared_diff = ((values - mean).pow(2) * mask)
        variance = squared_diff.sum() / (valid_count + 1e-8)
    }
    return mean.item(), variance, min_val.item(), max_val.item()
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


func sqrt(x: Tensor) -> Tensor {
    return x.pow(0.5)
}

