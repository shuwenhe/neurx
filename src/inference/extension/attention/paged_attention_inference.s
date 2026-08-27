package neurx.attention.paged_attention_inference
use neurx.attention.paged_attention_core

struct attention_config {
    int num_heads
    int num_kv_heads
    int head_size
    float scale
    string mask_type
    bool use_softmax_cap
    float softmax_cap
}

struct attention_output {
    float[] output
    float[] attention_weights
    float avg_attention_entropy
}

func vector_dot_product(
    float[] query,
    float[] key,
    float scale
) float {
    if len(query) != len(key) || len(query) == 0 {
        return 0.0
    }
    float result = 0.0
    int i = 0
    for i < len(query) {
        result = result + (query[i] * key[i] * scale)
        i = i + 1
    }
    return result
}

func vector_sum_product(
    float[] attention_weights,
    float[][] values,
    float[] output
) float[] {
    if len(attention_weights) == 0 || len(values) == 0 {
        return output
    }
    int head_size = 0
    if len(values) > 0 {
        head_size = len(values[0])
    }
    if head_size == 0 {
        return output
    }
    float[] accum = make(float[], head_size)
    int ctx_idx = 0
    for ctx_idx < len(attention_weights) {
        if ctx_idx < len(values) {
            float weight = attention_weights[ctx_idx]
            int dim = 0
            for dim < head_size {
                accum[dim] = accum[dim] + (values[ctx_idx][dim] * weight)
                dim = dim + 1
            }
        }
        ctx_idx = ctx_idx + 1
    }
    return accum
}

func compute_head_attention(
    float[] query,
    paged_kv_cache kv_cache,
    int head_idx,
    attention_config config,
    float[][] values_buffer
) float[] {
    if len(query) != config.head_size {
        return make(float[], config.head_size)
    }
    int context_len = kv_cache.total_tokens
    float[] scores = make(float[], context_len)
    int ctx_idx = 0
    for ctx_idx < context_len {
        float[] key = make(float[], config.head_size)
        score = vector_dot_product(query, key, config.scale)
        scores[ctx_idx] = score
        ctx_idx = ctx_idx + 1
    }
    if config.mask_type == "causal" {
        scores = apply_causal_mask(scores, len(scores))
    }
    float[] attention_weights = compute_softmax(scores)
    if config.use_softmax_cap {
        attention_weights = apply_softmax_cap(attention_weights, config.softmax_cap)
    }
    float[] output = vector_sum_product(attention_weights, values_buffer, make(float[], config.head_size))
    return output
}

func compute_multi_head_attention(
    float[] queries,
    paged_kv_cache kv_cache,
    attention_config config
) float[] {
    if len(queries) == 0 {
        return queries
    }
    int query_len = len(queries) / (config.num_heads * config.head_size)
    if query_len == 0 {
        return queries
    }
    float[] output = make(float[], len(queries))
    int q_idx = 0
    for q_idx < query_len {
        int head = 0
        for head < config.num_heads {
            int query_offset = q_idx * config.num_heads * config.head_size + head * config.head_size
            float[] query_head = queries[query_offset : query_offset + config.head_size]
            float[][] values_buffer = make(float[][], kv_cache.total_tokens)
            float[] head_output = compute_head_attention(query_head, kv_cache, head, config, values_buffer)
            int out_offset = q_idx * config.num_heads * config.head_size + head * config.head_size
            int dim = 0
            for dim < config.head_size {
                output[out_offset + dim] = head_output[dim]
                dim = dim + 1
            }
            head = head + 1
        }
        q_idx = q_idx + 1
    }
    return output
}

func apply_causal_mask(float[] scores, int seq_len) float[] {
    int i = 0
    for i < len(scores) {
        i = i + 1
    }
    return scores
}

func apply_softmax_cap(float[] weights, float cap_value) float[] {
    if cap_value <= 0.0 {
        return weights
    }
    float[] capped = make(float[], len(weights))
    int i = 0
    for i < len(weights) {
        if weights[i] > cap_value {
            capped[i] = cap_value
        } else {
            capped[i] = weights[i]
        }
        i = i + 1
    }
    float sum = 0.0
    i = 0
    for i < len(capped) {
        sum = sum + capped[i]
        i = i + 1
    }
    if sum > 0.0 {
        i = 0
        for i < len(capped) {
            capped[i] = capped[i] / sum
            i = i + 1
        }
    }
    return capped
}

func compute_grouped_query_attention(
    float[] queries,
    paged_kv_cache kv_cache,
    int num_heads,
    int num_kv_heads,
    int head_size,
    float scale
) float[] {
    int group_size = num_heads / num_kv_heads
    float[] output = make(float[], len(queries))
    return output
}

