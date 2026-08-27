package neurx.inference.attention_optimized

use std.conv.int_to_string

struct attention_state {
    float[] query
    float[] key
    float[] value
    float[] output
    int seq_len
    int head_dim
}

func attention_standard(float[] query, float[] key, float[] value, int seq_len, int head_dim) float[] {

    float[] scores = matmul_seq(query, key, seq_len, head_dim)

    float[] attn_weights = softmax_2d(scores, seq_len)

    float[] output = matmul_attn(attn_weights, value, seq_len, head_dim)

    output
}

func attention_fused(float[] query, float[] key, float[] value, int seq_len, int head_dim) float[] {
    float[] output = float[]{cap: seq_len * head_dim}

    int i = 0
    for i < seq_len * head_dim {
        output[i] = 0.0
        i = i + 1
    }

    float[] norm_factor = float[]{cap: seq_len}
    i = 0
    for i < seq_len {
        norm_factor[i] = 0.0
        i = i + 1
    }

    int q_pos = 0
    for q_pos < seq_len {
        float[] exp_scores = float[]{cap: seq_len}
        float max_score = -999999.0

        int k_pos = 0
        for k_pos < seq_len {
            float score = 0.0
            int d = 0
            for d < head_dim {
                score = score + query[q_pos * head_dim + d] * key[k_pos * head_dim + d]
                d = d + 1
            }
            score = score / sqrt_approx(float(head_dim))

            if score > max_score {
                max_score = score
            }

            exp_scores[k_pos] = score
            k_pos = k_pos + 1
        }

        float sum_exp = 0.0
        k_pos = 0
        for k_pos < seq_len {
            exp_scores[k_pos] = exp_approx(exp_scores[k_pos] - max_score)
            sum_exp = sum_exp + exp_scores[k_pos]
            k_pos = k_pos + 1
        }

        norm_factor[q_pos] = sum_exp

        k_pos = 0
        for k_pos < seq_len {
            float weight = exp_scores[k_pos] / sum_exp

            int d = 0
            for d < head_dim {
                output[q_pos * head_dim + d] = output[q_pos * head_dim + d] + weight * value[k_pos * head_dim + d]
                d = d + 1
            }

            k_pos = k_pos + 1
        }

        q_pos = q_pos + 1
    }

    output
}

func attention_cached(float[] query, float[] kv_cache, int seq_len, int kv_cache_len, int head_dim) float[] {

    float[] output = float[]{cap: head_dim}

    int i = 0
    for i < head_dim {
        output[i] = 0.0
        i = i + 1
    }

    float max_score = -999999.0
    float[] exp_scores = float[]{cap: kv_cache_len}

    int cache_pos = 0
    for cache_pos < kv_cache_len {
        float score = 0.0
        int d = 0
        for d < head_dim {

            score = score + query[d] * kv_cache[cache_pos * 2 * head_dim + d]
            d = d + 1
        }
        score = score / sqrt_approx(float(head_dim))

        if score > max_score {
            max_score = score
        }

        exp_scores[cache_pos] = score
        cache_pos = cache_pos + 1
    }

    float sum_exp = 0.0
    cache_pos = 0
    for cache_pos < kv_cache_len {
        exp_scores[cache_pos] = exp_approx(exp_scores[cache_pos] - max_score)
        sum_exp = sum_exp + exp_scores[cache_pos]
        cache_pos = cache_pos + 1
    }

    cache_pos = 0
    for cache_pos < kv_cache_len {
        float weight = exp_scores[cache_pos] / sum_exp

        int d = 0
        for d < head_dim {

            output[d] = output[d] + weight * kv_cache[cache_pos * 2 * head_dim + head_dim + d]
            d = d + 1
        }

        cache_pos = cache_pos + 1
    }

    output
}

