package neurx.attention.ring

// ═══════════════════════════════════════════════════════════════════
// Ring Attention — English text
//
// English text:
//   English text Flash Attention RequiredEnglish text Q/K/V English text GPU English text,
//   English text 128K+ English text,English textuse Flash Attention English text.
//
// English text (Ring Attention, English text "Ring Memory with Block Transpose"):
//
//   1. **English text**: English text [S] English text P English text [S/P], English text P English text GPU
//   2. **English text**: English text GPU English text Q_i English text,English text ring English textstepEnglish text K_j/V_j
//   3. **English text**: English text (Q_i, K_j) compute attention score English text
//   4. **P-1 English text**: English text GPU English text K/V,English textcompleteEnglish textresult
//
// English text: O((S/P)² * D) per GPU (vs O(S² * D) for standard)
// English text: O(P-1)English text ring all-gather, English text O((S/P)*D)
//
// English text:
//   • 32K / 64K / 128K+ context window
//   • Long-document understanding
//   • Code generation with large files
//   • Multi-turn conversation with full history
//
// English text:
//   • English text Tensor Parallelism English text (AllowedEnglish text)
//   • English text FSDP English textstepEnglish text
//   • support GQA/MQA English text KV cache English text
// ═══════════════════════════════════════════════════════════════════

use neurx.attention.flash_v2.{
    flash_attn_config, flash_attn_forward_head, flash_attn_backward
}

// ============================================================================
// 1. configurationEnglish textdataEnglish text
// ============================================================================

struct ring_attn_config {
    int sp_degree               // English text (English text ring English text GPU count)
    int sp_rank                 // English text GPU English text ring English text [0, sp_degree)

    int seq_len                 // completeEnglish text S
    int local_seq_len           // English text S / sp_degree

    int num_heads               // English text H
    int local_num_heads         // English text (English text = num_heads,English text TP)
    int head_dim                // English text d
    int kv_heads                // KV English text (GQA English text < num_heads)

    int block_size              // English textcomputeEnglish text (English text 64 English text 128)
    bool causal_mask            // English text (GPT English text)
    float softmax_scale         // 1 / sqrt(head_dim)

    // English textconfiguration
    bool use_async_comm         // English textstepEnglish text (English textcomputeEnglish text)
    int comm_overlap_depth      // English text

    // English textoptimize
    bool gradient_checkpointing // English textgradientcheckpoint
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
        local_seq_len = local_seq_len + 1  // English text
    }

    ring_attn_config {
        sp_degree: sp_degree,
        sp_rank: sp_rank,
        seq_len: seq_len,
        local_seq_len: local_seq_len,
        num_heads: num_heads,
        local_num_heads: num_heads,
        head_dim: head_dim,
        kv_heads: num_heads,  // default MHA
        block_size: 128,
        causal_mask: true,
        softmax_scale: 1.0 / sqrt_approx(float_of_int(head_dim)),
        use_async_comm: true,
        comm_overlap_depth: 2,
        gradient_checkpointing: true,
    }
}

// Ring Attention English textrunEnglish textstate
struct ring_attn_state {
    ring_attn_config config

    // English text Q/K/V data
    [][][]float local_q     // [local_num_heads, local_seq_len, head_dim]
    [][][]float local_k     // [local_kv_heads, local_seq_len, head_dim]
    [][][]float local_v     // [local_kv_heads, local_seq_len, head_dim]

    // English text (English text KV)
    [][]float remote_k_buffer   // [local_seq_len, head_dim] (English text K English text)
    [][]float remote_v_buffer   // [local_seq_len, head_dim] (English text V English text)

    // English textoutputEnglish textstatisticsinformation
    [][][]float attn_output     // [local_num_heads, local_seq_len, head_dim] English textoutput
    [][][]float row_max_accum   // [local_num_heads, local_seq_len] English text
    [][][]float row_sum_accum   // [local_num_heads, local_seq_len] English text

