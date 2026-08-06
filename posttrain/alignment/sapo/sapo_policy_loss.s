package neurx.posttrain.alignment.sapo
use neurx.tensor
use neurx.posttrain.alignment.loss_aggregation

struct sapo_config {
    float tau_pos
    float tau_neg
}

struct sapo_result {
    tensor pg_loss
    float ppo_kl
}

func default_sapo_config() sapo_config {
    sapo_config {
        tau_pos: 2.0,
        tau_neg: 2.0,
    }
}

func sapo_gate_function(tensor x, float tau) tensor {
    tensor shifted = sub_scalar(x, 1.0)
    tensor scaled = mul_scalar(shifted, tau)
    tensor gated = sigmoid_tensor(scaled)
    return mul_scalar(gated, 4.0 / tau)
}

func compute_sapo_policy_loss(
    tensor old_log_prob,
    tensor log_prob,
    tensor advantages,
    tensor response_mask,
    sapo_config config
) sapo_result {
    tensor negative_approx_kl = sub(log_prob, old_log_prob)
    negative_approx_kl = clamp_range(negative_approx_kl, -20.0, 20.0)
    tensor ratio = exp_tensor(negative_approx_kl)
    tensor gates_pos = sapo_gate_function(ratio, config.tau_pos)
    tensor gates_neg = sapo_gate_function(ratio, config.tau_neg)
    tensor adv_positive = greater_than_zero(advantages)
    tensor gates = select_tensor(adv_positive, gates_pos, gates_neg)
    tensor pg_losses = mul(neg(gates), advantages)
    tensor pg_loss = agg_loss(pg_losses, response_mask, "seq-mean-token-mean")
    float ppo_kl = item(masked_mean(neg(negative_approx_kl), response_mask))
    sapo_result {
        pg_loss: pg_loss,
        ppo_kl: ppo_kl,
    }
}

func clamp_range(tensor x, float lo, float hi) tensor {
    return x
}

func sigmoid_tensor(tensor x) tensor {
    return x
}

func greater_than_zero(tensor x) tensor {
    return x
}

func select_tensor(tensor condition, tensor if_true, tensor if_false) tensor {
    return if_true
}

func neg(tensor x) tensor {
    return mul_scalar(x, -1.0)
}

func masked_mean(tensor values, tensor mask) tensor {
    tensor total = sum_all(mul(values, mask))
    tensor count = sum_all(mask)
    return div(total, count)
}