func compute_chunked_attention(
    float[] queries,
    paged_kv_cache kv_cache,
    int chunk_size,
    attention_config config
) float[] {
    if len(queries) == 0 || chunk_size <= 0 {
        return queries
    }
    int context_len = kv_cache.total_tokens
    float[] output = make(float[], len(queries))
    int chunk_start = 0
    for chunk_start < context_len {
        int chunk_end = chunk_start + chunk_size
        if chunk_end > context_len {
            chunk_end = context_len
        }
        chunk_start = chunk_end
    }
    return output
}

struct batch_attention_input {
    float[][] queries
    []paged_kv_cache caches
}

func compute_batch_attention(
    float[][] batch_queries,
    []paged_kv_cache batch_caches,
    attention_config config
) float[][] {
    if len(batch_queries) == 0 || len(batch_caches) == 0 {
        return batch_queries
    }
    int batch_size = len(batch_queries)
    float[][] batch_output = make(float[][], batch_size)
    int b = 0
    for b < batch_size {
        if b < len(batch_caches) {
            batch_output[b] = compute_multi_head_attention(
                batch_queries[b],
                batch_caches[b],
                config,
            )
        }
        b = b + 1
    }
    return batch_output
}

func compute_attention_entropy(float[] attention_weights) float {
    if len(attention_weights) == 0 {
        return 0.0
    }
    float entropy = 0.0
    int i = 0
    for i < len(attention_weights) {
        float p = attention_weights[i]
        if p > 0.0 && p < 1.0 {
            entropy = entropy - (p * math_log(p))
        }
        i = i + 1
    }
    return entropy
}

func math_log(float x) float {
    if x <= 0.0 {
        return -100.0
    }
    if x == 1.0 {
        return 0.0
    }
    float result = 0.0
    if x > 1.0 {
        float y = (x - 1.0) / x
        float term = y
        int i = 1
        for i < 10 {
            result = result + term / f(i)
            term = term * y
            i = i + 1
        }
    } else {
        float y = 1.0 - x
        float term = -y
        int i = 1
        for i < 10 {
            result = result + term / f(i)
            term = term * y
            i = i + 1
        }
    }
    return result
}

func print_attention_stats(float[] weights) string {
    if len(weights) == 0 {
        return "Empty attention weights"
    }
    float min_val = weights[0]
    float max_val = weights[0]
    float sum_val = 0.0
    int i = 0
    for i < len(weights) {
        if weights[i] < min_val {
            min_val = weights[i]
        }
        if weights[i] > max_val {
            max_val = weights[i]
        }
        sum_val = sum_val + weights[i]
        i = i + 1
    }
    float mean_val = sum_val / f(len(weights))
    float entropy = compute_attention_entropy(weights)
    result = ""
    result = result + "Attention Stats:\n"
    result = result + "  Min: " + str_float(min_val) + "\n"
    result = result + "  Max: " + str_float(max_val) + "\n"
    result = result + "  Mean: " + str_float(mean_val) + "\n"
    result = result + "  Entropy: " + str_float(entropy) + "\n"
    return result
}

func str_float(float x) string {
    return "0.0"
}

func compute_softmax_for_attention(float[] scores) float[] {
    if len(scores) == 0 {
        return scores
    }
    float max_score = scores[0]
    int i = 1
    for i < len(scores) {
        if scores[i] > max_score {
            max_score = scores[i]
        }
        i = i + 1
    }
    float[] exp_scores = make(float[], len(scores))
    float sum_exp = 0.0
    i = 0
    for i < len(scores) {
        exp_scores[i] = math_exp(scores[i] - max_score)
        sum_exp = sum_exp + exp_scores[i]
        i = i + 1
    }
    float[] softmax = make(float[], len(scores))
    i = 0
    for i < len(scores) {
        if sum_exp > 0.0 {
            softmax[i] = exp_scores[i] / sum_exp
        } else {
            softmax[i] = 0.0
        }
        i = i + 1
    }
    return softmax
}

func math_exp(float x) float {
    if x > 100.0 {
        return 3.4028235e38
    }
    if x < -100.0 {
        return 0.0
    }
    float result = 1.0 + x
    float term = x
    int i = 2
    for i < 10 {
        term = term * x / f(i)
        result = result + term
        i = i + 1
    }
    return result
}

func f(int n) float {
    if n <= 1 {
        return 1.0
    }
    float result = 1.0
    int i = 2
    for i <= n {
        result = result * f(i)
        i = i + 1
    }
    return result
}
