package neurx.backends.compute_backend
struct device_info {
    string backend
    int device_id
    bool has_tensor_cores
    bool supports_bf16
    bool supports_fp16
    bool supports_fp8
    int memory_gb
    float peak_tflops
}

struct compute_context {
    device_info device
    bool gpu_available
    string active_dtype
    int stream_id
}
func detect_device() compute_context {
    compute_context {
        device: device_info {
            backend: "cpu",
            device_id: 0,
            has_tensor_cores: false,
            supports_bf16: true,
            supports_fp16: true,
            supports_fp8: false,
            memory_gb: 0,
            peak_tflops: 0.0,
        },
        gpu_available: false,
        active_dtype: "fp32",
        stream_id: 0,
    }
}

func new_compute_context(string backend, int device_id, string dtype) compute_context {
    bool is_gpu = backend == "cuda" || backend == "cann" || backend == "mps"
    string active_dtype = dtype
    if active_dtype == "" {
        active_dtype = "fp32"
    }
    compute_context {
        device: device_info {
            backend: backend,
            device_id: device_id,
            has_tensor_cores: backend == "cuda",
            supports_bf16: is_gpu,
            supports_fp16: is_gpu,
            supports_fp8: backend == "cuda",
            memory_gb: 0,
            peak_tflops: 0.0,
        },
        gpu_available: is_gpu,
        active_dtype: active_dtype,
        stream_id: 0,
    }
}

func backend_supports_dtype(device_info device, string dtype) bool {
    if dtype == "bf16" {
        return device.supports_bf16
    }
    if dtype == "fp16" {
        return device.supports_fp16
    }
    if dtype == "fp8" {
        return device.supports_fp8
    }
    if dtype == "" || dtype == "fp32" {
        return true
    }
    false
}

func resolve_compute_context(string preferred_backend, string preferred_dtype) compute_context {
    compute_context ctx = detect_device()
    if preferred_backend != "" {
        ctx = new_compute_context(preferred_backend, 0, preferred_dtype)
    } else {
        ctx.active_dtype = preferred_dtype
        if ctx.active_dtype == "" {
            ctx.active_dtype = "fp32"
        }
    }
    if !backend_supports_dtype(ctx.device, ctx.active_dtype) {
        ctx.active_dtype = "fp32"
    }
    ctx
}

func cb_abs(float x) float {
    if x < 0.0 { return -x }
    x
}

func quantize_mantissa(float value, int mantissa_bits) float {
    if value == 0.0 {
        return 0.0
    }
    bool neg = value < 0.0
    float mag = cb_abs(value)
    int exp = 0
    while mag >= 2.0 {
        mag = mag * 0.5
        exp = exp + 1
    }
    while mag < 1.0 {
        mag = mag * 2.0
        exp = exp - 1
    }
    float frac = mag - 1.0
    float levels = cb_pow2(mantissa_bits)
    float scaled = frac * levels
    int rounded = cb_round(scaled)
    if rounded >= cb_round(levels) {
        rounded = 0
        exp = exp + 1
    }
    float q_frac = (rounded * 1.0) / levels
    float q_mag = (1.0 + q_frac) * cb_pow2_signed(exp)
    if neg {
        return -q_mag
    }
    q_mag
}

func cb_pow2(int bits) float {
    float r = 1.0
    int i = 0
    while i < bits {
        r = r * 2.0
        i = i + 1
    }
    r
}

func cb_pow2_signed(int exp) float {
    float r = 1.0
    int e = exp
    if e >= 0 {
        while e > 0 { r = r * 2.0; e = e - 1 }
    } else {
        while e < 0 { r = r * 0.5; e = e + 1 }
    }
    r
}

func cb_round(float x) int {
    bool neg = x < 0.0
    float v = x
    if neg { v = -v }
    float y = v + 0.5
    int n = 0
    while y >= 1.0 { y = y - 1.0; n = n + 1 }
    if neg { return -n }
    n
}

func to_bf16(float value) float {
    quantize_mantissa(value, 7)
}

func to_fp16(float value) float {
    quantize_mantissa(value, 10)
}

func to_fp8_e4m3(float value) float {
    quantize_mantissa(value, 3)
}

func array_to_bf16([]float arr) []float {
    int n = len(arr)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = to_bf16(arr[i])
        i = i + 1
    }
    out
}

func array_to_fp16([]float arr) []float {
    int n = len(arr)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = to_fp16(arr[i])
        i = i + 1
    }
    out
}

func backend_matmul(
    compute_context ctx,
    []float a, []float b,
    int m, int k, int n
) []float {
    if ctx.gpu_available {
        if ctx.device.backend == "cann" {
            []float out = []float{cap: m * n}
            int idx = 0
            while idx < m * n { out[idx] = 0.0; idx = idx + 1 }
            __neurx_cann_matmul(a, b, out, m, k, n)
            return out
        }
        return cpu_matmul(a, b, m, k, n)
    }
    cpu_matmul(a, b, m, k, n)
}
extern "intrinsic" func __neurx_cann_matmul([]float a, []float b, []float out, int m, int k, int n) ()

