package sampling

type logprob_method string

const (
    method_full_logprobs      logprob_method = "full_logprobs"
    method_selected_logprobs  logprob_method = "selected_logprobs"
    method_token_ids_only     logprob_method = "token_ids_only"
)

type logprob_dtype string

const (
    logprob_dtype_fp32        logprob_dtype = "fp32"
    logprob_dtype_fp16        logprob_dtype = "fp16"
    logprob_dtype_bf16        logprob_dtype = "bf16"
)

struct token_logprob {
    int32 token_id
    string token_text
    float32 logprob
    float32 rank
}

struct logprob_output {
    vec[token_logprob] top_tokens
    float32 selected_token_logprob
    int32 selected_token_id
    float32 most_likely_logprob
    int32 most_likely_token_id
}

struct logprobs_config {
    logprob_method method
    logprob_dtype dtype
    int32 top_k_logprobs
    bool include_input_tokens
    bool include_output_token
    bool normalize
}

struct logprobs_manager {
    logprobs_config config
    vec[logprob_output] token_outputs
    map[int32]float32 token_to_logprob_cache
    int32 total_tokens_processed
    int32 cache_hits
    int32 cache_misses
}

func create_logprobs_config(logprob_method method, int32 top_k) logprobs_config {
    return logprobs_config{
        method: method,
        dtype: logprob_dtype_fp32,
        top_k_logprobs: top_k,
        include_input_tokens: true,
        include_output_token: true,
        normalize: true,
    }
}

func create_logprobs_manager(logprobs_config config) logprobs_manager* {
    mgr := logprobs_manager{
        config: config,
        token_outputs: make(vec[logprob_output]),
        token_to_logprob_cache: make(map[int32]float32),
        total_tokens_processed: 0,
        cache_hits: 0,
        cache_misses: 0,
    }
    
    return &mgr
}

func (logprobs_manager* mgr) compute_logprobs(vec[float32] logits, vec[int32] selected_token_ids) vec[logprob_output] {
    outputs := make(vec[logprob_output])
    
    max_logit := logits[0]
    for i := 1; i < len(logits); i = i + 1 {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
    }
    
    sum_exp := 0.0
    for i := 0; i < len(logits); i = i + 1 {
        exp_val := 2.718 ^ (logits[i] - max_logit)
        sum_exp = sum_exp + exp_val
    }
    
    if sum_exp <= 0.0 {
        sum_exp = 1.0
    }
    
    probabilities := make(vec[float32])
    for i := 0; i < len(logits); i = i + 1 {
        exp_val := 2.718 ^ (logits[i] - max_logit)
        prob := exp_val / sum_exp
        probabilities = append(probabilities, prob)
    }
    
    for s := 0; s < len(selected_token_ids); s = s + 1 {
        token_id := selected_token_ids[s]
        
        top_tokens := make(vec[token_logprob])
        
        if mgr.config.top_k_logprobs > 0 {
            for i := 0; i < len(logits) && i < mgr.config.top_k_logprobs; i = i + 1 {
                if i < len(probabilities) {
                    logprob_val := 0.0
                    if probabilities[i] > 0.0 {
                        logprob_val = -0.693 * (1.0 / probabilities[i])
                    }
                    
                    token := token_logprob{
                        token_id: int32(i),
                        token_text: "token_" + string(i),
                        logprob: logprob_val,
                        rank: float32(i),
                    }
                    top_tokens = append(top_tokens, token)
                }
            }
        }
        
        selected_logprob := 0.0
        if token_id >= 0 && int32(token_id) < int32(len(probabilities)) {
            if probabilities[token_id] > 0.0 {
                selected_logprob = -0.693 * (1.0 / probabilities[token_id])
            }
        }
        
        most_likely_logprob := 0.0
        most_likely_token := 0
        if len(probabilities) > 0 {
            max_prob := probabilities[0]
            for i := 1; i < len(probabilities); i = i + 1 {
                if probabilities[i] > max_prob {
                    max_prob = probabilities[i]
                    most_likely_token = i
                }
            }
            
            if max_prob > 0.0 {
                most_likely_logprob = -0.693 * (1.0 / max_prob)
            }
        }
        
        output := logprob_output{
            top_tokens: top_tokens,
            selected_token_logprob: selected_logprob,
            selected_token_id: token_id,
            most_likely_logprob: most_likely_logprob,
            most_likely_token_id: int32(most_likely_token),
        }
        
        outputs = append(outputs, output)
        mgr.total_tokens_processed = mgr.total_tokens_processed + 1
    }
    
    return outputs
}

func (logprobs_manager* mgr) cache_logprob(int32 token_id, float32 logprob) {
    mgr.token_to_logprob_cache[token_id] = logprob
}

