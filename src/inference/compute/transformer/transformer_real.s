package neurx.inference.transformer_real
extern "intrinsic" func __host_slice(string text, int start, int end) string

struct attention_state {
    []float query
    []float key
    []float value
    []float output
}

struct rope_cache {
    []float cos_cache
    []float sin_cache
    int max_pos
    int dim
}

func rope_init(int max_seq_len, int hidden_dim) rope_cache {
    int num_heads = 12
    int head_dim = hidden_dim / num_heads

    []float cos_cache = []float{cap: max_seq_len * head_dim}
    []float sin_cache = []float{cap: max_seq_len * head_dim}

    int pos = 0
    for pos < max_seq_len {
        int dim = 0
        for dim < head_dim {
            float theta = 1000000.0
            float exp_i = float(dim) / float(head_dim)
            theta = theta * exp_approx(0.0 - exp_i * 0.69314718)

            float m_theta = float(pos) * theta
            float cos_val = cos_approx(m_theta)
            float sin_val = sin_approx(m_theta)

            cos_cache[pos * head_dim + dim] = cos_val
            sin_cache[pos * head_dim + dim] = sin_val

            dim = dim + 1
        }
        pos = pos + 1
    }

    rope_cache{cos_cache: cos_cache, sin_cache: sin_cache, max_pos: max_seq_len, dim: head_dim}
}

func cos_approx(float x) float {
    for x > 6.28318531 {
        x = x - 6.28318531
    }
    for x < 0.0 {
        x = x + 6.28318531
    }

    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2

    return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0
}

func sin_approx(float x) float {
    for x > 6.28318531 {
        x = x - 6.28318531
    }
    for x < 0.0 {
        x = x + 6.28318531
    }

    float x2 = x * x
    float x3 = x2 * x
    float x5 = x3 * x2
    float x7 = x5 * x2

    return x - x3 / 6.0 + x5 / 120.0 - x7 / 5040.0
}

func exp_approx(float x) float {
    if x < -10.0 {
        return 0.0
    }
    if x > 10.0 {
        return 10000.0
    }
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    return 1.0 + x + x2 / 2.0 + x3 / 6.0 + x4 / 24.0
}

func apply_rope([]float q, []float k, rope_cache rope, int position) ([]float, []float) {
    int head_dim = rope.dim
    if position >= rope.max_pos {
        return q, k
    }

    []float q_rot = []float{cap: len(q)}
    []float k_rot = []float{cap: len(k)}

    int i = 0
    for i < len(q) {
        int head_idx = i / head_dim
        int dim_idx = i - head_idx * head_dim

        if dim_idx < 2 {
            float cos_val = rope.cos_cache[position * head_dim + dim_idx]
            float sin_val = rope.sin_cache[position * head_dim + dim_idx]

            int pair_idx = i + (1 - dim_idx * 2)
            if pair_idx < len(q) {
                q_rot[i] = q[i] * cos_val - q[pair_idx] * sin_val
                k_rot[i] = k[i] * cos_val - k[pair_idx] * sin_val
            } else {
                q_rot[i] = q[i]
                k_rot[i] = k[i]
            }
        } else {
            q_rot[i] = q[i]
            k_rot[i] = k[i]
        }

        i = i + 1
    }

    return q_rot, k_rot
}

func multi_head_attention([]float input, []float weights_qkv, []float weights_out, int num_heads, int hidden_dim) []float {
    int head_dim = hidden_dim / num_heads
    []float output = []float{cap: len(input)}

    []float query = project_linear(input, weights_qkv, hidden_dim)
    []float key = project_linear(input, weights_qkv, hidden_dim)
    []float value = project_linear(input, weights_qkv, hidden_dim)

    []float scores = compute_attention_scores(query, key, head_dim, num_heads)

    []float weights = softmax(scores)

    output = matrix_mult_weighted(value, weights, hidden_dim)

    output = project_linear(output, weights_out, hidden_dim)

    return output
}

func project_linear([]float input, []float weights, int output_dim) []float {
    []float output = []float{cap: output_dim}

    int i = 0
    for i < output_dim {
        float sum = 0.0
        int j = 0
        for j < len(input) && i * len(input) + j < len(weights) {
            sum = sum + input[j] * weights[i * len(input) + j]
            j = j + 1
        }
        output[i] = sum
        i = i + 1
    }

    return output
}

