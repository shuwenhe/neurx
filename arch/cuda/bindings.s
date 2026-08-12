package neurx.cpu.cuda.bindings
struct device_array {
    []float data
    int size
    bool on_device
}

func copy_float_values([]float values) []float {
    []float out = []float{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func to_device([]float host) device_array {
    device_array {
        data: copy_float_values(host),
        size: len(host),
        on_device: true,
    }
}

func to_host(device_array arr) []float {
    copy_float_values(arr.data)
}

func add_device(device_array left, device_array right) device_array {
    int n = left.size
    if right.size < n {
        n = right.size
    }
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = left.data[i] + right.data[i]
        i = i + 1
    }
    device_array {
        data: out,
        size: n,
        on_device: left.on_device || right.on_device,
    }
}

func mul_device(device_array left, device_array right) device_array {
    int n = left.size
    if right.size < n {
        n = right.size
    }
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = left.data[i] * right.data[i]
        i = i + 1
    }
    device_array {
        data: out,
        size: n,
        on_device: left.on_device || right.on_device,
    }
}

func add_bias_device(device_array values, device_array bias, int rows, int cols) device_array {
    int n = rows * cols
    if values.size < n {
        n = values.size
    }
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        int c = i % cols
        float b = 0.0
        if c < bias.size {
            b = bias.data[c]
        }
        out[i] = values.data[i] + b
        i = i + 1
    }
    device_array {
        data: out,
        size: n,
        on_device: values.on_device || bias.on_device,
    }
}
static py_object* tensor_cuda_add_bias_3d_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    py_object* b_capsule = nullptr;
    int bsz = 0, t = 0, c = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "OOiiis", &a_capsule, &b_capsule, &bsz, &t, &c, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, capsule, b, t, c, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "add_bias_3d_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    auto* b = _get_device_array(b_capsule);
    if (!a || !b) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)bsz * (size_t)t * (size_t)c != a->size || (size_t)c != b->size) {
        return _raise(py_exc_value_error, "add_bias_3d_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)bsz * (size_t)t * (size_t)c * sizeof(float)), "cudaMalloc");
        cuda_add_bias_3d_device_float((const float*)a->ptr, (const float*)b->ptr, (float*)d_out, bsz, t, c);
        _cuda_check(cuda_get_last_error(), "cuda_add_bias_3d_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)bsz * (size_t)t * (size_t)c};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_matmul_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    py_object* b_capsule = nullptr;
    int m = 0, k = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "OOiiis", &a_capsule, &b_capsule, &m, &k, &n, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, capsule, m, k, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "matmul_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    auto* b = _get_device_array(b_capsule);
    if (!a || !b) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)k != a->size || (size_t)k * (size_t)n != b->size) {
        return _raise(py_exc_value_error, "matmul_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * (size_t)n * sizeof(float)), "cudaMalloc");
        cuda_matmul_device_float((const float*)a->ptr, (const float*)b->ptr, (float*)d_out, m, k, n);
        _cuda_check(cuda_get_last_error(), "cuda_matmul_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m * (size_t)n};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_layernorm_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    py_object* g_capsule = nullptr;
    py_object* b_capsule = nullptr;
    int m = 0, n = 0;
    float eps = 0.00001f;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "OOOiifs", &a_capsule, &g_capsule, &b_capsule, &m, &n, &eps, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, gamma, beta, m, n, eps, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "layernorm_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    auto* g = _get_device_array(g_capsule);
    auto* b = _get_device_array(b_capsule);
    if (!a || !g || !b) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size || (size_t)n != g->size || (size_t)n != b->size) {
        return _raise(py_exc_value_error, "layernorm_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * (size_t)n * sizeof(float)), "cudaMalloc");
        cuda_layernorm_device_float((const float*)a->ptr, (const float*)g->ptr, (const float*)b->ptr, (float*)d_out, m, n, eps);
        _cuda_check(cuda_get_last_error(), "cuda_layernorm_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m * (size_t)n};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_softmax_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "softmax_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(py_exc_value_error, "softmax_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * (size_t)n * sizeof(float)), "cudaMalloc");
        cuda_softmax_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cuda_get_last_error(), "cuda_softmax_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m * (size_t)n};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_reduce_sum_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Ons", &a_capsule, &size, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "reduce_sum_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)size != a->size) {
        return _raise(py_exc_value_error, "reduce_sum_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, sizeof(float)), "cudaMalloc");
        cuda_reduce_sum_device_float((const float*)a->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cuda_get_last_error(), "cuda_reduce_sum_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, 1};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_reduce_mean_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Ons", &a_capsule, &size, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "reduce_mean_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)size != a->size) {
        return _raise(py_exc_value_error, "reduce_mean_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, sizeof(float)), "cudaMalloc");
        cuda_reduce_mean_device_float((const float*)a->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cuda_get_last_error(), "cuda_reduce_mean_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, 1};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_reduce_max_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Ons", &a_capsule, &size, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "reduce_max_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)size != a->size) {
        return _raise(py_exc_value_error, "reduce_max_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, sizeof(float)), "cudaMalloc");
        cuda_reduce_max_device_float((const float*)a->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cuda_get_last_error(), "cuda_reduce_max_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, 1};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_reduce_min_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    py_ssize_t size = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Ons", &a_capsule, &size, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, size, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "reduce_min_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)size != a->size) {
        return _raise(py_exc_value_error, "reduce_min_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, sizeof(float)), "cudaMalloc");
        cuda_reduce_min_device_float((const float*)a->ptr, (float*)d_out, (size_t)size);
        _cuda_check(cuda_get_last_error(), "cuda_reduce_min_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, 1};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_reduce_sum_lastdim_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "reduce_sum_lastdim_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(py_exc_value_error, "reduce_sum_lastdim_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * sizeof(float)), "cudaMalloc");
        cuda_reduce_sum_lastdim_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cuda_get_last_error(), "cuda_reduce_sum_lastdim_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_reduce_mean_lastdim_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "reduce_mean_lastdim_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(py_exc_value_error, "reduce_mean_lastdim_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * sizeof(float)), "cudaMalloc");
        cuda_reduce_mean_lastdim_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cuda_get_last_error(), "cuda_reduce_mean_lastdim_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_reduce_max_lastdim_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "reduce_max_lastdim_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(py_exc_value_error, "reduce_max_lastdim_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * sizeof(float)), "cudaMalloc");
        cuda_reduce_max_lastdim_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cuda_get_last_error(), "cuda_reduce_max_lastdim_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_reduce_min_lastdim_device(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "reduce_min_lastdim_device: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(py_exc_value_error, "reduce_min_lastdim_device: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * sizeof(float)), "cudaMalloc");
        cuda_reduce_min_lastdim_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cuda_get_last_error(), "cuda_reduce_min_lastdim_device");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_argmax_lastdim(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "argmax_lastdim: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(py_exc_value_error, "argmax_lastdim: size mismatch");
    }
    long long* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * sizeof(long long)), "cudaMalloc");
        cuda_argmax_lastdim_device_int64((const float*)a->ptr, d_out, m, n);
        _cuda_check(cuda_get_last_error(), "cuda_argmax_lastdim");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_argmin_lastdim(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "argmin_lastdim: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(py_exc_value_error, "argmin_lastdim: size mismatch");
    }
    long long* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * sizeof(long long)), "cudaMalloc");
        cuda_argmin_lastdim_device_int64((const float*)a->ptr, d_out, m, n);
        _cuda_check(cuda_get_last_error(), "cuda_argmin_lastdim");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_transpose_2d(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int m = 0, n = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiis", &a_capsule, &m, &n, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, m, n, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "transpose_2d: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)m * (size_t)n != a->size) {
        return _raise(py_exc_value_error, "transpose_2d: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)m * (size_t)n * sizeof(float)), "cudaMalloc");
        cuda_transpose_2d_device_float((const float*)a->ptr, (float*)d_out, m, n);
        _cuda_check(cuda_get_last_error(), "cuda_transpose_2d");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)m * (size_t)n};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_permute_3d_0_2_1(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int b = 0, t = 0, c = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiiis", &a_capsule, &b, &t, &c, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, b, t, c, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "permute_3d_0_2_1: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)b * (size_t)t * (size_t)c != a->size) {
        return _raise(py_exc_value_error, "permute_3d_0_2_1: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)b * (size_t)t * (size_t)c * sizeof(float)), "cudaMalloc");
        cuda_permute_3d_0_2_1_device_float((const float*)a->ptr, (float*)d_out, b, t, c);
        _cuda_check(cuda_get_last_error(), "cuda_permute_3d_0_2_1");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)b * (size_t)t * (size_t)c};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_object* tensor_cuda_permute_3d_1_2_0(py_object* , py_object* args) {
    py_object* a_capsule = nullptr;
    int b = 0, t = 0, c = 0;
    const char* dtype_str = nullptr;
    if (!py_arg_parse_tuple(args, "Oiiis", &a_capsule, &b, &t, &c, &dtype_str)) {
        return _raise(py_exc_type_error, "expected (capsule, b, t, c, dtype)");
    }
    if (std::string(dtype_str) != "float32") {
        return _raise(py_exc_type_error, "permute_3d_1_2_0: only float32 supported");
    }
    auto* a = _get_device_array(a_capsule);
    if (!a) {
        return _raise(py_exc_runtime_error, "invalid device array capsule");
    }
    if ((size_t)b * (size_t)t * (size_t)c != a->size) {
        return _raise(py_exc_value_error, "permute_3d_1_2_0: size mismatch");
    }
    void* d_out = nullptr;
    try {
        _cuda_check(cuda_malloc(&d_out, (size_t)b * (size_t)t * (size_t)c * sizeof(float)), "cudaMalloc");
        cuda_permute_3d_1_2_0_device_float((const float*)a->ptr, (float*)d_out, b, t, c);
        _cuda_check(cuda_get_last_error(), "cuda_permute_3d_1_2_0");
        _cuda_check(cuda_device_synchronize(), "cudaDeviceSynchronize");
    } catch (const std::exception& e) {
        if (d_out) cuda_free(d_out);
        return _raise(py_exc_runtime_error, e.what());
    }
    auto* out = new device_array{d_out, (size_t)b * (size_t)t * (size_t)c};
    return py_capsule_new(out, "neurx.cuda.DeviceArray", _capsule_destructor);
}
static py_method_def tensor_cuda_methods[] = {
    {"to_device", tensor_cuda_to_device, METH_VARARGS, "Copy numpy array to device"},
    {"to_host", tensor_cuda_to_host, METH_VARARGS, "Copy device array to numpy"},
    {"add_device", tensor_cuda_add_device, METH_VARARGS, "CUDA elementwise add (device)"},
    {"mul_device", tensor_cuda_mul_device, METH_VARARGS, "CUDA elementwise multiply (device)"},
    {"add_bias_device", tensor_cuda_add_bias_device, METH_VARARGS, "CUDA add bias (device)"},
    {"add_bias_3d_device", tensor_cuda_add_bias_3d_device, METH_VARARGS, "CUDA add bias 3d (device)"},
    {"matmul_device", tensor_cuda_matmul_device, METH_VARARGS, "CUDA matmul (device)"},
    {"layernorm_device", tensor_cuda_layernorm_device, METH_VARARGS, "CUDA layernorm (device)"},
    {"softmax_device", tensor_cuda_softmax_device, METH_VARARGS, "CUDA softmax (device)"},
    {"reduce_sum_device", tensor_cuda_reduce_sum_device, METH_VARARGS, "CUDA reduce sum (device)"},
    {"reduce_mean_device", tensor_cuda_reduce_mean_device, METH_VARARGS, "CUDA reduce mean (device)"},
    {"reduce_max_device", tensor_cuda_reduce_max_device, METH_VARARGS, "CUDA reduce max (device)"},
    {"reduce_min_device", tensor_cuda_reduce_min_device, METH_VARARGS, "CUDA reduce min (device)"},
    {"reduce_sum_lastdim_device", tensor_cuda_reduce_sum_lastdim_device, METH_VARARGS, "CUDA reduce sum last dim (device)"},
    {"reduce_mean_lastdim_device", tensor_cuda_reduce_mean_lastdim_device, METH_VARARGS, "CUDA reduce mean last dim (device)"},
    {"reduce_max_lastdim_device", tensor_cuda_reduce_max_lastdim_device, METH_VARARGS, "CUDA reduce max last dim (device)"},
    {"reduce_min_lastdim_device", tensor_cuda_reduce_min_lastdim_device, METH_VARARGS, "CUDA reduce min last dim (device)"},
    {"argmax_lastdim", tensor_cuda_argmax_lastdim, METH_VARARGS, "CUDA argmax last dim (device int64 indices)"},
    {"argmin_lastdim", tensor_cuda_argmin_lastdim, METH_VARARGS, "CUDA argmin last dim (device int64 indices)"},
    {"transpose_2d", tensor_cuda_transpose_2d, METH_VARARGS, "CUDA transpose 2d"},
    {"permute_3d_0_2_1", tensor_cuda_permute_3d_0_2_1, METH_VARARGS, "CUDA permute 3d (0,2,1)"},
    {"permute_3d_1_2_0", tensor_cuda_permute_3d_1_2_0, METH_VARARGS, "CUDA permute 3d (1,2,0)"},
    {nullptr, nullptr, 0, nullptr}
};
static struct py_module_def tensor_cuda_module = {
    py_module_def_head_init,
    "_tensor_cuda",
    "tensor_2 CUDA ops",
    -1,
    tensor_cuda_methods,
};
py_modinit_func py_init_tensor_cuda(void) {
    import_array();
    return py_module_create(&tensor_cuda_module);
}

