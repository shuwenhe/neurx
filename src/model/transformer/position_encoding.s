package neurx.model.transformer.position_encoding
struct position_encoding_config {
    int hidden_dim
    int max_seq_len
    string encoding_type
    float rope_base
}
struct absolute_position_encoding {
    int hidden_dim
    int max_seq_len
    float[] sin_encoding
    float[] cos_encoding
}
struct learned_position_encoding {
    int hidden_dim
    int max_seq_len
    float[] embeddings
}
struct rope_position_encoding {
    int hidden_dim
    float rope_base
    float[] frequencies
}
func allocate_vector(int size, float init_val) float[] {
    float[] v = float[]{cap: size}
    int i = 0
    for i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}
func copy_vector(float[] src) float[] {
    float[] out = allocate_vector(len(src), 0.0)
    int i = 0
    for i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}
func sin_approx(float x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    float value = x
    for value > pi {
        value = value - two_pi
    }
    for value < -pi {
        value = value + two_pi
    }
    float x2 = value * value
    float term = value
    float result = value
    int i = 1
    for i <= 10 {
        term = -term * x2 / ((2 * i) * (2 * i + 1) * 1.0)
        result = result + term
        i = i + 1
    }
    result
}
func cos_approx(float x) float {
    float pi = 3.141592653589793
    float two_pi = 6.283185307179586
    float value = x
    for value > pi {
        value = value - two_pi
    }
    for value < -pi {
        value = value + two_pi
    }
    float x2 = value * value
    float term = 1.0
    float result = 1.0
    int i = 1
    for i <= 10 {
        term = -term * x2 / ((2 * i - 1) * (2 * i) * 1.0)
        result = result + term
        i = i + 1
    }
    result
}
func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    for i <= 12 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    result
}
func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = x
    int i = 0
    for i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}