func compute_attention_scores([]float query, []float key, int head_dim, int num_heads) []float {
    []float scores = []float{cap: len(query) * len(key)}

    int i = 0
    for i < len(query) {
        int j = 0
        for j < len(key) {
            float dot = 0.0
            int k = 0
            for k < head_dim && i + k < len(query) && j + k < len(key) {
                dot = dot + query[i + k] * key[j + k]
                k = k + 1
            }
            float score = dot / sqrt_approx(float(head_dim))
            scores[i * len(key) + j] = score
            j = j + 1
        }
        i = i + 1
    }

    return scores
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float guess = x
    int i = 0
    for i < 3 {
        guess = (guess + x / guess) / 2.0
        i = i + 1
    }
    return guess
}

func matrix_mult_weighted([]float values, []float weights, int output_dim) []float {
    []float output = []float{cap: output_dim}

    int i = 0
    for i < output_dim {
        float sum = 0.0
        int j = 0
        for j < len(weights) && i + j < len(values) {
            sum = sum + values[i + j] * weights[j]
            j = j + 1
        }
        output[i] = sum
        i = i + 1
    }

    return output
}

func softmax([]float logits) []float {
    int n = len(logits)
    if n == 0 {
        return []float{cap: 0}
    }

    []float probs = []float{cap: n}

    float maxv = logits[0]
    int i = 1
    for i < n {
        if logits[i] > maxv {
            maxv = logits[i]
        }
        i = i + 1
    }

    float sum = 0.0
    i = 0
    for i < n {
        float p = exp_approx(logits[i] - maxv)
        probs[i] = p
        sum = sum + p
        i = i + 1
    }

    if sum == 0.0 {
        sum = 1.0
    }

    i = 0
    for i < n {
        probs[i] = probs[i] / sum
        i = i + 1
    }

    return probs
}

func feed_forward([]float input, []float weights_up, []float weights_down, int intermediate_size, int hidden_dim) []float {

    []float hidden = project_linear(input, weights_up, intermediate_size)

    int i = 0
    for i < len(hidden) {
        float x = hidden[i]
        float sig = 1.0 / (1.0 + exp_approx(0.0 - x))
        hidden[i] = x * sig
        i = i + 1
    }

    []float output = project_linear(hidden, weights_down, hidden_dim)

    return output
}

func rms_norm([]float input, []float gamma, float eps) []float {
    []float output = []float{cap: len(input)}

    float sum_sq = 0.0
    int i = 0
    for i < len(input) {
        float x = input[i]
        sum_sq = sum_sq + x * x
        i = i + 1
    }

    float mean_sq = sum_sq / float(len(input))
    float rms = sqrt_approx(mean_sq + eps)

    i = 0
    for i < len(input) {
        output[i] = (input[i] / rms) * gamma[i]
        i = i + 1
    }

    return output
}

func transformer_layer([]float input, []float attn_weights, []float ffn_weights, []float ln_weights, int num_heads, int hidden_dim, int intermediate_size) []float {

    []float norm1 = rms_norm(input, ln_weights, 0.000001)
    []float attn_out = multi_head_attention(norm1, attn_weights, attn_weights, num_heads, hidden_dim)
    []float residual1 = add_vectors(input, attn_out)

    []float norm2 = rms_norm(residual1, ln_weights, 0.000001)
    []float ffn_out = feed_forward(norm2, ffn_weights, ffn_weights, intermediate_size, hidden_dim)
    []float output = add_vectors(residual1, ffn_out)

    return output
}

func add_vectors([]float a, []float b) []float {
    []float result = []float{cap: len(a)}
    int i = 0
    for i < len(a) && i < len(b) {
        result[i] = a[i] + b[i]
        i = i + 1
    }
    for i < len(a) {
        result[i] = a[i]
        i = i + 1
    }
    return result
}

func int_to_string(int value) string {
    if value == 0 { return "0" }
    string result = ""
    int current = value
    if current < 0 { current = 0 - current }
    for current > 0 {
        int digit = current - (current / 10) * 10
        if digit == 0 { result = "0" + result }
        else if digit == 1 { result = "1" + result }
        else if digit == 2 { result = "2" + result }
        else if digit == 3 { result = "3" + result }
        else if digit == 4 { result = "4" + result }
        else if digit == 5 { result = "5" + result }
        else if digit == 6 { result = "6" + result }
        else if digit == 7 { result = "7" + result }
        else if digit == 8 { result = "8" + result }
        else if digit == 9 { result = "9" + result }
        current = current / 10
    }
    return result
}
