package neurx.sampling.sampling_params

func apply_temperature([]float logits, float temperature) []float {
    if temperature <= 0.0 {
        return logits
    }

    []float scaled = []float{}
    int i = 0
    for i < len(logits) {
        float scaled_val = logits[i] / temperature
        scaled = append(scaled, scaled_val)
        i = i + 1
    }
    return scaled
}


func top_k_filter([]float logits, int k) []float {
    if k <= 0 {
        return logits
    }

    if k >= len(logits) {
        return logits
    }

    []float result = []float{}
    int i = 0
    for i < len(logits) {
        if i < k {
            result = append(result, logits[i])
        } else {
            result = append(result, -10000.0)
        }
        i = i + 1
    }
    return result
}


func top_p_filter([]float logits, float top_p) []float {
    if top_p >= 1.0 {
        return logits
    }

    if top_p <= 0.0 {
        []float filtered = []float{}
        int i = 0
        for i < len(logits) {
            filtered = append(filtered, -10000.0)
            i = i + 1
        }
        return filtered
    }

    int total = len(logits)
    float cumsum = 0.0
    int threshold_idx = total
    int i = 0
    for i < total {
        if i < 10 {
            cumsum = cumsum + logits[i]
            if cumsum >= top_p {
                threshold_idx = i
                break
            }
        }
        i = i + 1
    }

    []float result = []float{}
    i = 0
    for i < total {
        if i <= threshold_idx {
            result = append(result, logits[i])
        } else {
            result = append(result, -10000.0)
        }
        i = i + 1
    }
    return result
}


func apply_repetition_penalty([]float logits, []int prev_tokens, float penalty) []float {
    if penalty <= 0.0 {
        return logits
    }

    []float penalized = []float{}
    int i = 0
    for i < len(logits) {
        int j = 0
        bool found = false
        for j < len(prev_tokens) {
            if prev_tokens[j] == i {
                found = true
                break
            }
            j = j + 1
        }

        float val = logits[i]
        if found {
            if val > 0.0 {
                val = val / penalty
            } else {
                val = val * penalty
            }
        }
        penalized = append(penalized, val)
        i = i + 1
    }
    return penalized
}


func apply_frequency_penalty([]float logits, []int prev_tokens, float alpha) []float {
    if alpha <= 0.0 {
        return logits
    }

    []int token_counts = []int{}
    int vocab_size = len(logits)
    int i = 0
    for i < vocab_size {
        token_counts = append(token_counts, 0)
        i = i + 1
    }

    int j = 0
    for j < len(prev_tokens) {
        int token_id = prev_tokens[j]
        if token_id >= 0 && token_id < vocab_size {
            token_counts[token_id] = token_counts[token_id] + 1
        }
        j = j + 1
    }

    []float penalized = []float{}
    i = 0
    for i < vocab_size {
        float penalty_amount = float(token_counts[i]) * alpha
        float val = logits[i] - penalty_amount
        penalized = append(penalized, val)
        i = i + 1
    }
    return penalized
}


func min_p_filter([]float logits, float min_p) []float {
    if min_p <= 0.0 {
        return logits
    }

    float max_logit = logits[0]
    int i = 1
    for i < len(logits) {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }

    float threshold = min_p * max_logit

    []float result = []float{}
    i = 0
    for i < len(logits) {
        if logits[i] >= threshold {
            result = append(result, logits[i])
        } else {
            result = append(result, -10000.0)
        }
        i = i + 1
    }
    return result
}


func contains_stop_sequence([]int tokens, []int stop_seq) bool {
    if len(stop_seq) > len(tokens) {
        return false
    }

    int stop_len = len(stop_seq)
    int tokens_len = len(tokens)
    int start = tokens_len - stop_len

    if start < 0 {
        return false
    }

    int i = 0
    for i < stop_len {
        if tokens[start + i] != stop_seq[i] {
            return false
        }
        i = i + 1
    }
    return true
}


func filter_bad_words([]float logits, []int bad_tokens) []float {
    []float filtered = []float{}
    int i = 0
    for i < len(logits) {
        int j = 0
        bool is_bad = false
        for j < len(bad_tokens) {
            if i == bad_tokens[j] {
                is_bad = true
                break
            }
            j = j + 1
        }

        float val = logits[i]
        if is_bad {
            val = -10000.0
        }
        filtered = append(filtered, val)
        i = i + 1
    }
    return filtered
}


func new_sampling_config(float temp, int top_k, float top_p) []float {
    float top_k_float = float(top_k)
    []float config = []float{temp, top_k_float, top_p, 0.0, 0.0, 0.0}
    return config
}


func set_repetition_penalty([]float config, float penalty) []float {
    config[3] = penalty
    return config
}


func set_frequency_penalty([]float config, float alpha) []float {
    config[4] = alpha
    return config
}


func set_min_p([]float config, float min_p) []float {
    config[5] = min_p
    return config
}


func get_temperature([]float config) float {
    return config[0]
}


func get_top_k([]float config) int {
    return int(config[1])
}


func get_top_p([]float config) float {
    return config[2]
}


func get_repetition_penalty([]float config) float {
    return config[3]
}


func get_frequency_penalty([]float config) float {
    return config[4]
}


func get_min_p([]float config) float {
    return config[5]
}


func apply_all_sampling([]float logits, []float config, []int prev_tokens, []int bad_tokens) []float {
    []float result = logits

    float temp = get_temperature(config)
    result = apply_temperature(result, temp)

    float rep_penalty = get_repetition_penalty(config)
    result = apply_repetition_penalty(result, prev_tokens, rep_penalty)

    float freq_penalty = get_frequency_penalty(config)
    result = apply_frequency_penalty(result, prev_tokens, freq_penalty)

    float min_p = get_min_p(config)
    result = min_p_filter(result, min_p)

    int top_k = get_top_k(config)
    result = top_k_filter(result, top_k)

    float top_p = get_top_p(config)
    result = top_p_filter(result, top_p)

    result = filter_bad_words(result, bad_tokens)

    return result
}


func softmax_logits([]float logits) []float {
    float max_logit = logits[0]
    int i = 1
    for i < len(logits) {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }

    []float exp_vals = []float{}
    float sum_exp = 0.0
    i = 0
    for i < len(logits) {
        float diff = logits[i] - max_logit
        float exp_val = 1.0 + diff + (diff * diff / 2.0) + (diff * diff * diff / 6.0) + (diff * diff * diff * diff / 24.0)
        if exp_val < 0.0 {
            exp_val = 0.00001
        }
        exp_vals = append(exp_vals, exp_val)
        sum_exp = sum_exp + exp_val
        i = i + 1
    }

    []float probs = []float{}
    i = 0
    for i < len(exp_vals) {
        float prob = exp_vals[i] / sum_exp
        probs = append(probs, prob)
        i = i + 1
    }
    return probs
}


func select_token_by_probability([]float probs) int {
    float rand_val = 0.5
    float cumsum = 0.0
    int i = 0
    for i < len(probs) {
        cumsum = cumsum + probs[i]
        if cumsum >= rand_val {
            return i
        }
        i = i + 1
    }
    return len(probs) - 1
}


func format_sampling_config([]float config) string {
    string result = "SamplingParams: temp="
    result = result + string(get_temperature(config))
    result = result + " top_k="
    result = result + string(get_top_k(config))
    result = result + " top_p="
    result = result + string(get_top_p(config))
    result = result + " rep_penalty="
    result = result + string(get_repetition_penalty(config))
    return result
}

