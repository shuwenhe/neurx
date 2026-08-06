package neurx.model.transformer.ffn

struct ffn_config {
    int hidden_dim
    int intermediate_dim
    string activation_type
    float dropout_rate
    bool use_bias
    string ffn_type
}

struct standard_ffn_state {
    int hidden_dim
    int intermediate_dim
    []float up_weight
    []float down_weight
    []float up_bias
    []float down_bias
}

struct glu_ffn_state {
    int hidden_dim
    int intermediate_dim
    []float gate_weight
    []float value_weight
    []float down_weight
    []float gate_bias
    []float value_bias
    []float down_bias
}

struct feed_forward_network {
    ffn_config config
    standard_ffn_state standard_ffn
    glu_ffn_state glu_ffn
    string active_type
}

struct ffn_layer {
    ffn_config config
    feed_forward_network network
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
    while i <= 12 {
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
    while i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func sigmoid(float x) float {
    1.0 / (1.0 + exp_approx(-x))
}

func swish(float x) float {
    x * sigmoid(x)
}

func gelu(float x) float {
    float x3 = x * x * x
    float inner = x + 0.044715 * x3
    float cdf = 0.5 * (1.0 + inner * 0.7978845608)
    x * cdf
}

func relu(float x) float {
    if x > 0.0 {
        return x
    }
    0.0
}

func new_ffn_config(int hidden_dim, int intermediate_dim, string activation_type, string ffn_type) ffn_config {
    ffn_config {
        hidden_dim: hidden_dim,
        intermediate_dim: intermediate_dim,
        activation_type: activation_type,
        dropout_rate: 0.0,
        use_bias: true,
        ffn_type: ffn_type,
    }
}

func new_ffn_layer(int hidden_dim, string activation_type) ffn_layer {
    ffn_config cfg = new_ffn_config(hidden_dim, hidden_dim * 4, activation_type, "standard")
    if activation_type == "swiglu" {
        return ffn_layer {
            config: cfg,
            network: new_glu_ffn(cfg),
        }
    }
    ffn_layer {
        config: cfg,
        network: new_standard_ffn(cfg),
    }
}

func build_ramp(int size, float scale) []float {
    []float values = allocate_vector(size, 0.0)
    int i = 0
    while i < size {
        values[i] = scale * ((i + 1) * 1.0) / ((size + 1) * 1.0)
        i = i + 1
    }
    values
}

func new_standard_ffn(ffn_config cfg) feed_forward_network {
    int up_size = cfg.hidden_dim * cfg.intermediate_dim
    int down_size = cfg.intermediate_dim * cfg.hidden_dim
    feed_forward_network {
        config: cfg,
        standard_ffn: standard_ffn_state {
            hidden_dim: cfg.hidden_dim,
            intermediate_dim: cfg.intermediate_dim,
            up_weight: build_ramp(up_size, 0.02),
            down_weight: build_ramp(down_size, 0.02),
            up_bias: allocate_vector(cfg.intermediate_dim, 0.0),
            down_bias: allocate_vector(cfg.hidden_dim, 0.0),
        },
        active_type: "standard",
    }
}

func new_glu_ffn(ffn_config cfg) feed_forward_network {
    int gate_size = cfg.hidden_dim * cfg.intermediate_dim
    int down_size = cfg.intermediate_dim * cfg.hidden_dim
    feed_forward_network {
        config: cfg,
        glu_ffn: glu_ffn_state {
            hidden_dim: cfg.hidden_dim,
            intermediate_dim: cfg.intermediate_dim,
            gate_weight: build_ramp(gate_size, 0.02),
            value_weight: build_ramp(gate_size, 0.018),
            down_weight: build_ramp(down_size, 0.02),
            gate_bias: allocate_vector(cfg.intermediate_dim, 0.0),
            value_bias: allocate_vector(cfg.intermediate_dim, 0.0),
            down_bias: allocate_vector(cfg.hidden_dim, 0.0),
        },
        active_type: "glu",
    }
}

func matmul_flat([]float a, []float b, int m, int k, int n) []float {
    []float result = allocate_vector(m * n, 0.0)
    int i = 0
    while i < m {
        int j = 0
        while j < n {
            float sum = 0.0
            int l = 0
            while l < k {
                sum = sum + a[i * k + l] * b[l * n + j]
                l = l + 1
            }
            result[i * n + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    result
}

func apply_activation(
    []float hidden,
    string activation_type
) []float {
    []float out = copy_vector(hidden)
    int i = 0
    while i < len(out) {
        if activation_type == "relu" {
            out[i] = relu(out[i])
        } else if activation_type == "gelu" {
            out[i] = gelu(out[i])
        } else if activation_type == "swiglu" {
            out[i] = swish(out[i])
        } else if activation_type == "geglu" {
            out[i] = gelu(out[i])
        }
        i = i + 1
    }
    out
}

func forward_standard_ffn(
    feed_forward_network ffn,
    []float hidden_states,
    int tokens
) []float {
    int hidden_dim = ffn.standard_ffn.hidden_dim
    int intermediate_dim = ffn.standard_ffn.intermediate_dim
    []float up = matmul_flat(hidden_states, ffn.standard_ffn.up_weight, tokens, hidden_dim, intermediate_dim)
    int i = 0
    while i < len(up) {
        up[i] = up[i] + ffn.standard_ffn.up_bias[i % intermediate_dim]
        i = i + 1
    }
    up = apply_activation(up, ffn.config.activation_type)
    []float down = matmul_flat(up, ffn.standard_ffn.down_weight, tokens, intermediate_dim, hidden_dim)
    i = 0
    while i < len(down) {
        down[i] = down[i] + ffn.standard_ffn.down_bias[i % hidden_dim]
        i = i + 1
    }
    down
}

func forward_ffn_layer(
    ffn_layer layer,
    []float hidden_states,
    int tokens
) []float {
    if layer.config.activation_type == "swiglu" || layer.config.activation_type == "geglu" {
        return forward_swiglu_ffn(layer.network, hidden_states, tokens)
    }
    return forward_standard_ffn(layer.network, hidden_states, tokens)
}

func forward_glu_ffn(
    feed_forward_network ffn,
    []float hidden_states,
    int tokens
) []float {
    int hidden_dim = ffn.glu_ffn.hidden_dim
    int intermediate_dim = ffn.glu_ffn.intermediate_dim
    []float gate = matmul_flat(hidden_states, ffn.glu_ffn.gate_weight, tokens, hidden_dim, intermediate_dim)
    []float value = matmul_flat(hidden_states, ffn.glu_ffn.value_weight, tokens, hidden_dim, intermediate_dim)
    int i = 0
    while i < len(gate) {
        gate[i] = sigmoid(gate[i] + ffn.glu_ffn.gate_bias[i % intermediate_dim])
        value[i] = swish(value[i] + ffn.glu_ffn.value_bias[i % intermediate_dim])
        value[i] = value[i] * gate[i]
        i = i + 1
    }
    []float down = matmul_flat(value, ffn.glu_ffn.down_weight, tokens, intermediate_dim, hidden_dim)
    i = 0
    while i < len(down) {
        down[i] = down[i] + ffn.glu_ffn.down_bias[i % hidden_dim]
        i = i + 1
    }
    down
}

func forward_swiglu_ffn(
    feed_forward_network ffn,
    []float hidden_states,
    int tokens
) []float {
    int hidden_dim = ffn.glu_ffn.hidden_dim
    int intermediate_dim = ffn.glu_ffn.intermediate_dim
    []float gate = matmul_flat(hidden_states, ffn.glu_ffn.gate_weight, tokens, hidden_dim, intermediate_dim)
    []float value = matmul_flat(hidden_states, ffn.glu_ffn.value_weight, tokens, hidden_dim, intermediate_dim)
    int i = 0
    while i < len(gate) {
        gate[i] = swish(gate[i] + ffn.glu_ffn.gate_bias[i % intermediate_dim])
        value[i] = value[i] + ffn.glu_ffn.value_bias[i % intermediate_dim]
        value[i] = value[i] * gate[i]
        i = i + 1
    }
    []float down = matmul_flat(value, ffn.glu_ffn.down_weight, tokens, intermediate_dim, hidden_dim)
    i = 0
    while i < len(down) {
        down[i] = down[i] + ffn.glu_ffn.down_bias[i % hidden_dim]
        i = i + 1
    }
    down
}

func apply_dropout(
    []float hidden,
    float dropout_rate,
    int seed
) []float {
    if dropout_rate <= 0.0 {
        return copy_vector(hidden)
    }
    []float out = copy_vector(hidden)
    float keep_scale = 1.0 / (1.0 - dropout_rate)
    int i = 0
    while i < len(out) {
        int bucket = (seed + i * 1315423911) % 1000
        if bucket < (dropout_rate * 1000.0) {
            out[i] = 0.0
        } else {
            out[i] = out[i] * keep_scale
        }
        i = i + 1
    }
    out
}

func compute_router_probs(
    []float router_logits,
    int seq_len,
    int num_experts,
    int num_active_experts
) []float {
    int total = seq_len * num_experts
    []float probs = allocate_vector(total, 0.0)
    int s = 0
    while s < seq_len {
        int base = s * num_experts
        float max_score = router_logits[base]
        int e = 1
        while e < num_experts {
            if router_logits[base + e] > max_score {
                max_score = router_logits[base + e]
            }
            e = e + 1
        }
        float sum_exp = 0.0
        e = 0
        while e < num_experts {
            float value = exp_approx(router_logits[base + e] - max_score)
            probs[base + e] = value
            sum_exp = sum_exp + value
            e = e + 1
        }
        if sum_exp > 0.0 {
            e = 0
            while e < num_experts {
                probs[base + e] = probs[base + e] / sum_exp
                e = e + 1
            }
        }
        s = s + 1
    }
    probs
}

func compute_load_balancing_loss(
    []float router_probs,
    int seq_len,
    int num_experts
) float {
    if seq_len <= 0 || num_experts <= 0 {
        return 0.0
    }
    float mean = 1.0 / (num_experts * 1.0)
    float total = 0.0
    int i = 0
    while i < len(router_probs) {
        float diff = router_probs[i] - mean
        total = total + diff * diff
        i = i + 1
    }
    total / (len(router_probs) * 1.0)
}

func get_ffn_complexity(
    feed_forward_network ffn,
    int batch_size,
    int seq_len
) map[string]long {
    map[string]long{}
}

