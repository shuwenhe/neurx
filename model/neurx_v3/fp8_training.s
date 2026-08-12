package neurx.model.neurx.fp8_training
struct fp8_config {
    string forward_dtype
    string backward_dtype
    int tile_size_m
    int tile_size_n
    int block_size
    []string no_quant_modules
    bool compress_gradients
    bool compress_moe_tokens
}

func new_fp8_config() fp8_config {
    []string no_quant = []string{cap: 4}
    no_quant[0] = "embedding"
    no_quant[1] = "attention_softmax"
    no_quant[2] = "norm"
    no_quant[3] = "moe_gate"
    fp8_config {
        forward_dtype: "e4m3",
        backward_dtype: "e5m2",
        tile_size_m: 128,
        tile_size_n: 128,
        block_size: 128,
        no_quant_modules: no_quant,
        compress_gradients: true,
        compress_moe_tokens: true,
    }
}

struct fp8_tensor {
    []int data
    []float scale
    int rows
    int cols
    int tile_m
    int tile_n
}

struct fp8_quant_stats {
    int tiles_quantized
    float max_abs_before
    float max_abs_after
    float avg_scale
    int overflow_count
    int underflow_count
}

func e4m3_max() float { 448.0 }

func e4m3_min_normal() float { 0.015625 }

func e5m2_max() float { 57344.0 }

func e5m2_min_normal() float { 0.00006103515625 }

func float_to_e4m3(float x) int {
    if x == 0.0 { return 0 }
    if x < 0.0 { return float_to_e4m3(-x) | 0x80 }
    if x > 448.0 { return 0x_7_e }
    if x < 0.001953125 { return 0 }
    int exp = 0
    float val = x
    while val >= 2.0 { val = val / 2.0; exp = exp + 1 }
    while val < 1.0 && exp > -9 { val = val * 2.0; exp = exp - 1 }
    if exp < -9 { return 0 }
    int biased_exp = exp + 7
    if biased_exp > 15 { return 0x_7_e }
    if biased_exp < 0 { return 0 }
    float mantissa = val - 1.0
    int mant_bits = (mantissa * 8.0) as int
    if mant_bits > 7 { mant_bits = 7 }
    (biased_exp << 3) | mant_bits
}

func float_to_e5m2(float x) int {
    if x == 0.0 { return 0 }
    if x < 0.0 { return float_to_e5m2(-x) | 0x80 }
    if x > 57344.0 { return 0x_7_b }
    if x < 0.0000076 { return 0 }
    int exp = 0
    float val = x
    while val >= 2.0 { val = val / 2.0; exp = exp + 1 }
    while val < 1.0 && exp > -17 { val = val * 2.0; exp = exp - 1 }
    if exp < -17 { return 0 }
    int biased_exp = exp + 15
    if biased_exp > 30 { return 0x_7_b }
    if biased_exp < 0 { return 0 }
    float mantissa = val - 1.0
    int mant_bits = (mantissa * 4.0) as int
    if mant_bits > 3 { mant_bits = 3 }
    (biased_exp << 2) | mant_bits
}

func e4m3_to_float(int fp8) float {
    int sign = (fp8 >> 7) & 1
    int exp = (fp8 >> 3) & 0x_f
    int mant = fp8 & 0x7
    if exp == 0 {
        float val = mant as float / 8.0 * 0.015625
        if sign == 1 { return -val }
        return val
    }
    if exp == 15 {
        if sign == 1 { return -448.0 }
        return 448.0
    }
    float val = (1.0 + mant as float / 8.0) * pow2(exp - 7)
    if sign == 1 { val = -val }
    val
}

func e5m2_to_float(int fp8) float {
    int sign = (fp8 >> 7) & 1
    int exp = (fp8 >> 2) & 0x_1_f
    int mant = fp8 & 0x3
    if exp == 0 {
        float val = mant as float / 4.0 * 0.00006103515625
        if sign == 1 { return -val }
        return val
    }
    if exp == 31 {
        if sign == 1 { return -57344.0 }
        return 57344.0
    }
    float val = (1.0 + mant as float / 4.0) * pow2(exp - 15)
    if sign == 1 { val = -val }
    val
}

func pow2(int n) float {
    float result = 1.0
    if n >= 0 {
        int i = 0
        while i < n { result = result * 2.0; i = i + 1 }
    } else {
        int i = 0
        while i < -n { result = result / 2.0; i = i + 1 }
    }
    result
}

func tile_abs_max([]float data, int start, int length) float {
    float max_val = 0.0
    int i = start
    int end = start + length
    while i < end {
        float abs_val = data[i]
        if abs_val < 0.0 { abs_val = -abs_val }
        if abs_val > max_val { max_val = abs_val }
        i = i + 1
    }
    max_val
}

