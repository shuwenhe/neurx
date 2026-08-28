package neurx.posttrain.reinforce_pp_baseline
use neurx.tensor
struct reinforce_pp_baseline_config {
    float gamma
    float epsilon
    bool use_whitening
}

struct reinforce_pp_baseline_state {
    reinforce_pp_baseline_config config
    int step_count
}

func default_reinforce_pp_baseline_config() reinforce_pp_baseline_config {
    reinforce_pp_baseline_config {
        gamma: 1.0,
        epsilon: 1e-6,
        use_whitening: true,
    }
}

func compute_reinforce_pp_baseline_advantages(
    tensor token_level_rewards,
    tensor response_mask,
    int[] index,
    reinforce_pp_baseline_config config
) (tensor, tensor) {
    int batch_size = size(token_level_rewards, 0)
    int seq_len = size(token_level_rewards, 1)
    tensor scores = sum_dim(mul(token_level_rewards, response_mask), 1)
    float[] id_scores = make(float[], 1024)
    int[] id_counts = make(int[], 1024)
    float[] id_means = make(float[], 1024)
    for int i = 0; i < batch_size; i = i + 1 {
        int idx = index[i]
        float score = item(select(scores, 0, i))
        id_scores[idx] = id_scores[idx] + score
        id_counts[idx] = id_counts[idx] + 1
    }
    for int idx = 0; idx < 1024; idx = idx + 1 {
        if id_counts[idx] == 1 {
            id_means[idx] = 0.0
        } else if id_counts[idx] > 1 {
            id_means[idx] = id_scores[idx] / float_from_int(id_counts[idx])
        }
    }
    float[] centered_scores = make(float[], batch_size)
    for int i = 0; i < batch_size; i = i + 1 {
        int idx = index[i]
        float score = item(select(scores, 0, i))
        centered_scores[i] = score - id_means[idx]
    }
    tensor advantages = from_float_array(centered_scores, int[]{batch_size})
    advantages = unsqueeze(advantages, 1)
    advantages = tile(advantages, int[]{1, seq_len})
    advantages = mul(advantages, response_mask)
    if config.use_whitening {
        advantages = masked_whiten(advantages, response_mask)
        advantages = mul(advantages, response_mask)
    }
    return advantages, advantages
}

func new_reinforce_pp_baseline_trainer(reinforce_pp_baseline_config config) reinforce_pp_baseline_state {
    reinforce_pp_baseline_state {
        config: config,
        step_count: 0,
    }
}

func masked_whiten(tensor values, tensor mask) tensor {
    tensor masked_values = mul(values, mask)
    float valid_count = item(sum_all(mask))
    if valid_count < 2.0 {
        return values
    }
    float mean = item(sum_all(masked_values)) / valid_count
    tensor centered = sub_scalar(values, mean)
    tensor squared = mul(centered, centered)
    tensor masked_squared = mul(squared, mask)
    float variance = item(sum_all(masked_squared)) / valid_count
    float std = sqrt_approx(variance)
    if std < 1e-8 {
        return values
    }
    return div_scalar(centered, std)
}

func float_from_int(int n) float {
    return 0.0 + float(n)
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x / 2.0
    for int i = 0; i < 10; i = i + 1 {
        guess = (guess + x / guess) / 2.0
    }
    return guess
}
