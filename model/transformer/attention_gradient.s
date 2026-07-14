package neurx.model.transformer.attention_grad

// =====================================================================
// Multi-Head Attention Backward Pass (Gradient Computation)
// =====================================================================

// Structure to store intermediate values needed for backward pass
struct attention_forward_cache {
    []float hidden_states       // Input to Q/K/V projections: [seq_len, hidden_dim]
    []float concatenated        // Input to output projection: [seq_len, hidden_dim]
    []float query              // Q: [seq_len, hidden_dim]
    []float key                // K: [seq_len, hidden_dim]
    []float value              // V: [seq_len, hidden_dim]
    []float attention_weights  // Softmax output: [seq_len, num_heads, seq_len]
    []float query_reshaped     // [seq_len, num_heads, head_dim]
    []float key_reshaped       // [seq_len, num_heads, head_dim]
    []float value_reshaped     // [seq_len, num_heads, head_dim]
    []float output             // Final output: [seq_len, hidden_dim]
    
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

// Gradient structure for attention module
struct attention_gradients {
    []float d_query            // Gradient w.r.t. query
    []float d_key              // Gradient w.r.t. key
    []float d_value            // Gradient w.r.t. value
    []float d_wq               // Gradient w.r.t. query weights
    []float d_wk               // Gradient w.r.t. key weights
    []float d_wv               // Gradient w.r.t. value weights
    []float d_wo               // Gradient w.r.t. output weights
    []float d_hidden_states    // Gradient w.r.t. input hidden states
}

// =====================================================================
// Backward Pass for Scaled Dot-Product Attention
// =====================================================================

// Compute gradient of softmax
// input_grad: gradient from next layer (downstream)
// softmax_output: output from forward pass
// Returns: gradient w.r.t. softmax input (pre-softmax scores)
func softmax_backward(
    []float input_grad,     // dL/d_softmax_output
    []float softmax_output, // softmax(x)
    int seq_len
) []float {
    []float output_grad = allocate_vector(seq_len, 0.0)
    
    // d_softmax_input[i] = sum_j(d_softmax_output[j] * softmax[j] * delta(i,j) - softmax[i] * softmax[j])
    // Simplified: d_input[i] = softmax[i] * (d_output[i] - sum(d_output * softmax))
    
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

// Backward pass for scaled dot-product attention
// d_output: gradient from downstream [seq_len, num_heads, head_dim]
// cache: forward pass cache
// Returns: (d_query, d_key, d_value)
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
        
        // For each query position i
        int i = 0
        while i < seq_len {
            // d_value gradient: d_value[j] += attn_weight[i,j] * d_output[i]
            // d_attn_weight[i,j] = d_output[i] * value[j]
            
            int j = 0
            while j < seq_len {
                int attn_idx = h * seq_len * seq_len + i * seq_len + j
                float attn_weight = cache.attention_weights[attn_idx]
                
                // Gradient w.r.t. value
                int d = 0
                while d < head_dim {
                    int v_idx = v_offset + j * head_dim + d
                    int out_idx = q_offset + i * head_dim + d
                    d_value[v_idx] = d_value[v_idx] + attn_weight * d_output[out_idx]
                    d = d + 1
                }
                j = j + 1
            }
            
            // Gradient through softmax and scaling
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
            
            // Softmax backward
            []float d_attn = softmax_backward(d_scores, slice_row(cache.attention_weights, h * seq_len * seq_len + i * seq_len, seq_len), seq_len)
            
            // Gradient w.r.t. Q and K through scaled dot-product
            j = 0
            while j < seq_len {
                float d_score = d_attn[j] * scale
                
                // d_query[i] += d_score * key[j]
                // d_key[j] += d_score * query[i]
                
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

// Backward pass for projection layers
// d_output: gradient from downstream [seq_len, hidden_dim]
// input: input to the projection [seq_len, hidden_dim]
// weights: projection weights [hidden_dim, hidden_dim]
// Returns: (d_input, d_weights, d_bias)
func projection_backward(
    []float d_output,
    []float input,
    []float weights,
    int seq_len,
    int input_dim,
    int output_dim
) projection_backward_result {
    
    // d_input = d_output @ weights^T
    []float d_input = matrix_multiply_transpose(d_output, weights, seq_len, output_dim, input_dim)
    
    // d_weights = input^T @ d_output
    []float d_weights = matrix_multiply_transpose_lhs(input, d_output, input_dim, seq_len, output_dim)
    
    projection_backward_result result
    result.d_input = d_input
    result.d_weights = d_weights

    return result
}

// =====================================================================
// Full Backward Pass
// =====================================================================

// Complete backward pass for attention layer
func attention_backward(
    []float d_output,          // Gradient from downstream
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
    
    // 1. Gradient through output projection
    projection_backward_result wo_grads = projection_backward(d_output, cache.concatenated, wo, seq_len, hidden_dim, hidden_dim)
    []float d_concatenated = wo_grads.d_input
    []float d_wo = wo_grads.d_weights
    
    // 2. Reshape d_output back to [seq_len, num_heads, head_dim]
    []float d_reshaped = reshape_for_heads(d_concatenated, seq_len, num_heads, head_dim)
    
    // 3. Gradient through attention computation
    scaled_dot_product_attention_backward_result attn_grads = scaled_dot_product_attention_backward(d_reshaped, cache)
    []float d_query_reshaped = attn_grads.d_query
    []float d_key_reshaped = attn_grads.d_key
    []float d_value_reshaped = attn_grads.d_value
    
    // 4. Reshape back to [seq_len, hidden_dim]
    []float d_query = reshape_from_heads(d_query_reshaped, seq_len, num_heads, head_dim)
    []float d_key = reshape_from_heads(d_key_reshaped, seq_len, num_heads, head_dim)
    []float d_value = reshape_from_heads(d_value_reshaped, seq_len, num_heads, head_dim)
    
    // 5. Gradients through Q, K, V projections
    projection_backward_result q_grads = projection_backward(d_query, cache.hidden_states, wq, seq_len, hidden_dim, hidden_dim)
    projection_backward_result k_grads = projection_backward(d_key, cache.hidden_states, wk, seq_len, hidden_dim, hidden_dim)
    projection_backward_result v_grads = projection_backward(d_value, cache.hidden_states, wv, seq_len, hidden_dim, hidden_dim)
    []float d_hidden_q = q_grads.d_input
    []float d_wq = q_grads.d_weights
    []float d_hidden_k = k_grads.d_input
    []float d_wk = k_grads.d_weights
    []float d_hidden_v = v_grads.d_input
    []float d_wv = v_grads.d_weights
    
    // 6. Combine gradients w.r.t. hidden states
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

// =====================================================================
// Helper Functions
// =====================================================================

// Helper: extract row from matrix
func slice_row([]float matrix, int row_start, int row_len) []float {
    []float row = allocate_vector(row_len, 0.0)
    int i = 0
    while i < row_len {
        row[i] = matrix[row_start + i]
        i = i + 1
    }
    return row
}

// Helper: matrix multiply with transposed second argument
// A: [m, k], B: [n, k] -> result: [m, n]
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

// Helper: matrix multiply with transposed first argument
// A: [k, m], B: [k, n] -> result: [m, n]
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

// Helper: reshape gradient from [seq_len, hidden_dim] to [seq_len, num_heads, head_dim]
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

// Helper: reshape back from [seq_len, num_heads, head_dim] to [seq_len, hidden_dim]
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

// Helper: allocate vector
func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v.push(init_val)
        i = i + 1
    }
    return v
}