    // statistics
    int current_ring_step       // English text ring English text
    float total_time_ms         // English texttime
    float comm_time_ms          // English texttime
    float compute_time_ms       // computetime
}

// ============================================================================
// 2. initialize
// ============================================================================

func init_ring_attn_state(ring_attn_config cfg) ring_attn_state {
    int L = cfg.local_seq_len
    int H = cfg.local_num_heads
    int D = cfg.head_dim
    int Hkv = cfg.kv_heads

    ring_attn_state {
        config: cfg,

        // English text Q/K/V (actualEnglish text forward English text)
        local_q: allocate_3d_tensor(H, L, D),
        local_k: allocate_3d_tensor(Hkv, L, D),
        local_v: allocate_3d_tensor(Hkv, L, D),

        // English text KV English text
        remote_k_buffer: allocate_2d_tensor(L, D),
        remote_v_buffer: allocate_2d_tensor(L, D),

        // English textinitialize
        attn_output: allocate_3d_tensor(H, L, D),
        row_max_accum: allocate_3d_tensor(H, L, 1),
        row_sum_accum: allocate_3d_tensor(H, L, 1),

        current_ring_step: 0,
        total_time_ms: 0.0,
        comm_time_ms: 0.0,
        compute_time_ms: 0.0,
    }
}

// ============================================================================
// 3. toolfunction
// ============================================================================

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

// English texthelperfunction
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

// ============================================================================
// 4. English text Ring Attention English text
// ============================================================================
//
// English textpipeline (P English text GPU,English text 0 English text P-1):
//
// initialize:
//   - English text GPU i English text Q_i, K_i, V_i (English text i English text QKV)
//   - output_i = 0, max_i = -inf, sum_i = 0
//
// Ring English text (P-1 English text):
//   English text step step (step = 0, ..., P-2):
//     1. English text KV Source: j = (i - step) % P
//     2. English text step == 0: useEnglish text K_i, V_i
//        English text: English text K_j, V_j (ring English text)
//     3. compute local attention: Q_i @ K_j^T → scores
//     4. English text causal mask (English textRequired)
//     5. Online softmax English text:
//        new_max = max(old_max, row_max(scores))
//        correction = exp(old_max - new_max)
//        output = output * correction + softmax(scores - new_max) @ V_j
//        max_i = new_max
//        sum_i = sum_i * correction + row_sum(softmax(scores - new_max))
//     6. English text K_j, V_j English text (English textstep,English textcomputeEnglish text)
//
// English text:
//   - English text: output_i = output_i / sum_i
//   - English textcompleteEnglish textresult

