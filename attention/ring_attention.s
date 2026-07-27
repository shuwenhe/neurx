package neurx.attention.ring
use neurx.attention.flash_v2.{
    flash_attn_config, flash_attn_forward_head, flash_attn_backward
}

struct ring_attn_config {
    int sp_degree
    int sp_rank
    int seq_len
    int local_seq_len
    int num_heads
    int local_num_heads
    int head_dim
    int kv_heads
    int block_size
    bool causal_mask
    float softmax_scale
    bool use_async_comm
    int comm_overlap_depth
    bool gradient_checkpointing
}

func default_ring_attn_config(
    int seq_len,
    int num_heads,
    int head_dim,
    int sp_degree,
    int sp_rank
) ring_attn_config {
    int local_seq_len = seq_len / sp_degree
    if seq_len % sp_degree != 0 {
        local_seq_len = local_seq_len + 1
    }
    ring_attn_config {
        sp_degree: sp_degree,
        sp_rank: sp_rank,
        seq_len: seq_len,
        local_seq_len: local_seq_len,
        num_heads: num_heads,
        local_num_heads: num_heads,
        head_dim: head_dim,
        kv_heads: num_heads,
        block_size: 128,
        causal_mask: true,
        softmax_scale: 1.0 / sqrt_approx(float_of_int(head_dim)),
        use_async_comm: true,
        comm_overlap_depth: 2,
        gradient_checkpointing: true,
    }
}

struct ring_attn_state {
    ring_attn_config config
    [][][]float local_q
    [][][]float local_k
    [][][]float local_v
    [][]float remote_k_buffer
    [][]float remote_v_buffer
    [][][]float attn_output
    [][][]float row_max_accum
    [][][]float row_sum_accum
    int current_ring_step
    float total_time_ms
    float comm_time_ms
    float compute_time_ms
}

func init_ring_attn_state(ring_attn_config cfg) ring_attn_state {
    int L = cfg.local_seq_len
    int H = cfg.local_num_heads
    int D = cfg.head_dim
    int Hkv = cfg.kv_heads
    ring_attn_state {
        config: cfg,
        local_q: allocate_3d_tensor(H, L, D),
        local_k: allocate_3d_tensor(Hkv, L, D),
        local_v: allocate_3d_tensor(Hkv, L, D),
        remote_k_buffer: allocate_2d_tensor(L, D),
        remote_v_buffer: allocate_2d_tensor(L, D),
        attn_output: allocate_3d_tensor(H, L, D),
        row_max_accum: allocate_3d_tensor(H, L, 1),
        row_sum_accum: allocate_3d_tensor(H, L, 1),
        current_ring_step: 0,
        total_time_ms: 0.0,
        comm_time_ms: 0.0,
        compute_time_ms: 0.0,
    }
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float guess = x * 0.5
    int iter = 0
    while iter < 20 {
        float ng = (guess + x / guess) * 0.5
        if ng == guess { break }
        guess = ng
        iter = iter + 1
    }
    return guess
}

func float_of_int(int n) float {
    float result = 0.0
    int i = 0
    while i < n {
        result = result + 1.0
        i = i + 1
    }
    return result
}

func max_float(float a, float b) float {
    if a > b { return a }
    return b
}

func min_int(int a, int b) int {
    if a < b { return a }
    return b
}

func mod_ring(int val, int div) int {
    if div <= 0 { return 0 }
    int r = val
    while r >= div { r = r - div }
    while r < 0 { r = r + div }
    return r
}

func exp_stable(float x) float {
    if x > 88.0 { return 2.41549527e38 }
    if x < -88.0 { return 0.0 }
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    float x6 = x5 * x
    1.0 + x + x2/2.0 + x3/6.0 + x4/24.0 + x5/120.0 + x6/720.0
}

func zeros(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out = append(out, 0.0)
        i = i + 1
    }
    out
}

func fill(int n, float val) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out = append(out, val)
        i = i + 1
    }
    out
}

func allocate_2d_tensor(int rows, int cols) [][]float {
    [][]float t = [][]float{cap: rows}
    int i = 0
    while i < rows {
        t[i] = fill(cols, 0.0)
        i = i + 1
    }
    return t
}

func allocate_3d_tensor(int d1, int d2, int d3) [][][]float {
    [][][]float t = [][][]float{cap: d1}
    int i = 0
    while i < d1 {
        t[i] = allocate_2d_tensor(d2, d3)
        i = i + 1
    }
    return t
}

