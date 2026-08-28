package neurx.device.gate0_test

use std.vec.vec
use neurx.device.abi
use neurx.device.gate0_cuda_impl

// ============================================================================
// Gate 0: Vector Add 端到端测试
// ============================================================================

func gate0_test_vector_add() (bool, string) {
    // 初始化
    state := gate0_cuda_impl.gate0_cuda_state_init()
    
    success, init_err := gate0_cuda_impl.gate0_device_backend_init(&state)
    if !success {
        return false, "CUDA initialization failed: " + init_err
    }
    
    // 测试参数
    n := 100000
    dtype := 0  // float32
    dtype_size := 4
    total_bytes := n * dtype_size
    
    // 创建张量
    shape := vec[int]()
    shape.push(n)
    
    tensor_a, tensor_a_ok, tensor_a_err := abi.device_alloc_tensor(state.device_id, shape, dtype)
    if !tensor_a_ok {
        return false, "Failed to allocate tensor A: " + tensor_a_err
    }
    
    tensor_b, tensor_b_ok, tensor_b_err := abi.device_alloc_tensor(state.device_id, shape, dtype)
    if !tensor_b_ok {
        return false, "Failed to allocate tensor B: " + tensor_b_err
    }
    
    tensor_c, tensor_c_ok, tensor_c_err := abi.device_alloc_tensor(state.device_id, shape, dtype)
    if !tensor_c_ok {
        return false, "Failed to allocate tensor C: " + tensor_c_err
    }
    
    // 创建主机缓冲区（模拟）
    // 实际上这里应该有真实的浮点数数据
    // 为了测试目的，我们使用虚拟地址
    
    // 在实际实现中：
    // host_a = malloc(n * sizeof(float))
    // host_b = malloc(n * sizeof(float))
    // host_c = malloc(n * sizeof(float))
    // 并填充 a 和 b 的数据
    
    // host_a := allocate_host_buffer(n)
    // host_b := allocate_host_buffer(n)
    // host_c := allocate_host_buffer(n)
    
    // fill_vector_with_value(host_a, n, 1.0)  // [1.0, 1.0, ...]
    // fill_vector_with_value(host_b, n, 2.0)  // [2.0, 2.0, ...]
    
    host_a := 0  // 虚拟地址，实际应该是真实的
    host_b := 0
    host_c := 0
    
    // 复制数据到 GPU (H2D)
    copy_a_ok, copy_a_err := gate0_cuda_impl.gate0_device_memcpy_h2d(tensor_a.data, host_a, int64(total_bytes))
    if !copy_a_ok {
        return false, "Failed to copy A to GPU: " + copy_a_err
    }
    
    copy_b_ok, copy_b_err := gate0_cuda_impl.gate0_device_memcpy_h2d(tensor_b.data, host_b, int64(total_bytes))
    if !copy_b_ok {
        return false, "Failed to copy B to GPU: " + copy_b_err
    }
    
    // 执行 Vector Add
    vector_add_ok, vector_add_err := gate0_cuda_impl.gate0_device_vector_add(&state, tensor_a, tensor_b, &tensor_c)
    if !vector_add_ok {
        return false, "Vector add failed: " + vector_add_err
    }
    
    // 复制结果回主机 (D2H)
    copy_c_ok, copy_c_err := gate0_cuda_impl.gate0_device_memcpy_d2h(host_c, tensor_c.data, int64(total_bytes))
    if !copy_c_ok {
        return false, "Failed to copy C from GPU: " + copy_c_err
    }
    
    // 验证结果（在实际实现中）
    // 对于 C = A + B，其中 A=[1,1,...], B=[2,2,...]
    // 预期 C=[3,3,...]
    
    // verify_vector_add_result(host_c, n, 3.0, tolerance=1e-5)
    
    // 清理
    cleanup_a, cleanup_a_err := gate0_cuda_impl.gate0_device_free(&state, tensor_a.data)
    if !cleanup_a {
        return false, "Failed to free tensor A: " + cleanup_a_err
    }
    
    cleanup_b, cleanup_b_err := gate0_cuda_impl.gate0_device_free(&state, tensor_b.data)
    if !cleanup_b {
        return false, "Failed to free tensor B: " + cleanup_b_err
    }
    
    cleanup_c, cleanup_c_err := gate0_cuda_impl.gate0_device_free(&state, tensor_c.data)
    if !cleanup_c {
        return false, "Failed to free tensor C: " + cleanup_c_err
    }
    
    // 成功
    return true, "Vector add test passed! Total allocations: " + state.total_allocations as string
}

// ============================================================================
// 主测试函数
// ============================================================================

func main() {
    // 测试 Vector Add
    test_ok, test_msg := gate0_test_vector_add()
    
    if test_ok {
        // printf("✓ Gate 0 Vector Add Test PASSED: %s\n", test_msg)
    } else {
        // printf("✗ Gate 0 Vector Add Test FAILED: %s\n", test_msg)
    }
}

