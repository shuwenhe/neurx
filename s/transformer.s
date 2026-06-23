package neurx.transformer

use neurx.tensor.tensor
use neurx.tensor.new

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    for i in 0..n {
        out[i] = data[i]
    }
    out
}

func copy_tensor(tensor value) tensor {
    new(copy_float(value.data), copy_int(value.shape), value.requires_grad)
}

func copy_layer(transformer_layer layer) transformer_layer {
    transformer_layer {
        w_q: copy_tensor(layer.w_q),
        w_k: copy_tensor(layer.w_k),
        w_v: copy_tensor(layer.w_v),
        w_o: copy_tensor(layer.w_o),
        w_ff1: copy_tensor(layer.w_ff1),
        w_ff2: copy_tensor(layer.w_ff2),
        b_ff1: copy_tensor(layer.b_ff1),
        b_ff2: copy_tensor(layer.b_ff2),
        w_up: copy_tensor(layer.w_up),
        b_up: copy_tensor(layer.b_up),
    }
}

func copy_layers([]transformer_layer layers) []transformer_layer {
    int n = len(layers)
    []transformer_layer out = []transformer_layer{cap: n}
    for i in 0..n {
        out.push(copy_layer(layers[i]))
    }
    out
}

struct transformer_config {
    int num_layers
    int num_heads
    int d_model
    int d_ff
    float dropout
}

struct transformer_layer {
    tensor w_q       // Query projection
    tensor w_k       // Key projection
    tensor w_v       // Value projection
    tensor w_o       // Output projection (attention)
    tensor w_ff1     // FFN gate projection (SwiGLU) or up projection (ReLU MLP)
    tensor w_ff2     // FFN down projection
    tensor b_ff1     // FFN gate bias
    tensor b_ff2     // FFN down bias
    tensor w_up      // FFN value/up projection (SwiGLU only, empty for ReLU fallback)
    tensor b_up      // FFN value/up bias (SwiGLU only)
}

struct transformer {
    transformer_config config
    []transformer_layer layers
}

func transformer_init(config transformer_config) transformer {
    []transformer_layer mut_layers = []transformer_layer{cap: config.num_layers}
    // Pre-create shape arrays to avoid complex array literals
    int i = 0
    while i < config.num_layers {
        // Create shapes using helper approach
        []int shape_dmd = make_int_array_2(config.d_model, config.d_model)
        []int shape_dmff = make_int_array_2(config.d_model, config.d_ff)
        []int shape_ffdm = make_int_array_2(config.d_ff, config.d_model)
        []int shape_ff = make_int_array_1(config.d_ff)
        []int shape_dm = make_int_array_1(config.d_model)

        transformer_layer layer = transformer_layer {
            // ── Attention weights ──
            w_q: tensor_randn(shape_dmd),   // [d_model, d_model]
            w_k: tensor_randn(shape_dmd),   // [d_model, d_model]
            w_v: tensor_randn(shape_dmd),   // [d_model, d_model]
            w_o: tensor_randn(shape_dmd),   // [d_model, d_model]

            // ── SwiGLU FFN weights ──
            w_ff1: tensor_randn(shape_dmff),  // gate:  [d_model, d_ff]
            w_up: tensor_randn(shape_dmff),    // value: [d_model, d_ff] (SwiGLU up proj)
            w_ff2: tensor_randn(shape_ffdm),   // down:  [d_ff, d_model]

            // Biases
            b_ff1: tensor_zeros(shape_ff),     // gate bias [d_ff]
            b_up: tensor_zeros(shape_ff),      // value bias [d_ff] (SwiGLU)
            b_ff2: tensor_zeros(shape_dm)      // down bias [d_model]
        }
        mut_layers[i] = layer
        i = i + 1
    }
    transformer {
        config: config,
        layers: mut_layers
    }
}

// Helper functions to create int arrays without inline literals
func make_int_array_1(int v) []int {
    []out = []int{cap: 1}
    out[0] = v
    out
}

func make_int_array_2(int a, int b) []int {
    []out = []int{cap: 2}
    out[0] = a
    out[1] = b
    out
}

func transformer_config_state_dict(transformer_config config) transformer_config {
    config
}

func transformer_config_load_state_dict(transformer_config config, transformer_config other) transformer_config {
    other
}

func transformer_layer_state_dict(transformer_layer layer) transformer_layer {
    copy_layer(layer)
}

func transformer_layer_load_state_dict(transformer_layer layer, transformer_layer other) transformer_layer {
    copy_layer(other)
}

func transformer_layers_state_dict([]transformer_layer layers) []transformer_layer {
    copy_layers(layers)
}

