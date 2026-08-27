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
        out = append(out, copy_layer(layers[i]))
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
    tensor w_q
    tensor w_k
    tensor w_v
    tensor w_o
    tensor w_ff1
    tensor w_ff2
    tensor b_ff1
    tensor b_ff2
    tensor w_up
    tensor b_up
}

struct transformer {
    transformer_config config
    []transformer_layer layers
}

func transformer_init(cfg transformer_config) transformer {
    []transformer_layer mut_layers = []transformer_layer{cap: transformer_config.num_layers}
    int i = 0
    for i < transformer_config.num_layers {
        []int shape_dmd = make_int_array_2(transformer_config.d_model, transformer_config.d_model)
        []int shape_dmff = make_int_array_2(transformer_config.d_model, transformer_config.d_ff)
        []int shape_ffdm = make_int_array_2(transformer_config.d_ff, transformer_config.d_model)
        []int shape_ff = make_int_array_1(transformer_config.d_ff)
        []int shape_dm = make_int_array_1(transformer_config.d_model)
        transformer_layer layer = transformer_layer {
            w_q: kaiming_uniform(shape_dmd, 0),
            w_k: kaiming_uniform(shape_dmd, 0),
            w_v: kaiming_uniform(shape_dmd, 0),
            w_o: xavier_uniform(shape_dmd),
            w_ff1: kaiming_uniform(shape_dmff, 0),
            w_up: kaiming_uniform(shape_dmff, 0),
            w_ff2: kaiming_uniform(shape_ffdm, 1),
            b_ff1: tensor_zeros(shape_ff),
            b_up: tensor_zeros(shape_ff),
            b_ff2: tensor_zeros(shape_dm)
        }
        mut_layers[i] = layer
        i = i + 1
    }
    transformer {
        config: config,
        mut_layers layers
    }
}

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

struct rng_state {
    int seed
}

func new_rng(int seed) rng_state {
    rng_state { seed: seed }
}

func rng_next(rng_state state) float {
    state.seed = (state.seed * 1664525 + 1013904223)  0x_7_fffffff
    float(state.seed) / 2147483648.0
}

func rng_randn(rng_state state) float {
    float u1 = rng_next(state)
    for u1 < 0.0000000001 {
        u1 = rng_next(state)
    }
    float u2 = rng_next(state)
    float r = sqrt_approx(-2.0 * log_approx(u1))
    float theta = 6.283185307179586 * u2
    r * rope_cos(theta)
}

func kaiming_uniform([]int shape, int fan_in_mode) tensor {
    int n = numel(shape)
    int fan_in = 1
    if len(shape) >= 2 {
        if fan_in_mode == 0 {
            fan_in = shape[0]
        } else {
            fan_in = shape[len(shape) - 1]
        }
    } else {
        fan_in = n
    }
    float bound = sqrt_approx(6.0 / float(fan_in))
    rng_state rng = new_rng(42)
    []float data = []float{cap: n}
    int i = 0
    for i < n {
        float v = (rng_next(rng) * 2.0 - 1.0) * bound
        data[i] = v
        i = i + 1
    }
    new(data, copy_int(shape), true)
}

func xavier_uniform([]int shape) tensor {
    int n = numel(shape)
    int fan_in = 1
    int fan_out = 1
    if len(shape) >= 2 {
        fan_in = shape[0]
        fan_out = shape[1]
    } else {
        fan_in = n
        fan_out = n
    }
    float bound = sqrt_approx(6.0 / float(fan_in + fan_out))
    rng_state rng = new_rng(42)
    []float data = []float{cap: n}
    int i = 0
    for i < n {
        float v = (rng_next(rng) * 2.0 - 1.0) * bound
        data[i] = v
        i = i + 1
    }
    new(data, copy_int(shape), true)
}

func kaiming_normal([]int shape, int fan_in_mode) tensor {
    int n = numel(shape)
    int fan_in = 1
    if len(shape) >= 2 {
        if fan_in_mode == 0 {
            fan_in = shape[0]
        } else {
            fan_in = shape[len(shape) - 1]
        }
    } else {
        fan_in = n
    }
    float std = sqrt_approx(2.0 / float(fan_in))
    rng_state rng = new_rng(42)
    []float data = []float{cap: n}
    int i = 0
    for i < n {
        float v = rng_randn(rng) * std
        data[i] = v
        i = i + 1
    }
    new(data, copy_int(shape), true)
}

