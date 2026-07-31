package neurx.cuda
struct cuda_device {
    int id
    string name
    int total_memory_bytes
    int free_memory_bytes
    int major_version
    int minor_version
    int max_threads_per_block
    int max_shared_mem_per_block
    int multiprocessor_count
    int clock_rate_khz
    bool supports_fp16
    bool supports_bfloat16
    bool supports_tensor_cores
}

struct cuda_context {
    cuda_device device
    bool is_initialized
    uint64 stream
    uint64 cublas_handle
    uint64 cudnn_handle
    int allocated_memory_bytes
    []memory_allocation allocations
}

struct memory_allocation {
    uint64 device_ptr
    int size_bytes
    string label
    bool is_pinned
}
func get_device_count() int {
    query_gpu_count()
}

func query_gpu_count() int {
    1
}
