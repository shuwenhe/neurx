












package neurx.moe.fine_grained





struct neurx_moe_config {
    int hidden_dim
    int ffn_dim
    int n_routed_experts
    int n_shared_experts
    int n_activated_experts
    int fine_grain_factor
    float expert_capacity_factor
    float bias_update_speed
}

func new_neurx_moe_config() neurx_moe_config {
    neurx_moe_config {
        hidden_dim: 5120,
        ffn_dim: 1536,
        n_routed_experts: 256,
        n_shared_experts: 2,
        n_activated_experts: 8,
        fine_grain_factor: 4,
        expert_capacity_factor: 1.25,
        bias_update_speed: 0.001,
    }
}





struct neurx_moe_weights {
    neurx_moe_config config


    []float gate_weight
    []float expert_bias


    [][]float routed_w1
    [][]float routed_w2


    []float shared_w1
    []float shared_w2
}





func zeros(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n { out[i] = 0.0; i = i + 1 }
    out
}

func fill_ramp(int n, float scale) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = scale * (i + 1) as float / (n + 1) as float
        i = i + 1
    }
    out
}

func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 12 {
        term = term * x / i as float
        result = result + term
        i = i + 1
    }
    result
}

func matmul_2d([]float a, []float b, int m, int k, int n) []float {
    []float result = zeros(m * n)
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

func gelu(float x) float {
    float c = 0.7978845608028654
    float x3 = x * x * x
    float inner = c * (x + 0.044715 * x3)
    float e2 = exp_approx(2.0 * inner)
    float tanh_val = (e2 - 1.0) / (e2 + 1.0)
    0.5 * x * (1.0 + tanh_val)
}





func new_neurx_moe_weights(neurx_moe_config cfg) neurx_moe_weights {
    int d = cfg.hidden_dim
    int df = cfg.ffn_dim
    int n_r = cfg.n_routed_experts
    int n_s = cfg.n_shared_experts

    []float gate_w = fill_ramp(d * n_r, 0.01)
    []float bias = zeros(n_r)

    [][]float r_w1 = [][]float{cap: n_r}
    [][]float r_w2 = [][]float{cap: n_r}
    int e = 0
    while e < n_r {
        r_w1[e] = fill_ramp(d * df, 0.02)
        r_w2[e] = fill_ramp(df * d, 0.02)
        e = e + 1
    }

    []float s_w1 = fill_ramp(d * df * n_s, 0.02)
    []float s_w2 = fill_ramp(df * n_s * d, 0.02)

    neurx_moe_weights {
        config: cfg,
        gate_weight: gate_w,
        expert_bias: bias,
        routed_w1: r_w1,
        routed_w2: r_w2,
        shared_w1: s_w1,
        shared_w2: s_w2,
    }
}










func update_expert_bias(
    []float bias, []float expert_load, int n_experts,
    float avg_load, float gamma
) []float {
    []float new_bias = []float{cap: n_experts}

    int i = 0
    while i < n_experts {
        if expert_load[i] > avg_load * 1.2 {
            new_bias[i] = bias[i] - gamma
        } else if expert_load[i] < avg_load * 0.8 {
            new_bias[i] = bias[i] + gamma
        } else {
            new_bias[i] = bias[i]
        }
        i = i + 1
    }

    new_bias
}





struct route_result {
    []int expert_indices
    []float expert_weights
    []float expert_load
}

func route_tokens_neurx(
    neurx_moe_weights w, []float hidden_states,
    int n_tokens
) route_result {
    neurx_moe_config cfg = w.config
    int d = cfg.hidden_dim
    int n_r = cfg.n_routed_experts
    int top_k = cfg.n_activated_experts


    []float logits = matmul_2d(hidden_states, w.gate_weight, n_tokens, d, n_r)


    int t = 0
    while t < n_tokens {
        int e = 0
        while e < n_r {
            logits[t * n_r + e] = logits[t * n_r + e] + w.expert_bias[e]
            e = e + 1
        }
        t = t + 1
    }


    []float probs = []float{cap: n_tokens * n_r}
    t = 0
    while t < n_tokens {
        float max_val = logits[t * n_r]
        int e = 1
        while e < n_r {
            if logits[t * n_r + e] > max_val { max_val = logits[t * n_r + e] }
            e = e + 1
        }

        float sum_exp = 0.0
        e = 0
        while e < n_r {
            float p = exp_approx(logits[t * n_r + e] - max_val)
            probs[t * n_r + e] = p
            sum_exp = sum_exp + p
            e = e + 1
        }

        if sum_exp > 0.0 {
            e = 0
            while e < n_r {
                probs[t * n_r + e] = probs[t * n_r + e] / sum_exp
                e = e + 1
            }
        }
        t = t + 1
    }


    []int indices = []int{cap: n_tokens * top_k}
    []float weights = []float{cap: n_tokens * top_k}
    []float load = zeros(n_r)

    t = 0
    while t < n_tokens {
        []int top_idx = top_k_indices_single(probs, t * n_r, n_r, top_k)

        int k = 0
        while k < top_k {
            int e = top_idx[k]
            indices[t * top_k + k] = e
            weights[t * top_k + k] = probs[t * n_r + e]
            load[e] = load[e] + 1.0
            k = k + 1
        }


        float w_sum = 0.0
        k = 0
        while k < top_k {
            w_sum = w_sum + weights[t * top_k + k]
            k = k + 1
        }
        if w_sum > 0.0 {
            k = 0
            while k < top_k {
                weights[t * top_k + k] = weights[t * top_k + k] / w_sum
                k = k + 1
            }
        }

        t = t + 1
    }

    route_result {
        expert_indices: indices,
        expert_weights: weights,
        expert_load: load,
    }
}


func top_k_indices_single([]float probs, int offset, int n_experts, int k) []int {
    []int result = []int{cap: k}
    []bool used = []bool{cap: n_experts}
    int i = 0
    while i < n_experts { used[i] = false; i = i + 1 }

    i = 0
    while i < k {
        float max_val = -1e9
        int max_idx = 0
        int e = 0
        while e < n_experts {
            if !used[e] && probs[offset + e] > max_val {
                max_val = probs[offset + e]
                max_idx = e
            }
            e = e + 1
        }
        result[i] = max_idx
        used[max_idx] = true
        i = i + 1
    }

    result
}





func shared_experts_forward(
    neurx_moe_weights w, []float hidden_states, int n_tokens
) []float {
    neurx_moe_config cfg = w.config
    int d = cfg.hidden_dim
    int df = cfg.ffn_dim
    int n_s = cfg.n_shared_experts
    int s_dim = df * n_s


    []float hidden = matmul_2d(hidden_states, w.shared_w1, n_tokens, d, s_dim)


    int t = 0
    while t < n_tokens {
        int e = 0
        while e < n_s {
            int dim = 0
            while dim < df {
                int idx = t * s_dim + e * df + dim
                hidden[idx] = gelu(hidden[idx])
                dim = dim + 1
            }
            e = e + 1
        }
        t = t + 1
    }


    []float output = matmul_2d(hidden, w.shared_w2, n_tokens, s_dim, d)

    output
}





func routed_experts_forward(
    neurx_moe_weights w, []float hidden_states,
    route_result route, int n_tokens
) []float {
    neurx_moe_config cfg = w.config
    int d = cfg.hidden_dim
    int df = cfg.ffn_dim
    int top_k = cfg.n_activated_experts

    []float output = zeros(n_tokens * d)

    int t = 0
    while t < n_tokens {
        int k = 0
        while k < top_k {
            int e = route.expert_indices[t * top_k + k]
            float gate_w = route.expert_weights[t * top_k + k]


            []float h_t = []float{cap: d}
            int dim = 0
            while dim < d {
                h_t[dim] = hidden_states[t * d + dim]
                dim = dim + 1
            }


            []float e_hidden = matmul_2d(h_t, w.routed_w1[e], 1, d, df)

            dim = 0
            while dim < df {
                e_hidden[dim] = gelu(e_hidden[dim])
                dim = dim + 1
            }

            []float e_out = matmul_2d(e_hidden, w.routed_w2[e], 1, df, d)


            dim = 0
            while dim < d {
                output[t * d + dim] = output[t * d + dim] + e_out[dim] * gate_w
                dim = dim + 1
            }

            k = k + 1
        }
        t = t + 1
    }

    output
}





struct neurx_moe_output {
    []float output
    route_result route
}

func neurx_moe_forward(
    neurx_moe_weights w, []float hidden_states,
    int n_tokens
) neurx_moe_output {
    neurx_moe_config cfg = w.config
    int d = cfg.hidden_dim


    []float shared_out = shared_experts_forward(w, hidden_states, n_tokens)


    route_result route = route_tokens_neurx(w, hidden_states, n_tokens)
    []float routed_out = routed_experts_forward(w, hidden_states, route, n_tokens)


    []float output = zeros(n_tokens * d)
    int i = 0
    while i < n_tokens * d {
        output[i] = shared_out[i] + routed_out[i]
        i = i + 1
    }

    neurx_moe_output { output: output, route: route }
}





func neurx_moe_step_update_bias(
    neurx_moe_weights w, route_result route,
    int n_tokens
) neurx_moe_weights {
    neurx_moe_config cfg = w.config
    int n_r = cfg.n_routed_experts
    float gamma = cfg.bias_update_speed

    float avg_load = n_tokens * cfg.n_activated_experts as float / n_r as float

    []float new_bias = update_expert_bias(w.expert_bias, route.expert_load, n_r, avg_load, gamma)

    neurx_moe_weights new_w = w
    new_w.expert_bias = new_bias
    new_w
}





struct load_balance_stats {
    float max_load
    float min_load
    float avg_load
    float load_imbalance_ratio
    float utilization
}

func compute_load_stats([]float load, int n_experts, int n_tokens, int top_k) load_balance_stats {
    float max_l = load[0]
    float min_l = load[0]
    float sum_l = 0.0
    int active = 0

    int i = 0
    while i < n_experts {
        sum_l = sum_l + load[i]
        if load[i] > max_l { max_l = load[i] }
        if load[i] < min_l { min_l = load[i] }
        if load[i] > 0.0 { active = active + 1 }
        i = i + 1
    }

    float avg = sum_l / n_experts as float
    float ratio = 0.0
    if avg > 0.0 { ratio = max_l / avg }

    load_balance_stats {
        max_load: max_l,
        min_load: min_l,
        avg_load: avg,
        load_imbalance_ratio: ratio,
        utilization: active as float / n_experts as float,
    }
}





func compute_moe_params(neurx_moe_config cfg) int {
    int d = cfg.hidden_dim
    int df = cfg.ffn_dim
    int n_r = cfg.n_routed_experts
    int n_s = cfg.n_shared_experts

    int router_params = d * n_r + n_r
    int routed_params = n_r * 2 * d * df
    int shared_params = 2 * d * df * n_s

    router_params + routed_params + shared_params
}

func compute_activated_params(neurx_moe_config cfg) int {
    int d = cfg.hidden_dim
    int df = cfg.ffn_dim
    int n_s = cfg.n_shared_experts
    int top_k = cfg.n_activated_experts

    cfg.n_routed_experts + top_k * 2 * d * df + 2 * d * df * n_s
}





func unit_name() string {
    "neurx/model/neurx/moe"
}

func unit_ready() int {
    1
}
