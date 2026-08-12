package neurx.attention.gradient
struct attention_forward_cache {
    []float hidden_states
    []float concatenated
    []float query
    []float key
    []float value
    []float attention_weights
    []float query_reshaped
    []float key_reshaped
    []float value_reshaped
    []float output
    int seq_len
    int hidden_dim
    int num_heads
    int head_dim
    float scale_factor
}

struct scaled_dot_product_attention_backward_result {
    []float d_query
    []float d_key
    []float d_value
}

struct projection_backward_result {
    []float d_input
    []float d_weights
}

struct attention_gradients {
    []float d_query
    []float d_key
    []float d_value
    []float d_wq
    []float d_wk
    []float d_wv
    []float d_wo
    []float d_hidden_states
}

func softmax_backward(
    []float input_grad,
    []float softmax_output,
    int seq_len
) []float {
    []float output_grad = allocate_vector(seq_len, 0.0)
    float sum_grad_softmax = 0.0
    int i = 0
    while i < seq_len {
        sum_grad_softmax = sum_grad_softmax + input_grad[i] * softmax_output[i]
        i = i + 1
    }
    i = 0
    while i < seq_len {
        output_grad[i] = softmax_output[i] * (input_grad[i] - sum_grad_softmax)
        i = i + 1
    }
    return output_grad
}

func scaled_dot_product_attention_backward(
    []float d_output,
    attention_forward_cache cache
) scaled_dot_product_attention_backward_result {
    int seq_len = cache.seq_len
    int num_heads = cache.num_heads
    int head_dim = cache.head_dim
    float scale = cache.scale_factor
    int size_per_head = seq_len * head_dim
    []float d_query = allocate_vector(seq_len * num_heads * head_dim, 0.0)
    []float d_key = allocate_vector(seq_len * num_heads * head_dim, 0.0)
    []float d_value = allocate_vector(seq_len * num_heads * head_dim, 0.0)
    int h = 0
    while h < num_heads {
        int q_offset = h * size_per_head
        int k_offset = h * size_per_head
        int v_offset = h * size_per_head
        int i = 0
        while i < seq_len {
            int j = 0
            while j < seq_len {
                int attn_idx = h * seq_len * seq_len + i * seq_len + j
                float attn_weight = cache.attention_weights[attn_idx]
                int d = 0
                while d < head_dim {
                    int v_idx = v_offset + j * head_dim + d
                    int out_idx = q_offset + i * head_dim + d
                    d_value[v_idx] = d_value[v_idx] + attn_weight * d_output[out_idx]
                    d = d + 1
                }
                j = j + 1
            }
            []float d_scores = allocate_vector(seq_len, 0.0)
            j = 0
            while j < seq_len {
                int attn_idx = h * seq_len * seq_len + i * seq_len + j
                float attn_weight = cache.attention_weights[attn_idx]
                int d = 0
                float grad_sum = 0.0
                while d < head_dim {
                    int out_idx = q_offset + i * head_dim + d
                    int v_idx = v_offset + j * head_dim + d
                    grad_sum = grad_sum + d_output[out_idx] * cache.value_reshaped[v_idx]
                    d = d + 1
                }
                d_scores[j] = grad_sum
                j = j + 1
            }
            []float d_attn = softmax_backward(d_scores, slice_row(cache.attention_weights, h * seq_len * seq_len + i * seq_len, seq_len), seq_len)
            j = 0
            while j < seq_len {
                float d_score = d_attn[j] * scale
                int d = 0
                while d < head_dim {
                    int q_idx = q_offset + i * head_dim + d
                    int k_idx = k_offset + j * head_dim + d
                    d_query[q_idx] = d_query[q_idx] + d_score * cache.key_reshaped[k_idx]
                    d_key[k_idx] = d_key[k_idx] + d_score * cache.query_reshaped[q_idx]
                    d = d + 1
                }
                j = j + 1
            }
            i = i + 1
        }
        h = h + 1
    }
    scaled_dot_product_attention_backward_result result
    result.d_query = d_query
    result.d_key = d_key
    result.d_value = d_value
    return result
}

func projection_backward(
    []float d_output,
    []float input,
    []float weights,
    int seq_len,
    int input_dim,
    int output_dim
) projection_backward_result {
    []float d_input = matrix_multiply_transpose(d_output, weights, seq_len, output_dim, input_dim)
    []float d_weights = matrix_multiply_transpose_lhs(input, d_output, input_dim, seq_len, output_dim)
    projection_backward_result result
    result.d_input = d_input
    result.d_weights = d_weights
    return result
}