func quantize_matrix_blockwise(
    []float data, int M, int N,
    int tile_m, int tile_n, bool is_e5m2
) (fp8_tensor, fp8_quant_stats) {
    int tiles_m = (M + tile_m - 1) / tile_m
    int tiles_n = (N + tile_n - 1) / tile_n
    int total_tiles = tiles_m * tiles_n
    []int fp8_data = []int{cap: M * N}
    []float scales = []float{cap: total_tiles}
    float global_max = 0.0
    int overflow_count = 0
    int underflow_count = 0
    float sum_scale = 0.0
    float dtype_max = 448.0
    float dtype_min = 0.015625
    if is_e5m2 {
        dtype_max = 57344.0
        dtype_min = 0.00006103515625
    }
    int ti = 0
    while ti < tiles_m {
        int m_start = ti * tile_m
        int m_end = m_start + tile_m
        if m_end > M { m_end = M }
        int tj = 0
        while tj < tiles_n {
            int n_start = tj * tile_n
            int n_end = n_start + tile_n
            if n_end > N { n_end = N }
            int tile_elems = (m_end - m_start) * (n_end - n_start)
            []float tile_data = []float{cap: tile_elems}
            int idx = 0
            int mi = m_start
            while mi < m_end {
                int nj = n_start
                while nj < n_end {
                    tile_data[idx] = data[mi * N + nj]
                    idx = idx + 1
                    nj = nj + 1
                }
                mi = mi + 1
            }
            float tile_max = tile_abs_max(tile_data, 0, tile_elems)
            if tile_max > global_max { global_max = tile_max }
            float scale = tile_max / dtype_max
            if scale < 1e-10 { scale = 1.0 }
            int tile_idx = ti * tiles_n + tj
            scales[tile_idx] = scale
            sum_scale = sum_scale + scale
            float inv_scale = 1.0 / scale
            idx = 0
            mi = m_start
            while mi < m_end {
                int nj = n_start
                while nj < n_end {
                    float val = data[mi * N + nj] * inv_scale
                    if val > dtype_max { overflow_count = overflow_count + 1 }
                    if val < dtype_min && val > -dtype_min { underflow_count = underflow_count + 1 }
                    if is_e5m2 {
                        fp8_data[mi * N + nj] = float_to_e5m2(val)
                    } else {
                        fp8_data[mi * N + nj] = float_to_e4m3(val)
                    }
                    nj = nj + 1
                }
                mi = mi + 1
            }
            tj = tj + 1
        }
        ti = ti + 1
    }
    fp8_tensor tensor = fp8_tensor {
        data: fp8_data,
        scale: scales,
        rows: M,
        cols: N,
        tile_m: tile_m,
        tile_n: tile_n,
    }
    fp8_quant_stats stats = fp8_quant_stats {
        tiles_quantized: total_tiles,
        max_abs_before: global_max,
        max_abs_after: dtype_max,
        avg_scale: sum_scale / total_tiles as float,
        overflow_count: overflow_count,
        underflow_count: underflow_count,
    }
    (tensor, stats)
}

func dequantize_matrix_blockwise(fp8_tensor t, bool is_e5m2) []float {
    int M = t.rows
    int N = t.cols
    int tiles_m = (M + t.tile_m - 1) / t.tile_m
    int tiles_n = (N + t.tile_n - 1) / t.tile_n
    []float result = []float{cap: M * N}
    int ti = 0
    while ti < tiles_m {
        int m_start = ti * t.tile_m
        int m_end = m_start + t.tile_m
        if m_end > M { m_end = M }
        int tj = 0
        while tj < tiles_n {
            int n_start = tj * t.tile_n
            int n_end = n_start + t.tile_n
            if n_end > N { n_end = N }
            float scale = t.scale[ti * tiles_n + tj]
            int mi = m_start
            while mi < m_end {
                int nj = n_start
                while nj < n_end {
                    float val = 0.0
                    if is_e5m2 {
                        val = e5m2_to_float(t.data[mi * N + nj])
                    } else {
                        val = e4m3_to_float(t.data[mi * N + nj])
                    }
                    result[mi * N + nj] = val * scale
                    nj = nj + 1
                }
                mi = mi + 1
            }
            tj = tj + 1
        }
        ti = ti + 1
    }
    result
}

