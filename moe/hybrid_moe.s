package neurx.moe.hybrid

use neurx.moe.core.{moe_config, moe_weights, moe_result, new_moe_config, new_moe_weights, moe_forward}

// NeurX S hybrid sparse-model implementation.
//
// Implemented:
//   - channel-gated delta attention with recurrent state
//   - Gated latent attention (NoPE, compressed KV)
//   - Stable latent-space top-k MoE with shared experts
//   - attention residual retrieval across block depth
//   - a 3 KDA : 1 global-attention hybrid backbone

struct hybrid_moe_config {
    int hidden_dim
    int state_dim
    int latent_dim
    int ffn_dim
    int conv_kernel
    int n_shared_experts
    int n_routed_experts
    int top_k
    int kda_per_group
    int groups
    int max_history
}

struct kda_weights {
    hybrid_moe_config config
    []float w_q
    []float w_k
    []float w_v
    []float conv_q
    []float conv_k
    []float conv_v
    []float w_alpha_down
    []float w_alpha_up
    []float w_beta
    []float w_gate_down
    []float w_gate_up
    []float w_output
}

struct kda_result {
    []float output
    []float final_state
    []float alpha
    []float beta
}

struct gated_mla_weights {
    hybrid_moe_config config
    []float w_dq
    []float w_uq
    []float w_dkv
    []float w_uk
    []float w_uv
    []float w_gate
    []float w_output
}

struct gated_mla_result {
    []float output
    []float attention
    []float gate
}

struct attnres_weights {
    hybrid_moe_config config
    []float query_scale
    []float depth_keys
    []float depth_bias
}

struct attnres_result {
    []float output
    []float weights
}

struct hybrid_moe_model {
    hybrid_moe_config config
    kda_weights kda
    gated_mla_weights mla
    moe_weights moe
    attnres_weights residual
}

struct hybrid_moe_forward_result {
    []float output
    []float kda_state
    []float last_residual_weights
    []int last_expert_indices
    []float last_expert_weights
    int history_count
}

func tiny_hybrid_moe_config() hybrid_moe_config {
    hybrid_moe_config {
        hidden_dim: 4,
        state_dim: 4,
        latent_dim: 2,
        ffn_dim: 6,
        conv_kernel: 3,
        n_shared_experts: 1,
        n_routed_experts: 4,
        top_k: 2,
        kda_per_group: 3,
        groups: 1,
        max_history: 10,
    }
}

func production_hybrid_moe_shape() hybrid_moe_config {
    // Large sparse configuration. Dimensions remain configurable because
    // allocating every expert is not the portable self-test path.
    hybrid_moe_config {
        hidden_dim: 7168,
        state_dim: 128,
        latent_dim: 512,
        ffn_dim: 2048,
        conv_kernel: 4,
        n_shared_experts: 2,
        n_routed_experts: 896,
        top_k: 16,
        kda_per_group: 3,
        groups: 1,
        max_history: 256,
    }
}

func zeros(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = 0.0
        i = i + 1
    }
    out
}

func zeros_int(int n) []int {
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = 0
        i = i + 1
    }
    out
}

func deterministic_weights(int n, int salt, float scale) []float {
    []float out = zeros(n)
    int i = 0
    while i < n {
        int raw = (i * 37 + salt * 19 + 11)
        int centered = raw - (raw / 29) * 29 - 14
        out[i] = (centered as float) * scale
        i = i + 1
    }
    out
}

func copy_floats([]float values) []float {
    []float out = zeros(len(values))
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float result = 1.0
    if x > 1.0 {
        result = x
    }
    int i = 0
    while i < 20 {
        result = 0.5 * (result + x / result)
        i = i + 1
    }
    result
}

func exp_approx(float x) float {
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
    while i <= 24 {
        term = term * value / (i as float)
        result = result + term
        i = i + 1
    }
    if result < 0.0000001 {
        return 0.0000001
    }
    result
}

func sigmoid(float x) float {
    1.0 / (1.0 + exp_approx(0.0 - x))
}

