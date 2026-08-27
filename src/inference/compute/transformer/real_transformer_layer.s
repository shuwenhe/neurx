package neurx.inference.real_transformer_layer
use neurx.attention.paged_attention_core.{
    paged_attention_config,
    paged_kv_cache,
    slot_mapping,
    new_paged_kv_cache,
    reserve_tokens,
    write_kv_to_cache,
    compute_paged_attention,
    compute_paged_attention_gqa,
}

struct transformer_layer_config {
    int hidden_size
    int num_heads
    int num_kv_heads
    int head_size
    int intermediate_size
    int num_experts
    int num_experts_per_tok
    int block_size
    int max_blocks
    float rms_eps
    float rope_theta
}

struct transformer_layer_weights {
    float[] input_norm_weight
    float[] post_attention_norm_weight
    float[] w_q
    float[] w_k
    float[] w_v
    float[] w_o
    float[] gate_proj_weight
    float[] up_proj_weight
    float[] down_proj_weight
    float[] moe_gate_weight
    float[][] expert_gate_weights
    float[][] expert_up_weights
    float[][] expert_down_weights
    bool use_moe
}

struct moe_routing_result {
    int[] selected_experts
    float[] weights
    int num_selected
}

func default_layer_config() transformer_layer_config {
    transformer_layer_config{
        hidden_size: 896,
        num_heads: 14,
        num_kv_heads: 2,
        head_size: 64,
        intermediate_size: 4864,
        num_experts: 8,
        num_experts_per_tok: 2,
        block_size: 16,
        max_blocks: 1024,
        rms_eps: 1.0e-6,
        rope_theta: 10000.0,
    }
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float g = x
    int i = 0
    for i < 8 {
        g = 0.5 * (g + x / g)
        i = i + 1
    }
    g
}

func math_sin(float x) float {
    float result = 0.0
    float term = x
    int n = 1
    for n < 12 {
        result = result + term
        float factor = 0.0 - float((2 * n) * (2 * n + 1))
        term = term * x * x / factor
        n = n + 1
    }
    result
}

func math_cos(float x) float {
    float result = 1.0
    float term = 1.0
    int n = 1
    for n < 12 {
        float factor = 0.0 - float((2 * n - 1) * (2 * n))
        term = term * x * x / factor
        result = result + term
        n = n + 1
    }
    result
}

func rms_norm(float[] hidden, float[] weight, int hidden_size, float eps) float[] {
    float[] output = make(float[], hidden_size)
    float sum_sq = 0.0
    int i = 0
    for i < hidden_size {
        sum_sq = sum_sq + hidden[i] * hidden[i]
        i = i + 1
    }
    float rms = sqrt_approx(sum_sq / float(hidden_size) + eps)
    float inv = 1.0 / rms
    i = 0
    for i < hidden_size {
        float w = 1.0
        if i < len(weight) {
            w = weight[i]
        }
        output[i] = hidden[i] * inv * w
        i = i + 1
    }
    output
}

func matmul_vec(float[] x, float[] w, int in_dim, int out_dim) float[] {
    float[] output = make(float[], out_dim)
    int o = 0
    for o < out_dim {
        float acc = 0.0
        int i = 0
        for i < in_dim {
            acc = acc + x[i] * w[o * in_dim + i]
            i = i + 1
        }
        output[o] = acc
        o = o + 1
    }
    output
}

func apply_rope(float[] qk, int num_heads, int head_size, int position, float theta) float[] {
    float[] output = make(float[], len(qk))
    int h = 0
    for h < num_heads {
        int base = h * head_size
        int d = 0
        for d < head_size / 2 {
            float freq = 1.0
            int p = 0
            for p < d {
                freq = freq / theta
                p = p + 1
            }
            float angle = float(position) * freq
            float cos_v = math_cos(angle)
            float sin_v = math_sin(angle)
            float x0 = qk[base + d]
            float x1 = qk[base + d + head_size / 2]
            output[base + d] = x0 * cos_v - x1 * sin_v
            output[base + d + head_size / 2] = x0 * sin_v + x1 * cos_v
            d = d + 1
        }
        h = h + 1
    }
    output
}

func silu(float x) float {
    float sig = 1.0 / (1.0 + math_exp_neg(-x))
    x * sig
}