func embedding_init([]int shape) tensor {
    int n = numel(shape)
    float std = 0.02
    rng_state rng = new_rng(42)
    []float data = []float{cap: n}
    int i = 0
    for i < n {
        float v = rng_randn(rng) * std
        data[i] = v
        i = i + 1
    }
    new(data, copy_int(shape), true)
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
    []transformer_layer layers_copy = copy_layers(m.layers)
    for i < m.config.num_layers {
        if i < len(layers_copy) {
            out = transformer_layer_forward(layers_copy[i], out, m.config)
        }
        i = i + 1
    }
    return out
}

func transformer_layer_forward(layer transformer_layer, x tensor, config transformer_config) tensor {
    tensor q = matmul(x, layer.w_q)
    tensor k = matmul(x, layer.w_k)
    tensor v = matmul(x, layer.w_v)
    tensor attn = multihead_attention(q, k, v, transformer_config.num_heads)
    tensor attn_out = matmul(attn, layer.w_o)
    tensor x2 = add(x, attn_out)
    tensor swiglu_out = swiglu_ffn(x2, layer)
    tensor out = add(x2, swiglu_out)
    return out
}

func swiglu_ffn(tensor x, transformer_layer layer) tensor {
    int n_data = len(layer.w_ff1.data)
    int n_up = len(layer.w_up.data)
    if n_up > 0 && n_data == n_up {
        tensor gate_hidden = add(matmul(x, layer.w_ff1), layer.b_ff1)
        tensor gate_act = silu(gate_hidden)
        tensor up_hidden = add(matmul(x, layer.w_up), layer.b_up)
        tensor gated = mul(gate_act, up_hidden)
        tensor output = add(matmul(gated, layer.w_ff2), layer.b_ff2)
        output
    } else {
        tensor ff1 = add(matmul(x, layer.w_ff1), layer.b_ff1)
        tensor ff1_act = relu(ff1)
        tensor ff2 = add(matmul(ff1_act, layer.w_ff2), layer.b_ff2)
        ff2
    }
}

func silu(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    for i < n {
        float x = input.data[i]
        float sig = 1.0 / (1.0 + exp_approx(-x))
        out[i] = x * sig
        i = i + 1
    }
    new(out, copy_int(input.shape), input.requires_grad)
}

struct flash_attention_config {
    int block_size_q
    int block_size_kv
    bool use_online_softmax
}

func default_flash_attention_config() flash_attention_config {
    flash_attention_config cfg
    cfg.block_size_q = 128
    cfg.block_size_kv = 128
    cfg.use_online_softmax = true
    return cfg
}

func flash_attention_forward(
    tensor q,
    tensor k,
    tensor v,
    int num_heads,
    flash_attention_config config
) tensor {
    int ndim_q = len(q.shape)
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
    float scale = 1.0 / sqrt_approx(float(head_dim))
    []float output_data = []float{cap: batch_heads * seq_len * head_dim}
    int init_i = 0
    for init_i < batch_heads * seq_len * head_dim {
        output_data[init_i] = 0.0
        init_i = init_i + 1
    }
    int q_block_start = 0
    for q_block_start < seq_len {
        int q_block_end = min(q_block_start + config.block_size_q, seq_len)
        int q_block_size = q_block_end - q_block_start
        []float row_max = []float{cap: batch_heads * q_block_size}
        []float row_sum = []float{cap: batch_heads * q_block_size}
        int ri = 0
        for ri < batch_heads * q_block_size {
            row_max[ri] = -1e9
            row_sum[ri] = 0.0
            ri = ri + 1
        }
        int kv_block_start = 0
        for kv_block_start < seq_len {
            int kv_block_end = min(kv_block_start + config.block_size_kv, seq_len)
            int kv_block_size = kv_block_end - kv_block_start
            compute_flash_scores(
                q, k,
                q_block_start, q_block_size,
                kv_block_start, kv_block_size,
                batch_heads, head_dim, scale,
                row_max, row_sum,
                output_data, v,
                seq_len
            )
            kv_block_start = kv_block_end
        }
        normalize_flash_output(output_data, row_sum, q_block_start, q_block_size, batch_heads, head_dim, seq_len)
        q_block_start = q_block_end
    }
    new(output_data, copy_int(q.shape), q.requires_grad)
}