func transformer_layers_load_state_dict([]transformer_layer layers, []transformer_layer other) []transformer_layer {
    copy_layers(other)
}

func transformer_layer_count(transformer m) int {
    len(m.layers)
}

func transformer_state_dict(transformer state) transformer {
    transformer {
        config: state.config,
        layers: copy_layers(state.layers),
    }
}

func transformer_load_state_dict(transformer state, transformer other) transformer {
    del state
    transformer {
        config: other.config,
        layers: copy_layers(other.layers),
    }
}

func transformer_forward(m transformer, x tensor) tensor {
    int i = 0
    tensor out = x
    // Workaround for S compiler array indexing limitation with complex types
    // Use iteration-based access instead of direct indexing
    []transformer_layer layers_copy = copy_layers(m.layers)
    while i < m.config.num_layers {
        if i < len(layers_copy) {
            out = transformer_layer_forward(layers_copy[i], out, m.config)
        }
        i = i + 1
    }
    return out
}

func transformer_layer_forward(layer transformer_layer, x tensor, config transformer_config) tensor {
    // ── Multi-head self-attention with causal mask ──
    tensor q = matmul(x, layer.w_q)
    tensor k = matmul(x, layer.w_k)
    tensor v = matmul(x, layer.w_v)
    tensor attn = multihead_attention(q, k, v, config.num_heads)
    tensor attn_out = matmul(attn, layer.w_o)

    // Residual connection after attention
    tensor x2 = add(x, attn_out)

    // ── SwiGLU Feed-Forward Network (replaces ReLU MLP) ──
    // SwiGLU: output = (silu(xW_gate)) * (xW_up) @ W_down
    // Used by LLaMA, Claude, Mistral, etc.
    tensor swiglu_out = swiglu_ffn(x2, layer)

    // Residual connection after FFN
    tensor out = add(x2, swiglu_out)
    return out
}

// ── SwiGLU FFN Forward Pass ─────────────────────────────────────────────────
// Implements gated activation used in modern LLMs:
//   gate = silu(x @ W_gate + b_gate)   [Swish activation]
//   up   = x @ W_up + b_up             [linear projection]
//   h    = gate * up                    [element-wise gating]
//   out  = h @ W_down + b_down         [output projection]

func swiglu_ffn(tensor x, transformer_layer layer) tensor {
    int n_data = len(layer.w_ff1.data)
    int n_up = len(layer.w_up.data)

    if n_up > 0 && n_data == n_up {
        // Full SwiGLU: separate gate and up projections
        tensor gate_hidden = add(matmul(x, layer.w_ff1), layer.b_ff1)  // gate path
        tensor gate_act = silu(gate_hidden)                            // silu activation
        tensor up_hidden = add(matmul(x, layer.w_up), layer.b_up)      // value path
        tensor gated = mul(gate_act, up_hidden)                        // gating
        tensor output = add(matmul(gated, layer.w_ff2), layer.b_ff2)   // down project
        output
    } else {
        // Fallback to ReLU MLP when SwiGLU weights not initialized
        tensor ff1 = add(matmul(x, layer.w_ff1), layer.b_ff1)
        tensor ff1_act = relu(ff1)
        tensor ff2 = add(matmul(ff1_act, layer.w_ff2), layer.b_ff2)
        ff2
    }
}

// SiLU / Swish activation: x * sigmoid(x)
func silu(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float x = input.data[i]
        float sig = 1.0 / (1.0 + exp_approx(-x))
        out[i] = x * sig
        i = i + 1
    }
    new(out, copy_int(input.shape), input.requires_grad)
}

func multihead_attention(tensor q, tensor k, tensor v, int num_heads) tensor {
    scaled_dot_product_attention_causal(q, k, v, num_heads)
}

// ── Causal Mask ──────────────────────────────────────────────────────────────
// Generate a lower-triangular causal mask: 0 where allowed, -inf where masked.
// Shape: [seq_len, seq_len]

func make_causal_mask(int seq_len) tensor {
    int total = seq_len * seq_len
    []float data = []float{cap: total}
    int r = 0
    while r < seq_len {
        int c = 0
        while c < seq_len {
            // position (r, c): allow if c <= r (can attend to past + current)
            if c <= r {
                data.push(0.0)
            } else {
                data.push(-1e9)
            }
            c = c + 1
        }
        r = r + 1
    }
    new(data, [seq_len, seq_len], false)
}

// ── Scaled Dot-Product Attention with Causal Mask ────────────────────────────
// q, k, v: [batch * heads, seq_len, head_dim] or [seq_len, head_dim] for single
// Applies causal mask so each position can only attend to itself and previous positions.

