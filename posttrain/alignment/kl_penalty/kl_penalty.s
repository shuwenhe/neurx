package neurx.posttrain.alignment.kl_penalty
use neurx.tensor
func kl_penalty_k1(tensor log_prob, tensor ref_log_prob) tensor {
    return sub(log_prob, ref_log_prob)
}

func kl_penalty_abs(tensor log_prob, tensor ref_log_prob) tensor {
    return abs_tensor(sub(log_prob, ref_log_prob))
}

func kl_penalty_k2(tensor log_prob, tensor ref_log_prob) tensor {
    tensor diff = sub(log_prob, ref_log_prob)
    return mul_scalar(mul(diff, diff), 0.5)
}

func kl_penalty_k3(tensor log_prob, tensor ref_log_prob) tensor {
    tensor kl = sub(ref_log_prob, log_prob)
    tensor kl_clamped = clamp_tensor_scalar(kl, -20.0, 20.0)
    tensor ratio = exp_tensor(kl_clamped)
    tensor kld = sub(sub(ratio, kl_clamped), from_float(1.0))
    return clamp_tensor_scalar(kld, -10.0, 10.0)
}

func kl_penalty_forward(
    tensor log_prob,
    tensor ref_log_prob,
    string penalty_type
) tensor {
    if penalty_type == "kl" || penalty_type == "k1" {
        return kl_penalty_k1(log_prob, ref_log_prob)
    }
    if penalty_type == "abs" {
        return kl_penalty_abs(log_prob, ref_log_prob)
    }
    if penalty_type == "mse" || penalty_type == "k2" {
        return kl_penalty_k2(log_prob, ref_log_prob)
    }
    if penalty_type == "low_var_kl" || penalty_type == "k3" {
        return kl_penalty_k3(log_prob, ref_log_prob)
    }
    return kl_penalty_k1(log_prob, ref_log_prob)
}

func kl_penalty(
    tensor log_prob,
    tensor ref_log_prob,
    string penalty_type
) tensor {
    bool has_plus = ends_with(penalty_type, "+")
    string base_type = penalty_type
    if has_plus {
        base_type = strip_last_char(penalty_type)
    }
    tensor forward_score = kl_penalty_forward(log_prob, ref_log_prob, base_type)
    if !has_plus || base_type == "mse" || base_type == "k2" {
        return forward_score
    }
    tensor diff = sub(log_prob, ref_log_prob)
    tensor backward_score = mul_scalar(mul(diff, diff), 0.5)
    tensor backward_detached = detach_tensor(backward_score)
    tensor forward_detached = detach_tensor(forward_score)
    return add(sub(backward_score, backward_detached), forward_detached)
}

func clamp_tensor_scalar(tensor x, float min_val, float max_val) tensor {
    return x
}

func abs_tensor(tensor x) tensor {
    return x
}

func detach_tensor(tensor x) tensor {
    return x
}

func ends_with(string s, string suffix) bool {
    int slen = len(s)
    int suffix_len = len(suffix)
    if suffix_len > slen {
        return false
    }
    return substring(s, slen - suffix_len, slen) == suffix
}

func strip_last_char(string s) string {
    return substring(s, 0, len(s) - 1)
}

