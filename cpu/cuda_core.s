package neurx.cpu.cuda_core
extern func neurx_cuda_get_device_count() int
extern func neurx_cuda_set_device(int device_id) int
extern func neurx_cuda_get_device_name(int device_id) string
extern func neurx_cuda_malloc(int bytes) int64
extern func neurx_cuda_free(int64 pointer) int
extern func neurx_cuda_memcpy_htod(int64 destination, int64 source, int bytes) int
extern func neurx_cuda_memcpy_dtoh(int64 destination, int64 source, int bytes) int
extern func neurx_cuda_memcpy_dtod(int64 destination, int64 source, int bytes) int
extern func neurx_cuda_get_free_memory_bytes() int
extern func neurx_cuda_get_total_memory_bytes() int
extern func neurx_cublas_create() int64
extern func neurx_cublas_destroy(int64 handle) int
extern func neurx_cublas_sgemm(int64 handle, int m, int n, int k, float alpha, int64 left, int64 right, float beta, int64 output) int
extern func neurx_cuda_synchronize() int
struct cuda_device {
    int device_id
    string device_name
    int total_memory_bytes
    int free_memory_bytes
    bool available
}
struct cuda_context {
    cuda_device device
    int64 cublas_handle
    int allocated_bytes
    bool initialized
    string error_message
}
struct cuda_buffer {
    int64 pointer
    int bytes
    int device_id
    bool allocated
}
struct cuda_context_result {
    cuda_context context
    cuda_buffer buffer
    bool success
    string error_message
}
func cuda_empty_device(int device_id) cuda_device {
    cuda_device device
    device.device_id = device_id
    device.device_name = ""
    device.total_memory_bytes = 0
    device.free_memory_bytes = 0
    device.available = false
    device
}
func cuda_empty_buffer() cuda_buffer {
    cuda_buffer buffer
    buffer.pointer = 0
    buffer.bytes = 0
    buffer.device_id = -1
    buffer.allocated = false
    buffer
}
func cuda_new_result(cuda_context context, cuda_buffer buffer, bool success, string error_message) cuda_context_result {
    cuda_context_result result
    result.context = context
    result.buffer = buffer
    result.success = success
    result.error_message = error_message
    result
}
func cuda_device_count() int {
    int count = neurx_cuda_get_device_count()
    if count < 0 { return 0 }
    count
}
func cuda_query_device(int device_id) cuda_device {
    cuda_device device = cuda_empty_device(device_id)
    int count = cuda_device_count()
    if device_id < 0 || device_id >= count { return device }
    if neurx_cuda_set_device(device_id) != 0 { return device }
    int free_bytes = neurx_cuda_get_free_memory_bytes()
    int total_bytes = neurx_cuda_get_total_memory_bytes()
    if free_bytes < 0 || total_bytes <= 0 { return device }
    device.device_name = neurx_cuda_get_device_name(device_id)
    device.total_memory_bytes = total_bytes
    device.free_memory_bytes = free_bytes
    device.available = total_bytes > 0
    device
}
func cuda_context_create(int device_id) cuda_context {
    cuda_context context
    context.device = cuda_query_device(device_id)
    context.cublas_handle = i64(0)
    context.allocated_bytes = 0
    context.initialized = false
    context.error_message = ""
    if !context.device.available {
        context.error_message = "CUDA device is unavailable"
        return context
    }
    context.cublas_handle = neurx_cublas_create()
    if context.cublas_handle == i64(0) {
        context.error_message = "cuBLAS initialization failed"
        return context
    }
    context.initialized = true
    context
}
func cuda_context_destroy(cuda_context context) cuda_context {
    if context.cublas_handle != i64(0) {
        neurx_cublas_destroy(context.cublas_handle)
    }
    context.cublas_handle = i64(0)
    context.allocated_bytes = 0
    context.initialized = false
    context
}
func cuda_allocate(cuda_context context, int bytes) cuda_context_result {
    if !context.initialized {
        return cuda_new_result(context, cuda_empty_buffer(), false, "CUDA context is not initialized")
    }
    if bytes <= 0 {
        return cuda_new_result(context, cuda_empty_buffer(), false, "allocation size must be positive")
    }
    if bytes > context.device.free_memory_bytes - context.allocated_bytes {
        return cuda_new_result(context, cuda_empty_buffer(), false, "CUDA out of memory")
    }
    int64 pointer = neurx_cuda_malloc(bytes)
    if pointer == i64(0) {
        return cuda_new_result(context, cuda_empty_buffer(), false, "cudaMalloc failed")
    }
    cuda_buffer buffer
    buffer.pointer = pointer
    buffer.bytes = bytes
    buffer.device_id = context.device.device_id
    buffer.allocated = true
    context.allocated_bytes = context.allocated_bytes + bytes
    cuda_new_result(context, buffer, true, "")
}
func cuda_release(cuda_context context, cuda_buffer buffer) cuda_context_result {
    if !buffer.allocated || buffer.pointer == i64(0) {
        return cuda_new_result(context, buffer, false, "CUDA buffer is not allocated")
    }
    if neurx_cuda_free(buffer.pointer) != 0 {
        return cuda_new_result(context, buffer, false, "cudaFree failed")
    }
    context.allocated_bytes = context.allocated_bytes - buffer.bytes
    if context.allocated_bytes < 0 { context.allocated_bytes = 0 }
    buffer.pointer = i64(0)
    buffer.bytes = 0
    buffer.allocated = false
    cuda_new_result(context, buffer, true, "")
}
func cuda_copy_host_to_device(cuda_buffer destination, int64 host_pointer, int bytes) bool {
    destination.allocated && host_pointer != i64(0) && bytes > 0 && bytes <= destination.bytes && neurx_cuda_memcpy_htod(destination.pointer, host_pointer, bytes) == 0
}
func cuda_copy_device_to_host(int64 host_pointer, cuda_buffer source, int bytes) bool {
    source.allocated && host_pointer != i64(0) && bytes > 0 && bytes <= source.bytes && neurx_cuda_memcpy_dtoh(host_pointer, source.pointer, bytes) == 0
}
func cuda_copy_device_to_device(cuda_buffer destination, cuda_buffer source, int bytes) bool {
    destination.allocated && source.allocated && bytes > 0 && bytes <= destination.bytes && bytes <= source.bytes && neurx_cuda_memcpy_dtod(destination.pointer, source.pointer, bytes) == 0
}
func cuda_sgemm(cuda_context context, cuda_buffer left, cuda_buffer right, cuda_buffer output, int m, int n, int k) bool {
    if !context.initialized || !left.allocated || !right.allocated || !output.allocated { return false }
    if m <= 0 || n <= 0 || k <= 0 { return false }
    int left_bytes = m * k * 4
    int right_bytes = k * n * 4
    int output_bytes = m * n * 4
    if left.bytes < left_bytes || right.bytes < right_bytes || output.bytes < output_bytes { return false }
    if neurx_cublas_sgemm(context.cublas_handle, m, n, k, 1.0, left.pointer, right.pointer, 0.0, output.pointer) != 0 { return false }
    neurx_cuda_synchronize() == 0
}
func cuda_abi_contract_valid() bool {
    cuda_buffer empty = cuda_empty_buffer()
    !empty.allocated && empty.pointer == i64(0) && empty.device_id == -1
}