func log_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    if x == 1.0 {
        return 0.0
    }
    float y = 0.0
    float z = (x - 1.0) / (x + 1.0)
    float z2 = z * z
    float term = z
    float result = z
    int i = 1
    for i <= 10 {
        term = term * z2
        result = result + term * 1.0 / (2 * i + 1)
        i = i + 1
    }
    result * 2.0
}
func new_absolute_position_encoding(position_encoding_config cfg) absolute_position_encoding {
    int hidden_dim = cfg.hidden_dim
    int max_seq_len = cfg.max_seq_len
    float[] sin_encoding = allocate_vector(max_seq_len * hidden_dim, 0.0)
    float[] cos_encoding = allocate_vector(max_seq_len * hidden_dim, 0.0)
    float pi = 3.141592653589793
    float log_10000 = log_approx(10000.0)
    int pos = 0
    for pos < max_seq_len {
        int dim = 0
        for dim < hidden_dim {
            float freq = exp_approx(-log_10000 * (dim * 1.0) / (hidden_dim * 1.0))
            float angle = (pos * 1.0) * freq
            if dim % 2 == 0 {
                sin_encoding[pos * hidden_dim + dim] = sin_approx(angle)
                cos_encoding[pos * hidden_dim + dim] = cos_approx(angle)
            } else {
                sin_encoding[pos * hidden_dim + dim] = sin_approx(angle)
                cos_encoding[pos * hidden_dim + dim] = cos_approx(angle)
            }
            dim = dim + 1
        }
        pos = pos + 1
    }
    absolute_position_encoding {
        hidden_dim: hidden_dim,
        max_seq_len: max_seq_len,
        sin_encoding: sin_encoding,
        cos_encoding: cos_encoding,
    }
}
func get_position_encoding(
    absolute_position_encoding enc,
    int position,
    int seq_len
) float[] {
    int hidden_dim = enc.hidden_dim
    float[] output = allocate_vector(seq_len * hidden_dim, 0.0)
    int pos = 0
    for pos < seq_len {
        int actual_pos = position + pos
        if actual_pos >= enc.max_seq_len {
            actual_pos = enc.max_seq_len - 1
        }
        int dim = 0
        for dim < hidden_dim {
            int out_idx = pos * hidden_dim + dim
            int enc_idx = actual_pos * hidden_dim + dim
            if dim % 2 == 0 {
                output[out_idx] = enc.sin_encoding[enc_idx]
            } else {
                output[out_idx] = enc.cos_encoding[enc_idx]
            }
            dim = dim + 1
        }
        pos = pos + 1
    }
    output
}
func new_learned_position_encoding(position_encoding_config cfg) learned_position_encoding {
    int hidden_dim = cfg.hidden_dim
    int max_seq_len = cfg.max_seq_len
    float[] embeddings = allocate_vector(max_seq_len * hidden_dim, 0.1)
    learned_position_encoding {
        hidden_dim: hidden_dim,
        max_seq_len: max_seq_len,
        embeddings: embeddings,
    }
}
func get_learned_position_encoding(
    learned_position_encoding enc,
    int position,
    int seq_len
) float[] {
    int hidden_dim = enc.hidden_dim
    float[] output = allocate_vector(seq_len * hidden_dim, 0.0)
    int pos = 0
    for pos < seq_len {
        int actual_pos = position + pos
        if actual_pos >= enc.max_seq_len {
            actual_pos = enc.max_seq_len - 1
        }
        int dim = 0
        for dim < hidden_dim {
            int out_idx = pos * hidden_dim + dim
            int enc_idx = actual_pos * hidden_dim + dim
            output[out_idx] = enc.embeddings[enc_idx]
            dim = dim + 1
        }
        pos = pos + 1
    }
    output
}
func new_rope_position_encoding(position_encoding_config cfg) rope_position_encoding {
    int hidden_dim = cfg.hidden_dim
    float rope_base = cfg.rope_base
    float[] frequencies = allocate_vector(hidden_dim / 2, 0.0)
    int i = 0
    for i < hidden_dim / 2 {
        float inv_freq = 1.0 / exp_approx(2.0 * log_approx(rope_base) * (i * 1.0) / (hidden_dim * 1.0))
        frequencies[i] = inv_freq
        i = i + 1
    }
    rope_position_encoding {
        hidden_dim: hidden_dim,
        rope_base: rope_base,
        frequencies: frequencies,
    }
}
func apply_rope_position(
    rope_position_encoding enc,
    float[] query,
    float[] key,
    int seq_len,
    int position
) float[][] {
    int hidden_dim = enc.hidden_dim
    float[] q_out = copy_vector(query)
    float[] k_out = copy_vector(key)
    int pos = 0
    for pos < seq_len {
        int actual_pos = position + pos
        float theta_i = (actual_pos * 1.0)
        int d = 0
        for d < hidden_dim / 2 {
            float angle = theta_i * enc.frequencies[d]
            float cos_angle = cos_approx(angle)
            float sin_angle = sin_approx(angle)
            int q_idx_1 = pos * hidden_dim + 2 * d
            int q_idx_2 = pos * hidden_dim + 2 * d + 1
            int k_idx_1 = pos * hidden_dim + 2 * d
            int k_idx_2 = pos * hidden_dim + 2 * d + 1
            float q1 = q_out[q_idx_1]
            float q2 = q_out[q_idx_2]
            float k1 = k_out[k_idx_1]
            float k2 = k_out[k_idx_2]
            q_out[q_idx_1] = q1 * cos_angle - q2 * sin_angle
            q_out[q_idx_2] = q1 * sin_angle + q2 * cos_angle
            k_out[k_idx_1] = k1 * cos_angle - k2 * sin_angle
            k_out[k_idx_2] = k1 * sin_angle + k2 * cos_angle
            d = d + 1
        }
        pos = pos + 1
    }
    float[][] result = float[][]{cap: 2}
    result[0] = q_out
    result[1] = k_out
    result
}
func add_position_encoding_to_hidden(
    float[] hidden_states,
    float[] position_encoding,
    int batch_size,
    int seq_len,
    int hidden_dim
) float[] {
    float[] output = copy_vector(hidden_states)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int d = 0
            for d < hidden_dim {
                int hidden_idx = (b * seq_len + s) * hidden_dim + d
                int pos_idx = s * hidden_dim + d
                output[hidden_idx] = output[hidden_idx] + position_encoding[pos_idx]
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    output
}