func fp8_gemm(
    fp8_tensor a, fp8_tensor b, int M, int K, int N,
    bool is_e5m2
) []float {
    []float c = []float{cap: M * N}
    int idx = 0
    while idx < M * N { c[idx] = 0.0; idx = idx + 1 }
    int tiles_m = (M + a.tile_m - 1) / a.tile_m
    int tiles_n = (N + b.tile_n - 1) / b.tile_n
    int tiles_k = (K + a.tile_n - 1) / a.tile_n
    int ti = 0
    while ti < tiles_m {
        int tj = 0
        while tj < tiles_n {
            int tk = 0
            while tk < tiles_k {
                float scale_a = a.scale[ti * tiles_k + tk]
                float scale_b = b.scale[tk * tiles_n + tj]
                float combined_scale = scale_a * scale_b
                int m_start = ti * a.tile_m
                int m_end = m_start + a.tile_m
                if m_end > M { m_end = M }
                int k_start = tk * a.tile_n
                int k_end = k_start + a.tile_n
                if k_end > K { k_end = K }
                int mi = m_start
                while mi < m_end {
                    int nj = tj * b.tile_n
                    int nj_end = nj + b.tile_n
                    if nj_end > N { nj_end = N }
                    while nj < nj_end {
                        float dot = 0.0
                        int ki = k_start
                        while ki < k_end {
                            float a_val = 0.0
                            float b_val = 0.0
                            if is_e5m2 {
                                a_val = e5m2_to_float(a.data[mi * K + ki])
                                b_val = e5m2_to_float(b.data[ki * N + nj])
                            } else {
                                a_val = e4m3_to_float(a.data[mi * K + ki])
                                b_val = e4m3_to_float(b.data[ki * N + nj])
                            }
                            dot = dot + a_val * b_val
                            ki = ki + 1
                        }
                        c[mi * N + nj] = c[mi * N + nj] + dot * combined_scale
                        nj = nj + 1
                    }
                    mi = mi + 1
                }
                tk = tk + 1
            }
            tj = tj + 1
        }
        ti = ti + 1
    }
    c
}

struct fp8_training_state {
    fp8_config config
    int step
    []fp8_quant_stats quant_stats_history
    float grad_scale
    float grad_scale_growth
    float grad_scale_backoff
}

func new_fp8_training_state(fp8_config cfg) fp8_training_state {
    fp8_training_state {
        config: cfg,
        step: 0,
        quant_stats_history: []fp8_quant_stats{cap: 0},
        grad_scale: 1.0,
        grad_scale_growth: 2.0,
        grad_scale_backoff: 0.5,
    }
}

func fp8_linear_forward(
    fp8_training_state state, []float input, []float weight,
    int M, int K, int N
) []float {
    fp8_config cfg = state.config
    bool use_e5m2 = cfg.forward_dtype == "e5m2"
    (fp8_tensor input_fp8, fp8_quant_stats stat_i) = quantize_matrix_blockwise(
        input, M, K, cfg.tile_size_m, cfg.tile_size_n, use_e5m2
    )
    (fp8_tensor weight_fp8, fp8_quant_stats stat_w) = quantize_matrix_blockwise(
        weight, K, N, cfg.tile_size_n, cfg.tile_size_m, use_e5m2
    )
    []float output = fp8_gemm(input_fp8, weight_fp8, M, K, N, use_e5m2)
    output
}

func fp8_gradient_quantize(
    fp8_training_state state, []float grad, int M, int N
) fp8_tensor {
    fp8_config cfg = state.config
    bool use_e5m2 = cfg.backward_dtype == "e5m2"
    (fp8_tensor grad_fp8, fp8_quant_stats stat) = quantize_matrix_blockwise(
        grad, M, N, cfg.tile_size_m, cfg.tile_size_n, use_e5m2
    )
    grad_fp8
}

struct fp8_monitor {
    int step
    float avg_overflow_rate
    float avg_underflow_rate
    float grad_scale_current
    float memory_saved_percent
    float speedup_estimated
}

func fp8_get_monitor(fp8_training_state state, int total_elems) fp8_monitor {
    float avg_overflow = 0.0
    float avg_underflow = 0.0
    int n_stats = len(state.quant_stats_history)
    int i = 0
    while i < n_stats {
        fp8_quant_stats s = state.quant_stats_history[i]
        avg_overflow = avg_overflow + s.overflow_count as float
        avg_underflow = avg_underflow + s.underflow_count as float
        i = i + 1
    }
    if n_stats > 0 {
        avg_overflow = avg_overflow / (n_stats * total_elems) as float
        avg_underflow = avg_underflow / (n_stats * total_elems) as float
    }
    fp8_monitor {
        step: state.step,
        avg_overflow_rate: avg_overflow,
        avg_underflow_rate: avg_underflow,
        grad_scale_current: state.grad_scale,
        memory_saved_percent: 50.0,
        speedup_estimated: 1.8,
    }
}

func should_skip_quantization(string module_name, fp8_config cfg) bool {
    int i = 0
    while i < len(cfg.no_quant_modules) {
        if contains_string(module_name, cfg.no_quant_modules[i]) {
            return true
        }
        i = i + 1
    }
    false
}

func contains_string(string s, string substr) bool {
    int s_len = len(s)
    int sub_len = len(substr)
    if sub_len > s_len { return false }
    int i = 0
    while i <= s_len - sub_len {
        bool match = true
        int j = 0
        while j < sub_len {
            if slice(s, i + j, i + j + 1) != slice(substr, j, j + 1) {
                match = false
                break
            }
            j = j + 1
        }
        if match { return true }
        i = i + 1
    }
    false
}

func unit_name() string {
    "neurx/model/neurx/fp8_training"
}

func unit_ready() int {
    1
}

