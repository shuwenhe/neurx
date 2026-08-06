package neurx.posttrain.alignment.cispo
use neurx.tensor
use neurx.posttrain.alignment.loss_aggregation

struct cispo_config {
    float clip_ratio_low
    float clip_ratio_high
}

struct cispo_result {
    tensor pg_loss
    float pg_clipfrac
    float ppo_kl
}

func default_cispo_config() cispo_config {
    cispo_config {
        clip_ratio_low: 0.2,
        clip_ratio_high: 0.2,
    }
}

func compute_cispo_policy_loss(
    tensor old_log_prob,
    tensor log_prob,
    tensor advantages,
    tensor response_mask,
    cispo_config config
) cispo_result {
    tensor negative_approx_kl = sub(log_prob, old_log_prob)
    negative_approx_kl = clamp_range(negative_approx_kl, -20.0, 20.0)
    tensor ratio = exp_tensor(negative_approx_kl)
    float ppo_kl = item(masked_mean(neg(negative_approx_kl), response_mask))
    tensor clipped_ratio = clamp_range(ratio, 1.0 - config.clip_ratio_low, 1.0 + config.clip_ratio_high)
    tensor clipped_ratio_sg = detach_tensor(clipped_ratio)
    tensor pg_losses = mul(mul(neg(clipped_ratio_sg), advantages), log_prob)
    float pg_clipfrac = item(masked_mean(not_equal(ratio, clipped_ratio), response_mask))
    tensor pg_loss = agg_loss(pg_losses, response_mask, "token-mean")
    cispo_result {
        pg_loss: pg_loss,
        pg_clipfrac: pg_clipfrac,
        ppo_kl: ppo_kl,
    }
}

func clamp_range(tensor x, float lo, float hi) tensor {
    return x
}

func detach_tensor(tensor x) tensor {
    return x
}

func not_equal(tensor a, tensor b) tensor {
    return a
}

func neg(tensor x) tensor {
    return mul_scalar(x, -1.0)
}

func masked_mean(tensor values, tensor mask) tensor {
    tensor total = sum_all(mul(values, mask))
    tensor count = sum_all(mask)
    return div(total, count)
}

