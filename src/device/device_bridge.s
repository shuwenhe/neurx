package neurx.device.device_bridge
use neurx.device.abi
use neurx.device.gate0_cuda_impl
struct device_bridge_state {
    bool is_initialized
    gate0_cuda_impl.gate0_cuda_state cuda_state
}
func device_bridge_state_init() device_bridge_state {
    state := device_bridge_state {
        is_initialized: false,
        cuda_state: gate0_cuda_impl.gate0_cuda_state_init(),
    }
    return state
}
var g_device_bridge device_bridge_state
func device_bridge_init() (bool, string) {
    g_device_bridge = device_bridge_state_init()
    success, err := gate0_cuda_impl.gate0_device_backend_init(&g_device_bridge.cuda_state)
    if !success {
        return false, err
    }
    g_device_bridge.is_initialized = true
    return true, ""
}
func device_bridge_set_current(device_id: int) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return true, ""
}
func device_bridge_create_stream(device_id: int) (abi.stream_handle, bool, string) {
    if !g_device_bridge.is_initialized {
        return abi.stream_handle{}, false, "Device bridge not initialized"
    }
    stream_id, success, err := gate0_cuda_impl.cuda_runtime_create_stream()
    if !success {
        return abi.stream_handle{}, false, err
    }
    handle := abi.stream_handle {
        handle: stream_id,
        device_id: device_id,
    }
    return handle, true, ""
}
func device_bridge_destroy_stream(stream: abi.stream_handle) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return true, ""
}
func device_bridge_synchronize(device_id: int) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.cuda_runtime_stream_synchronize(g_device_bridge.cuda_state.default_stream)
}
func device_bridge_get_memory_info(device_id: int) (int64, int64, bool, string) {
    if !g_device_bridge.is_initialized {
        return 0, 0, false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_get_memory_info(&g_device_bridge.cuda_state)
}
func device_bridge_alloc(device_id: int, num_bytes: int64) (abi.device_ptr, bool, string) {
    if !g_device_bridge.is_initialized {
        return abi.device_ptr{}, false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_device_malloc(&g_device_bridge.cuda_state, num_bytes)
}
func device_bridge_free(ptr: abi.device_ptr) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_device_free(&g_device_bridge.cuda_state, ptr)
}
func device_bridge_memcpy_h2d(
    dst: abi.device_ptr,
    host_src: int64,
    num_bytes: int64,
    stream: abi.stream_handle
) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_device_memcpy_h2d(dst, host_src, num_bytes)
}
func device_bridge_memcpy_d2h(
    host_dst: int64,
    src: abi.device_ptr,
    num_bytes: int64,
    stream: abi.stream_handle
) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_device_memcpy_d2h(host_dst, src, num_bytes)
}
func device_bridge_memcpy_d2d(
    dst: abi.device_ptr,
    src: abi.device_ptr,
    num_bytes: int64,
    stream: abi.stream_handle
) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.cuda_runtime_memcpy_d2d(dst.address, src.address, num_bytes)
}
func device_bridge_vector_add(
    a: abi.device_tensor,
    b: abi.device_tensor,
    c: abi.device_tensor,
    stream: abi.stream_handle
) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    if a.element_count != b.element_count || a.element_count != c.element_count {
        return false, "Tensor size mismatch"
    }
    if a.dtype != 0 || b.dtype != 0 || c.dtype != 0 {
        return false, "Only float32 supported for vector_add in Gate 0"
    }
    var c_mut abi.device_tensor
    c_mut = c
    return gate0_cuda_impl.gate0_device_vector_add(&g_device_bridge.cuda_state, a, b, &c_mut)
}
func device_bridge_print_status() (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_print_device_info(&g_device_bridge.cuda_state)
}
func device_bridge_get_cuda_state() gate0_cuda_impl.gate0_cuda_state {
    return g_device_bridge.cuda_state
}
func device_bridge_create_event(device_id: int) (abi.event_handle, bool, string) {
    if !g_device_bridge.is_initialized {
        return abi.event_handle{}, false, "Device bridge not initialized"
    }
    event_id, success, err := gate0_cuda_impl.cuda_runtime_create_event()
    if !success {
        return abi.event_handle{}, false, err
    }
    handle := abi.event_handle {
        handle: event_id,
        device_id: device_id,
    }
    return handle, true, ""
}
func device_bridge_destroy_event(event: abi.event_handle) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.cuda_runtime_destroy_event(event.handle)
}
func device_bridge_record_event(event: abi.event_handle, stream: abi.stream_handle) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.cuda_runtime_record_event(event.handle, stream.handle)
}
func device_bridge_sync_event(event: abi.event_handle) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.cuda_runtime_event_synchronize(event.handle)
}
func device_bridge_stream_wait_event(stream: abi.stream_handle, event: abi.event_handle) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.cuda_runtime_stream_wait_event(stream.handle, event.handle)
}
func device_bridge_memset(
    ptr: abi.device_ptr,
    value: int,
    num_bytes: int64,
    stream: abi.stream_handle
) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_device_memset(&g_device_bridge.cuda_state, ptr.address, value, num_bytes)
}
func device_bridge_copy_tensor_h2d(
    dst: abi.device_tensor,
    host_src: int64,
    stream: abi.stream_handle
) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    total_bytes := dst.element_count * abi.device_get_dtype_size(dst.dtype)
    return device_bridge_memcpy_h2d(dst.data, host_src, int64(total_bytes), stream)
}
func device_bridge_copy_tensor_d2h(
    host_dst: int64,
    src: abi.device_tensor,
    stream: abi.stream_handle
) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    total_bytes := src.element_count * abi.device_get_dtype_size(src.dtype)
    return device_bridge_memcpy_d2h(host_dst, src.data, int64(total_bytes), stream)
}
func device_bridge_copy_tensor_d2d(
    dst: abi.device_tensor,
    src: abi.device_tensor,
    stream: abi.stream_handle
) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    if dst.element_count != src.element_count {
        return false, "Tensor size mismatch"
    }
    if dst.dtype != src.dtype {
        return false, "Tensor dtype mismatch"
    }
    total_bytes := src.element_count * abi.device_get_dtype_size(src.dtype)
    return device_bridge_memcpy_d2d(dst.data, src.data, int64(total_bytes), stream)
}
func device_bridge_get_device_count() (int, bool, string) {
    if !g_device_bridge.is_initialized {
        return 0, false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.cuda_runtime_get_device_count()
}
func device_bridge_get_device_properties(device_id: int) (int, int, int, bool, string) {
    if !g_device_bridge.is_initialized {
        return 0, 0, 0, false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.cuda_runtime_get_device_properties(device_id)
}
func device_bridge_backend_init() (bool, string) {
    if g_device_bridge.is_initialized {
        return false, "Device bridge already initialized"
    }
    g_device_bridge = device_bridge_state_init()
    success, err := gate0_cuda_impl.cuda_runtime_backend_init()
    if !success {
        return false, err
    }
    success, err = gate0_cuda_impl.gate0_device_backend_init(&g_device_bridge.cuda_state)
    if !success {
        return false, err
    }
    g_device_bridge.is_initialized = true
    return true, ""
}
func device_bridge_backend_finalize() (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    success, err := gate0_cuda_impl.cuda_runtime_backend_finalize()
    g_device_bridge.is_initialized = false
    return success, err
}