func ring_attention_forward(
    ref ring_attn_state state,
    [][][]float q_input,    // [num_heads, local_seq_len, head_dim]
    [][][]float k_input,    // [kv_heads, local_seq_len, head_dim]
    [][][]float v_input     // [kv_heads, local_seq_len, head_dim]
) [][][]float {
    int P = state.config.sp_degree
    int rank = state.config.sp_rank
    int L = state.config.local_seq_len
    int H = state.config.local_num_heads
    int Hkv = state.config.kv_heads
    int D = state.config.head_dim

    // saveinputEnglish text state
    state.local_q = q_input
    state.local_k = k_input
    state.local_v = v_input

    // initializeEnglish text
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

    // ===== Ring English text =====
    int step = 0
    while step < P {
        // English textuseEnglish text KV Source rank
        int source_rank = mod_ring(rank - step, P)

        // English text KV English text
        [][]float current_k
        [][]float current_v

        if source_rank == rank {
            // useEnglish text KV
            current_k = k_input[0]  // English text kv_heads=1 for simplicity in indexing
            current_v = v_input[0]
        } else {
            // English text (English text)
            current_k = state.remote_k_buffer
            current_v = state.remote_v_buffer
        }

        // English textcomputeEnglish text
        h = 0
        while h < H {
            // GQA: English text KV English text
            int kv_h = h
            if Hkv > 0 && Hkv < H {
                kv_h = h / (H / Hkv)
            }

            // English text Q English text K,V
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

            // English textstep online softmax attention update
            ring_attn_update_step(
                state,
                q_h, k_h, v_h,
                h, L, D,
                source_rank, step
            )

            h = h + 1
        }

        // English text (English textstepEnglish text KV English text)
        if step < P - 1 {
            prepare_next_ring_comm(state, source_rank)
        }

        state.current_ring_step = step + 1
        step = step + 1
    }

    // ===== English text =====
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

// English textstepEnglish text softmax attention English text
func ring_attn_update_step(
    ref ring_attn_state state,
    [][]float q_local,      // [local_seq_len, head_dim]
    [][]float kv_block,     // [block_seq_len, head_dim] (K or V)
    [][]float v_block,      // [block_seq_len, head_dim] (V)
    int head_idx,
    int L,                  // local_seq_len
    int D,                  // head_dim
    int source_rank,
    int step
) {
    float scale = state.config.softmax_scale
    bool causal = state.config.causal_mask
    int P = state.config.sp_degree
    int rank = state.config.sp_rank

    int kv_L = len(kv_block)
    if kv_L == 0 { kv_L = L }  // fallback

    // computeEnglish text (English text causal mask)
    // English text position = rank * L + local_pos
    // source global position = source_rank * L + source_pos
    int global_offset = (source_rank - rank) * L
    if global_offset < 0 { global_offset = 0 }

    // English text query position
    int qi = 0
    while qi < L {
        float old_max = state.row_max_accum[head_idx][qi][0]
        float old_sum = state.row_max_accum[head_idx][qi][0]  // reuse slot for sum

        // compute Q[i] @ K^T English text scores
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

        // Causal mask: English text source English text mask
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

        // English text
        float new_max = old_max
        kj = 0
        while kj < kv_L && kj < L {
            if scores[kj] > new_max {
                new_max = scores[kj]
            }
            kj = kj + 1
        }

        // English textresult
        float rescale = exp_stable(old_max - new_max)
        state.row_sum_accum[head_idx][qi][0] = state.row_sum_accum[head_idx][qi][0] * rescale
        int d = 0
        while d < D {
            state.attn_output[head_idx][qi][d] = state.attn_output[head_idx][qi][d] * rescale
            d = d + 1
        }

        // English text
        float row_lsum = 0.0
        kj = 0
        while kj < kv_L && kj < L {
            float p = exp_stable(scores[kj] - new_max)
            row_lsum = row_lsum + p

            // English text V
            d = 0
            while d < D {
                state.attn_output[head_idx][qi][d] = state.attn_output[head_idx][qi][d] +
                                                       p * v_block[kj][d]
                d = d + 1
            }
            kj = kj + 1
        }

        // English text
        state.row_max_accum[head_idx][qi][0] = new_max
        state.row_sum_accum[head_idx][qi][0] = state.row_sum_accum[head_idx][qi][0] + row_lsum

        qi = qi + 1
    }
}

// English text ring English text (English text)
func prepare_next_ring_comm(ref ring_attn_state state, int current_source_rank) {
    int P = state.config.sp_degree
    int rank = state.config.sp_rank

    // English textdata
    int target_rank = mod_ring(rank + 1, P)
    int send_source = mod_ring(rank - state.current_ring_step, P)

    // English textactualimplementationEnglish text,English text NCCL Send/Recv
    // English text:English text KV English text buffer (English text)

    if send_source == rank {
        // English text KV
        int L = state.config.local_seq_len
        int D = state.config.head_dim
        int s = 0
        while s < L {
            int d = 0
            while d < D {
                // English text:actualEnglish text neighbor English text
                state.remote_k_buffer[s][d] = state.local_k[0][s][d]  // simplified
                state.remote_v_buffer[s][d] = state.local_v[0][s][d]
                d = d + 1
            }
            s = s + 1
        }
    }
}

// ============================================================================
// 5. English text (Ring Attention Backward)
// ============================================================================
//
// English text,English textRequired ring English textgradient:
//   - dQ RequiredEnglish text K, V, English text
//   - dK, dV Required Q, English text
//
// English text:
//   - English textcomputeEnglish text: English textsaveEnglish textresult,English text attention
//   - English textsaveEnglish textresult (LSE English text)

struct ring_attn_grad_result {
    [][][]float dq   // [num_heads, local_seq_len, head_dim]
    [][][]float dk   // [kv_heads, total_seq_len, head_dim] (English text?)
    [][][]float dv   // [kv_heads, total_seq_len, head_dim]
}

// Ring Attention English text (English text:English textcache)
func ring_attention_backward(
    ring_attn_state fwd_state,
    [][][]float dout    // [num_heads, local_seq_len, head_dim] outputgradient
) ring_attn_grad_result {
    int L = fwd_state.config.local_seq_len
    int H = fwd_state.config.local_num_heads
    int D = fwd_state.config.head_dim
    int P = fwd_state.config.sp_degree

    // English textgradient
    [][][]float dq = allocate_3d_tensor(H, L, D)
    [][][]float dk = allocate_3d_tensor(H, L, D)  // English text:English text
    [][][]float dv = allocate_3d_tensor(H, L, D)

    // English text ring English text,English textcomputegradient
    // ... (completeimplementationEnglish text)

    // placeholder:English textgradient (Requiredcompleteimplementation)
    ring_attn_grad_result {
        dq: dq,
        dk: dk,
        dv: dv,
    }
}

// ============================================================================
// 6. Sequence Parallelism (English textsupport)
// ============================================================================
//
// English text,English text (FFN, LayerNorm English text) English textRequiredEnglish text:
//
// English text:
//   1. All-Gather: English textcompleteEnglish text,English textcompute,English text scatter English text
//      - English text:English text,English text
//      - English text:English text (O(S*H) per layer)
//
//   2. Ring-based Reduce: English text Ring Attention,English text reduce
//      - English text:English text,English text
//      - English text:RequiredEnglish textimplementation
//
//   3. English text batch English text (All-to-All):
//      - English text [S/P, H] English text [S/P * P, H] = [S, H],English text GPU
//      - English text FFN English text token English text

struct sequence_parallel_config {
    int sp_degree
    int sp_rank
    int seq_len
    int hidden_dim
    bool use_ring_reduce      // true: ring reduce; false: all-gather
}

// Sequence Parallel: LayerNorm (RequiredEnglish textcompleteEnglish textcompute mean/variance)
func sp_layernorm_forward(
    sequence_parallel_config sp_cfg,
    [][]float local_hidden    // [local_seq_len, hidden_dim],
) [][]float {
    int L = sp_cfg.seq_len / sp_cfg.sp_degree
    int H = sp_cfg.hidden_dim

    if !sp_cfg.use_ring_reduce {
        // English text 1: All-Gather → LN → Scatter
        // 1. All-Gather English textcompleteEnglish text
        [][]float gathered = simulate_allgather(sp_cfg, local_hidden, L, H)
        int total_L = len(gathered)

        // 2. English textcompleteEnglish textcompute LayerNorm
        [][]float normalized = layernorm_full_sequence(gathered, total_L, H)

        // 3. English text
        [][]float local_result = extract_local_portion(normalized, sp_cfg.sp_rank, L, H)
        return local_result
    } else {
        // English text 2: Ring Reduce (English textstepcompute mean/variance)
        return sp_layernorm_ring_reduce(sp_cfg, local_hidden)
    }
}

// English text All-Gather (actualEnglish text NCCL)
func simulate_allgather(sequence_parallel_config sp_cfg, [][]float input, int L, int H) [][]float {
    int P = sp_cfg.sp_degree
    int total_L = L * P

    // English text rank English textdata
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
                    // actualEnglish text rank r English text
                    gathered[offset + s][d] = 0.0  // placeholder
                }
                d = d + 1
            }
            s = s + 1
        }
        r = r + 1
    }

    return gathered
}

