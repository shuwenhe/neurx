package neurx.device.device_bridge

use neurx.device.abi
use neurx.device.gate0_cuda_impl

// ============================================================================
// Device ABI 桥接实现 - 连接 ABI 与 CUDA 后端
// ============================================================================

// 全局 CUDA 状态
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

// ============================================================================
// 实现 abi.device_* 函数
// ============================================================================

// 全局状态指针（在实际应用中应该通过其他方式管理）
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

// 实现 abi.device_set_current
func device_bridge_set_current(device_id: int) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return true, ""
}

// 实现 abi.device_create_stream
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

// 实现 abi.device_destroy_stream
func device_bridge_destroy_stream(stream: abi.stream_handle) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return true, ""
}

// 实现 abi.device_synchronize
func device_bridge_synchronize(device_id: int) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.cuda_runtime_stream_synchronize(g_device_bridge.cuda_state.default_stream)
}

// 实现 abi.device_get_memory_info
func device_bridge_get_memory_info(device_id: int) (int64, int64, bool, string) {
    if !g_device_bridge.is_initialized {
        return 0, 0, false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_get_memory_info(&g_device_bridge.cuda_state)
}

// 实现 abi.device_alloc
func device_bridge_alloc(device_id: int, num_bytes: int64) (abi.device_ptr, bool, string) {
    if !g_device_bridge.is_initialized {
        return abi.device_ptr{}, false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_device_malloc(&g_device_bridge.cuda_state, num_bytes)
}

// 实现 abi.device_free
func device_bridge_free(ptr: abi.device_ptr) (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_device_free(&g_device_bridge.cuda_state, ptr)
}

// 实现 abi.device_memcpy_h2d
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

// 实现 abi.device_memcpy_d2h
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

// 实现 abi.device_memcpy_d2d
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

// 实现 abi.device_vector_add
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
    
    // 调用 CUDA 实现
    var c_mut abi.device_tensor
    c_mut = c
    return gate0_cuda_impl.gate0_device_vector_add(&g_device_bridge.cuda_state, a, b, &c_mut)
}

// ============================================================================
// 诊断函数
// ============================================================================

func device_bridge_print_status() (bool, string) {
    if !g_device_bridge.is_initialized {
        return false, "Device bridge not initialized"
    }
    return gate0_cuda_impl.gate0_print_device_info(&g_device_bridge.cuda_state)
}

func device_bridge_get_cuda_state() gate0_cuda_impl.gate0_cuda_state {
    return g_device_bridge.cuda_state
}

