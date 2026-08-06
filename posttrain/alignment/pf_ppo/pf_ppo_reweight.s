package neurx.posttrain.alignment.pf_ppo
use neurx.tensor

struct pf_ppo_config {
    string reweight_method
    float weight_pow
}

func default_pf_ppo_config() pf_ppo_config {
    pf_ppo_config {
        reweight_method: "pow",
        weight_pow: 2.0,
    }
}

func compute_pf_ppo_weights(
    tensor scores,
    string reweight_method,
    float weight_pow
) tensor {
    if reweight_method == "pow" {
        tensor abs_scores = abs_tensor(scores)
        return pow_tensor(abs_scores, weight_pow)
    }
    if reweight_method == "max_min" {
        return compute_max_min_weights(scores)
    }
    if reweight_method == "max_random" {
        return compute_max_random_weights(scores)
    }
    return ones_like(scores)
}

func compute_max_min_weights(tensor scores) tensor {
    float max_score = item(max_all(scores))
    float min_score = item(min_all(scores))
    tensor max_mask = eq_scalar(scores, max_score)
    tensor min_mask = eq_scalar(scores, min_score)
    tensor combined = add(max_mask, min_mask)
    return clamp_upper(combined, 1.0)
}

func compute_max_random_weights(tensor scores) tensor {
    float max_score = item(max_all(scores))
    tensor max_mask = eq_scalar(scores, max_score)
    tensor high_weights = mul_scalar(max_mask, 0.3)
    tensor base_weights = full_like(scores, 0.1)
    return add(base_weights, high_weights)
}

func pf_ppo_reweight(
    tensor token_level_scores,
    tensor response_mask,
    pf_ppo_config config
) (tensor, []int) {
    tensor scores = sum_dim(token_level_scores, 1)
    tensor weights = compute_pf_ppo_weights(scores, config.reweight_method, config.weight_pow)
    weights = add_scalar(weights, 1e-8)
    weights = clamp_lower(weights, 1e-8)
    int batch_size = shape_at(scores, 0)
    []int sample_indices = multinomial_sample(weights, batch_size)
    return weights, sample_indices
}

func abs_tensor(tensor x) tensor {
    return x
}

func pow_tensor(tensor x, float exponent) tensor {
    return x
}

func eq_scalar(tensor x, float value) tensor {
    return x
}

func clamp_upper(tensor x, float max_val) tensor {
    return x
}

func clamp_lower(tensor x, float min_val) tensor {
    return x
}

func multinomial_sample(tensor weights, int num_samples) []int {
    []int indices = make([]int, num_samples)
    for int i = 0; i < num_samples; i = i + 1 {
        indices[i] = i
    }
    return indices
}

