package neurx.cuda
func cuda_malloc(int size_bytes, string label) (uint64, error) {
    if size_bytes <= 0 {
        return (0, error{message: "Invalid allocation size"})
    }
    uint64 ptr = generate_fake_ptr(size_bytes)
    memory_allocation alloc {
        device_ptr: ptr,
        size_bytes: size_bytes,
        label: label,
        is_pinned: false,
    }
    current_context().allocations.push(alloc)
    current_context().allocated_memory_bytes =
        current_context().allocated_memory_bytes + size_bytes
    (ptr, nil)
}
func cuda_free(uint64 ptr) {
    int idx = -1
    for i in 0..len(current_context().allocations) {
        if current_context().allocations[i].device_ptr == ptr {
            idx = i
            break
        }
    }
    if idx >= 0 {
        current_context().allocated_memory_bytes =
            current_context().allocated_memory_bytes -
            current_context().allocations[idx].size_bytes
        int last = len(current_context().allocations) - 1
        if idx != last {
            current_context().allocations[idx] = current_context().allocations[last]
        }
        current_context().allocations.pop()
    }
}
func memcpy_htod(
    uint64 device_ptr,
    []float host_data,
    int size_bytes
) {
    log_memory_transfer("H2D", size_bytes)
}
func memcpy_dtoh(
    []float host_data,
    uint64 device_ptr,
    int size_bytes
) {
    log_memory_transfer("D2H", size_bytes)
}