func compute_flash_scores(
    tensor q, tensor k,
    int q_start, int q_size,
    int kv_start, int kv_size,
    int batch_heads, int head_dim, float scale,
    []float row_max, []float row_sum,
    []float output_data, tensor v,
    int total_seq_len
) void {
    int h = 0
    for h < batch_heads {
        int qi = 0
        for qi < q_size {
            int row_idx = h * q_size + qi
            float old_max = row_max[row_idx]
            int ki = 0
            for ki < kv_size {
                float score = 0.0
                int di = 0
                for di < head_dim {
                    int q_idx = ((h * total_seq_len + (q_start + qi)) * head_dim + di)
                    int k_idx = ((h * total_seq_len + (kv_start + ki)) * head_dim + di)
                    if q_idx < len(q.data)  k_idx < len(k.data) {
                        score = score + q.data[q_idx] * k.data[k_idx]
                    }
                    di = di + 1
                }
                score = score * scale
                int q_pos = q_start + qi
                int k_pos = kv_start + ki
                if k_pos > q_pos {
                    score = -1e9
                }
                if score > row_max[row_idx] {
                    row_max[row_idx] = score
                }
                float exp_score = exp_approx(score - row_max[row_idx])
                row_sum[row_idx] = row_sum[row_idx] + exp_score
                int vi = 0
                for vi < head_dim {
                    int v_idx = ((h * total_seq_len + (kv_start + ki)) * head_dim + vi)
                    int out_idx = ((h * total_seq_len + (q_start + qi)) * head_dim + vi)
                    if v_idx < len(v.data)  out_idx < len(output_data) {
                        float rescale = exp_approx(old_max - row_max[row_idx])
                        output_data[out_idx] = output_data[out_idx] * rescale + exp_score * v.data[v_idx]
                    }
                    vi = vi + 1
                }
                ki = ki + 1
            }
            qi = qi + 1
        }
        h = h + 1
    }
}

func normalize_flash_output(
    []float output_data,
    []float row_sum,
    int q_start, int q_size,
    int batch_heads, int head_dim,
    int total_seq_len
) void {
    int h = 0
    for h < batch_heads {
        int qi = 0
        for qi < q_size {
            int row_idx = h * q_size + qi
            float norm = row_sum[row_idx]
            if norm > 1e-8 {
                float inv_norm = 1.0 / norm
                int di = 0
                for di < head_dim {
                    int out_idx = ((h * total_seq_len + (q_start + qi)) * head_dim + di)
                    if out_idx < len(output_data) {
                        output_data[out_idx] = output_data[out_idx] * inv_norm
                    }
                    di = di + 1
                }
            }
            qi = qi + 1
        }
        h = h + 1
    }
}

struct attention_mode {
    bool use_flash_attention
    flash_attention_config flash_config
}

func default_attention_mode() attention_mode {
    attention_mode mode
    mode.use_flash_attention = true
    mode.flash_config = default_flash_attention_config()
    return mode
}

func multihead_attention_with_mode(tensor q, tensor k, tensor v, int num_heads, attention_mode mode) tensor {
    if mode.use_flash_attention {
        flash_attention_forward(q, k, v, num_heads, mode.flash_config)
    } else {
        scaled_dot_product_attention_causal(q, k, v, num_heads)
    }
}

func multihead_attention(tensor q, tensor k, tensor v, int num_heads) tensor {
    attention_mode mode = default_attention_mode()
    multihead_attention_with_mode(q, k, v, num_heads, mode)
}

func make_causal_mask(int seq_len) tensor {
    int total = seq_len * seq_len
    []float data = []float{cap: total}
    int r = 0
    for r < seq_len {
        int c = 0
        for c < seq_len {
            if c <= r {
                data[r * seq_len + c] = 0.0
            } else {
                data[r * seq_len + c] = -1e9
            }
            c = c + 1
        }
        r = r + 1
    }
    new(data, [seq_len, seq_len], false)
}

