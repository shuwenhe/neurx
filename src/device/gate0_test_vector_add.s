package neurx.device.gate0_test
use std.vec.vec
use neurx.device.abi
use neurx.device.gate0_cuda_impl
func gate0_test_vector_add() (bool, string) {
    state := gate0_cuda_impl.gate0_cuda_state_init()
    success, init_err := gate0_cuda_impl.gate0_device_backend_init(&state)
    if !success {
        return false, "CUDA initialization failed: " + init_err
    }
    n := 100000
    dtype := 0  
    dtype_size := 4
    total_bytes := n * dtype_size
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
    host_a := 0  
    host_b := 0
    host_c := 0
    copy_a_ok, copy_a_err := gate0_cuda_impl.gate0_device_memcpy_h2d(tensor_a.data, host_a, int64(total_bytes))
    if !copy_a_ok {
        return false, "Failed to copy A to GPU: " + copy_a_err
    }
    copy_b_ok, copy_b_err := gate0_cuda_impl.gate0_device_memcpy_h2d(tensor_b.data, host_b, int64(total_bytes))
    if !copy_b_ok {
        return false, "Failed to copy B to GPU: " + copy_b_err
    }
    vector_add_ok, vector_add_err := gate0_cuda_impl.gate0_device_vector_add(&state, tensor_a, tensor_b, &tensor_c)
    if !vector_add_ok {
        return false, "Vector add failed: " + vector_add_err
    }
    copy_c_ok, copy_c_err := gate0_cuda_impl.gate0_device_memcpy_d2h(host_c, tensor_c.data, int64(total_bytes))
    if !copy_c_ok {
        return false, "Failed to copy C from GPU: " + copy_c_err
    }
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
    return true, "Vector add test passed! Total allocations: " + state.total_allocations as string
}

func main() {
    test_ok, test_msg := gate0_test_vector_add()
    if test_ok {
    } else {
    }
}
