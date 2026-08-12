package neurx.posttrain.alignment.dppo
use neurx.tensor
use neurx.posttrain.alignment.loss_aggregation
struct dppo_config {
    float clip_divergence_low
    float clip_divergence_high
    float clip_ratio_c
    string loss_agg_mode
}

struct dppo_result {
    tensor pg_loss
    float pg_clipfrac
    float pg_clipfrac_lower
    float ppo_kl
}

func default_dppo_config() dppo_config {
    dppo_config {
        clip_divergence_low: 0.2,
        clip_divergence_high: 0.2,
        clip_ratio_c: 20.0,
        loss_agg_mode: "token-mean",
    }
}

func compute_dppo_tv_policy_loss(
    tensor old_log_prob,
    tensor log_prob,
    tensor advantages,
    tensor response_mask,
    dppo_config config
) dppo_result {
    tensor negative_approx_kl = sub(log_prob, old_log_prob)
    negative_approx_kl = clamp_range(negative_approx_kl, -20.0, 20.0)
    tensor ratio = exp_tensor(negative_approx_kl)
    float ppo_kl = item(masked_mean(neg(negative_approx_kl), response_mask))
    tensor truncated_ratio = clamp_max(ratio, config.clip_ratio_c)
    truncated_ratio = detach_tensor(truncated_ratio)
    tensor prob = exp_tensor(log_prob)
    tensor old_prob = exp_tensor(old_log_prob)
    tensor prob_diff = sub(prob, old_prob)
    tensor valid_positive_mask = less_equal_scalar(prob_diff, config.clip_divergence_high)
    tensor valid_negative_mask = greater_equal_scalar(prob_diff, 0.0 - config.clip_divergence_low)
    tensor adv_positive = greater_than_zero(advantages)
    tensor valid_mask = detach_tensor(select_tensor(adv_positive, valid_positive_mask, valid_negative_mask))
    tensor pg_losses = mul(mul(mul(neg(advantages), truncated_ratio), log_prob), valid_mask)
    tensor pg_loss = agg_loss(pg_losses, response_mask, config.loss_agg_mode)
    float pg_clipfrac = item(masked_mean(sub_from_one(valid_mask), response_mask))
    float pg_clipfrac_lower = item(masked_mean(mul(greater_scalar(ratio, config.clip_ratio_c), valid_mask), response_mask))
    dppo_result {
        pg_loss: pg_loss,
        pg_clipfrac: pg_clipfrac,
        pg_clipfrac_lower: pg_clipfrac_lower,
        ppo_kl: ppo_kl,
    }
}

func compute_dppo_kl_policy_loss(
    tensor old_log_prob,
    tensor log_prob,
    tensor advantages,
    tensor response_mask,
    dppo_config config
) dppo_result {
    tensor negative_approx_kl = sub(log_prob, old_log_prob)
    negative_approx_kl = clamp_range(negative_approx_kl, -20.0, 20.0)
    tensor ratio = exp_tensor(negative_approx_kl)
    float ppo_kl = item(masked_mean(neg(negative_approx_kl), response_mask))
    tensor truncated_ratio = detach_tensor(clamp_max(ratio, config.clip_ratio_c))
    tensor prob = exp_tensor(log_prob)
    tensor old_prob = exp_tensor(old_log_prob)
    tensor binary_kl = compute_binary_kl(prob, old_prob)
    tensor valid_positive_mask = less_equal_scalar(binary_kl, config.clip_divergence_high)
    tensor valid_negative_mask = less_equal_scalar(binary_kl, config.clip_divergence_low)
    tensor adv_positive = greater_than_zero(advantages)
    tensor valid_mask = detach_tensor(select_tensor(adv_positive, valid_positive_mask, valid_negative_mask))
    tensor pg_losses = mul(mul(mul(neg(advantages), truncated_ratio), log_prob), valid_mask)
    tensor pg_loss = agg_loss(pg_losses, response_mask, config.loss_agg_mode)
    float pg_clipfrac = item(masked_mean(sub_from_one(valid_mask), response_mask))
    float pg_clipfrac_lower = item(masked_mean(mul(greater_scalar(ratio, config.clip_ratio_c), valid_mask), response_mask))
    dppo_result {
        pg_loss: pg_loss,
        pg_clipfrac: pg_clipfrac,
        pg_clipfrac_lower: pg_clipfrac_lower,
        ppo_kl: ppo_kl,
    }
}

func compute_binary_kl(tensor p, tensor q) tensor {
    tensor eps = from_float(1e-8)
    tensor p_clamped = clamp_range(p, 1e-8, 1.0)
    tensor q_clamped = clamp_range(q, 1e-8, 1.0)
    tensor term1 = mul(p_clamped, log_tensor(div(p_clamped, q_clamped)))
    tensor one_minus_p = sub(from_float(1.0), p_clamped)
    tensor one_minus_q = sub(from_float(1.0), q_clamped)
    tensor term2 = mul(one_minus_p, log_tensor(div(one_minus_p, one_minus_q)))
    return add(term1, term2)
}

func clamp_range(tensor x, float lo, float hi) tensor {
    return x
}

func clamp_max(tensor x, float max_val) tensor {
    return x
}

func detach_tensor(tensor x) tensor {
    return x
}

func log_tensor(tensor x) tensor {
    return x
}

func less_equal_scalar(tensor x, float value) tensor {
    return x
}

func greater_equal_scalar(tensor x, float value) tensor {
    return x
}

func greater_scalar(tensor x, float value) tensor {
    return x
}

func greater_than_zero(tensor x) tensor {
    return x
}

func select_tensor(tensor condition, tensor if_true, tensor if_false) tensor {
    return if_true
}

func sub_from_one(tensor x) tensor {
    return sub(from_float(1.0), x)
}

func neg(tensor x) tensor {
    return mul_scalar(x, -1.0)
}

func masked_mean(tensor values, tensor mask) tensor {
    tensor total = sum_all(mul(values, mask))
    tensor count = sum_all(mask)
    return div(total, count)
}

