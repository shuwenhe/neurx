package neurx.distributed.tensor_parallel_v2
struct tp_v2_config {
    int tp_degree
    int tp_rank
    int hidden_dim
    int num_attention_heads
    int num_kv_heads
    int ffn_intermediate_dim
    bool use_sequence_parallel
}
struct tp_v2_state {
    tp_v2_config config
    int local_hidden_dim
    int local_num_heads
    int local_num_kv_heads
    int head_dim
    int local_ffn_dim
    [][]double w_q_local
    [][]double w_k_local
    [][]double w_v_local
    [][]double w_o_local
    [][]double w_gate_local
    [][]double w_up_local
    [][]double w_down_local
    []double norm1_gamma
    []double norm2_gamma
    double time_attn_ms
    double time_mlp_ms
    double time_comm_ms
}
func tp_mod(int val, int div) int {
    if div <= 0 { return 0 }
    int r = val
    for r >= div { r = r - div }
    for r < 0 { r = r + div }
    return r
}
func init_tp_v2(tp_v2_config cfg) tp_v2_state {
    tp_v2_state state
    state.config = cfg
    int h_rem = tp_mod(cfg.hidden_dim, cfg.tp_degree)
    int head_rem = tp_mod(cfg.num_attention_heads, cfg.tp_degree)
    state.local_hidden_dim = cfg.hidden_dim / cfg.tp_degree
    state.local_num_heads = cfg.num_attention_heads / cfg.tp_degree
    state.head_dim = cfg.hidden_dim / cfg.num_attention_heads
    state.local_num_kv_heads = cfg.num_kv_heads / cfg.tp_degree
    state.local_ffn_dim = cfg.ffn_intermediate_dim / cfg.tp_degree
    int h = cfg.hidden_dim
    int lh = state.local_hidden_dim
    int lffn = state.local_ffn_dim
    state.w_q_local = alloc_matrix(lh, h)
    state.w_k_local = alloc_matrix(lh, h)
    state.w_v_local = alloc_matrix(lh, h)
    state.w_o_local = alloc_matrix(h, lh)
    state.w_gate_local = alloc_matrix(lffn, h)
    state.w_up_local = alloc_matrix(lffn, h)
    state.w_down_local = alloc_matrix(h, lffn)
    state.norm1_gamma = []double{cap: h}
    state.norm2_gamma = []double{cap: h}
    int i = 0
    for i < h {
        state.norm1_gamma[i] = 1.0
        state.norm2_gamma[i] = 1.0
        i = i + 1
    }
    state.time_attn_ms = 0.0
    state.time_mlp_ms = 0.0
    state.time_comm_ms = 0.0
    return state
}
func alloc_matrix(int rows, int cols) [][]double {
    [][]double m = [][][]double{cap: rows}
    int i = 0
    for i < rows {
        m[i] = []double{cap: cols}
        i = i + 1
    }
    return m
}
func tp_attention_forward(
    tp_v2_state state,
    [][]double input,
    bool causal_mask) [][]double {
    int batch_size = len(input)
    int seq_len = 0
    if batch_size > 0 { seq_len = len(input[0]) }
    int H = state.config.hidden_dim
    int local_h = state.local_hidden_dim
    int nh = state.local_num_heads
    int nkh = state.local_num_kv_heads
    int d = state.head_dim
    [][]double normalized = rmsnorm_forward(input, state.norm1_gamma, 1e-6)
    [][]double q_local = matmul2d(normalized, transpose_matrix(state.w_q_local))
    [][]double k_local = matmul2d(normalized, transpose_matrix(state.w_k_local))
    [][]double v_local = matmul2d(normalized, transpose_matrix(state.w_v_local))
    [][]double q_heads = reshape_to_heads(q_local, batch_size, seq_len, nh, d)
    [][]double k_heads = reshape_to_heads(k_local, batch_size, seq_len, nkh, d)
    [][]double v_heads = reshape_to_heads(v_local, batch_size, seq_len, nkh, d)
    q_heads = apply_rope(q_heads, batch_size, seq_len, nh, d, state.config)
    k_heads = apply_rope(k_heads, batch_size, seq_len, nkh, d, state.config)
    int n_kv_groups = nh / nkh
    [][]double attn_out = [][][]double{cap: batch_size}
    int b = 0
    for b < batch_size {
        attn_out[b] = [][][]double{cap: nh}
        int h_idx = 0
        for h_idx < nh {
            int kv_h_idx = h_idx / n_kv_groups
            [][]double scores = compute_attn_scores(q_heads[b][h_idx], k_heads[b][kv_h_idx], seq_len, d)
            double scale = 1.0 / sqrt_double(double(d))
            scores = scale_matrix(scores, scale)
            if causal_mask {
                scores = apply_causal_mask(scores, seq_len)
            }
            [][]double attn_weights = softmax_2d(scores, 1)
            attn_out[b][h_idx] = matmul2d(attn_weights, v_heads[b][kv_h_idx])
            h_idx = h_idx + 1
        }
        b = b + 1
    }
    [][]double concat_out = concat_heads(attn_out, batch_size, seq_len, nh, d)
    [][]double attn_proj = matmul2d(concat_out, transpose_matrix(state.w_o_local))
    attn_proj = tp_allreduce_sum(attn_proj, state)
    [][]double output = add_matrices(input, attn_proj)
    return output
}
func tp_mlp_forward(
    tp_v2_state state,
    [][]double input) [][]double {
    int batch_size = len(input)
    int seq_len = 0
    if batch_size > 0 { seq_len = len(input[0]) }
    int H = state.config.hidden_dim
    int lffn = state.local_ffn_dim
    [][]double normalized = rmsnorm_forward(input, state.norm2_gamma, 1e-6)
    [][]double gate = matmul2d(normalized, transpose_matrix(state.w_gate_local))
    [][]double up = matmul2d(normalized, transpose_matrix(state.w_up_local))
    [][]double activated = silu_activation(gate)
    [][]double gated = elementwise_mul(activated, up)
    [][]double proj = matmul2d(gated, transpose_matrix(state.w_down_local))
    proj = tp_allreduce_sum(proj, state)
    [][]double output = add_matrices(input, proj)
    return output
}
func tp_transformer_block_forward(
    ref tp_v2_state state,
    [][]double input,
    bool causal_mask) [][]double {
    [][]double attn_out = tp_attention_forward(state, input, causal_mask)
    [][]double mlp_out = tp_mlp_forward(state, attn_out)
    return mlp_out
}
func tp_allreduce_sum([][][]double tensor, tp_v2_state state) [][][]double {
    return tensor
}
func matmul2d([][]double a, [][]double b) [][]double {
    int M = len(a)
    int K = 0
    if M > 0 { K = len(a[0]) }
    int N = len(b)
    [][]double c = alloc_matrix(M, N)
    int i = 0
    for i < M {
        int j = 0
        for j < N {
            double sum = 0.0
            int k = 0
            for k < K {
                sum = sum + a[i][k] * b[j][k]
                k = k + 1
            }
            c[i][j] = sum
            j = j + 1
        }
        i = i + 1
    }
    return c
}
func transpose_matrix([][]double m) [][]double {
    int rows = len(m)
    int cols = 0
    if rows > 0 { cols = len(m[0]) }
    [][]double t = alloc_matrix(cols, rows)
    int i = 0
    for i < rows {
        int j = 0
        for j < cols {
            t[j][i] = m[i][j]
            j = j + 1
        }
        i = i + 1
    }
    return t
}
func add_matrices([][]double a, [][]double b) [][]double {
    int rows = len(a)
    int cols = 0
    if rows > 0 { cols = len(a[0]) }
    [][]double c = alloc_matrix(rows, cols)
    int i = 0
    for i < rows {
        int j = 0
        for j < cols {
            c[i][j] = a[i][j] + b[i][j]
            j = j + 1
        }
        i = i + 1
    }
    return c
}
func elementwise_mul([][]double a, [][]double b) [][]double {
    int rows = len(a)
    int cols = 0
    if rows > 0 { cols = len(a[0]) }
    [][]double c = alloc_matrix(rows, cols)
    int i = 0
    for i < rows {
        int j = 0
        for j < cols {
            c[i][j] = a[i][j] * b[i][j]
            j = j + 1
        }
        i = i + 1
    }
    return c
}
func scale_matrix([][]double m, double scalar) [][]double {
    int rows = len(m)
    int i = 0
    for i < rows {
        int j = 0
        for j < len(m[i]) {
            m[i][j] = m[i][j] * scalar
            j = j + 1
        }
        i = i + 1
    }
    return m
}
func rmsnorm_forward([][]double input, []double gamma, double eps) [][]double {
    int rows = len(input)
    int cols = 0
    if rows > 0 { cols = len(input[0]) }
    [][]double output = alloc_matrix(rows, cols)
    int i = 0
    for i < rows {
        double sum_sq = 0.0
        int j = 0
        for j < cols {
            sum_sq = sum_sq + input[i][j] * input[i][j]
            j = j + 1
        }
        double mean_sq = sum_sq / double(cols)
        double inv_norm = 1.0 / sqrt_double(mean_sq + eps)
        int k = 0
        for k < cols {
            output[i][k] = input[i][k] * inv_norm * gamma[k]
            k = k + 1
        }
        i = i + 1
    }
    return output
}
func silu_activation([][]double m) [][]double {
    int rows = len(m)
    int i = 0
    for i < rows {
        int j = 0
        for j < len(m[i]) {
            double x = m[i][j]
            double sig = 1.0 / (1.0 + exp_approx(-x))
            m[i][j] = x * sig
            j = j + 1
        }
        i = i + 1
    }
    return m
}
func exp_approx(double x) double {
    if x > 20.0 { return 22026.46579 }
    if x < -20.0 { return 0.0 }
    double result = 1.0
    double term = 1.0
    int n = 1
    for n <= 15 {
        term = term * x / double(n)
        result = result + term
        n = n + 1
    }
    return result
}
func sqrt_double(double x) double {
    if x <= 0.0 { return 0.0 }
    double g = x / 2.0
    int iter = 0
    for iter < 20 {
        double ng = (g + x / g) / 2.0
        if ng == g { break }
        g = ng
        iter = iter + 1
    }
    return g
}
func softmax_2d([][]double logits, int axis) [][]double {
    int rows = len(logits)
    int cols = 0
    if rows > 0 { cols = len(logits[0]) }
    [][]double output = alloc_matrix(rows, cols)
    int i = 0
    for i < rows {
        double max_val = logits[i][0]
        int j = 1
        for j < cols {
            if logits[i][j] > max_val { max_val = logits[i][j] }
            j = j + 1
        }
        double sum_exp = 0.0
        int k = 0
        for k < cols {
            output[i][k] = exp_approx(logits[i][k] - max_val)
            sum_exp = sum_exp + output[i][k]
            k = k + 1
        }
        int m = 0
        for m < cols {
            output[i][m] = output[i][m] / sum_exp
            m = m + 1
        }
        i = i + 1
    }
    return output
}
func reshape_to_heads([][]double x, int B, int S, int nh, int d) [][][]double {
    [][][]double result = [][][]double{cap: B}
    int b = 0
    for b < B {
        result[b] = [][][]double{cap: nh}
        int h = 0
        for h < nh {
            result[b][h] = [][]double{cap: S}
            int s = 0
            for s < S {
                result[b][h][s] = []double{cap: d}
                int dd = 0
                for dd < d {
                    int src_idx = s * (nh * d) + h * d + dd
                    if src_idx < len(x[b]) {
                        result[b][h][s][dd] = x[b][src_idx]
                    }
                    dd = dd + 1
                }
                s = s + 1
            }
            h = h + 1
        }
        b = b + 1
    }
    return result
}
func concat_heads([][][]double x, int B, int S, int nh, int d) [][]double {
    [][]double result = alloc_matrix(B, S * nh * d)
    int b = 0
    for b < B {
        int h = 0
        for h < nh {
            int s = 0
            for s < S {
                int dd = 0
                for dd < d {
                    int dst_idx = s * (nh * d) + h * d + dd
                    if dst_idx < len(result[b]) {
                        result[b][dst_idx] = x[b][h][s][dd]
                    }
                    dd = dd + 1
                }
                s = s + 1
            }
            h = h + 1
        }
        b = b + 1
    }
    return result
}
func apply_causal_mask([][]double scores, int seq_len) [][]double {
    int i = 0
    for i < seq_len {
        int j = 0
        for j < seq_len {
            if j > i {
                scores[i][j] = -1e9
            }
            j = j + 1
        }
        i = i + 1
    }
    return scores
}
func compute_attn_scores([][]double q_head, [][]double k_head, int seq_len, int d) [][]double {
    [][]double scores = alloc_matrix(seq_len, seq_len)
    int i = 0
    for i < seq_len {
        int j = 0
        for j < seq_len {
            double dot = 0.0
            int dd = 0
            for dd < d {
                dot = dot + q_head[i][dd] * k_head[j][dd]
                dd = dd + 1
            }
            scores[i][j] = dot
            j = j + 1
        }
        i = i + 1
    }
    return scores
}
func apply_rope([][][]double x, int B, int S, int nh, int d, tp_v2_config cfg) [][][]double {
    int half_d = d / 2
    int b = 0
    for b < B {
        int h = 0
        for h < nh {
            int s = 0
            for s < S {
                int i = 0
                for i < half_d {
                    double freq = 1.0 / pow_dbl(10000.0, double(2*i) / double(d))
                    double angle = double(s) * freq
                    double cos_a = cos_approx(angle)
                    double sin_a = sin_approx(angle)
                    double x0 = x[b][h][s][2*i]
                    double x1 = x[b][h][s][2*i+1]
                    x[b][h][s][2*i]   = x0 * cos_a - x1 * sin_a
                    x[b][h][s][2*i+1] = x0 * sin_a + x1 * cos_a
                    i = i + 1
                }
                s = s + 1
            }
            h = h + 1
        }
        b = b + 1
    }
    return x
}
func cos_approx(double x) double {
    double term = 1.0
    double result = 1.0
    double xx = x * x
    int n = 1
    for n <= 10 {
        term = -term * xx / double((2*n-1) * (2*n))
        result = result + term
        n = n + 1
    }
    return result
}
func sin_approx(double x) double {
    double term = x
    double result = x
    double xx = x * x
    int n = 1
    for n <= 10 {
        term = -term * xx / double((2*n) * (2*n+1))
        result = result + term
        n = n + 1
    }
    return result
}
func pow_dbl(double base, double exp) double {
    if exp == 0.0 { return 1.0 }
    double result = 1.0
    bool negative = exp < 0.0
    if negative { exp = -exp }
    double e = 0.0
    for e < exp {
        result = result * base
        e = e + 1.0
    }
    if negative { result = 1.0 / result }
    return result
}
