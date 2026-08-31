package neurx.device.cuda_runtime_binding

// CUDA Runtime API FFI Bindings
// These are extern declarations to NVIDIA CUDA libraries

extern func cudaGetDeviceCount(int* count) -> int
extern func cudaSetDevice(int device) -> int
extern func cudaGetDevice(int* device) -> int
extern func cudaMalloc(void** devPtr, int size) -> int
extern func cudaFree(void* devPtr) -> int
extern func cudaMemcpy(void* dst, void* src, int size, int kind) -> int
extern func cudaMemset(void* devPtr, int value, int size) -> int
extern func cudaStreamCreate(void** pStream) -> int
extern func cudaStreamDestroy(void* stream) -> int
extern func cudaStreamSynchronize(void* stream) -> int
extern func cudaEventCreate(void** pEvent) -> int
extern func cudaEventDestroy(void* event) -> int
extern func cudaEventRecord(void* event, void* stream) -> int
extern func cudaEventSynchronize(void* event) -> int
extern func cudaGetLastError() -> int

// CUDA error codes
int CUDA_SUCCESS = 0
int CUDA_ERROR_INVALID_DEVICE = 1
int CUDA_ERROR_OUT_OF_MEMORY = 2
int CUDA_ERROR_NOT_INITIALIZED = 3

// Memory copy kinds
int CUDA_MEMCPY_HOST_TO_DEVICE = 1
int CUDA_MEMCPY_DEVICE_TO_HOST = 2
int CUDA_MEMCPY_DEVICE_TO_DEVICE = 3

// Basic device operations

func cuda_get_device_count() (int, bool, string) {
    count := 0
    status := cudaGetDeviceCount(&count)
    if status != CUDA_SUCCESS {
        return 0, false, "failed to get device count"
    }
    return count, true, ""
}

func cuda_set_device(int device_id) (bool, string) {
    status := cudaSetDevice(device_id)
    if status != CUDA_SUCCESS {
        return false, "failed to set device"
    }
    return true, ""
}

func cuda_get_current_device() (int, bool, string) {
    device := 0
    status := cudaGetDevice(&device)
    if status != CUDA_SUCCESS {
        return -1, false, "failed to get current device"
    }
    return device, true, ""
}

// Memory management

func cuda_malloc(int64 size) (int64, bool, string) {
    ptr := 0
    size_int := size as int
    status := cudaMalloc(&ptr, size_int)
    if status != CUDA_SUCCESS {
        return 0, false, "cuda malloc failed"
    }
    return ptr as int64, true, ""
}

func cuda_free(int64 ptr) (bool, string) {
    ptr_void := ptr as void*
    status := cudaFree(ptr_void)
    if status != CUDA_SUCCESS {
        return false, "cuda free failed"
    }
    return true, ""
}

func cuda_memcpy_h2d(int64 host_ptr, int64 device_ptr, int64 size) (bool, string) {
    status := cudaMemcpy(device_ptr as void*, host_ptr as void*, size as int, CUDA_MEMCPY_HOST_TO_DEVICE)
    if status != CUDA_SUCCESS {
        return false, "h2d memcpy failed"
    }
    return true, ""
}

func cuda_memcpy_d2h(int64 device_ptr, int64 host_ptr, int64 size) (bool, string) {
    status := cudaMemcpy(host_ptr as void*, device_ptr as void*, size as int, CUDA_MEMCPY_DEVICE_TO_HOST)
    if status != CUDA_SUCCESS {
        return false, "d2h memcpy failed"
    }
    return true, ""
}

func cuda_memcpy_d2d(int64 src, int64 dst, int64 size) (bool, string) {
    status := cudaMemcpy(dst as void*, src as void*, size as int, CUDA_MEMCPY_DEVICE_TO_DEVICE)
    if status != CUDA_SUCCESS {
        return false, "d2d memcpy failed"
    }
    return true, ""
}

// Stream management

func cuda_stream_create() (int64, bool, string) {
    stream := 0
    status := cudaStreamCreate(&stream)
    if status != CUDA_SUCCESS {
        return 0, false, "stream create failed"
    }
    return stream as int64, true, ""
}

func cuda_stream_destroy(int64 stream) (bool, string) {
    status := cudaStreamDestroy(stream as void*)
    if status != CUDA_SUCCESS {
        return false, "stream destroy failed"
    }
    return true, ""
}

func cuda_stream_synchronize(int64 stream) (bool, string) {
    status := cudaStreamSynchronize(stream as void*)
    if status != CUDA_SUCCESS {
        return false, "stream synchronize failed"
    }
    return true, ""
}

func cuda_device_synchronize() (bool, string) {
    return cuda_stream_synchronize(0)
}

// Error handling

func cuda_get_last_error() (int, string) {
    error_code := cudaGetLastError()
    if error_code == CUDA_SUCCESS {
        return error_code, "success"
    } else if error_code == CUDA_ERROR_INVALID_DEVICE {
        return error_code, "invalid device"
    } else if error_code == CUDA_ERROR_OUT_OF_MEMORY {
        return error_code, "out of memory"
    } else if error_code == CUDA_ERROR_NOT_INITIALIZED {
        return error_code, "cuda not initialized"
    }
    return error_code, "unknown error"
}
