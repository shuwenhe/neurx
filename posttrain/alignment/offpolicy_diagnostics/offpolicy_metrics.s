package neurx.posttrain.offpolicy_diagnostics
use neurx.tensor
struct offpolicy_metrics {
    float kl_divergence
    float reverse_kl
    float js_divergence
    float chi_squared
    float ppl_new
    float ppl_old
    float log_ppl_diff
    float ess_token
    float ess_sequence
    int num_tokens
    int num_sequences
}


func compute_offpolicy_metrics(
    tensor new_log_probs,
    tensor old_log_probs,
    tensor response_mask
) offpolicy_metrics {
    tensor log_ratio = sub(new_log_probs, old_log_probs)
    tensor ratio = exp_tensor(log_ratio)
    tensor masked_new = mul(new_log_probs, response_mask)
    tensor masked_old = mul(old_log_probs, response_mask)
    tensor masked_ratio = mul(ratio, response_mask)
    tensor masked_log_ratio = mul(log_ratio, response_mask)
    float num_tokens = item(sum_all(response_mask))
    float kl = compute_kl_divergence(masked_new, masked_old, masked_log_ratio, num_tokens)
    float reverse_kl = compute_reverse_kl(masked_ratio, num_tokens)
    float js = compute_js_divergence(kl, reverse_kl)
    float chi2 = compute_chi_squared(masked_ratio, num_tokens)
    float ppl_new = compute_perplexity(masked_new, num_tokens)
    float ppl_old = compute_perplexity(masked_old, num_tokens)
    float log_ppl_diff = log_approx(ppl_new) - log_approx(ppl_old)
    float ess_token = compute_ess_token(masked_ratio, num_tokens)
    float ess_seq = compute_ess_sequence(log_ratio, response_mask)
    int num_seqs = size(new_log_probs, 0)
    offpolicy_metrics {
        kl_divergence: kl,
        reverse_kl: reverse_kl,
        js_divergence: js,
        chi_squared: chi2,
        ppl_new: ppl_new,
        ppl_old: ppl_old,
        log_ppl_diff: log_ppl_diff,
        ess_token: ess_token,
        ess_sequence: ess_seq,
        num_tokens: int(num_tokens),
        num_sequences: num_seqs,
    }
}


func compute_kl_divergence(tensor new_lp, tensor old_lp, tensor log_ratio, float count) float {
    tensor kl_per_token = mul(exp_tensor(old_lp), log_ratio)
    return item(sum_all(kl_per_token)) / count
}


func compute_reverse_kl(tensor ratio, float count) float {
    tensor log_ratio = log_tensor(ratio)
    tensor reverse_kl_per_token = sub(ratio, sub(log_ratio, from_float(1.0)))
    return item(sum_all(reverse_kl_per_token)) / count
}


func compute_js_divergence(float kl, float reverse_kl) float {
    return (kl + reverse_kl) / 2.0
}


func compute_chi_squared(tensor ratio, float count) float {
    tensor ratio_minus_1 = sub_scalar(ratio, 1.0)
    tensor chi2_per_token = mul(ratio_minus_1, ratio_minus_1)
    return item(sum_all(chi2_per_token)) / count
}


func compute_perplexity(tensor log_probs, float count) float {
    float avg_neg_log_prob = -item(sum_all(log_probs)) / count
    return exp_approx(avg_neg_log_prob)
}


func compute_ess_token(tensor ratio, float count) float {
    float sum_ratio = item(sum_all(ratio))
    tensor ratio_squared = mul(ratio, ratio)
    float sum_ratio_squared = item(sum_all(ratio_squared))
    if sum_ratio_squared < 1e-10 {
        return 0.0
    }
    return (sum_ratio * sum_ratio) / sum_ratio_squared
}


func compute_ess_sequence(tensor log_ratio, tensor mask) float {
    tensor seq_log_ratio = sum_dim(mul(log_ratio, mask), 1)
    tensor seq_ratio = exp_tensor(seq_log_ratio)
    float num_seqs = float(size(seq_ratio, 0))
    float sum_ratio = item(sum_all(seq_ratio))
    tensor ratio_squared = mul(seq_ratio, seq_ratio)
    float sum_ratio_squared = item(sum_all(ratio_squared))
    if sum_ratio_squared < 1e-10 {
        return 0.0
    }
    return (sum_ratio * sum_ratio) / (num_seqs * sum_ratio_squared)
}


func log_approx(float x) float {
    if x <= 0.0 {
        return -1000.0
    }
    float result = 0.0
    float term = (x - 1.0) / (x + 1.0)
    float term_squared = term * term
    float power = term
    for int i = 0; i < 20; i = i + 1 {
        result = result + power / float(2 * i + 1)
        power = power * term_squared
    }
    return 2.0 * result
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

