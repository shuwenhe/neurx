package neurx.attention.nda

struct nda_config {
    int hidden_dim
    int state_dim
    int latent_dim
    int conv_kernel
}

struct nda_weights {
    nda_config config
    float[] w_q
    float[] w_k
    float[] w_v
    float[] conv_q
    float[] conv_k
    float[] conv_v
    float[] w_alpha_down
    float[] w_alpha_up
    float[] w_beta
    float[] w_gate_down
    float[] w_gate_up
    float[] w_output
}

struct nda_result {
    float[] output
    float[] final_state
    float[] alpha
    float[] beta
}

func new_nda_config(int hidden, int state, int latent, int kernel) nda_config {
    nda_config {
        hidden_dim: hidden,
        state_dim: state,
        latent_dim: latent,
        conv_kernel: kernel,
    }
}

func nda_zeros(int n) float[] {
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        out[i] = 0.0
        i = i + 1
    }
    out
}

func nda_deterministic_weights(int n, int salt, float scale) float[] {
    float[] out = nda_zeros(n)
    int i = 0
    for i < n {
        int raw = (i * 37 + salt * 19 + 11)
        int centered = raw - (raw / 29) * 29 - 14
        out[i] = (centered as float) * scale
        i = i + 1
    }
    out
}

func nda_copy_floats(float[] values) float[] {
    float[] out = nda_zeros(len(values))
    int i = 0
    for i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func nda_sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float result = 1.0
    if x > 1.0 {
        result = x
    }
    int i = 0
    for i < 20 {
        result = 0.5 * (result + x / result)
        i = i + 1
    }
    result
}

