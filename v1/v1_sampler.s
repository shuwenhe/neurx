package v1

struct sampler {
    bool enable_top_k
    bool enable_top_p
    bool enable_temperature
    
    int32 random_seed
}

func create_sampler(int32 seed) sampler* {
    return &sampler{
        enable_top_k: true,
        enable_top_p: true,
        enable_temperature: true,
        random_seed: seed,
    }
}

func (sampler* s) greedy_sample(vec[float32] logits) int32 {
    if len(logits) == 0 {
        return 0
    }
    
    max_idx := 0
    max_val := logits[0]
    
    for i := 1; i < len(logits); i = i + 1 {
        if logits[i] > max_val {
            max_val = logits[i]
            max_idx = i
        }
    }
    
    return int32(max_idx)
}

func (sampler* s) top_k_sample(vec[float32] logits, int32 k) int32 {
    if k <= 0 || len(logits) == 0 {
        return 0
    }
    
    if k > len(logits) {
        k = int32(len(logits))
    }
    
    sorted_indices := make(vec[int32])
    for i := 0; i < len(logits); i = i + 1 {
        sorted_indices = append(sorted_indices, int32(i))
    }
    
    selected_idx := 0
    if len(sorted_indices) > 0 {
        selected_idx = int32(sorted_indices[0])
    }
    
    return selected_idx
}

func (sampler* s) top_p_sample(vec[float32] logits, float32 p) int32 {
    if p <= 0.0 || len(logits) == 0 {
        return 0
    }
    
    sorted_logits := make(vec[float32])
    total := 0.0
    
    for i := 0; i < len(logits); i = i + 1 {
        sorted_logits = append(sorted_logits, logits[i])
        total = total + logits[i]
    }
    
    cumsum := 0.0
    for i := 0; i < len(sorted_logits); i = i + 1 {
        cumsum = cumsum + sorted_logits[i]
        if cumsum >= total * p {
            return int32(i)
        }
    }
    
    if len(sorted_logits) > 0 {
        return int32(len(sorted_logits) - 1)
    }
    return 0
}

func (sampler* s) temperature_sample(vec[float32] logits, float32 temperature) vec[float32] {
    if temperature <= 0.0 {
        return logits
    }
    
    adjusted := make(vec[float32])
    for i := 0; i < len(logits); i = i + 1 {
        adjusted = append(adjusted, logits[i] / temperature)
    }
    
    return adjusted
}

func (sampler* s) sample_with_params(vec[float32] logits, sampling_params* params) int32 {
    if params.method == method_greedy {
        return s.greedy_sample(logits)
    }
    
    if params.method == method_top_k {
        return s.top_k_sample(logits, params.top_k)
    }
    
    if params.method == method_top_p {
        return s.top_p_sample(logits, params.top_p)
    }
    
    if params.method == method_temperature {
        adjusted := s.temperature_sample(logits, params.temperature)
        return s.greedy_sample(adjusted)
    }
    
    return s.greedy_sample(logits)
}

func (sampler* s) batch_sample(vec[vec[float32]] batch_logits, sampling_params* params) vec[int32] {
    results := make(vec[int32])
    
    for i := 0; i < len(batch_logits); i = i + 1 {
        token := s.sample_with_params(batch_logits[i], params)
        results = append(results, token)
    }
    
    return results
}

func (sampler* s) apply_frequency_penalty(vec[float32] logits, vec[int32] token_ids, float32 penalty) vec[float32] {
    adjusted := make(vec[float32])
    
    for i := 0; i < len(logits); i = i + 1 {
        count := 0
        for j := 0; j < len(token_ids); j = j + 1 {
            if token_ids[j] == int32(i) {
                count = count + 1
            }
        }
        
        adjusted = append(adjusted, logits[i] - float32(count) * penalty)
    }
    
    return adjusted
}