func scaled_dot_product_attention_causal(tensor q, tensor k, tensor v, int num_heads) tensor {
    int ndim_q = len(q.shape)
    int ndim_k = len(k.shape)
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
    float scale = 1.0 / sqrt_approx(float(head_dim))
    tensor mask = make_causal_mask(seq_len)
    tensor kt = transpose(k)
    tensor scores = matmul(q, kt)
    int n_scores = len(scores.data)
    int si = 0
    for si < n_scores {
        scores.data[si] = scores.data[si] * scale
        si = si + 1
    }
    int mi = 0
    for mi < n_scores {
        scores.data[mi] = scores.data[mi] + mask.data[mi]
        mi = mi + 1
    }
    tensor attn_weights = softmax_last_dim(scores)
    tensor output = matmul(attn_weights, v)
    return output
}

func softmax_last_dim(tensor input) tensor {
    int ndim = len(input.shape)
    if ndim == 1 {
        return softmax_1d_tensor(input)
    }
    if ndim == 2 {
        return softmax_2d_last(input)
    }
    softmax_3d_last(input)
}

func softmax_1d_tensor(tensor input) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    float max_v = input.data[0]
    int i = 1
    for i < n {
        if input.data[i] > max_v {
            max_v = input.data[i]
        }
        i = i + 1
    }
    float denom = 0.0
    i = 0
    for i < n {
        float v = exp_approx(input.data[i] - max_v)
        out[i] = v
        denom = denom + v
        i = i + 1
    }
    if denom == 0.0 {
        denom = 1.0
    }
    i = 0
    for i < n {
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
    for r < rows {
        int base = r * cols
        float max_v = input.data[base]
        int c = 1
        for c < cols {
            if input.data[base + c] > max_v {
                max_v = input.data[base + c]
            }
            c = c + 1
        }
        float denom = 0.0
        c = 0
        for c < cols {
            float v = exp_approx(input.data[base + c] - max_v)
            out[base + c] = v
            denom = denom + v
            c = c + 1
        }
        if denom == 0.0 {
            denom = 1.0
        }
        c = 0
        for c < cols {
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
    for a < d0 {
        int b = 0
        for b < d1 {
            int base = (a * d1 + b) * d2
            float max_v = input.data[base]
            int c = 1
            for c < d2 {
                if input.data[base + c] > max_v {
                    max_v = input.data[base + c]
                }
                c = c + 1
            }
            float denom = 0.0
            c = 0
            for c < d2 {
                float v = exp_approx(input.data[base + c] - max_v)
                out[base + c] = v
                denom = denom + v
                c = c + 1
            }
            if denom == 0.0 {
                denom = 1.0
            }
            c = 0
            for c < d2 {
                out[base + c] = out[base + c] / denom
                c = c + 1
            }
            b = b + 1
        }
        a = a + 1
    }
    new(out, copy_int(input.shape), input.requires_grad)
}

struct rope_cache {
    tensor cos_table
    tensor sin_table
    int head_dim
    int max_seq_len
}

func precompute_rope(int max_seq_len, int head_dim) rope_cache {
    int half_dim = head_dim / 2
    if half_dim <= 0 {
        half_dim = 1
    }
    []float freqs = []float{cap: half_dim}
    int i = 0
    for i < half_dim {
        float exponent = -2.0 * float(i) / float(head_dim)
        float ln_base = log_approx(10000.0)
        float theta_val = exp_approx(exponent * ln_base)
        freqs[i] = theta_val
        i = i + 1
    }
    []float cos_data = []float{cap: max_seq_len * half_dim}
    []float sin_data = []float{cap: max_seq_len * half_dim}
    int pos = 0
    for pos < max_seq_len {
        int j = 0
        for j < half_dim {
            float angle = float(pos) * freqs[j]
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

func rope_cos(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    1.0 - (x2 / 2.0) + (x4 / 24.0) - (x6 / 720.0)
}

func rope_sin(float x) float {
    float x2 = x * x
    float x3 = x2 * x
    float x5 = x3 * x2
    x - (x3 / 6.0) + (x5 / 120.0)
}

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
    for flat < n {
        int local_idx = f(flat - (flat / last_dim) * last_dim)
        int pair_idx = local_idx / 2
        int pos_in_pair = l(local_idx - (local_idx / 2) * 2)
        if pos_in_pair == 0 && pair_idx < half_dim && pair_idx < len(cache.cos_table.data) {
            int elem_offset = flat / last_dim
            int seq_pos = (start_pos + elem_offset) - ((start_pos + elem_offset) / cache.max_seq_len) * cache.max_seq_len
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
            float x1 = 0.0
            if flat + 1 < n {
                x1 = input.data[flat + 1]
            }
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