// completeEnglish text LayerNorm
func layernorm_full_sequence([][]float x, int seq_len, int dim) [][]float {
    float eps = 1e-6

    [][]float out = allocate_2d_tensor(seq_len, dim)

    int s = 0
    while s < seq_len {
        // computeEnglish text
        float mean = 0.0
        int d = 0
        while d < dim {
            mean = mean + x[s][d]
            d = d + 1
        }
        mean = mean / float_of_int(dim)

        // computeEnglish text
        float var = 0.0
        d = 0
        while d < dim {
            float diff = x[s][d] - mean
            var = var + diff * diff
            d = d + 1
        }
        var = var / float_of_int(dim)

        // English text
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

// English text
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

// Ring Reduce English text LayerNorm
func sp_layernorm_ring_reduce(
    sequence_parallel_config sp_cfg,
    [][]float local_hidden
) [][]float {
    int L = sp_cfg.seq_len / sp_cfg.sp_degree
    int H = sp_cfg.hidden_dim
    int P = sp_cfg.sp_degree

    // Phase 1: English textstatisticsEnglish text
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

    // Phase 2: Ring AllReduce English text (English text)
    []float global_sum = ring_allreduce_sum(local_sum, sp_cfg)
    []float global_sq_sum = ring_allreduce_sum(local_sq_sum, sp_cfg)

    int total_seq_len = L * P

    // Phase 3: English textstatisticsEnglish text normalization
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

// Ring AllReduce Sum (English text)
func ring_allreduce_sum([]float input, sequence_parallel_config sp_cfg) []float {
    int P = sp_cfg.sp_degree
    int N = len(input)

    // English text:English text input * P (English text rank English text)
    []float result = fill(N, 0.0)
    int i = 0
    while i < N {
        result[i] = input[i] * float_of_int(P)  // English text rank English text
        i = i + 1
    }

    return result
}

// ============================================================================
// 7. English text & statistics
// ============================================================================

struct ring_attn_stats {
    float gflops                   // computeEnglish text
    float bandwidth_gb_s           // English text
    float memory_per_gpu_gb        // English text GPU English text
    float speedup_vs_standard       // English text
    int supported_seq_length       // supportEnglish text
}

// English text Ring Attention English text
func estimate_ring_attn_performance(ring_attn_config cfg) ring_attn_stats {
    int S = cfg.seq_len
    int P = cfg.sp_degree
    int L = S / P
    int H = cfg.num_heads
    int D = cfg.head_dim

    // FLOPs English text (English text)
    // English textstep: 2 * L * D (matmul) * L (sequence) = 2 * L^2 * D
    // P stepEnglish text: 2 * L^2 * D * P = 2 * (S/P)^2 * D * P = 2 * S^2 * D / P
    float flops = 2.0 * float_of_int(S * S) * float_of_int(D) * float_of_int(H) / float_of_int(P)

    // English text
    // Q/K/V: 3 * H * L * D * sizeof(float)
    // Output + accumulators: ~2 * H * L * D
    // Total: ~5 * H * L * D bytes per GPU
    float mem_bytes = 5.0 * float_of_int(H * L * D) * 4.0  // float32
    float mem_gb = mem_bytes / (1024.0 * 1024.0 * 1024.0)

    // English text
    // English text ring: send/receive K/V block = 2 * L * D * sizeof(float)
    // P-1 English text: 2 * (P-1) * L * D bytes
    float comm_bytes = 2.0 * float_of_int(P - 1) * float_of_int(L * D) * 4.0
    float comm_gb = comm_bytes / (1024.0 * 1024.0 * 1024.0)

    // English text 100 GB/s (NVLink)
    float bandwidth = 100.0  // GB/s
    float comm_time_s = comm_gb / bandwidth

    // English textcomputeEnglish text 50 TFLOPS
    float compute_throughput = 50e12  // FLOPS
    float compute_time_s = flops / compute_throughput

    // English text vs English text (O(S^2) memory)
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

// English textconfigurationsummary
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