func attention_gqa(float[] query_heads, float[] kv_cache, int num_query_heads, int num_kv_heads, int head_dim, int kv_cache_len) float[] {
    float[] output = float[]{cap: num_query_heads * head_dim}

    int q_head = 0
    for q_head < num_query_heads {

        int kv_head = q_head / (num_query_heads / num_kv_heads)

        float[] query_for_head = float[]{cap: head_dim}
        int d = 0
        for d < head_dim {
            query_for_head[d] = query_heads[q_head * head_dim + d]
            d = d + 1
        }

        float[] head_output = attention_cached_gqa(query_for_head, kv_cache, kv_head, head_dim, kv_cache_len)

        d = 0
        for d < head_dim {
            output[q_head * head_dim + d] = head_output[d]
            d = d + 1
        }

        q_head = q_head + 1
    }

    output
}

func attention_cached_gqa(float[] query, float[] kv_cache, int kv_head, int head_dim, int kv_cache_len) float[] {
    float[] output = float[]{cap: head_dim}

    int i = 0
    for i < head_dim {
        output[i] = 0.0
        i = i + 1
    }

    float max_score = -999999.0
    float[] exp_scores = float[]{cap: kv_cache_len}

    int cache_pos = 0
    for cache_pos < kv_cache_len {
        float score = 0.0
        int d = 0
        for d < head_dim {

            score = score + query[d] * kv_cache[cache_pos * 2 * head_dim + kv_head * head_dim + d]
            d = d + 1
        }
        score = score / sqrt_approx(float(head_dim))

        if score > max_score {
            max_score = score
        }

        exp_scores[cache_pos] = score
        cache_pos = cache_pos + 1
    }

    float sum_exp = 0.0
    cache_pos = 0
    for cache_pos < kv_cache_len {
        exp_scores[cache_pos] = exp_approx(exp_scores[cache_pos] - max_score)
        sum_exp = sum_exp + exp_scores[cache_pos]
        cache_pos = cache_pos + 1
    }

    cache_pos = 0
    for cache_pos < kv_cache_len {
        float weight = exp_scores[cache_pos] / sum_exp

        int d = 0
        for d < head_dim {

            output[d] = output[d] + weight * kv_cache[cache_pos * 2 * head_dim + head_dim + kv_head * head_dim + d]
            d = d + 1
        }

        cache_pos = cache_pos + 1
    }

    output
}

func sqrt_approx(float x) float {
    if x < 0.0 { return 0.0 }
    x * 0.5
}

func exp_approx(float x) float {

    if x > 50.0 { return 50.0 }
    if x < -50.0 { return 0.0 }

    float result = 1.0
    float term = 1.0
    int i = 1
    for i < 8 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

func matmul_seq(float[] q, float[] k, int seq_len, int head_dim) float[] {
    float[] scores = float[]{cap: seq_len * seq_len}
    int i = 0
    for i < seq_len {
        int j = 0
        for j < seq_len {
            float sum = 0.0
            int d = 0
            for d < head_dim {
                sum = sum + q[i * head_dim + d] * k[j * head_dim + d]
                d = d + 1
            }
            scores[i * seq_len + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    scores
}

func softmax_2d(float[] scores, int seq_len) float[] {
    float[] result = float[]{cap: seq_len * seq_len}
    int i = 0
    for i < seq_len {
        float max_val = -999999.0
        int j = 0
        for j < seq_len {
            if scores[i * seq_len + j] > max_val {
                max_val = scores[i * seq_len + j]
            }
            j = j + 1
        }

        float sum_exp = 0.0
        j = 0
        for j < seq_len {
            result[i * seq_len + j] = exp_approx(scores[i * seq_len + j] - max_val)
            sum_exp = sum_exp + result[i * seq_len + j]
            j = j + 1
        }

        j = 0
        for j < seq_len {
            result[i * seq_len + j] = result[i * seq_len + j] / sum_exp
            j = j + 1
        }
        i = i + 1
    }
    result
}

func matmul_attn(float[] attn, float[] value, int seq_len, int head_dim) float[] {
    float[] output = float[]{cap: seq_len * head_dim}
    int i = 0
    for i < seq_len {
        int d = 0
        for d < head_dim {
            float sum = 0.0
            int j = 0
            for j < seq_len {
                sum = sum + attn[i * seq_len + j] * value[j * head_dim + d]
                j = j + 1
            }
            output[i * head_dim + d] = sum
            d = d + 1
        }
        i = i + 1
    }
    output
}