func swish(float x) float {
    x * sigmoid(x)
}

func situ(float x) float {
    // Bounded sigmoid-tanh multiplicative activation.
    float s = sigmoid(x)
    float e2 = exp_approx(2.0 * x)
    float t = (e2 - 1.0) / (e2 + 1.0)
    s * t
}

func rms_norm_tokens([]float input, int tokens, int hidden) []float {
    []float out = zeros(tokens * hidden)
    int t = 0
    while t < tokens {
        float sum_sq = 0.0
        int h = 0
        while h < hidden {
            float value = input[t * hidden + h]
            sum_sq = sum_sq + value * value
            h = h + 1
        }
        float scale = 1.0 / sqrt_approx(sum_sq / (hidden as float) + 0.000001)
        h = 0
        while h < hidden {
            out[t * hidden + h] = input[t * hidden + h] * scale
            h = h + 1
        }
        t = t + 1
    }
    out
}

func l2_normalize_channels([]float input, int tokens, int width) []float {
    []float out = zeros(tokens * width)
    int t = 0
    while t < tokens {
        float sum_sq = 0.0
        int i = 0
        while i < width {
            float value = input[t * width + i]
            sum_sq = sum_sq + value * value
            i = i + 1
        }
        float scale = 1.0 / sqrt_approx(sum_sq + 0.000001)
        i = 0
        while i < width {
            out[t * width + i] = input[t * width + i] * scale
            i = i + 1
        }
        t = t + 1
    }
    out
}

