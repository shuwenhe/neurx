package neurx.moe.core
struct moe_config {
    int hidden_dim
    int latent_dim
    int ffn_dim
    int n_shared_experts
    int n_routed_experts
    int top_k
}

struct moe_weights {
    moe_config config
    float[] router_down
    float[] router_up
    float[] router_balance_bias
    float[] shared_w1
    float[] shared_w2
    float[] routed_w1
    float[] routed_w2
}

struct moe_result {
    float[] output
    int[] expert_indices
    float[] expert_weights
    float[] expert_load
}

func new_moe_config(
    int hidden_dim,
    int latent_dim,
    int ffn_dim,
    int n_shared_experts,
    int n_routed_experts,
    int top_k
) moe_config {
    moe_config {
        hidden_dim: hidden_dim,
        latent_dim: latent_dim,
        ffn_dim: ffn_dim,
        n_shared_experts: n_shared_experts,
        n_routed_experts: n_routed_experts,
        top_k: top_k,
    }
}

func moe_zeros(int n) float[] {
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        out[i] = 0.0
        i = i + 1
    }
    out
}

func moe_zeros_int(int n) int[] {
    int[] out = int[]{cap: n}
    int i = 0
    for i < n {
        out[i] = 0
        i = i + 1
    }
    out
}

func moe_deterministic_weights(int n, int salt, float scale) float[] {
    float[] out = moe_zeros(n)
    int i = 0
    for i < n {
        int raw = i * 37 + salt * 19 + 11
        int centered = raw - (raw / 29) * 29 - 14
        out[i] = (centered as float) * scale
        i = i + 1
    }
    out
}

