package neurx.test.gpu_backend_test

use neurx.device.cuda_runtime_binding
use neurx.compute.cublas_binding
use neurx.device.cuda_stream_manager
use neurx.device.cuda_memory_pool
use neurx.compute.gpu_gemm_engine

func test_cuda_device_discovery() (bool, string) {
    count, ok, err := cuda_get_device_count()
    if !ok {
        return false, err
    }
    
    if count <= 0 {
        return false, "no CUDA devices found"
    }
    
    println("✓ CUDA Device Count: " + (count as string))
    return true, ""
}

func test_cuda_memory_allocation() (bool, string) {
    count, ok, _ := cuda_get_device_count()
    if !ok || count <= 0 {
        return false, "no CUDA devices"
    }
    
    ok, err := cuda_set_device(0)
    if !ok {
        return false, err
    }
    
    ptr, ok, err := cuda_malloc(1024 * 1024)
    if !ok {
        return false, err
    }
    
    if ptr == 0 {
        return false, "invalid pointer"
    }
    
    ok, err = cuda_free(ptr)
    if !ok {
        return false, err
    }
    
    println("✓ CUDA Memory Allocation OK")
    return true, ""
}

func test_cuda_stream_management() (bool, string) {
    count, ok, _ := cuda_get_device_count()
    if !ok || count <= 0 {
        return false, "no CUDA devices"
    }
    
    ok, err := cuda_set_device(0)
    if !ok {
        return false, err
    }
    
    pool := new_stream_pool(4)
    ok, err = stream_pool_init(&pool)
    if !ok {
        return false, err
    }
    
    stream, ok, err := stream_pool_acquire(&pool)
    if !ok {
        return false, err
    }
    
    ok, err = stream_pool_release(&pool, stream)
    if !ok {
        return false, err
    }
    
    ok, err = stream_pool_finalize(&pool)
    if !ok {
        return false, err
    }
    
    println("✓ CUDA Stream Management OK")
    return true, ""
}

func test_cublas_initialization() (bool, string) {
    count, ok, _ := cuda_get_device_count()
    if !ok || count <= 0 {
        return false, "no CUDA devices"
    }
    
    ok, err := cuda_set_device(0)
    if !ok {
        return false, err
    }
    
    handle, ok, err := cublas_create()
    if !ok {
        return false, err
    }
    
    if !handle.is_valid {
        return false, "handle invalid"
    }
    
    ok, err = cublas_destroy(&handle)
    if !ok {
        return false, err
    }
    
    println("✓ cuBLAS Initialization OK")
    return true, ""
}

func main() int {
    println("=== GPU Backend Test Suite ===")
    println("")
    
    result, msg := test_cuda_device_discovery()
    if !result {
        println("✗ Device Discovery Failed: " + msg)
        return 1
    }
    
    result, msg = test_cuda_memory_allocation()
    if !result {
        println("✗ Memory Allocation Failed: " + msg)
        return 1
    }
    
    result, msg = test_cuda_stream_management()
    if !result {
        println("✗ Stream Management Failed: " + msg)
        return 1
    }
    
    result, msg = test_cublas_initialization()
    if !result {
        println("✗ cuBLAS Initialization Failed: " + msg)
        return 1
    }
    
    println("")
    println("=== All Tests Passed ✓ ===")
    return 0
}
