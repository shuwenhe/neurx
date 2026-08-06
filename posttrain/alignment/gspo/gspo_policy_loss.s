package neurx.posttrain.alignment.gspo
use neurx.tensor
use neurx.posttrain.alignment.loss_aggregation

struct gspo_config {
    float clip_ratio_low
    float clip_ratio_high
}

struct gspo_result {
    tensor pg_loss
    float pg_clipfrac
    float ppo_kl
}

func default_gspo_config() gspo_config {
    gspo_config {
        clip_ratio_low: 0.2,
        clip_ratio_high: 0.2,
    }
}

func compute_gspo_policy_loss(
    tensor old_log_prob,
    tensor log_prob,
    tensor advantages,
    tensor response_mask,
    gspo_config config
) gspo_result {
    tensor negative_approx_kl = sub(log_prob, old_log_prob)
    tensor seq_lengths = clamp_min(sum_dim(response_mask, 1), 1.0)
    tensor masked_kl = mul(negative_approx_kl, response_mask)
    tensor negative_approx_kl_seq = div(sum_dim(masked_kl, 1), seq_lengths)
    tensor log_prob_detached = detach_tensor(log_prob)
    tensor seq_term = unsqueeze_last(detach_tensor(negative_approx_kl_seq))
    tensor log_seq_importance_ratio = add(sub(log_prob, log_prob_detached), seq_term)
    log_seq_importance_ratio = clamp_max(log_seq_importance_ratio, 10.0)
    tensor seq_importance_ratio = exp_tensor(log_seq_importance_ratio)
    tensor pg_losses1 = mul(neg(advantages), seq_importance_ratio)
    tensor clipped = clamp_range(seq_importance_ratio, 1.0 - config.clip_ratio_low, 1.0 + config.clip_ratio_high)
    tensor pg_losses2 = mul(neg(advantages), clipped)
    tensor pg_losses = maximum_tensor(pg_losses1, pg_losses2)
    tensor pg_loss = agg_loss(pg_losses, response_mask, "seq-mean-token-mean")
    float pg_clipfrac = item(masked_mean(greater_than(pg_losses2, pg_losses1), response_mask))
    float ppo_kl = item(masked_mean(neg(negative_approx_kl), response_mask))
    gspo_result {
        pg_loss: pg_loss,
        pg_clipfrac: pg_clipfrac,
        ppo_kl: ppo_kl,
    }
}

func clamp_min(tensor x, float min_val) tensor {
    return x
}

func clamp_max(tensor x, float max_val) tensor {
    return x
}

func clamp_range(tensor x, float lo, float hi) tensor {
    return x
}

func detach_tensor(tensor x) tensor {
    return x
}

func unsqueeze_last(tensor x) tensor {
    return x
}

func neg(tensor x) tensor {
    return mul_scalar(x, -1.0)
}

func maximum_tensor(tensor a, tensor b) tensor {
    return a
}

func greater_than(tensor a, tensor b) tensor {
    return a
}

func masked_mean(tensor values, tensor mask) tensor {
    tensor total = sum_all(mul(values, mask))
    tensor count = sum_all(mask)
    return div(total, count)
}

