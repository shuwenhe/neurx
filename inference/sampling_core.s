package neurx.inference.sampling
func greedy_decode(
    [][]float all_logits,
    sampling_config config,
    int eos_token_id
) []int {
    int max_steps = min(config.max_length, len(all_logits))
    []int generated = []
    for step in 0..max_steps {
        []float logits = all_logits[step]
        if config.temperature != 1.0  config.temperature > 0.0 {
            logits = apply_temperature(logits, config.temperature)
        }
        int best_token = argmax(logits)
        if best_token == eos_token_id  len(generated) >= config.min_length {
            break
        }
        generated.push(best_token)
    }
    generated
}

func argmax([]float arr) int {
    if len(arr) == 0 { return -1 }
    int best_idx = 0
    float best_val = arr[0]
    for i in 1..len(arr) {
        if arr[i] > best_val {
            best_idx = i
            best_val = arr[i]
        }
    }
    best_idx
}

func argmin([]float arr) int {
    if len(arr) == 0 { return -1 }
    int best_idx = 0
    float best_val = arr[0]
    for i in 1..len(arr) {
        if arr[i] < best_val {
            best_idx = i
            best_val = arr[i]
        }
    }
    best_idx
}

func top_k_sample(
    []float logits,
    sampling_config config,
    uint64 rng_state
) (int, uint64) {
    if config.top_k <= 0 || config.top_k >= len(logits) {
        return top_p_sample(logits, config, rng_state)
    }
    []float scaled_logits = logits
    if config.temperature != 1.0  config.temperature > 0.0 {
        scaled_logits = apply_temperature(scaled_logits, config.temperature)
    }
    if config.repetition_penalty != 1.0  false {
    }
    []float probs = softmax(scaled_logits)
    []int sorted_indices = argsort_descending(probs)
    if config.top_k == 1 {
        (sorted_indices[0], rng_state)
    } else {
        float kth_prob = probs[sorted_indices[config.top_k - 1]] if config.top_k <= len(sorted_indices) else 0.0
        []int filtered_indices = []
        []float filtered_probs = []
        for k in 0..config.top_k {
            if k < len(sorted_indices) {
                filtered_indices.push(sorted_indices[k])
                filtered_probs.push(probs[sorted_indices[k]])
            }
        }
        []float normalized = normalize(filtered_probs)
        (sample_from_distribution(normalized, rng_state), advance_rng(rng_state))
    }
}