func attention_backward(
    []float d_output,
    attention_forward_cache cache,
    []float wq,
    []float wk,
    []float wv,
    []float wo
) attention_gradients {
    int seq_len = cache.seq_len
    int hidden_dim = cache.hidden_dim
    int num_heads = cache.num_heads
    int head_dim = cache.head_dim
    projection_backward_result wo_grads = projection_backward(d_output, cache.concatenated, wo, seq_len, hidden_dim, hidden_dim)
    []float d_concatenated = wo_grads.d_input
    []float d_wo = wo_grads.d_weights
    []float d_reshaped = reshape_for_heads(d_concatenated, seq_len, num_heads, head_dim)
    scaled_dot_product_attention_backward_result attn_grads = scaled_dot_product_attention_backward(d_reshaped, cache)
    []float d_query_reshaped = attn_grads.d_query
    []float d_key_reshaped = attn_grads.d_key
    []float d_value_reshaped = attn_grads.d_value
    []float d_query = reshape_from_heads(d_query_reshaped, seq_len, num_heads, head_dim)
    []float d_key = reshape_from_heads(d_key_reshaped, seq_len, num_heads, head_dim)
    []float d_value = reshape_from_heads(d_value_reshaped, seq_len, num_heads, head_dim)
    projection_backward_result q_grads = projection_backward(d_query, cache.hidden_states, wq, seq_len, hidden_dim, hidden_dim)
    projection_backward_result k_grads = projection_backward(d_key, cache.hidden_states, wk, seq_len, hidden_dim, hidden_dim)
    projection_backward_result v_grads = projection_backward(d_value, cache.hidden_states, wv, seq_len, hidden_dim, hidden_dim)
    []float d_hidden_q = q_grads.d_input
    []float d_wq = q_grads.d_weights
    []float d_hidden_k = k_grads.d_input
    []float d_wk = k_grads.d_weights
    []float d_hidden_v = v_grads.d_input
    []float d_wv = v_grads.d_weights
    []float d_hidden_states = allocate_vector(seq_len * hidden_dim, 0.0)
    int i = 0
    while i < seq_len * hidden_dim {
        d_hidden_states[i] = d_hidden_q[i] + d_hidden_k[i] + d_hidden_v[i]
        i = i + 1
    }
    attention_gradients grads
    grads.d_query = d_query
    grads.d_key = d_key
    grads.d_value = d_value
    grads.d_wq = d_wq
    grads.d_wk = d_wk
    grads.d_wv = d_wv
    grads.d_wo = d_wo
    grads.d_hidden_states = d_hidden_states
    return grads
}

func slice_row([]float matrix, int row_start, int row_len) []float {
    []float row = allocate_vector(row_len, 0.0)
    int i = 0
    while i < row_len {
        row[i] = matrix[row_start + i]
        i = i + 1
    }
    return row
}

func matrix_multiply_transpose([]float a, []float b, int m, int k, int n) []float {
    []float result = allocate_vector(m * n, 0.0)
    int i = 0
    while i < m {
        int j = 0
        while j < n {
            float sum = 0.0
            int l = 0
            while l < k {
                int a_idx = i * k + l
                int b_idx = j * k + l
                sum = sum + a[a_idx] * b[b_idx]
                l = l + 1
            }
            result[i * n + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    return result
}

func matrix_multiply_transpose_lhs([]float a, []float b, int m, int k, int n) []float {
    []float result = allocate_vector(m * n, 0.0)
    int i = 0
    while i < m {
        int j = 0
        while j < n {
            float sum = 0.0
            int l = 0
            while l < k {
                int a_idx = l * m + i
                int b_idx = l * n + j
                sum = sum + a[a_idx] * b[b_idx]
                l = l + 1
            }
            result[i * n + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    return result
}

func reshape_for_heads([]float x, int seq_len, int num_heads, int head_dim) []float {
    int size = seq_len * num_heads * head_dim
    []float reshaped = allocate_vector(size, 0.0)
    int i = 0
    while i < size {
        reshaped[i] = x[i]
        i = i + 1
    }
    return reshaped
}

func reshape_from_heads([]float x, int seq_len, int num_heads, int head_dim) []float {
    int hidden_dim = num_heads * head_dim
    int size = seq_len * hidden_dim
    []float reshaped = allocate_vector(size, 0.0)
    int i = 0
    while i < size {
        reshaped[i] = x[i]
        i = i + 1
    }
    return reshaped
}

func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v.push(init_val)
        i = i + 1
    }
    return v
}

