package neurx.gate0_integration_test
use std.vec.vec
use neurx.device.abi
use neurx.device.device_bridge
struct vector_add_test_config {
    int vector_size
    float tolerance
    bool verbose
}
func vector_add_test_config_default() vector_add_test_config {
    config := vector_add_test_config {
        vector_size: 100000,
        tolerance: 1e-5,
        verbose: true,
    }
    return config
}
func test_basic_workflow(config: vector_add_test_config) (bool, string) {
    device_bridge.device_bridge_init()
    shape := vec[int]()
    shape.push(config.vector_size)
    tensor_a, ok_a, err_a := abi.device_alloc_tensor(0, shape, 0)
    if !ok_a {
        return false, "Failed to allocate tensor A: " + err_a
    }
    defer abi.device_free_tensor(&tensor_a)
    tensor_b, ok_b, err_b := abi.device_alloc_tensor(0, shape, 0)
    if !ok_b {
        return false, "Failed to allocate tensor B: " + err_b
    }
    defer abi.device_free_tensor(&tensor_b)
    tensor_c, ok_c, err_c := abi.device_alloc_tensor(0, shape, 0)
    if !ok_c {
        return false, "Failed to allocate tensor C: " + err_c
    }
    defer abi.device_free_tensor(&tensor_c)
    stream, ok_stream, err_stream := abi.device_create_stream(0)
    if !ok_stream {
        return false, "Failed to create stream: " + err_stream
    }
    return true, "Basic workflow test passed"
}
func test_memory_management(config: vector_add_test_config) (bool, string) {
    free_before, total_before, ok_before, err_before := abi.device_get_memory_info(0)
    if !ok_before {
        return false, "Failed to get initial memory info: " + err_before
    }
    tensor_count := 10
    tensor_size := config.vector_size
    shape := vec[int]()
    shape.push(tensor_size)
    tensors := vec[abi.device_tensor]()
    int i = 0
    for i < tensor_count {
        tensor, ok, err := abi.device_alloc_tensor(0, shape, 0)
        if !ok {
            return false, "Failed to allocate tensor " + i as string + ": " + err
        }
        tensors.push(tensor)
        i = i + 1
    }
    free_after, total_after, ok_after, err_after := abi.device_get_memory_info(0)
    if !ok_after {
        return false, "Failed to get memory info after allocation: " + err_after
    }
    allocated := free_before - free_after
    expected_size := tensor_count * tensor_size * 4  
    if allocated < expected_size {
        return false, "Allocated memory less than expected"
    }
    i = 0
    for i < tensors.len() {
        tensor := tensors[i]
        ok, err := abi.device_free_tensor(&tensor)
        if !ok {
            return false, "Failed to free tensor " + i as string + ": " + err
        }
        i = i + 1
    }
    return true, "Memory management test passed"
}
func test_tensor_operations(config: vector_add_test_config) (bool, string) {
    shape := vec[int]()
    shape.push(config.vector_size)
    tensor_a, ok_a, err_a := abi.device_alloc_tensor(0, shape, 0)
    if !ok_a {
        return false, "Failed to create tensor A: " + err_a
    }
    defer abi.device_free_tensor(&tensor_a)
    tensor_b, ok_b, err_b := abi.device_alloc_tensor(0, shape, 0)
    if !ok_b {
        return false, "Failed to create tensor B: " + err_b
    }
    defer abi.device_free_tensor(&tensor_b)
    tensor_c, ok_c, err_c := abi.device_alloc_tensor(0, shape, 0)
    if !ok_c {
        return false, "Failed to create tensor C: " + err_c
    }
    defer abi.device_free_tensor(&tensor_c)
    stream, ok_stream, err_stream := abi.device_create_stream(0)
    if !ok_stream {
        return false, "Failed to create stream: " + err_stream
    }
    ok_add, err_add := abi.device_vector_add(tensor_a, tensor_b, tensor_c, stream)
    if !ok_add {
        return false, "Vector add failed: " + err_add
    }
    ok_sync, err_sync := abi.device_synchronize(0)
    if !ok_sync {
        return false, "Failed to synchronize device: " + err_sync
    }
    return true, "Tensor operations test passed"
}
func test_scale_and_performance(config: vector_add_test_config) (bool, string) {
    sizes := vec[int]()
    sizes.push(1000)
    sizes.push(10000)
    sizes.push(100000)
    sizes.push(1000000)
    int i = 0
    for i < sizes.len() {
        size := sizes[i]
        shape := vec[int]()
        shape.push(size)
        tensor_a, ok_a, err_a := abi.device_alloc_tensor(0, shape, 0)
        if !ok_a {
            return false, "Failed to allocate tensor at size " + size as string
        }
        defer abi.device_free_tensor(&tensor_a)
        tensor_b, ok_b, err_b := abi.device_alloc_tensor(0, shape, 0)
        if !ok_b {
            return false, "Failed to allocate tensor at size " + size as string
        }
        defer abi.device_free_tensor(&tensor_b)
        tensor_c, ok_c, err_c := abi.device_alloc_tensor(0, shape, 0)
        if !ok_c {
            return false, "Failed to allocate output tensor at size " + size as string
        }
        defer abi.device_free_tensor(&tensor_c)
        stream, ok_stream, _ := abi.device_create_stream(0)
        if !ok_stream {
            return false, "Failed to create stream"
        }
        ok_add, _ := abi.device_vector_add(tensor_a, tensor_b, tensor_c, stream)
        if !ok_add {
            return false, "Vector add failed at size " + size as string
        }
        i = i + 1
    }
    return true, "Scale and performance test passed"
}
func run_all_tests() (int, int, string) {
    config := vector_add_test_config_default()
    tests_passed := 0
    tests_failed := 0
    results := vec[string]()
    ok1, msg1 := test_basic_workflow(config)
    if ok1 {
        tests_passed = tests_passed + 1
        results.push("✓ Test 1 (Basic Workflow): " + msg1)
    } else {
        tests_failed = tests_failed + 1
        results.push("✗ Test 1 (Basic Workflow): " + msg1)
    }
    ok2, msg2 := test_memory_management(config)
    if ok2 {
        tests_passed = tests_passed + 1
        results.push("✓ Test 2 (Memory Management): " + msg2)
    } else {
        tests_failed = tests_failed + 1
        results.push("✗ Test 2 (Memory Management): " + msg2)
    }
    ok3, msg3 := test_tensor_operations(config)
    if ok3 {
        tests_passed = tests_passed + 1
        results.push("✓ Test 3 (Tensor Operations): " + msg3)
    } else {
        tests_failed = tests_failed + 1
        results.push("✗ Test 3 (Tensor Operations): " + msg3)
    }
    ok4, msg4 := test_scale_and_performance(config)
    if ok4 {
        tests_passed = tests_passed + 1
        results.push("✓ Test 4 (Scale and Performance): " + msg4)
    } else {
        tests_failed = tests_failed + 1
        results.push("✗ Test 4 (Scale and Performance): " + msg4)
    }
    summary := "Gate 0 Integration Test Summary: " + tests_passed as string + " passed, " + tests_failed as string + " failed"
    int i = 0
    for i < results.len() {
        summary = summary + "\n" + results[i]
        i = i + 1
    }
    return tests_passed, tests_failed, summary
}
func main() {
    passed, failed, summary := run_all_tests()
}