func cpu_matmul([]float a, []float b, int m, int k, int n) []float {
    []float result = []float{cap: m * n}
    int idx = 0
    while idx < m * n { result[idx] = 0.0; idx = idx + 1 }
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

func backend_matmul_bf16(
    compute_context ctx,
    []float a, []float b,
    int m, int k, int n
) []float {
    []float a_bf = array_to_bf16(a)
    []float b_bf = array_to_bf16(b)
    return backend_matmul(ctx, a_bf, b_bf, m, k, n)
}

func backend_matmul_dispatch(
    compute_context ctx,
    []float a, []float b,
    int m, int k, int n
) []float {
    if ctx.active_dtype == "bf16" {
        return backend_matmul_bf16(ctx, a, b, m, k, n)
    }
    if ctx.active_dtype == "fp16" {
        []float a_fp16 = array_to_fp16(a)
        []float b_fp16 = array_to_fp16(b)
        return backend_matmul(ctx, a_fp16, b_fp16, m, k, n)
    }
    return backend_matmul(ctx, a, b, m, k, n)
}

struct comm_context {
    int world_size
    int rank
    int comm_id
    string backend
}

func new_comm_context(int world_size, int rank) comm_context {
    comm_context {
        world_size: world_size,
        rank: rank,
        comm_id: 0,
        backend: "local",
    }
}

func backend_all_reduce(
    comm_context comm,
    []float buffer
) []float {
    if comm.backend == "nccl" && comm.world_size > 1 {
        return buffer
    }
    buffer
}

func backend_all_reduce_pair([]float a, []float b) []float {
    int n = len(a)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float bv = 0.0
        if i < len(b) { bv = b[i] }
        out[i] = a[i] + bv
        i = i + 1
    }
    out
}

func backend_broadcast(comm_context comm, []float buffer, int root) []float {
    if comm.backend == "nccl" && comm.world_size > 1 {
        return buffer
    }
    buffer
}

struct amp_state {
    float loss_scale
    float scale_growth
    float scale_backoff
    int growth_interval
    int steps_since_overflow
    bool last_overflow
    string compute_dtype
}

func new_amp_state(string dtype) amp_state {
    float init_scale = 65536.0
    if dtype == "bf16" {
        init_scale = 1.0
    }
    amp_state {
        loss_scale: init_scale,
        scale_growth: 2.0,
        scale_backoff: 0.5,
        growth_interval: 2000,
        steps_since_overflow: 0,
        last_overflow: false,
        compute_dtype: dtype,
    }
}

func amp_scale_loss(amp_state amp, float loss) float {
    loss * amp.loss_scale
}

func amp_unscale_grad(amp_state amp, []float grad) []float {
    float inv = 1.0 / amp.loss_scale
    int n = len(grad)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = grad[i] * inv
        i = i + 1
    }
    out
}

func amp_check_overflow([]float grad) bool {
    int i = 0
    while i < len(grad) {
        float g = grad[i]
        if g > 1e30 || g < -1e30 {
            return true
        }
        if g != g {
            return true
        }
        i = i + 1
    }
    false
}

func amp_update_scale(amp_state amp, bool overflow) amp_state {
    if overflow {
        amp.loss_scale = amp.loss_scale * amp.scale_backoff
        if amp.loss_scale < 1.0 {
            amp.loss_scale = 1.0
        }
        amp.steps_since_overflow = 0
        amp.last_overflow = true
    } else {
        amp.steps_since_overflow = amp.steps_since_overflow + 1
        if amp.steps_since_overflow >= amp.growth_interval {
            amp.loss_scale = amp.loss_scale * amp.scale_growth
            amp.steps_since_overflow = 0
        }
        amp.last_overflow = false
    }
    amp
}

struct memory_estimate {
    int params_bytes
    int gradients_bytes
    int optimizer_bytes
    int activations_bytes
    int total_bytes
    int total_gb
}

func estimate_training_memory(int params, string dtype, int batch_tokens, int hidden, int layers) memory_estimate {
    int param_byte = 4
    if dtype == "bf16" || dtype == "fp16" {
        param_byte = 2
    }
    int params_b = params * param_byte
    int master_b = params * 4
    int grad_b = params * param_byte
    int opt_b = params * 8
    int act_b = batch_tokens * hidden * layers * 2
    int total = params_b + master_b + grad_b + opt_b + act_b
    memory_estimate {
        params_bytes: params_b + master_b,
        gradients_bytes: grad_b,
        optimizer_bytes: opt_b,
        activations_bytes: act_b,
        total_bytes: total,
        total_gb: total / (1024 * 1024 * 1024),
    }
}

func bf16_max_relative_error([]float arr) float {
    float max_err = 0.0
    int i = 0
    while i < len(arr) {
        float orig = arr[i]
        float q = to_bf16(orig)
        float denom = cb_abs(orig)
        if denom < 1e-12 { denom = 1.0 }
        float rel = cb_abs(orig - q) / denom
        if rel > max_err { max_err = rel }
        i = i + 1
    }
    max_err
}
