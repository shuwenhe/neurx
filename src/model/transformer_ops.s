package neurx.model.transformer_ops
use std.io.eprintln
func embedding_lookup(
    []int token_ids,
    []float embed_weight,
    int batch_size,
    int seq_len,
    int hidden_size,
    int vocab_size
) []float {
    []float output = make([]float, batch_size * seq_len * hidden_size)
    int idx = 0
    for idx < batch_size * seq_len {
        int token_id = token_ids[idx]
        if token_id < 0 { token_id = 0 }
        if token_id >= vocab_size { token_id = vocab_size - 1 }
        int h = 0
        for h < hidden_size {
            int embed_offset = token_id * hidden_size + h
            int out_offset = idx * hidden_size + h
            output[out_offset] = embed_weight[embed_offset]
            h = h + 1
        }
        idx = idx + 1
    }
    output
}

func rms_norm(
    []float x,
    []float weight,
    int batch_size,
    int seq_len,
    int hidden_size,
    float eps
) []float {
    []float output = make([]float, batch_size * seq_len * hidden_size)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int offset = (b * seq_len + s) * hidden_size
            float sum_sq = 0.0
            int h = 0
            for h < hidden_size {
                float val = x[offset + h]
                sum_sq = sum_sq + val * val
                h = h + 1
            }
            float rms = sqrt_approx(sum_sq / (hidden_size as float) + eps)
            h = 0
            for h < hidden_size {
                output[offset + h] = (x[offset + h] / rms) * weight[h]
                h = h + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    output
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float guess = x / 2.0
    int i = 0
    for i < 5 {
        guess = (guess + x / guess) / 2.0
        i = i + 1
    }
    guess
}

func matmul(
    []float A,
    []float B,
    int M,
    int K,
    int N
) []float {
    []float C = make([]float, M * N)
    int m = 0
    for m < M {
        int n = 0
        for n < N {
            float sum = 0.0
            int k = 0
            for k < K {
                sum = sum + A[m * K + k] * B[k * N + n]
                k = k + 1
            }
            C[m * N + n] = sum
            n = n + 1
        }
        m = m + 1
    }
    C
}

func softmax(
    []float x,
    int total_size,
    int last_dim
) []float {
    []float output = make([]float, total_size)
    int num_softmax = total_size / last_dim
    int i = 0
    for i < num_softmax {
        int offset = i * last_dim
        float max_val = x[offset]
        int j = 1
        for j < last_dim {
            if x[offset + j] > max_val {
                max_val = x[offset + j]
            }
            j = j + 1
        }
        float sum = 0.0
        j = 0
        for j < last_dim {
            float exp_val = exp_approx(x[offset + j] - max_val)
            output[offset + j] = exp_val
            sum = sum + exp_val
            j = j + 1
        }
        j = 0
        for j < last_dim {
            output[offset + j] = output[offset + j] / sum
            j = j + 1
        }
        i = i + 1
    }
    output
}

func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i <= 10 {
        term = term * x / (i as float)
        result = result + term
        i = i + 1
    }
    result
}

func silu([]float x) []float {
    []float output = make([]float, len(x))
    int i = 0
    for i < len(x) {
        float val = x[i]
        output[i] = val / (1.0 + exp_approx(0.0 - val))
        i = i + 1
    }
    output
}

func add_arrays([]float a, []float b) []float {
    int size = len(a)
    if len(b) < size { size = len(b) }
    []float output = make([]float, size)
    int i = 0
    for i < size {
        output[i] = a[i] + b[i]
        i = i + 1
    }
    output
}

func mul_arrays([]float a, []float b) []float {
    int size = len(a)
    if len(b) < size { size = len(b) }
    []float output = make([]float, size)
    int i = 0
    for i < size {
        output[i] = a[i] * b[i]
        i = i + 1
    }
    output
}

func simplified_attention(
    []float hidden_states,
    []float q_weight,
    []float k_weight,
    []float v_weight,
    []float o_weight,
    int batch_size,
    int seq_len,
    int hidden_size,
    int num_heads
) []float {
    int total_tokens = batch_size * seq_len
    []float q = matmul(hidden_states, q_weight, total_tokens, hidden_size, hidden_size)
    []float k = matmul(hidden_states, k_weight, total_tokens, hidden_size, hidden_size)
    []float v = matmul(hidden_states, v_weight, total_tokens, hidden_size, hidden_size)
    int head_dim = hidden_size / num_heads
    float scale = 1.0 / sqrt_approx(head_dim as float)
    []float attn_scores = make([]float, total_tokens * total_tokens)
    int i = 0
    for i < total_tokens {
        int j = 0
        for j < total_tokens {
            float score = 0.0
            int h = 0
            for h < head_dim {
                score = score + q[i * hidden_size + h] * k[j * hidden_size + h]
                h = h + 1
            }
            attn_scores[i * total_tokens + j] = score * scale
            j = j + 1
        }
        i = i + 1
    }
    []float attn_weights = softmax(attn_scores, total_tokens * total_tokens, total_tokens)
    []float context = make([]float, total_tokens * hidden_size)
    i = 0
    for i < total_tokens {
        int h = 0
        for h < head_dim {
            float sum = 0.0
            int j = 0
            for j < total_tokens {
                sum = sum + attn_weights[i * total_tokens + j] * v[j * hidden_size + h]
                j = j + 1
            }
            context[i * hidden_size + h] = sum
            h = h + 1
        }
        i = i + 1
    }
    []float output = matmul(context, o_weight, total_tokens, hidden_size, hidden_size)
    output
}

func swiglu_mlp(
    []float hidden_states,
    []float gate_weight,
    []float up_weight,
    []float down_weight,
    int batch_size,
    int seq_len,
    int hidden_size,
    int intermediate_size
) []float {
    int total_tokens = batch_size * seq_len
    []float gate = matmul(hidden_states, gate_weight, total_tokens, hidden_size, intermediate_size)
    []float up = matmul(hidden_states, up_weight, total_tokens, hidden_size, intermediate_size)
    []float silu_up = silu(up)
    []float activated = mul_arrays(gate, silu_up)
    []float output = matmul(activated, down_weight, total_tokens, intermediate_size, hidden_size)
    output
}

func transformer_layer(
    []float hidden_states,
    []float input_ln_weight,
    []float post_ln_weight,
    []float q_weight,
    []float k_weight,
    []float v_weight,
    []float o_weight,
    []float gate_weight,
    []float up_weight,
    []float down_weight,
    int batch_size,
    int seq_len,
    int hidden_size,
    int num_heads,
    int intermediate_size
) []float {
    []float normed = rms_norm(hidden_states, input_ln_weight, batch_size, seq_len, hidden_size, 0.000001)
    []float attn_output = simplified_attention(normed, q_weight, k_weight, v_weight, o_weight,
                                               batch_size, seq_len, hidden_size, num_heads)
    []float after_attn = add_arrays(hidden_states, attn_output)
    normed = rms_norm(after_attn, post_ln_weight, batch_size, seq_len, hidden_size, 0.000001)
    []float mlp_output = swiglu_mlp(normed, gate_weight, up_weight, down_weight,
                                    batch_size, seq_len, hidden_size, intermediate_size)
    []float output = add_arrays(after_attn, mlp_output)
    output
}