func math_exp_neg(float x) float {
    if x > 88.0 {
        return 1.0
    }
    if x < -88.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    float neg_x = 0.0 - x
    int i = 1
    for i < 24 {
        term = term * neg_x / float(i)
        result = result + term
        if term < 0.0 {
            term = 0.0 - term
        }
        if term < 1.0e-12 {
            break
        }
        i = i + 1
    }
    result
}

func swiglu_ffn(float[] hidden, float[] gate_w, float[] up_w, float[] down_w, int hidden_size, int inter_dim) float[] {
    float[] gate = matmul_vec(hidden, gate_w, hidden_size, inter_dim)
    float[] up = matmul_vec(hidden, up_w, hidden_size, inter_dim)
    float[] act = make(float[], inter_dim)
    int i = 0
    for i < inter_dim {
        act[i] = silu(gate[i]) * up[i]
        i = i + 1
    }
    matmul_vec(act, down_w, inter_dim, hidden_size)
}

func moe_route(float[] hidden, float[] gate_weight, int hidden_size, int num_experts, int top_k) moe_routing_result {
    float[] logits = matmul_vec(hidden, gate_weight, hidden_size, num_experts)
    int[] selected = make(int[], top_k)
    float[] weights = make(float[], top_k)
    bool[] used = make(bool[], num_experts)
    int k = 0
    for k < top_k {
        float best = -1.0e30
        int best_idx = 0
        int e = 0
        for e < num_experts {
            if !used[e] && logits[e] > best {
                best = logits[e]
                best_idx = e
            }
            e = e + 1
        }
        selected[k] = best_idx
        used[best_idx] = true
        k = k + 1
    }
    float max_logit = logits[selected[0]]
    int j = 1
    for j < top_k {
        if logits[selected[j]] > max_logit {
            max_logit = logits[selected[j]]
        }
        j = j + 1
    }
    float sum_exp = 0.0
    j = 0
    for j < top_k {
        float e_val = math_exp_neg(logits[selected[j]] - max_logit)
        weights[j] = e_val
        sum_exp = sum_exp + e_val
        j = j + 1
    }
    if sum_exp <= 0.0 {
        sum_exp = 1.0
    }
    j = 0
    for j < top_k {
        weights[j] = weights[j] / sum_exp
        j = j + 1
    }
    moe_routing_result{selected_experts: selected, weights: weights, num_selected: top_k}
}

func moe_ffn(float[] hidden, transformer_layer_weights weights, transformer_layer_config config, moe_routing_result route) float[] {
    int inter = config.intermediate_size
    float[] output = make(float[], config.hidden_size)
    int k = 0
    for k < route.num_selected {
        int expert_idx = route.selected_experts[k]
        float weight = route.weights[k]
        if expert_idx < 0 || expert_idx >= len(weights.expert_gate_weights) {
            k = k + 1
            continue
        }
        float[] gate_w = weights.expert_gate_weights[expert_idx]
        float[] up_w = weights.expert_up_weights[expert_idx]
        float[] down_w = weights.expert_down_weights[expert_idx]
        float[] gate = matmul_vec(hidden, gate_w, config.hidden_size, inter)
        float[] up = matmul_vec(hidden, up_w, config.hidden_size, inter)
        float[] act = make(float[], inter)
        int i = 0
        for i < inter {
            act[i] = silu(gate[i]) * up[i]
            i = i + 1
        }
        float[] expert_out = matmul_vec(act, down_w, inter, config.hidden_size)
        int j = 0
        for j < config.hidden_size {
            output[j] = output[j] + weight * expert_out[j]
            j = j + 1
        }
        k = k + 1
    }
    output
}