func ring_attention_forward(
    ref ring_attn_state state,
    [][][]float q_input,
    [][][]float k_input,
    [][][]float v_input
) [][][]float {
    int P = state.config.sp_degree
    int rank = state.config.sp_rank
    int L = state.config.local_seq_len
    int H = state.config.local_num_heads
    int Hkv = state.config.kv_heads
    int D = state.config.head_dim
    state.local_q = q_input
    state.local_k = k_input
    state.local_v = v_input
    int h = 0
    while h < H {
        int s = 0
        while s < L {
            int d = 0
            while d < D {
                state.attn_output[h][s][d] = 0.0
                d = d + 1
            }
            state.row_max_accum[h][s][0] = -1e9
            state.row_sum_accum[h][s][0] = 0.0
            s = s + 1
        }
        h = h + 1
    }
    int step = 0
    while step < P {
        int source_rank = mod_ring(rank - step, P)
        [][]float current_k
        [][]float current_v
        if source_rank == rank {
            current_k = k_input[0]
            current_v = v_input[0]
        } else {
            current_k = state.remote_k_buffer
            current_v = state.remote_v_buffer
        }
        h = 0
        while h < H {
            int kv_h = h
            if Hkv > 0 && Hkv < H {
                kv_h = h / (H / Hkv)
            }
            [][]float q_h = q_input[h]
            [][]float k_h
            [][]float v_h
            if source_rank == rank {
                k_h = k_input[kv_h]
                v_h = v_input[kv_h]
            } else {
                k_h = current_k
                v_h = current_v
            }
            ring_attn_update_step(
                state,
                q_h, k_h, v_h,
                h, L, D,
                source_rank, step
            )
            h = h + 1
        }
        if step < P - 1 {
            prepare_next_ring_comm(state, source_rank)
        }
        state.current_ring_step = step + 1
        step = step + 1
    }
    h = 0
    while h < H {
        int s = 0
        while s < L {
            float inv_sum = 1.0
            if state.row_sum_accum[h][s][0] > 1e-10 {
                inv_sum = 1.0 / state.row_sum_accum[h][s][0]
            }
            int d = 0
            while d < D {
                state.attn_output[h][s][d] = state.attn_output[h][s][d] * inv_sum
                d = d + 1
            }
            s = s + 1
        }
        h = h + 1
    }
    return state.attn_output
}

func ring_attn_update_step(
    ref ring_attn_state state,
    [][]float q_local,
    [][]float kv_block,
    [][]float v_block,
    int head_idx,
    int L,
    int D,
    int source_rank,
    int step
) {
    float scale = state.config.softmax_scale
    bool causal = state.config.causal_mask
    int P = state.config.sp_degree
    int rank = state.config.sp_rank
    int kv_L = len(kv_block)
    if kv_L == 0 { kv_L = L }
    int global_offset = (source_rank - rank) * L
    if global_offset < 0 { global_offset = 0 }
    int qi = 0
    while qi < L {
        float old_max = state.row_max_accum[head_idx][qi][0]
        float old_sum = state.row_max_accum[head_idx][qi][0]
        []float scores = fill(kv_L, 0.0)
        int kj = 0
        while kj < kv_L && kj < L {
            float dot = 0.0
            int d = 0
            while d < D {
                dot = dot + q_local[qi][d] * kv_block[kj][d]
                d = d + 1
            }
            scores[kj] = dot * scale
            kj = kj + 1
        }
        if causal {
            int qi_global = rank * L + qi
            kj = 0
            while kj < kv_L && kj < L {
                int kj_global = source_rank * L + kj
                if kj_global > qi_global {
                    scores[kj] = -1e9
                }
                kj = kj + 1
            }
        }
        float new_max = old_max
        kj = 0
        while kj < kv_L && kj < L {
            if scores[kj] > new_max {
                new_max = scores[kj]
            }
            kj = kj + 1
        }
        float rescale = exp_stable(old_max - new_max)
        state.row_sum_accum[head_idx][qi][0] = state.row_sum_accum[head_idx][qi][0] * rescale
        int d = 0
        while d < D {
            state.attn_output[head_idx][qi][d] = state.attn_output[head_idx][qi][d] * rescale
            d = d + 1
        }
        float row_lsum = 0.0
        kj = 0
        while kj < kv_L && kj < L {
            float p = exp_stable(scores[kj] - new_max)
            row_lsum = row_lsum + p
            d = 0
            while d < D {
                state.attn_output[head_idx][qi][d] = state.attn_output[head_idx][qi][d] +
                                                       p * v_block[kj][d]
                d = d + 1
            }
            kj = kj + 1
        }
        state.row_max_accum[head_idx][qi][0] = new_max
        state.row_sum_accum[head_idx][qi][0] = state.row_sum_accum[head_idx][qi][0] + row_lsum
        qi = qi + 1
    }
}