func linear([]float input, []float weight, int rows, int in_dim, int out_dim) []float {
    []float out = zeros(rows * out_dim)
    int r = 0
    while r < rows {
        int o = 0
        while o < out_dim {
            float sum = 0.0
            int i = 0
            while i < in_dim {
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

func short_conv([]float input, []float kernel, int tokens, int channels, int kernel_size) []float {
    []float out = zeros(tokens * channels)
    int t = 0
    while t < tokens {
        int c = 0
        while c < channels {
            float sum = 0.0
            int tap = 0
            while tap < kernel_size {
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

func activate_swish([]float input) []float {
    []float out = zeros(len(input))
    int i = 0
    while i < len(input) {
        out[i] = swish(input[i])
        i = i + 1
    }
    out
}

func add_arrays([]float a, []float b) []float {
    []float out = zeros(len(a))
    int i = 0
    while i < len(a) {
        out[i] = a[i] + b[i]
        i = i + 1
    }
    out
}

func new_kda_weights(hybrid_moe_config cfg) kda_weights {
    int h = cfg.hidden_dim
    int d = cfg.state_dim
    int l = cfg.latent_dim
    int kernel = cfg.conv_kernel
    kda_weights {
        config: cfg,
        w_q: deterministic_weights(h * d, 1, 0.008),
        w_k: deterministic_weights(h * d, 2, 0.008),
        w_v: deterministic_weights(h * d, 3, 0.008),
        conv_q: deterministic_weights(d * kernel, 4, 0.03),
        conv_k: deterministic_weights(d * kernel, 5, 0.03),
        conv_v: deterministic_weights(d * kernel, 6, 0.03),
        w_alpha_down: deterministic_weights(h * l, 7, 0.01),
        w_alpha_up: deterministic_weights(l * d, 8, 0.01),
        w_beta: deterministic_weights(h, 9, 0.01),
        w_gate_down: deterministic_weights(h * l, 10, 0.01),
        w_gate_up: deterministic_weights(l * d, 11, 0.01),
        w_output: deterministic_weights(d * h, 12, 0.01),
    }
}

func kda_forward(kda_weights weights, []float input, int tokens, []float initial_state) kda_result {
    hybrid_moe_config cfg = weights.config
    int h = cfg.hidden_dim
    int d = cfg.state_dim
    []float q_raw = activate_swish(short_conv(linear(input, weights.w_q, tokens, h, d), weights.conv_q, tokens, d, cfg.conv_kernel))
    []float k_raw = activate_swish(short_conv(linear(input, weights.w_k, tokens, h, d), weights.conv_k, tokens, d, cfg.conv_kernel))
    []float v_values = activate_swish(short_conv(linear(input, weights.w_v, tokens, h, d), weights.conv_v, tokens, d, cfg.conv_kernel))
    []float q = l2_normalize_channels(q_raw, tokens, d)
    []float k = l2_normalize_channels(k_raw, tokens, d)
    []float alpha_hidden = linear(input, weights.w_alpha_down, tokens, h, cfg.latent_dim)
    []float alpha_logits = linear(alpha_hidden, weights.w_alpha_up, tokens, cfg.latent_dim, d)
    []float beta_logits = linear(input, weights.w_beta, tokens, h, 1)
    []float gate_hidden = linear(input, weights.w_gate_down, tokens, h, cfg.latent_dim)
    []float gate_logits = linear(gate_hidden, weights.w_gate_up, tokens, cfg.latent_dim, d)
    []float state = copy_floats(initial_state)
    if len(state) != d * d {
        state = zeros(d * d)
    }
    []float recurrent = zeros(tokens * d)
    []float alpha_values = zeros(tokens * d)
    []float beta_values = zeros(tokens)

    int t = 0
    while t < tokens {
        int i = 0
        while i < d {
            // Fine-grained channel decay.
            alpha_values[t * d + i] = sigmoid(alpha_logits[t * d + i])
            i = i + 1
        }
        float beta = sigmoid(beta_logits[t])
        beta_values[t] = beta

        // KDA delta recurrence:
        //   S <- (I - beta*k*k^T) Diag(alpha) S + beta*k*v^T
        // evaluated as decay followed by a prediction-error rank-1 update.
        []float decayed = zeros(d * d)
        i = 0
        while i < d {
            int j = 0
            while j < d {
                decayed[i * d + j] = alpha_values[t * d + i] * state[i * d + j]
                j = j + 1
            }
            i = i + 1
        }
        []float prediction = zeros(d)
        int j = 0
        while j < d {
            i = 0
            while i < d {
                prediction[j] = prediction[j] + k[t * d + i] * decayed[i * d + j]
                i = i + 1
            }
            j = j + 1
        }
        i = 0
        while i < d {
            j = 0
            while j < d {
                float error = v_values[t * d + j] - prediction[j]
                state[i * d + j] = decayed[i * d + j] + beta * k[t * d + i] * error
                j = j + 1
            }
            i = i + 1
        }
        j = 0
        while j < d {
            i = 0
            while i < d {
                recurrent[t * d + j] = recurrent[t * d + j] + q[t * d + i] * state[i * d + j]
                i = i + 1
            }
            recurrent[t * d + j] = recurrent[t * d + j] * sigmoid(gate_logits[t * d + j])
            j = j + 1
        }
        t = t + 1
    }
    []float normalized = rms_norm_tokens(recurrent, tokens, d)
    kda_result {
        output: linear(normalized, weights.w_output, tokens, d, h),
        final_state: state,
        alpha: alpha_values,
        beta: beta_values,
    }
}

func new_gated_mla_weights(hybrid_moe_config cfg) gated_mla_weights {
    int h = cfg.hidden_dim
    int l = cfg.latent_dim
    gated_mla_weights {
        config: cfg,
        w_dq: deterministic_weights(h * l, 20, 0.01),
        w_uq: deterministic_weights(l * h, 21, 0.01),
        w_dkv: deterministic_weights(h * l, 22, 0.01),
        w_uk: deterministic_weights(l * h, 23, 0.01),
        w_uv: deterministic_weights(l * h, 24, 0.01),
        w_gate: deterministic_weights(h * h, 25, 0.01),
        w_output: deterministic_weights(h * h, 26, 0.01),
    }
}

func gated_mla_forward(gated_mla_weights weights, []float input, int tokens) gated_mla_result {
    hybrid_moe_config cfg = weights.config
    int h = cfg.hidden_dim
    int l = cfg.latent_dim
    []float q = linear(linear(input, weights.w_dq, tokens, h, l), weights.w_uq, tokens, l, h)
    []float kv_latent = linear(input, weights.w_dkv, tokens, h, l)
    []float k = linear(kv_latent, weights.w_uk, tokens, l, h)
    []float v = linear(kv_latent, weights.w_uv, tokens, l, h)
    []float attention = zeros(tokens * tokens)
    []float context = zeros(tokens * h)
    float scale = 1.0 / sqrt_approx(h as float)
    int t = 0
    while t < tokens {
        []float scores = zeros(tokens)
        float max_score = -1000000.0
        int s = 0
        while s <= t {
            int i = 0
            while i < h {
                scores[s] = scores[s] + q[t * h + i] * k[s * h + i] * scale
                i = i + 1
            }
            if scores[s] > max_score {
                max_score = scores[s]
            }
            s = s + 1
        }
        float normalizer = 0.0
        s = 0
        while s <= t {
            scores[s] = exp_approx(scores[s] - max_score)
            normalizer = normalizer + scores[s]
            s = s + 1
        }
        s = 0
        while s <= t {
            float probability = scores[s] / normalizer
            attention[t * tokens + s] = probability
            int i = 0
            while i < h {
                context[t * h + i] = context[t * h + i] + probability * v[s * h + i]
                i = i + 1
            }
            s = s + 1
        }
        t = t + 1
    }
    []float gate_logits = linear(input, weights.w_gate, tokens, h, h)
    []float gated = zeros(tokens * h)
    int i = 0
    while i < tokens * h {
        gated[i] = context[i] * sigmoid(gate_logits[i])
        i = i + 1
    }
    gated_mla_result {
        output: linear(rms_norm_tokens(gated, tokens, h), weights.w_output, tokens, h, h),
        attention: attention,
        gate: gate_logits,
    }
}

func new_attnres_weights(hybrid_moe_config cfg) attnres_weights {
    attnres_weights {
        config: cfg,
        query_scale: deterministic_weights(cfg.hidden_dim, 40, 0.02),
        depth_keys: deterministic_weights(cfg.max_history * cfg.hidden_dim, 41, 0.01),
        depth_bias: deterministic_weights(cfg.max_history, 42, 0.001),
    }
}

func attention_residual(
    attnres_weights weights,
    []float query,
    []float history,
    int history_count,
    int tokens
) attnres_result {
    int h = weights.config.hidden_dim
    []float output = zeros(tokens * h)
    []float probabilities = zeros(tokens * history_count)
    int t = 0
    while t < tokens {
        []float scores = zeros(history_count)
        float max_score = -1000000.0
        int depth = 0
        while depth < history_count {
            int channel = 0
            while channel < h {
                float q = query[t * h + channel] * weights.query_scale[channel]
                float key = weights.depth_keys[depth * h + channel]
                // Content similarity plus a learned depth key.
                int history_index = depth * tokens * h + t * h + channel
                scores[depth] = scores[depth] + q * (history[history_index] + key)
                channel = channel + 1
            }
            scores[depth] = scores[depth] / sqrt_approx(h as float) + weights.depth_bias[depth]
            if scores[depth] > max_score {
                max_score = scores[depth]
            }
            depth = depth + 1
        }
        float normalizer = 0.0
        depth = 0
        while depth < history_count {
            scores[depth] = exp_approx(scores[depth] - max_score)
            normalizer = normalizer + scores[depth]
            depth = depth + 1
        }
        depth = 0
        while depth < history_count {
            float probability = scores[depth] / normalizer
            probabilities[t * history_count + depth] = probability
            int channel = 0
            while channel < h {
                output[t * h + channel] = output[t * h + channel] +
                    probability * history[depth * tokens * h + t * h + channel]
                channel = channel + 1
            }
            depth = depth + 1
        }
        t = t + 1
    }
    attnres_result {
        output: output,
        weights: probabilities,
    }
}

func store_history([]float history, []float values, int depth, int width) []float {
    []float out = copy_floats(history)
    int i = 0
    while i < width {
        out[depth * width + i] = values[i]
        i = i + 1
    }
    out
}

func new_hybrid_moe_model(hybrid_moe_config cfg) hybrid_moe_model {
    moe_config sparse_cfg = new_moe_config(
        cfg.hidden_dim,
        cfg.latent_dim,
        cfg.ffn_dim,
        cfg.n_shared_experts,
        cfg.n_routed_experts,
        cfg.top_k
    )
    hybrid_moe_model {
        config: cfg,
        kda: new_kda_weights(cfg),
        mla: new_gated_mla_weights(cfg),
        moe: new_moe_weights(sparse_cfg),
        residual: new_attnres_weights(cfg),
    }
}

func hybrid_moe_forward(hybrid_moe_model model, []float embeddings, int tokens) hybrid_moe_forward_result {
    hybrid_moe_config cfg = model.config
    int history_width = tokens * cfg.hidden_dim
    []float history = zeros(cfg.max_history * history_width)
    history = store_history(history, embeddings, 0, history_width)
    int history_count = 1
    []float current = copy_floats(embeddings)
    []float state = zeros(cfg.state_dim * cfg.state_dim)
    []float last_residual_weights = []
    []int last_indices = []
    []float last_expert_weights = []
    int group = 0
    while group < cfg.groups {
        int layer = 0
        while layer < cfg.kda_per_group {
            attnres_result retrieved = attention_residual(model.residual, current, history, history_count, tokens)
            kda_result mixed = kda_forward(model.kda, rms_norm_tokens(retrieved.output, tokens, cfg.hidden_dim), tokens, state)
            state = mixed.final_state
            current = add_arrays(retrieved.output, mixed.output)
            history = store_history(history, current, history_count, history_width)
            history_count = history_count + 1

            attnres_result moe_input = attention_residual(model.residual, current, history, history_count, tokens)
            moe_result moe_output = moe_forward(model.moe, rms_norm_tokens(moe_input.output, tokens, cfg.hidden_dim), tokens)
            current = add_arrays(moe_input.output, moe_output.output)
            history = store_history(history, current, history_count, history_width)
            history_count = history_count + 1
            last_residual_weights = moe_input.weights
            last_indices = moe_output.expert_indices
            last_expert_weights = moe_output.expert_weights
            layer = layer + 1
        }

        attnres_result global_input = attention_residual(model.residual, current, history, history_count, tokens)
        gated_mla_result global_output = gated_mla_forward(model.mla, rms_norm_tokens(global_input.output, tokens, cfg.hidden_dim), tokens)
        current = add_arrays(global_input.output, global_output.output)
        history = store_history(history, current, history_count, history_width)
        history_count = history_count + 1

        attnres_result global_moe_input = attention_residual(model.residual, current, history, history_count, tokens)
        moe_result global_moe = moe_forward(model.moe, rms_norm_tokens(global_moe_input.output, tokens, cfg.hidden_dim), tokens)
        current = add_arrays(global_moe_input.output, global_moe.output)
        history = store_history(history, current, history_count, history_width)
        history_count = history_count + 1
        last_residual_weights = global_moe_input.weights
        last_indices = global_moe.expert_indices
        last_expert_weights = global_moe.expert_weights
        group = group + 1
    }

    // Output AttnRes retrieves from every registered block representation.
    attnres_result final_retrieval = attention_residual(model.residual, current, history, history_count, tokens)
    hybrid_moe_forward_result {
        output: rms_norm_tokens(final_retrieval.output, tokens, cfg.hidden_dim),
        kda_state: state,
        last_residual_weights: final_retrieval.weights,
        last_expert_indices: last_indices,
        last_expert_weights: last_expert_weights,
        history_count: history_count,
    }
}

func finite_array([]float values) bool {
    int i = 0
    while i < len(values) {
        // NaN is the only floating value not equal to itself.
        if values[i] != values[i] || values[i] > 1000000000.0 || values[i] < -1000000000.0 {
            return false
        }
        i = i + 1
    }
    true
}

func sum_range([]float values, int offset, int count) float {
    float sum = 0.0
    int i = 0
    while i < count {
        sum = sum + values[offset + i]
        i = i + 1
    }
    sum
}

func abs_float(float value) float {
    if value < 0.0 {
        return 0.0 - value
    }
    value
}

func assert_true(bool condition, string message) int {
    if !condition {
        println("[hybrid-moe-s] FAIL: " + message)
        return 1
    }
    0
}

func main() int {
    hybrid_moe_config cfg = tiny_hybrid_moe_config()
    hybrid_moe_model model = new_hybrid_moe_model(cfg)
    int tokens = 4
    []float embeddings = deterministic_weights(tokens * cfg.hidden_dim, 50, 0.03)

    kda_result kda = kda_forward(model.kda, embeddings, tokens, zeros(cfg.state_dim * cfg.state_dim))
    int failures = 0
    failures = failures + assert_true(len(kda.output) == tokens * cfg.hidden_dim, "KDA output shape")
    failures = failures + assert_true(len(kda.final_state) == cfg.state_dim * cfg.state_dim, "KDA recurrent state shape")
    failures = failures + assert_true(finite_array(kda.output) && finite_array(kda.final_state), "KDA numerical stability")

    gated_mla_result mla = gated_mla_forward(model.mla, embeddings, tokens)
    int t = 0
    while t < tokens {
        failures = failures + assert_true(
            abs_float(sum_range(mla.attention, t * tokens, t + 1) - 1.0) < 0.001,
            "Gated MLA causal attention normalization"
        )
        t = t + 1
    }

    moe_result moe = moe_forward(model.moe, embeddings, tokens)
    t = 0
    while t < tokens {
        failures = failures + assert_true(
            abs_float(sum_range(moe.expert_weights, t * cfg.top_k, cfg.top_k) - 1.0) < 0.001,
            "Stable LatentMoE top-k normalization"
        )
        failures = failures + assert_true(
            moe.expert_indices[t * cfg.top_k] != moe.expert_indices[t * cfg.top_k + 1],
            "Stable LatentMoE unique experts"
        )
        t = t + 1
    }

    hybrid_moe_forward_result result = hybrid_moe_forward(model, embeddings, tokens)
    failures = failures + assert_true(len(result.output) == tokens * cfg.hidden_dim, "K3 backbone output shape")
    failures = failures + assert_true(finite_array(result.output), "K3 backbone numerical stability")
    failures = failures + assert_true(result.history_count == 1 + (cfg.kda_per_group * 2 + 2) * cfg.groups, "3:1 hybrid history topology")
    t = 0
    while t < tokens {
        failures = failures + assert_true(
            abs_float(sum_range(result.last_residual_weights, t * result.history_count, result.history_count) - 1.0) < 0.001,
            "AttnRes depth weights normalization"
        )
        t = t + 1
    }

    hybrid_moe_config production = production_hybrid_moe_shape()
    failures = failures + assert_true(production.n_routed_experts == 896, "production routed expert count")
    failures = failures + assert_true(production.top_k == 16, "production active expert count")

    if failures > 0 {
        println("[hybrid-moe-s] failures=" + int_to_string(failures))
        return 1
    }
    println("[hybrid-moe-s] KDA: PASS")
    println("[hybrid-moe-s] Gated MLA: PASS")
    println("[hybrid-moe-s] Stable LatentMoE: PASS")
    println("[hybrid-moe-s] AttnRes 3:1 backbone: PASS")
    println("[hybrid-moe-s] output_shape=" + int_to_string(tokens) + "x" + int_to_string(cfg.hidden_dim))
    println("[hybrid-moe-s] production_experts=16/896")
    0
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    int current = value
    string out = ""
    while current > 0 {
        int digit = current - (current / 10) * 10
        out = string_char(digit + 48) + out
        current = current / 10
    }
    out
}

func string_char(int code) string {
    string(code)
}