func transformer_layer_forward(
    float[] hidden,
    transformer_layer_weights weights,
    transformer_layer_config config,
    paged_kv_cache cache,
    []slot_mapping slots,
    int position
) (float[], paged_kv_cache) {
    int hidden_size = config.hidden_size
    int num_heads = config.num_heads
    int num_kv_heads = config.num_kv_heads
    int head_size = config.head_size
    float scale = 1.0 / sqrt_approx(float(head_size))
    float[] normed = rms_norm(hidden, weights.input_norm_weight, hidden_size, config.rms_eps)
    float[] q = matmul_vec(normed, weights.w_q, hidden_size, num_heads * head_size)
    float[] k = matmul_vec(normed, weights.w_k, hidden_size, num_kv_heads * head_size)
    float[] v = matmul_vec(normed, weights.w_v, hidden_size, num_kv_heads * head_size)
    q = apply_rope(q, num_heads, head_size, position, config.rope_theta)
    k = apply_rope(k, num_kv_heads, head_size, position, config.rope_theta)
    cache = write_kv_to_cache(cache, k, v, position)
    float[] attn_out = make(float[], num_heads * head_size)
    []slot_mapping single_slot = []slot_mapping{}
    if position < len(slots) {
        single_slot = append(single_slot, slots[position])
    }
    float[] local_slots_kv = slots
    if position + 1 < len(slots) {
        local_slots_kv = slots[0:position+1]
    }
    if num_kv_heads < num_heads {
        attn_out = compute_paged_attention_gqa(cache, q, attn_out, local_slots_kv, num_heads, num_kv_heads, head_size, scale)
    } else {
        attn_out = compute_paged_attention(cache, q, attn_out, local_slots_kv, num_heads, head_size, scale)
    }
    float[] attn_proj = matmul_vec(attn_out, weights.w_o, num_heads * head_size, hidden_size)
    float[] residual = make(float[], hidden_size)
    int i = 0
    for i < hidden_size {
        residual[i] = hidden[i] + attn_proj[i]
        i = i + 1
    }
    float[] normed2 = rms_norm(residual, weights.post_attention_norm_weight, hidden_size, config.rms_eps)
    float[] ffn_out
    if weights.use_moe && config.num_experts > 0 {
        moe_routing_result route = moe_route(normed2, weights.moe_gate_weight, hidden_size, config.num_experts, config.num_experts_per_tok)
        ffn_out = moe_ffn(normed2, weights, config, route)
    } else {
        ffn_out = swiglu_ffn(normed2, weights.gate_proj_weight, weights.up_proj_weight, weights.down_proj_weight, hidden_size, config.intermediate_size)
    }
    float[] output = make(float[], hidden_size)
    i = 0
    for i < hidden_size {
        output[i] = residual[i] + ffn_out[i]
        i = i + 1
    }
    (output, cache)
}

func make_identity_weights(transformer_layer_config config) transformer_layer_weights {
    int hidden = config.hidden_size
    int inter = config.intermediate_size
    int q_dim = config.num_heads * config.head_size
    int kv_dim = config.num_kv_heads * config.head_size
    int total_experts = config.num_experts
    if total_experts <= 0 {
        total_experts = 1
    }
    float[] norm_w = make(float[], hidden)
    int i = 0
    for i < hidden {
        norm_w[i] = 1.0
        i = i + 1
    }
    float[] w_q = identity_matrix(hidden, q_dim)
    float[] w_k = identity_matrix(hidden, kv_dim)
    float[] w_v = identity_matrix(hidden, kv_dim)
    float[] w_o = identity_matrix(q_dim, hidden)
    float[] gate_w = identity_matrix(hidden, inter)
    float[] up_w = identity_matrix(hidden, inter)
    float[] down_w = identity_matrix(inter, hidden)
    float[] moe_gate = make(float[], hidden * total_experts)
    int e = 0
    for e < total_experts {
        int j = 0
        for j < hidden && j < total_experts {
            if j == e {
                moe_gate[e * hidden + j] = 1.0
            }
            j = j + 1
        }
        e = e + 1
    }
    float[][] expert_gate = make(float[][], total_experts)
    float[][] expert_up = make(float[][], total_experts)
    float[][] expert_down = make(float[][], total_experts)
    e = 0
    for e < total_experts {
        expert_gate[e] = identity_matrix(hidden, inter)
        expert_up[e] = identity_matrix(hidden, inter)
        expert_down[e] = identity_matrix(inter, hidden)
        e = e + 1
    }
    transformer_layer_weights{
        input_norm_weight: norm_w,
        post_attention_norm_weight: norm_w,
        w_q: w_q,
        w_k: w_k,
        w_v: w_v,
        w_o: w_o,
        gate_proj_weight: gate_w,
        up_proj_weight: up_w,
        down_proj_weight: down_w,
        moe_gate_weight: moe_gate,
        expert_gate_weights: expert_gate,
        expert_up_weights: expert_up,
        expert_down_weights: expert_down,
        use_moe: config.num_experts > 0,
    }
}

func identity_matrix(int in_dim, int out_dim) float[] {
    float[] w = make(float[], out_dim * in_dim)
    int i = 0
    for i < out_dim && i < in_dim {
        w[i * in_dim + i] = 1.0
        i = i + 1
    }
    w
}