func prepare_next_ring_comm(ref ring_attn_state state, int current_source_rank) {
    int P = state.config.sp_degree
    int rank = state.config.sp_rank
    int target_rank = mod_ring(rank + 1, P)
    int send_source = mod_ring(rank - state.current_ring_step, P)
    if send_source == rank {
        int L = state.config.local_seq_len
        int D = state.config.head_dim
        int s = 0
        while s < L {
            int d = 0
            while d < D {
                state.remote_k_buffer[s][d] = state.local_k[0][s][d]
                state.remote_v_buffer[s][d] = state.local_v[0][s][d]
                d = d + 1
            }
            s = s + 1
        }
    }
}

struct ring_attn_grad_result {
    [][][]float dq
    [][][]float dk
    [][][]float dv
}

func ring_attention_backward(
    ring_attn_state fwd_state,
    [][][]float dout
) ring_attn_grad_result {
    int L = fwd_state.config.local_seq_len
    int H = fwd_state.config.local_num_heads
    int D = fwd_state.config.head_dim
    int P = fwd_state.config.sp_degree
    [][][]float dq = allocate_3d_tensor(H, L, D)
    [][][]float dk = allocate_3d_tensor(H, L, D)
    [][][]float dv = allocate_3d_tensor(H, L, D)
    ring_attn_grad_result {
        dq: dq,
        dk: dk,
        dv: dv,
    }
}

struct sequence_parallel_config {
    int sp_degree
    int sp_rank
    int seq_len
    int hidden_dim
    bool use_ring_reduce
}

func sp_layernorm_forward(
    sequence_parallel_config sp_cfg,
    [][]float local_hidden
) [][]float {
    int L = sp_cfg.seq_len / sp_cfg.sp_degree
    int H = sp_cfg.hidden_dim
    if !sp_cfg.use_ring_reduce {
        [][]float gathered = simulate_allgather(sp_cfg, local_hidden, L, H)
        int total_L = len(gathered)
        [][]float normalized = layernorm_full_sequence(gathered, total_L, H)
        [][]float local_result = extract_local_portion(normalized, sp_cfg.sp_rank, L, H)
        return local_result
    } else {
        return sp_layernorm_ring_reduce(sp_cfg, local_hidden)
    }
}

func simulate_allgather(sequence_parallel_config sp_cfg, [][]float input, int L, int H) [][]float {
    int P = sp_cfg.sp_degree
    int total_L = L * P
    [][]float gathered = allocate_2d_tensor(total_L, H)
    int rank = sp_cfg.sp_rank
    int r = 0
    while r < P {
        int offset = r * L
        int s = 0
        while s < L {
            int d = 0
            while d < H {
                if r == rank {
                    gathered[offset + s][d] = input[s][d]
                } else {
                    gathered[offset + s][d] = 0.0
                }
                d = d + 1
            }
            s = s + 1
        }
        r = r + 1
    }
    return gathered
}

func layernorm_full_sequence([][]float x, int seq_len, int dim) [][]float {
    float eps = 1e-6
    [][]float out = allocate_2d_tensor(seq_len, dim)
    int s = 0
    while s < seq_len {
        float mean = 0.0
        int d = 0
        while d < dim {
            mean = mean + x[s][d]
            d = d + 1
        }
        mean = mean / float_of_int(dim)
        float var = 0.0
        d = 0
        while d < dim {
            float diff = x[s][d] - mean
            var = var + diff * diff
            d = d + 1
        }
        var = var / float_of_int(dim)
        float inv_std = 1.0 / sqrt_approx(var + eps)
        d = 0
        while d < dim {
            out[s][d] = (x[s][d] - mean) * inv_std
            d = d + 1
        }
        s = s + 1
    }
    return out
}

func extract_local_portion([][]float full, int rank, int L, int H) [][]float {
    int offset = rank * L
    [][]float local = allocate_2d_tensor(L, H)
    int s = 0
    while s < L {
        int d = 0
        while d < H {
            local[s][d] = full[offset + s][d]
            d = d + 1
        }
        s = s + 1
    }
    return local
}

