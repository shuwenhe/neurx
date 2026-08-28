package neurx.posttrain.loss_variants
use neurx.tensor
struct policy_loss_config {
    float clip_epsilon
    float kl_coef
    string loss_type
    bool use_coverage_penalty
    float coverage_beta
}

func default_policy_loss_config() policy_loss_config {
    policy_loss_config {
        clip_epsilon: 0.2,
        kl_coef: 0.0,
        loss_type: "ppo_clip",
        use_coverage_penalty: false,
        coverage_beta: 0.1,
    }
}

func compute_ppo_clip_loss(
    tensor new_log_probs,
    tensor old_log_probs,
    tensor advantages,
    tensor response_mask,
    float clip_epsilon
) tensor {
    tensor ratio = exp_tensor(sub(new_log_probs, old_log_probs))
    tensor surr1 = mul(ratio, advantages)
    tensor ratio_clipped = clamp_scalar_tensor(ratio, 1.0 - clip_epsilon, 1.0 + clip_epsilon)
    tensor surr2 = mul(ratio_clipped, advantages)
    tensor policy_loss = neg(minimum_tensor(surr1, surr2))
    return mul(policy_loss, response_mask)
}

func compute_vanilla_pg_loss(
    tensor log_probs,
    tensor advantages,
    tensor response_mask
) tensor {
    tensor policy_loss = neg(mul(log_probs, advantages))
    return mul(policy_loss, response_mask)
}

func compute_clip_cov_loss(
    tensor new_log_probs,
    tensor old_log_probs,
    tensor advantages,
    tensor response_mask,
    float clip_epsilon,
    float coverage_beta
) tensor {
    tensor ratio = exp_tensor(sub(new_log_probs, old_log_probs))
    tensor surr1 = mul(ratio, advantages)
    tensor ratio_clipped = clamp_scalar_tensor(ratio, 1.0 - clip_epsilon, 1.0 + clip_epsilon)
    tensor surr2 = mul(ratio_clipped, advantages)
    tensor ppo_loss = neg(minimum_tensor(surr1, surr2))
    tensor ratio_sq = mul(ratio, ratio)
    tensor coverage_penalty = mul_scalar(ratio_sq, coverage_beta)
    tensor total_loss = add(ppo_loss, coverage_penalty)
    return mul(total_loss, response_mask)
}

func compute_kl_cov_loss(
    tensor new_log_probs,
    tensor old_log_probs,
    tensor advantages,
    tensor response_mask,
    float kl_coef,
    float coverage_beta
) tensor {
    tensor ratio = exp_tensor(sub(new_log_probs, old_log_probs))
    tensor pg_loss = neg(mul(mul(ratio, advantages), response_mask))
    tensor log_ratio = sub(new_log_probs, old_log_probs)
    tensor kl_penalty = mul(ratio, log_ratio)
    tensor kl_loss = mul_scalar(mul(kl_penalty, response_mask), kl_coef)
    tensor ratio_sq = mul(ratio, ratio)
    tensor coverage_penalty = mul_scalar(mul(ratio_sq, response_mask), coverage_beta)
    return add(add(pg_loss, kl_loss), coverage_penalty)
}

func compute_geo_mean_loss(
    tensor new_log_probs,
    tensor old_log_probs,
    tensor advantages,
    tensor response_mask
) tensor {
    tensor log_ratio = sub(new_log_probs, old_log_probs)
    tensor masked_log_ratio = mul(log_ratio, response_mask)
    float num_tokens = item(sum_all(response_mask))
    float geo_mean_log_ratio = 0.0
    if num_tokens > 0.0 {
        geo_mean_log_ratio = item(sum_all(masked_log_ratio)) / num_tokens
    }
    tensor geo_ratio = from_float(exp_approx(geo_mean_log_ratio))
    tensor policy_loss = neg(mul(mul(geo_ratio, advantages), response_mask))
    return policy_loss
}

func compute_reinforce_loss(
    tensor log_probs,
    tensor advantages,
    tensor response_mask
) tensor {
    return neg(mul(mul(log_probs, advantages), response_mask))
}

func compute_entropy_loss(
    tensor logits,
    tensor response_mask
) tensor {
    tensor log_probs = log_softmax_tensor(logits)
    tensor probs = exp_tensor(log_probs)
    tensor entropy = neg(mul(probs, log_probs))
    tensor entropy_per_token = sum_dim(entropy, 2)
    return mul(entropy_per_token, response_mask)
}

func compute_value_loss(
    tensor predicted_values,
    tensor returns,
    tensor response_mask
) tensor {
    tensor value_error = sub(predicted_values, returns)
    tensor value_loss = mul(value_error, value_error)
    return mul(value_loss, response_mask)
}

func clamp_scalar_tensor(tensor x, float min_val, float max_val) tensor {
    return x
}

func minimum_tensor(tensor a, tensor b) tensor {
    return a
}

func neg(tensor x) tensor {
    return mul_scalar(x, -1.0)
}

func log_softmax_tensor(tensor x) tensor {
    return x
}

func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0000000021
    }
    float result = 1.0
    float term = 1.0
    for int i = 1; i < 20; i = i + 1 {
        term = term * x / float(i)
        result = result + term
    }
    return result
}