func nda_exp_approx(float x) float {
    float value = x
    if value > 10.0 {
        value = 10.0
    }
    if value < -10.0 {
        value = -10.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i <= 24 {
        term = term * value / (i as float)
        result = result + term
        i = i + 1
    }
    if result < 0.0000001 {
        return 0.0000001
    }
    result
}

func nda_sigmoid(float x) float {
    1.0 / (1.0 + nda_exp_approx(0.0 - x))
}

func nda_swish(float x) float {
    x * nda_sigmoid(x)
}

func nda_rms_norm_tokens(float[] input, int tokens, int hidden) float[] {
    float[] out = nda_zeros(tokens * hidden)
    int t = 0
    for t < tokens {
        float sum_sq = 0.0
        int h = 0
        for h < hidden {
            float value = input[t * hidden + h]
            sum_sq = sum_sq + value * value
            h = h + 1
        }
        float scale = 1.0 / nda_sqrt_approx(sum_sq / (hidden as float) + 0.000001)
        h = 0
        for h < hidden {
            out[t * hidden + h] = input[t * hidden + h] * scale
            h = h + 1
        }
        t = t + 1
    }
    out
}

func nda_l2_normalize_channels(float[] input, int tokens, int width) float[] {
    float[] out = nda_zeros(tokens * width)
    int t = 0
    for t < tokens {
        float sum_sq = 0.0
        int i = 0
        for i < width {
            float value = input[t * width + i]
            sum_sq = sum_sq + value * value
            i = i + 1
        }
        float scale = 1.0 / nda_sqrt_approx(sum_sq + 0.000001)
        i = 0
        for i < width {
            out[t * width + i] = input[t * width + i] * scale
            i = i + 1
        }
        t = t + 1
    }
    out
}

func nda_linear(float[] input, float[] weight, int rows, int in_dim, int out_dim) float[] {
    float[] out = nda_zeros(rows * out_dim)
    int r = 0
    for r < rows {
        int o = 0
        for o < out_dim {
            float sum = 0.0
            int i = 0
            for i < in_dim {
                sum = sum + input[r * in_dim + i] * weight[i * out_dim + o]
                i = i + 1
            }
            out[r * out_dim + o] = sum
            o = o + 1
        }
        r = r + 1
    }
    out
}

func nda_short_conv(float[] input, float[] kernel, int tokens, int channels, int kernel_size) float[] {
    float[] out = nda_zeros(tokens * channels)
    int t = 0
    for t < tokens {
        int c = 0
        for c < channels {
            float sum = 0.0
            int tap = 0
            for tap < kernel_size {
                int source = t - tap
                if source >= 0 {
                    sum = sum + input[source * channels + c] * kernel[c * kernel_size + tap]
                }
                tap = tap + 1
            }
            out[t * channels + c] = sum
            c = c + 1
        }
        t = t + 1
    }
    out
}

func nda_activate_swish(float[] input) float[] {
    float[] out = nda_zeros(len(input))
    int i = 0
    for i < len(input) {
        out[i] = nda_swish(input[i])
        i = i + 1
    }
    out
}

func new_nda_weights(nda_config cfg) nda_weights {
    int h = cfg.hidden_dim
    int d = cfg.state_dim
    int l = cfg.latent_dim
    int kernel = cfg.conv_kernel
    nda_weights {
        config: cfg,
        w_q: nda_deterministic_weights(h * d, 1, 0.008),
        w_k: nda_deterministic_weights(h * d, 2, 0.008),
        w_v: nda_deterministic_weights(h * d, 3, 0.008),
        conv_q: nda_deterministic_weights(d * kernel, 4, 0.03),
        conv_k: nda_deterministic_weights(d * kernel, 5, 0.03),
        conv_v: nda_deterministic_weights(d * kernel, 6, 0.03),
        w_alpha_down: nda_deterministic_weights(h * l, 7, 0.01),
        w_alpha_up: nda_deterministic_weights(l * d, 8, 0.01),
        w_beta: nda_deterministic_weights(h, 9, 0.01),
        w_gate_down: nda_deterministic_weights(h * l, 10, 0.01),
        w_gate_up: nda_deterministic_weights(l * d, 11, 0.01),
        w_output: nda_deterministic_weights(d * h, 12, 0.01),
    }
}

func nda_forward(nda_weights weights, float[] input, int tokens, float[] initial_state) nda_result {
    nda_config cfg = weights.config
    int h = cfg.hidden_dim
    int d = cfg.state_dim
    float[] q_raw = nda_activate_swish(nda_short_conv(nda_linear(input, weights.w_q, tokens, h, d), weights.conv_q, tokens, d, cfg.conv_kernel))
    float[] k_raw = nda_activate_swish(nda_short_conv(nda_linear(input, weights.w_k, tokens, h, d), weights.conv_k, tokens, d, cfg.conv_kernel))
    float[] v_values = nda_activate_swish(nda_short_conv(nda_linear(input, weights.w_v, tokens, h, d), weights.conv_v, tokens, d, cfg.conv_kernel))
    float[] q = nda_l2_normalize_channels(q_raw, tokens, d)
    float[] k = nda_l2_normalize_channels(k_raw, tokens, d)
    float[] alpha_hidden = nda_linear(input, weights.w_alpha_down, tokens, h, cfg.latent_dim)
    float[] alpha_logits = nda_linear(alpha_hidden, weights.w_alpha_up, tokens, cfg.latent_dim, d)
    float[] beta_logits = nda_linear(input, weights.w_beta, tokens, h, 1)
    float[] gate_hidden = nda_linear(input, weights.w_gate_down, tokens, h, cfg.latent_dim)
    float[] gate_logits = nda_linear(gate_hidden, weights.w_gate_up, tokens, cfg.latent_dim, d)
    float[] state = nda_copy_floats(initial_state)
    if len(state) != d * d {
        state = nda_zeros(d * d)
    }
    float[] recurrent = nda_zeros(tokens * d)
    float[] alpha_values = nda_zeros(tokens * d)
    float[] beta_values = nda_zeros(tokens)
    int t = 0
    for t < tokens {
        int i = 0
        for i < d {
            alpha_values[t * d + i] = nda_sigmoid(alpha_logits[t * d + i])
            i = i + 1
        }
        float beta = nda_sigmoid(beta_logits[t])
        beta_values[t] = beta
        float[] decayed = nda_zeros(d * d)
        i = 0
        for i < d {
            int j = 0
            for j < d {
                decayed[i * d + j] = alpha_values[t * d + i] * state[i * d + j]
                j = j + 1
            }
            i = i + 1
        }
        float[] prediction = nda_zeros(d)
        int j = 0
        for j < d {
            i = 0
            for i < d {
                prediction[j] = prediction[j] + k[t * d + i] * decayed[i * d + j]
                i = i + 1
            }
            j = j + 1
        }
        i = 0
        for i < d {
            j = 0
            for j < d {
                float error = v_values[t * d + j] - prediction[j]
                state[i * d + j] = decayed[i * d + j] + beta * k[t * d + i] * error
                j = j + 1
            }
            i = i + 1
        }
        j = 0
        for j < d {
            i = 0
            for i < d {
                recurrent[t * d + j] = recurrent[t * d + j] + q[t * d + i] * state[i * d + j]
                i = i + 1
            }
            recurrent[t * d + j] = recurrent[t * d + j] * nda_sigmoid(gate_logits[t * d + j])
            j = j + 1
        }
        t = t + 1
    }
    float[] normalized = nda_rms_norm_tokens(recurrent, tokens, d)
    nda_result {
        output: nda_linear(normalized, weights.w_output, tokens, d, h),
        final_state: state,
        alpha: alpha_values,
        beta: beta_values,
    }
}