func scaled_dot_product_attention_causal(tensor q, tensor k, tensor v, int num_heads) tensor {
    int ndim_q = len(q.shape)
    int ndim_k = len(k.shape)

    // Determine sequence length and head_dim from shapes
    int seq_len = 1
    int head_dim = 1
    int batch_heads = 1

    if ndim_q == 3 {
        batch_heads = q.shape[0]
        seq_len = q.shape[1]
        head_dim = q.shape[2]
    } else {
        if ndim_q == 2 {
            seq_len = q.shape[0]
            head_dim = q.shape[1]
        }
    }

    // Scale factor for attention scores
    float scale = 1.0 / sqrt_approx(float(head_dim))

    // Build causal mask once
    tensor mask = make_causal_mask(seq_len)

    // Compute attention scores: Q @ K^T / sqrt(d_k)
    tensor kt = transpose(k) // [batch*heads, head_dim, seq_len] or [head_dim, seq_len]
    tensor scores = matmul(q, kt) // [batch*heads, seq_len, seq_len] or [seq_len, seq_len]

    // Apply scale
    int n_scores = len(scores.data)
    int si = 0
    while si < n_scores {
        scores.data[si] = scores.data[si] * scale
        si = si + 1
    }

    // Apply causal mask (add -inf to masked positions)
    int mi = 0
    while mi < n_scores {
        scores.data[mi] = scores.data[mi] + mask.data[mi]
        mi = mi + 1
    }

    // Softmax over last dimension (keys dimension)
    tensor attn_weights = softmax_last_dim(scores)

    // Apply to values: attn_weights @ V
    tensor output = matmul(attn_weights, v)
    return output
}

// ── Softmax on last dimension (for attention weights) ────────────────────────
// Numerically stable softmax along the last axis.

func softmax_last_dim(tensor input) tensor {
    int ndim = len(input.shape)
    if ndim == 1 {
        return softmax_1d_tensor(input)
    }
    // For 2D: [rows, cols] -> softmax over cols
    if ndim == 2 {
        return softmax_2d_last(input)
    }
    // For 3D: [batch, seq, dim] -> softmax over last dim
    softmax_3d_last(input)
}

func softmax_1d_tensor(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    // Find max for numerical stability
    float max_v = input.data[0]
    int i = 1
    while i < n {
        if input.data[i] > max_v {
            max_v = input.data[i]
        }
        i = i + 1
    }
    // exp and sum
    float denom = 0.0
    i = 0
    while i < n {
        float v = exp_approx(input.data[i] - max_v)
        out[i] = v
        denom = denom + v
        i = i + 1
    }
    if denom == 0.0 {
        denom = 1.0
    }
    // Normalize
    i = 0
    while i < n {
        out[i] = out[i] / denom
        i = i + 1
    }
    new(out, copy_int(input.shape), input.requires_grad)
}

func softmax_2d_last(tensor input) tensor {
    int rows = input.shape[0]
    int cols = input.shape[1]
    []float out = []float{cap: rows * cols}
    int r = 0
    while r < rows {
        int base = r * cols
        // Find max in this row
        float max_v = input.data[base]
        int c = 1
        while c < cols {
            if input.data[base + c] > max_v {
                max_v = input.data[base + c]
            }
            c = c + 1
        }
        // Exp and sum
        float denom = 0.0
        c = 0
        while c < cols {
            float v = exp_approx(input.data[base + c] - max_v)
            out[base + c] = v
            denom = denom + v
            c = c + 1
        }
        if denom == 0.0 {
            denom = 1.0
        }
        // Normalize
        c = 0
        while c < cols {
            out[base + c] = out[base + c] / denom
            c = c + 1
        }
        r = r + 1
    }
    new(out, copy_int(input.shape), input.requires_grad)
}

func softmax_3d_last(tensor input) tensor {
    int d0 = input.shape[0]
    int d1 = input.shape[1]
    int d2 = input.shape[2]
    int stride = d2
    []float out = []float{cap: d0 * d1 * d2}
    int a = 0
    while a < d0 {
        int b = 0
        while b < d1 {
            int base = (a * d1 + b) * d2
            // Find max
            float max_v = input.data[base]
            int c = 1
            while c < d2 {
                if input.data[base + c] > max_v {
                    max_v = input.data[base + c]
                }
                c = c + 1
            }
            // Exp and sum
            float denom = 0.0
            c = 0
            while c < d2 {
                float v = exp_approx(input.data[base + c] - max_v)
                out[base + c] = v
                denom = denom + v
                c = c + 1
            }
            if denom == 0.0 {
                denom = 1.0
            }
            // Normalize
            c = 0
            while c < d2 {
                out[base + c] = out[base + c] / denom
                c = c + 1
            }
            b = b + 1
        }
        a = a + 1
    }
    new(out, copy_int(input.shape), input.requires_grad)
}