func sp_layernorm_ring_reduce(
    sequence_parallel_config sp_cfg,
    [][]float local_hidden
) [][]float {
    int L = sp_cfg.seq_len / sp_cfg.sp_degree
    int H = sp_cfg.hidden_dim
    int P = sp_cfg.sp_degree
    []float local_sum = fill(H, 0.0)
    []float local_sq_sum = fill(H, 0.0)
    int s = 0
    while s < L {
        int d = 0
        while d < H {
            local_sum[d] = local_sum[d] + local_hidden[s][d]
            local_sq_sum[d] = local_sq_sum[d] + local_hidden[s][d] * local_hidden[s][d]
            d = d + 1
        }
        s = s + 1
    }
    []float global_sum = ring_allreduce_sum(local_sum, sp_cfg)
    []float global_sq_sum = ring_allreduce_sum(local_sq_sum, sp_cfg)
    int total_seq_len = L * P
    [][]float out = allocate_2d_tensor(L, H)
    float eps = 1e-6
    int d = 0
    while d < H {
        float global_mean = global_sum[d] / float_of_int(total_seq_len)
        float global_var = global_sq_sum[d] / float_of_int(total_seq_len) - global_mean * global_mean
        float inv_std = 1.0 / sqrt_approx(global_var + eps)
        s = 0
        while s < L {
            out[s][d] = (local_hidden[s][d] - global_mean) * inv_std
            s = s + 1
        }
        d = d + 1
    }
    return out
}

func ring_allreduce_sum([]float input, sequence_parallel_config sp_cfg) []float {
    int P = sp_cfg.sp_degree
    int N = len(input)
    []float result = fill(N, 0.0)
    int i = 0
    while i < N {
        result[i] = input[i] * float_of_int(P)
        i = i + 1
    }
    return result
}

struct ring_attn_stats {
    float gflops
    float bandwidth_gb_s
    float memory_per_gpu_gb
    float speedup_vs_standard
    int supported_seq_length
}

func estimate_ring_attn_performance(ring_attn_config cfg) ring_attn_stats {
    int S = cfg.seq_len
    int P = cfg.sp_degree
    int L = S / P
    int H = cfg.num_heads
    int D = cfg.head_dim
    float flops = 2.0 * float_of_int(S * S) * float_of_int(D) * float_of_int(H) / float_of_int(P)
    float mem_bytes = 5.0 * float_of_int(H * L * D) * 4.0
    float mem_gb = mem_bytes / (1024.0 * 1024.0 * 1024.0)
    float comm_bytes = 2.0 * float_of_int(P - 1) * float_of_int(L * D) * 4.0
    float comm_gb = comm_bytes / (1024.0 * 1024.0 * 1024.0)
    float bandwidth = 100.0
    float comm_time_s = comm_gb / bandwidth
    float compute_throughput = 50e12
    float compute_time_s = flops / compute_throughput
    float standard_mem = 5.0 * float_of_int(S * H * D) * 4.0 / (1024^3)
    float speedup = standard_mem / mem_gb
    ring_attn_stats {
        gflops: flops / 1e9,
        bandwidth_gb_s: bandwidth * (comm_gb / (comm_gb + compute_time_s * bandwidth)),
        memory_per_gpu_gb: mem_gb,
        speedup_vs_standard: speedup,
        supported_seq_length: S,
    }
}

func print_ring_attn_summary(ring_attn_config cfg) string {
    ring_attn_stats stats = estimate_ring_attn_performance(cfg)
    "Ring Attention Configuration:\n" +
    "  Sequence Length: " + string(cfg.seq_len) + " (" + string(cfg.seq_len / 1024) + "K)\n" +
    "  SP Degree (GPUs): " + string(cfg.sp_degree) + "\n" +
    "  Local Seq Len: " + string(cfg.local_seq_len) + "\n" +
    "  Heads × Dim: " + string(cfg.num_heads) + " × " + string(cfg.head_dim) + "\n" +
    "  Memory/GPU: " + string(stats.memory_per_gpu_gb) + " GB\n" +
    "  Speedup vs Standard: " + string(stats.speedup_vs_standard) + "x\n" +
    "  Causal Mask: " + string(cfg.causal_mask) + "\n" +
    "  Async Comm: " + string(cfg.use_async_comm)
}