func moe_exp(float x) float {
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

func moe_sigmoid(float x) float {
    1.0 / (1.0 + moe_exp(0.0 - x))
}

func moe_situ(float x) float {
    float s = moe_sigmoid(x)
    float e2 = moe_exp(2.0 * x)
    float t = (e2 - 1.0) / (e2 + 1.0)
    s * t
}

func moe_linear(float[] input, float[] weight, int rows, int in_dim, int out_dim) float[] {
    float[] out = moe_zeros(rows * out_dim)
    int row = 0
    for row < rows {
        int o = 0
        for o < out_dim {
            int i = 0
            for i < in_dim {
                out[row * out_dim + o] = out[row * out_dim + o] +
                    input[row * in_dim + i] * weight[i * out_dim + o]
                i = i + 1
            }
            o = o + 1
        }
        row = row + 1
    }
    out
}

func new_moe_weights(moe_config cfg) moe_weights {
    int h = cfg.hidden_dim
    int l = cfg.latent_dim
    int f = cfg.ffn_dim
    int e = cfg.n_routed_experts
    moe_weights {
        config: cfg,
        router_down: moe_deterministic_weights(h * l, 30, 0.01),
        router_up: moe_deterministic_weights(l * e, 31, 0.01),
        router_balance_bias: moe_zeros(e),
        shared_w1: moe_deterministic_weights(h * f, 32, 0.01),
        shared_w2: moe_deterministic_weights(f * h, 33, 0.01),
        routed_w1: moe_deterministic_weights(e * h * f, 34, 0.01),
        routed_w2: moe_deterministic_weights(e * f * h, 35, 0.01),
    }
}

func moe_top_k_indices(float[] scores, int offset, int count, int top_k) int[] {
    int[] indices = moe_zeros_int(top_k)
    float[] selected = moe_zeros(top_k)
    int k = 0
    for k < top_k {
        selected[k] = -1000000.0
        indices[k] = -1
        k = k + 1
    }
    int expert = 0
    for expert < count {
        float score = scores[offset + expert]
        int insert = -1
        k = 0
        for k < top_k && insert < 0 {
            if score > selected[k] {
                insert = k
            }
            k = k + 1
        }
        if insert >= 0 {
            k = top_k - 1
            for k > insert {
                selected[k] = selected[k - 1]
                indices[k] = indices[k - 1]
                k = k - 1
            }
            selected[insert] = score
            indices[insert] = expert
        }
        expert = expert + 1
    }
    indices
}

func moe_expert_ffn(
    float[] input,
    float[] w1,
    float[] w2,
    int w1_offset,
    int w2_offset,
    int hidden,
    int ffn
) float[] {
    float[] middle = moe_zeros(ffn)
    int f = 0
    for f < ffn {
        int h = 0
        for h < hidden {
            middle[f] = middle[f] + input[h] * w1[w1_offset + h * ffn + f]
            h = h + 1
        }
        middle[f] = moe_situ(middle[f])
        f = f + 1
    }
    float[] out = moe_zeros(hidden)
    int h = 0
    for h < hidden {
        f = 0
        for f < ffn {
            out[h] = out[h] + middle[f] * w2[w2_offset + f * hidden + h]
            f = f + 1
        }
        h = h + 1
    }
    out
}

func moe_forward(moe_weights weights, float[] input, int tokens) moe_result {
    moe_config cfg = weights.config
    int h = cfg.hidden_dim
    int l = cfg.latent_dim
    int expert_count = cfg.n_routed_experts
    int top_k = cfg.top_k
    float[] latent = moe_linear(input, weights.router_down, tokens, h, l)
    float[] scores = moe_linear(latent, weights.router_up, tokens, l, expert_count)
    float[] output = moe_zeros(tokens * h)
    int[] indices = moe_zeros_int(tokens * top_k)
    float[] route_weights = moe_zeros(tokens * top_k)
    float[] load = moe_zeros(expert_count)
    int token = 0
    for token < tokens {
        float mean_score = 0.0
        int expert = 0
        for expert < expert_count {
            int score_index = token * expert_count + expert
            scores[score_index] = scores[score_index] + weights.router_balance_bias[expert]
            mean_score = mean_score + scores[score_index]
            expert = expert + 1
        }
        mean_score = mean_score / (expert_count as float)
        expert = 0
        for expert < expert_count {
            scores[token * expert_count + expert] =
                scores[token * expert_count + expert] - mean_score
            expert = expert + 1
        }
        int[] chosen = moe_top_k_indices(scores, token * expert_count, expert_count, top_k)
        float route_sum = 0.0
        int k = 0
        for k < top_k {
            expert = chosen[k]
            float route = moe_sigmoid(scores[token * expert_count + expert])
            indices[token * top_k + k] = expert
            route_weights[token * top_k + k] = route
            route_sum = route_sum + route
            load[expert] = load[expert] + 1.0
            k = k + 1
        }
        k = 0
        for k < top_k {
            route_weights[token * top_k + k] =
                route_weights[token * top_k + k] / route_sum
            k = k + 1
        }
        float[] token_input = moe_zeros(h)
        int channel = 0
        for channel < h {
            token_input[channel] = input[token * h + channel]
            channel = channel + 1
        }
        float[] shared = moe_expert_ffn(
            token_input, weights.shared_w1, weights.shared_w2, 0, 0, h, cfg.ffn_dim
        )
        channel = 0
        for channel < h {
            output[token * h + channel] = shared[channel]
            channel = channel + 1
        }
        k = 0
        for k < top_k {
            expert = indices[token * top_k + k]
            float[] routed = moe_expert_ffn(
                token_input,
                weights.routed_w1,
                weights.routed_w2,
                expert * h * cfg.ffn_dim,
                expert * cfg.ffn_dim * h,
                h,
                cfg.ffn_dim
            )
            channel = 0
            for channel < h {
                output[token * h + channel] = output[token * h + channel] +
                    route_weights[token * top_k + k] * routed[channel]
                channel = channel + 1
            }
            k = k + 1
        }
        token = token + 1
    }
    moe_result {
        output: output,
        expert_indices: indices,
        expert_weights: route_weights,
        expert_load: load,
    }
}

func moe_sum(float[] values, int offset, int count) float {
    float result = 0.0
    int i = 0
    for i < count {
        result = result + values[offset + i]
        i = i + 1
    }
    result
}

func moe_abs(float value) float {
    if value < 0.0 {
        return 0.0 - value
    }
    value
}

func moe_core_self_test() int {
    moe_config cfg = new_moe_config(4, 2, 6, 1, 4, 2)
    moe_weights weights = new_moe_weights(cfg)
    float[] input = moe_deterministic_weights(16, 51, 0.03)
    moe_result result = moe_forward(weights, input, 4)
    int token = 0
    for token < 4 {
        if moe_abs(moe_sum(result.expert_weights, token * cfg.top_k, cfg.top_k) - 1.0) > 0.001 {
            return 1
        }
        if result.expert_indices[token * cfg.top_k] == result.expert_indices[token * cfg.top_k + 1] {
            return 2
        }
        token = token + 1
    }
    if moe_abs(moe_sum(result.expert_load, 0, cfg.n_routed_experts) - 8.0) > 0.001 {
        return 3
    }
    0
}