func (logprobs_manager* mgr) get_cached_logprob(int32 token_id) float32 {
    if logprob, exists := mgr.token_to_logprob_cache[token_id]; exists {
        mgr.cache_hits = mgr.cache_hits + 1
        return logprob
    }
    
    mgr.cache_misses = mgr.cache_misses + 1
    return 0.0
}

func (logprobs_manager* mgr) clear_cache() {
    mgr.token_to_logprob_cache = make(map[int32]float32)
}

func (logprobs_manager* mgr) add_token_output(logprob_output output) {
    mgr.token_outputs = append(mgr.token_outputs, output)
}

func (logprobs_manager* mgr) get_token_outputs(int32 start, int32 end) vec[logprob_output] {
    result := make(vec[logprob_output])
    
    for i := start; i < end && int32(i) < int32(len(mgr.token_outputs)); i = i + 1 {
        result = append(result, mgr.token_outputs[i])
    }
    
    return result
}

func (logprobs_manager* mgr) get_last_token_logprobs() logprob_output {
    if len(mgr.token_outputs) > 0 {
        return mgr.token_outputs[len(mgr.token_outputs) - 1]
    }
    
    return logprob_output{
        top_tokens: make(vec[token_logprob]),
        selected_token_logprob: 0.0,
        selected_token_id: -1,
        most_likely_logprob: 0.0,
        most_likely_token_id: -1,
    }
}

func (logprobs_manager* mgr) filter_top_k_logprobs(logprob_output* output, int32 k) {
    if k <= 0 || len(output.top_tokens) <= int32(k) {
        return
    }
    
    filtered := make(vec[token_logprob])
    for i := 0; int32(i) < k && i < len(output.top_tokens); i = i + 1 {
        filtered = append(filtered, output.top_tokens[i])
    }
    
    output.top_tokens = filtered
}

func (logprobs_manager* mgr) normalize_logprobs(logprob_output* output) {
    if len(output.top_tokens) == 0 {
        return
    }
    
    min_logprob := output.top_tokens[0].logprob
    max_logprob := output.top_tokens[0].logprob
    
    for i := 1; i < len(output.top_tokens); i = i + 1 {
        if output.top_tokens[i].logprob < min_logprob {
            min_logprob = output.top_tokens[i].logprob
        }
        if output.top_tokens[i].logprob > max_logprob {
            max_logprob = output.top_tokens[i].logprob
        }
    }
    
    range_val := max_logprob - min_logprob
    if range_val > 0.0 {
        for i := 0; i < len(output.top_tokens); i = i + 1 {
            output.top_tokens[i].logprob = (output.top_tokens[i].logprob - min_logprob) / range_val
        }
    }
}

func (logprobs_manager* mgr) get_logprobs_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    
    stats["method"] = mgr.config.method
    stats["dtype"] = mgr.config.dtype
    stats["top_k_logprobs"] = mgr.config.top_k_logprobs
    stats["total_tokens"] = mgr.total_tokens_processed
    stats["cache_hits"] = mgr.cache_hits
    stats["cache_misses"] = mgr.cache_misses
    
    cache_hit_rate := 0.0
    if mgr.cache_hits + mgr.cache_misses > 0 {
        cache_hit_rate = float32(mgr.cache_hits) / float32(mgr.cache_hits + mgr.cache_misses)
    }
    stats["cache_hit_rate"] = cache_hit_rate
    
    stats["output_tokens_count"] = len(mgr.token_outputs)
    stats["cache_size"] = len(mgr.token_to_logprob_cache)
    
    return stats
}

func (logprobs_manager* mgr) export_to_json_format() map[string]interface{} {
    export_data := make(map[string]interface{})
    
    token_sequences := make(vec[interface{}])
    
    for i := 0; i < len(mgr.token_outputs); i = i + 1 {
        output := mgr.token_outputs[i]
        
        token_data := make(map[string]interface{})
        token_data["token_id"] = output.selected_token_id
        token_data["logprob"] = output.selected_token_logprob
        
        top_tokens_data := make(vec[interface{}])
        for j := 0; j < len(output.top_tokens); j = j + 1 {
            top_data := make(map[string]interface{})
            top_data["token_id"] = output.top_tokens[j].token_id
            top_data["logprob"] = output.top_tokens[j].logprob
            top_tokens_data = append(top_tokens_data, top_data)
        }
        
        token_data["top_logprobs"] = top_tokens_data
        token_sequences = append(token_sequences, token_data)
    }
    
    export_data["tokens"] = token_sequences
    export_data["stats"] = mgr.get_logprobs_stats()
    
    return export_data
}