// ── RoPE (Rotary Position Embedding) Precomputation ──────────────────────────
// Generate cos and sin tables for rotary position embeddings.
// Used by LLaMA, Claude, PaLM, etc.

struct rope_cache {
    tensor cos_table   // [seq_len, head_dim/2]
    tensor sin_table   // [seq_len, head_dim/2]
    int head_dim
    int max_seq_len
}

// Precompute cos/sin frequencies for RoPE
// theta_i = 10000^(-2i/d_model) for pair dimension index i
func precompute_rope(int max_seq_len, int head_dim) rope_cache {
    int half_dim = head_dim / 2
    if half_dim <= 0 {
        half_dim = 1
    }

    // Compute frequency bands: theta_i = 1 / (10000^(2i/head_dim))
    []float freqs = []float{cap: half_dim}
    int i = 0
    while i < half_dim {
        float exponent = -2.0 * float(i) / float(head_dim)
        // 10000^exponent = exp(exponent * ln(10000))
        float ln_base = log_approx(10000.0)
        float theta_val = exp_approx(exponent * ln_base)
        freqs.push(theta_val)
        i = i + 1
    }

    // Compute position * frequency for each position
    []float cos_data = []float{cap: max_seq_len * half_dim}
    []float sin_data = []float{cap: max_seq_len * half_dim}
    int pos = 0
    while pos < max_seq_len {
        int j = 0
        while j < half_dim {
            float angle = float(pos) * freqs[j]
            // Use Taylor series approximations
            cos_data[pos * half_dim + j] = rope_cos(angle)
            sin_data[pos * half_dim + j] = rope_sin(angle)
            j = j + 1
        }
        pos = pos + 1
    }

    rope_cache {
        cos_table: new(cos_data, [max_seq_len, half_dim], false),
        sin_table: new(sin_data, [max_seq_len, half_dim], false),
        head_dim: head_dim,
        max_seq_len: max_seq_len,
    }
}

// Cos approximation for RoPE angles
func rope_cos(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    // cos(x) ~ 1 - x^2/2 + x^4/24 - x^6/720
    1.0 - (x2 / 2.0) + (x4 / 24.0) - (x6 / 720.0)
}

// Sin approximation for RoPE angles
func rope_sin(float x) float {
    float x2 = x * x
    float x3 = x2 * x
    float x5 = x3 * x2
    // sin(x) ~ x - x^3/6 + x^5/120
    x - (x3 / 6.0) + (x5 / 120.0)
}

// Apply RoPE to a tensor (pairwise rotation)
// input: [..., head_dim], rotates pairs of dimensions
func apply_rope(tensor input, rope_cache cache, int start_pos) tensor {
    int n = len(input.data)
    int ndim = len(input.shape)
    int last_dim = input.shape[ndim - 1]
    int half_dim = cache.head_dim / 2
    if half_dim <= 0 {
        half_dim = 1
    }

    []float out = []float{cap: n}
    int flat = 0
    while flat < n {
        // Determine which "row" we're in (sequence position within this batch element)
        int local_idx = flat % last_dim
        int pair_idx = local_idx / 2
        int pos_in_pair = local_idx % 2

        if pos_in_pair == 0 && pair_idx < half_dim && pair_idx < len(cache.cos_table.data) {
            // Determine position offset for this element
            int elem_offset = flat / last_dim
            int seq_pos = (start_pos + elem_offset) % cache.max_seq_len
            if seq_pos < 0 {
                seq_pos = 0
            }
            int table_idx = seq_pos * half_dim + pair_idx
            if table_idx >= len(cache.cos_table.data) {
                table_idx = 0
            }

            float cos_v = cache.cos_table.data[table_idx]
            float sin_v = cache.sin_table.data[table_idx]
            float x0 = input.data[flat]
            // Get the paired element (next dimension)
            float x1 = 0.0
            if flat + 1 < n {
                x1 = input.data[flat + 1]
            }
            // Rotate: [x0, x1] -> [x0*cos - x1*sin, x0*sin + x1*cos]
            out[flat] = x0 * cos_v - x1 * sin_v
            if flat + 1 < n {
                out[flat + 1] = x0 * sin_v + x1 * cos_v
            }
        } else {
            out[flat] = input.data[flat]
        }
        flat = flat + 1
    }
    new(out, copy_int(input.shape), input.requires_grad)
}
