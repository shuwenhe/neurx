package neurx.moe.transformer
struct moe_config {
    int num_experts
    int num_experts_per_token
    int hidden_dim
    int expert_dim
    float capacity_factor
    float aux_loss_coeff
    bool use_top_k
    bool use_load_balancing
    bool use_expert_parallelism
    int expert_parallel_size
}
struct moe_layer {
    moe_config config
    []float gate_weight
    []float gate_bias
    [][]float expert_w1
    [][]float expert_w2
    [][]float expert_w3
    []float expert_b1
    []float expert_b2
    []float expert_b3
    []float router_logits
    []int expert_indices
    []int expert_counts
}
struct moe_forward_result {
    []float output
    float aux_loss
    []int expert_load
    []float router_probabilities
}
struct expert_forward_result {
    []float output
    []int token_indices
    []int expert_indices
}
struct moe_route_result {
    []int expert_indices
    []float router_probs
}
func new_moe_config(int hidden_dim, int expert_dim, int num_experts) moe_config {
    moe_config {
        num_experts: num_experts,
        num_experts_per_token: 2,
        hidden_dim: hidden_dim,
        expert_dim: expert_dim,
        capacity_factor: 1.25,
        aux_loss_coeff: 0.01,
        use_top_k: true,
        use_load_balancing: true,
        use_expert_parallelism: false,
        expert_parallel_size: 1,
    }
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
func fill_ramp(int size, float scale) []float {
    []float values = allocate_vector(size, 0.0)
    int i = 0
    while i < size {
        values[i] = scale * ((i + 1) * 1.0) / ((size + 1) * 1.0)
        i = i + 1
    }
    values
}
func new_moe_layer(moe_config cfg) moe_layer {
    int num_experts = cfg.num_experts
    int hidden_dim = cfg.hidden_dim
    int expert_dim = cfg.expert_dim
    moe_layer layer {
        config: cfg,
        gate_weight: fill_ramp(hidden_dim * num_experts, 0.01),
        gate_bias: allocate_vector(num_experts, 0.0),
    }
    layer.expert_w1 = [][]float{cap: num_experts}
    layer.expert_w2 = [][]float{cap: num_experts}
    layer.expert_w3 = [][]float{cap: num_experts}
    layer.expert_b1 = []float{cap: num_experts}
    layer.expert_b2 = []float{cap: num_experts}
    layer.expert_b3 = []float{cap: num_experts}
    layer.router_logits = []float{}
    layer.expert_indices = []int{}
    layer.expert_counts = allocate_vector(num_experts, 0)
    int e = 0
    while e < num_experts {
        layer.expert_w1.push(fill_ramp(hidden_dim * expert_dim, 0.02))
        layer.expert_w2.push(fill_ramp(expert_dim * expert_dim, 0.02))
        layer.expert_w3.push(fill_ramp(expert_dim * hidden_dim, 0.02))
        layer.expert_b1.push(allocate_vector(expert_dim, 0.0))
        layer.expert_b2.push(allocate_vector(expert_dim, 0.0))
        layer.expert_b3.push(allocate_vector(hidden_dim, 0.0))
        e = e + 1
    }
    layer
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
func softmax_row([]float row, int size) []float {
    []float out = allocate_vector(size, 0.0)
    float max_val = row[0]
    int i = 1
    while i < size {
        if row[i] > max_val {
            max_val = row[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    while i < size {
        float e = exp_approx(row[i] - max_val)
        out[i] = e
        sum_exp = sum_exp + e
        i = i + 1
    }
    if sum_exp > 0.0 {
        i = 0
        while i < size {
            out[i] = out[i] / sum_exp
            i = i + 1
        }
    }
    out
}
func top_k_indices([]float values, int k) []int {
    int n = len(values)
    []int indices = []int{cap: n}
    []float vals = []float{cap: n}
    int i = 0
    while i < n {
        indices[i] = i
        vals[i] = values[i]
        i = i + 1
    }
    int j = 0
    while j < k {
        int max_idx = j
        float max_val = vals[j]
        int l = j + 1
        while l < n {
            if vals[l] > max_val {
                max_val = vals[l]
                max_idx = l
            }
            l = l + 1
        }
        int temp_idx = indices[j]
        indices[j] = indices[max_idx]
        indices[max_idx] = temp_idx
        float temp_val = vals[j]
        vals[j] = vals[max_idx]
        vals[max_idx] = temp_val
        j = j + 1
    }
    []int result = []int{cap: k}
    int m = 0
    while m < k {
        result[m] = indices[m]
        m = m + 1
    }
    result
}
func route_tokens(moe_layer layer, []float hidden_states, int seq_len) moe_route_result {
    int hidden_dim = layer.config.hidden_dim
    int num_experts = layer.config.num_experts
    int num_tokens = seq_len
    []float gate_logits = matmul_flat(hidden_states, layer.gate_weight, num_tokens, hidden_dim, num_experts)
    int i = 0
    while i < num_tokens {
        int j = 0
        while j < num_experts {
            gate_logits[i * num_experts + j] = gate_logits[i * num_experts + j] + layer.gate_bias[j]
            j = j + 1
        }
        i = i + 1
    }
    []int expert_indices = []int{cap: num_tokens * layer.config.num_experts_per_token}
    []float router_probs = []float{cap: num_tokens * num_experts}
    i = 0
    while i < num_tokens {
        []float row = gate_logits[i * num_experts..(i+1) * num_experts]
        []float probs = softmax_row(row, num_experts)
        int j = 0
        while j < num_experts {
            router_probs[i * num_experts + j] = probs[j]
            j = j + 1
        }
        []int top_indices = top_k_indices(probs, layer.config.num_experts_per_token)
        j = 0
        while j < layer.config.num_experts_per_token {
            expert_indices.push(top_indices[j])
            j = j + 1
        }
        i = i + 1
    }
    moe_route_result {
        expert_indices: expert_indices,
        router_probs: router_probs,
    }
}
func expert_forward(moe_layer layer, int expert_id, []float input, int batch_size) []float {
    int hidden_dim = layer.config.hidden_dim
    int expert_dim = layer.config.expert_dim
    []float w1 = layer.expert_w1[expert_id]
    []float w2 = layer.expert_w2[expert_id]
    []float w3 = layer.expert_w3[expert_id]
    []float b1 = layer.expert_b1[expert_id]
    []float b2 = layer.expert_b2[expert_id]
    []float b3 = layer.expert_b3[expert_id]
    []float hidden = matmul_flat(input, w1, batch_size, hidden_dim, expert_dim)
    int i = 0
    while i < len(hidden) {
        hidden[i] = hidden[i] + b1[i % expert_dim]
        if hidden[i] < 0.0 {
            hidden[i] = 0.0
        }
        i = i + 1
    }
    []float hidden2 = matmul_flat(hidden, w2, batch_size, expert_dim, expert_dim)
    i = 0
    while i < len(hidden2) {
        hidden2[i] = hidden2[i] + b2[i % expert_dim]
        if hidden2[i] < 0.0 {
            hidden2[i] = 0.0
        }
        i = i + 1
    }
    []float output = matmul_flat(hidden2, w3, batch_size, expert_dim, hidden_dim)
    i = 0
    while i < len(output) {
        output[i] = output[i] + b3[i % hidden_dim]
        i = i + 1
    }
    output
}
func compute_aux_loss(moe_layer layer, []float router_probs, int seq_len) float {
    int num_experts = layer.config.num_experts
    int num_tokens = seq_len
    []float expert_load = allocate_vector(num_experts, 0.0)
    []float expert_prob = allocate_vector(num_experts, 0.0)
    int i = 0
    while i < num_tokens {
        int j = 0
        while j < num_experts {
            expert_prob[j] = expert_prob[j] + router_probs[i * num_experts + j]
            j = j + 1
        }
        i = i + 1
    }
    i = 0
    while i < num_tokens * layer.config.num_experts_per_token {
        int expert_id = layer.expert_indices[i]
        expert_load[expert_id] = expert_load[expert_id] + 1.0
        i = i + 1
    }
    float loss = 0.0
    i = 0
    while i < num_experts {
        float prob = expert_prob[i] / num_tokens
        float load = expert_load[i] / num_tokens
        loss = loss + prob * load
        i = i + 1
    }
    loss * layer.config.aux_loss_coeff
}
func moe_forward(moe_layer layer, []float hidden_states, int seq_len) moe_forward_result {
    int hidden_dim = layer.config.hidden_dim
    int num_tokens = seq_len
    int num_experts = layer.config.num_experts
    int num_experts_per_token = layer.config.num_experts_per_token
    moe_route_result routed = route_tokens(layer, hidden_states, seq_len)
    []int expert_indices = routed.expert_indices
    []float router_probs = routed.router_probs
    layer.expert_indices = expert_indices
    layer.router_logits = router_probs
    []float output = allocate_vector(num_tokens * hidden_dim, 0.0)
    []int expert_load = allocate_vector(num_experts, 0)
    int e = 0
    while e < num_experts {
        []int token_indices = []int{}
        int t = 0
        while t < num_tokens {
            int offset = t * num_experts_per_token
            int idx = 0
            while idx < num_experts_per_token {
                if expert_indices[offset + idx] == e {
                    token_indices.push(t)
                    break
                }
                idx = idx + 1
            }
            t = t + 1
        }
        if len(token_indices) == 0 {
            e = e + 1
            continue
        }
        int batch_size = len(token_indices)
        []float expert_input = allocate_vector(batch_size * hidden_dim, 0.0)
        int i = 0
        while i < batch_size {
            int token_idx = token_indices[i]
            int j = 0
            while j < hidden_dim {
                expert_input[i * hidden_dim + j] = hidden_states[token_idx * hidden_dim + j]
                j = j + 1
            }
            i = i + 1
        }
        []float expert_out = expert_forward(layer, e, expert_input, batch_size)
        i = 0
        while i < batch_size {
            int token_idx = token_indices[i]
            int j = 0
            while j < hidden_dim {
                float gate_prob = 0.0
                int k = 0
                while k < num_experts_per_token {
                    if expert_indices[token_idx * num_experts_per_token + k] == e {
                        gate_prob = router_probs[token_idx * num_experts + e]
                        break
                    }
                    k = k + 1
                }
                output[token_idx * hidden_dim + j] = output[token_idx * hidden_dim + j] + expert_out[i * hidden_dim + j] * gate_prob
                j = j + 1
            }
            i = i + 1
        }
        expert_load[e] = batch_size
        e = e + 1
    }
    float aux_loss = 0.0
    if layer.config.use_load_balancing {
        aux_loss = compute_aux_loss(layer, router_probs, seq_len)
    }
    moe_forward_result {
        output: output,
        aux_loss: aux_loss,
        expert_load: expert_load,
        router_probabilities: router_probs,
    }
}
func moe_backward(moe_layer layer, []float grad_output, int seq_len) []float {
    int hidden_dim = layer.config.hidden_dim
    int num_tokens = seq_len
    []float grad_input = allocate_vector(num_tokens * hidden_dim, 0.0)
    []float grad_gate = allocate_vector(len(layer.gate_weight), 0.0)
    int e = 0
    while e < layer.config.num_experts {
        []int token_indices = []int{}
        int t = 0
        while t < num_tokens {
            int offset = t * layer.config.num_experts_per_token
            int idx = 0
            while idx < layer.config.num_experts_per_token {
                if layer.expert_indices[offset + idx] == e {
                    token_indices.push(t)
                    break
                }
                idx = idx + 1
            }
            t = t + 1
        }
        if len(token_indices) == 0 {
            e = e + 1
            continue
        }
        int batch_size = len(token_indices)
        []float expert_grad_in = allocate_vector(batch_size * hidden_dim, 0.0)
        int i = 0
        while i < batch_size {
            int token_idx = token_indices[i]
            int j = 0
            while j < hidden_dim {
                float gate_prob = layer.router_logits[token_idx * layer.config.num_experts + e]
                expert_grad_in[i * hidden_dim + j] = grad_output[token_idx * hidden_dim + j] * gate_prob
                j = j + 1
            }
            i = i + 1
        }
        []float expert_grad_out = moe_backward_expert(layer, e, expert_grad_in, batch_size)
        i = 0
        while i < batch_size {
            int token_idx = token_indices[i]
            int j = 0
            while j < hidden_dim {
                grad_input[token_idx * hidden_dim + j] = grad_input[token_idx * hidden_dim + j] + expert_grad_out[i * hidden_dim + j]
                j = j + 1
            }
            i = i + 1
        }
        e = e + 1
    }
    grad_input
}
func moe_backward_expert(moe_layer layer, int expert_id, []float grad_output, int batch_size) []float {
    int hidden_dim = layer.config.hidden_dim
    int expert_dim = layer.config.expert_dim
    []float w1 = layer.expert_w1[expert_id]
    []float w2 = layer.expert_w2[expert_id]
    []float w3 = layer.expert_w3[expert_id]
    []float grad_hidden2 = matmul_flat(grad_output, transpose(w3, expert_dim, hidden_dim), batch_size, hidden_dim, expert_dim)
    []float grad_hidden = matmul_flat(grad_hidden2, transpose(w2, expert_dim, expert_dim), batch_size, expert_dim, expert_dim)
    []float grad_input = matmul_flat(grad_hidden, transpose(w1, hidden_dim, expert_dim), batch_size, expert_dim, hidden_dim)
    grad_input
}
func transpose([]float matrix, int rows, int cols) []float {
    []float result = allocate_vector(rows * cols, 0.0)
    int i = 0
    while i < rows {
        int j = 0
        while j < cols {
            result[j * rows + i] = matrix[i * cols + j]
            j = j + 1
        }
        i = i + 1
    }
    result
}
func moe_layer_parameters(moe_layer layer) []float {
    []float params = []float{}
    params = params + layer.gate_weight
    params = params + layer.gate_bias
    int e = 0
    while e < layer.config.num_experts {
        params = params + layer.expert_w1[e]
        params = params + layer.expert_w2[e]
        params = params + layer.expert_w3[e]
        params = params + layer.expert_b1[e]
        params = params + layer.expert_b2[e]
        params = params + layer.expert_b3[e]
        e = e + 1
    }
    params
}
func moe_compute_flops(moe_layer layer, int batch_size, int seq_len) long {
    int hidden_dim = layer.config.hidden_dim
    int expert_dim = layer.config.expert_dim
    int num_experts = layer.config.num_experts
    long expert_flops = batch_size * seq_len * (2 * hidden_dim * expert_dim + 2 * expert_dim * expert_dim + 2 * expert_dim * hidden_dim)
    long gate_flops = batch_size * seq_len * 2 * hidden_dim * num_experts
    expert_flops + gate_flops
}
func moe_compute_memory(moe_layer layer, int batch_size, int seq_len) long {
    int hidden_dim = layer.config.hidden_dim
    int expert_dim = layer.config.expert_dim
    int num_experts = layer.config.num_experts
    long param_memory = num_experts * (hidden_dim * expert_dim + expert_dim * expert_dim + expert_dim * hidden_dim + hidden_dim + expert_dim + expert_dim) * 4
    long activation_memory = batch_size * seq_len * (hidden_dim + expert_dim) * 4
    param_memory + activation_memory
}
