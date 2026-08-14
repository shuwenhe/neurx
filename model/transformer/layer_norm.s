package neurx.model.transformer.layer_norm
struct layer_norm_config {
    int hidden_dim
    float epsilon
    bool use_bias
}

struct layer_norm_state {
    int hidden_dim
    float epsilon
    []float gamma
    []float beta
    bool use_bias
}

struct rms_norm_state {
    int hidden_dim
    float epsilon
    []float gamma
}

struct layer_norm_output {
    []float normalized
    []float mean
    []float variance
}

struct rms_norm_output {
    []float normalized
    []float variance
}

func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func copy_vector([]float src) []float {
    []float out = allocate_vector(len(src), 0.0)
    int i = 0
    while i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = x
    int i = 0
    while i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func new_layer_norm(layer_norm_config cfg) layer_norm_state {
    layer_norm_state {
        hidden_dim: cfg.hidden_dim,
        epsilon: cfg.epsilon,
        gamma: allocate_vector(cfg.hidden_dim, 1.0),
        beta: allocate_vector(cfg.hidden_dim, 0.0),
        use_bias: cfg.use_bias,
    }
}

func layer_normalize(
    layer_norm_state ln,
    []float input,
    int batch_size,
    int seq_len
) layer_norm_output {
    int hidden_dim = ln.hidden_dim
    []float output = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    []float mean_out = allocate_vector(batch_size * seq_len, 0.0)
    []float var_out = allocate_vector(batch_size * seq_len, 0.0)
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int base_idx = (b * seq_len + s) * hidden_dim
            int stat_idx = b * seq_len + s
            float mean = 0.0
            int d = 0
            while d < hidden_dim {
                mean = mean + input[base_idx + d]
                d = d + 1
            }
            mean = mean / (hidden_dim * 1.0)
            float variance = 0.0
            d = 0
            while d < hidden_dim {
                float diff = input[base_idx + d] - mean
                variance = variance + diff * diff
                d = d + 1
            }
            variance = variance / (hidden_dim * 1.0)
            mean_out[stat_idx] = mean
            var_out[stat_idx] = variance
            float std_dev = sqrt_approx(variance + ln.epsilon)
            d = 0
            while d < hidden_dim {
                float normalized = (input[base_idx + d] - mean) / std_dev
                float scaled = normalized * ln.gamma[d]
                if ln.use_bias {
                    scaled = scaled + ln.beta[d]
                }
                output[base_idx + d] = scaled
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    layer_norm_output {
        normalized: output,
        mean: mean_out,
        variance: var_out,
    }
}

func layer_norm_backward(
    layer_norm_state ln,
    []float grad_output,
    []float input,
    []float mean,
    []float variance,
    int batch_size,
    int seq_len
) [][]float {
    int hidden_dim = ln.hidden_dim
    []float grad_input = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    []float grad_gamma = allocate_vector(hidden_dim, 0.0)
    []float grad_beta = allocate_vector(hidden_dim, 0.0)
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int base_idx = (b * seq_len + s) * hidden_dim
            int stat_idx = b * seq_len + s
            float mean_val = mean[stat_idx]
            float var_val = variance[stat_idx]
            float std_dev = sqrt_approx(var_val + ln.epsilon)
            int d = 0
            while d < hidden_dim {
                float normalized = (input[base_idx + d] - mean_val) / std_dev
                grad_gamma[d] = grad_gamma[d] + grad_output[base_idx + d] * normalized
                if ln.use_bias {
                    grad_beta[d] = grad_beta[d] + grad_output[base_idx + d]
                }
                d = d + 1
            }
            float sum1 = 0.0
            float sum2 = 0.0
            d = 0
            while d < hidden_dim {
                float normalized = (input[base_idx + d] - mean_val) / std_dev
                sum1 = sum1 + grad_output[base_idx + d] * ln.gamma[d]
                sum2 = sum2 + grad_output[base_idx + d] * ln.gamma[d] * normalized
                d = d + 1
            }
            d = 0
            while d < hidden_dim {
                float normalized = (input[base_idx + d] - mean_val) / std_dev
                float g = sum1 - sum2 * normalized / (hidden_dim * 1.0)
                grad_input[base_idx + d] = g / (std_dev * hidden_dim * 1.0)
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    [][]float result = [][]float{cap: 3}
    result[0] = grad_input
    result[1] = grad_gamma
    result[2] = grad_beta
    result
}

func new_rms_norm(layer_norm_config cfg) rms_norm_state {
    rms_norm_state {
        hidden_dim: cfg.hidden_dim,
        epsilon: cfg.epsilon,
        gamma: allocate_vector(cfg.hidden_dim, 1.0),
    }
}

func rms_normalize(
    rms_norm_state rn,
    []float input,
    int batch_size,
    int seq_len
) rms_norm_output {
    int hidden_dim = rn.hidden_dim
    []float output = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    []float var_out = allocate_vector(batch_size * seq_len, 0.0)
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int base_idx = (b * seq_len + s) * hidden_dim
            int stat_idx = b * seq_len + s
            float rms = 0.0
            int d = 0
            while d < hidden_dim {
                rms = rms + input[base_idx + d] * input[base_idx + d]
                d = d + 1
            }
            rms = rms / (hidden_dim * 1.0)
            rms = sqrt_approx(rms + rn.epsilon)
            var_out[stat_idx] = rms
            d = 0
            while d < hidden_dim {
                float normalized = input[base_idx + d] / rms
                output[base_idx + d] = normalized * rn.gamma[d]
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    rms_norm_output {
        normalized: output,
        variance: var_out,
    }
}

func rms_norm_backward(
    rms_norm_state rn,
    []float grad_output,
    []float input,
    []float variance,
    int batch_size,
    int seq_len
) [][]float {
    int hidden_dim = rn.hidden_dim
    []float grad_input = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    []float grad_gamma = allocate_vector(hidden_dim, 0.0)
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int base_idx = (b * seq_len + s) * hidden_dim
            int stat_idx = b * seq_len + s
            float rms_val = variance[stat_idx]
            int d = 0
            while d < hidden_dim {
                float normalized = input[base_idx + d] / rms_val
                grad_gamma[d] = grad_gamma[d] + grad_output[base_idx + d] * normalized
                d = d + 1
            }
            float sum_val = 0.0
            d = 0
            while d < hidden_dim {
                float normalized = input[base_idx + d] / rms_val
                sum_val = sum_val + grad_output[base_idx + d] * rn.gamma[d] * input[base_idx + d]
                d = d + 1
            }
            sum_val = sum_val / (rms_val * rms_val)
            d = 0
            while d < hidden_dim {
                float grad = (grad_output[base_idx + d] * rn.gamma[d] - input[base_idx + d] * sum_val / (hidden_dim * 1.0)) / rms_val
                grad_input[base_idx + d] = grad
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    [][]float result = [][]float{cap: 2}
    result[0] = grad_input
    result[1] = grad_gamma
    result
}
