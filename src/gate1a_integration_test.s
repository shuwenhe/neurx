package neurx.gate1a_test

use neurx.device.abi
use neurx.device.device_bridge
use neurx.device.device_tensor_manager

struct gate1a_test_config {
    int initial_tensor_count
    int64 pool_size
    bool enable_fragmentation_test
    bool verbose
}

func test_tensor_reshape() (bool, string) {
    device_bridge.device_bridge_init()
    device_tensor_manager.device_tensor_manager_init(0, 1000000000)

    shape := vec[int]()
    shape.push(1000)
    shape.push(100)

    tensor, success, err := device_tensor_manager.device_tensor_manager_allocate(100000, 0)
    if !success {
        return false, "Failed to allocate tensor: " + err
    }

    new_shape := vec[int]()
    new_shape.push(100)
    new_shape.push(1000)

    reshaped, success, err := device_tensor_manager.device_tensor_reshape(tensor, new_shape)
    if !success {
        return false, "Failed to reshape tensor: " + err
    }

    if reshaped.element_count != 100000 {
        return false, "Reshape: element count mismatch"
    }

    if reshaped.shape.len() != 2 {
        return false, "Reshape: shape dimension mismatch"
    }

    return true, ""
}

func test_tensor_view() (bool, string) {
    device_bridge.device_bridge_init()
    device_tensor_manager.device_tensor_manager_init(0, 1000000000)

    tensor, success, err := device_tensor_manager.device_tensor_manager_allocate(10000, 0)
    if !success {
        return false, "Failed to allocate tensor"
    }

    view, success, err := device_tensor_manager.device_tensor_view(tensor, 1000, 5000)
    if !success {
        return false, "Failed to create view: " + err
    }

    if view.element_count != 5000 {
        return false, "View: element count mismatch"
    }

    if view.is_view != true {
        return false, "View: is_view flag not set"
    }

    return true, ""
}

func test_tensor_transpose() (bool, string) {
    device_bridge.device_bridge_init()
    device_tensor_manager.device_tensor_manager_init(0, 1000000000)

    tensor, success, err := device_tensor_manager.device_tensor_manager_allocate(100000, 0)
    if !success {
        return false, "Failed to allocate tensor"
    }

    axes := vec[int]()
    axes.push(1)
    axes.push(0)

    transposed, success, err := device_tensor_manager.device_tensor_transpose(tensor, axes)
    if !success {
        return false, "Failed to transpose tensor: " + err
    }

    if transposed.element_count != 100000 {
        return false, "Transpose: element count mismatch"
    }

    return true, ""
}

func test_tensor_ref_counting() (bool, string) {
    device_bridge.device_bridge_init()
    device_tensor_manager.device_tensor_manager_init(0, 1000000000)

    tensor, success, err := device_tensor_manager.device_tensor_manager_allocate(10000, 0)
    if !success {
        return false, "Failed to allocate tensor"
    }

    initial_ref := tensor.ref_count

    acquired := device_tensor_manager.device_tensor_ref_acquire(tensor)
    if acquired.ref_count != initial_ref + 1 {
        return false, "Ref counting: acquire failed"
    }

    success, err = device_tensor_manager.device_tensor_ref_release(acquired)
    if !success {
        return false, "Ref counting: release failed"
    }

    return true, ""
}

func test_tensor_memory_pool() (bool, string) {
    device_bridge.device_bridge_init()
    device_tensor_manager.device_tensor_manager_init(0, 1000000000)

    total, used, frag, success, err := device_tensor_manager.device_tensor_get_stats()
    if !success {
        return false, "Failed to get stats"
    }

    if total != 1000000000 {
        return false, "Memory pool: total size mismatch"
    }

    tensor1, success, _ := device_tensor_manager.device_tensor_manager_allocate(100000, 0)
    if !success {
        return false, "Failed to allocate tensor 1"
    }

    tensor2, success, _ := device_tensor_manager.device_tensor_manager_allocate(100000, 0)
    if !success {
        return false, "Failed to allocate tensor 2"
    }

    total, used, frag, success, _ = device_tensor_manager.device_tensor_get_stats()
    if used <= 0 {
        return false, "Memory pool: used size not updated"
    }

    return true, ""
}

func test_view_chaining() (bool, string) {
    device_bridge.device_bridge_init()
    device_tensor_manager.device_tensor_manager_init(0, 1000000000)

    tensor, success, _ := device_tensor_manager.device_tensor_manager_allocate(10000, 0)
    if !success {
        return false, "Failed to allocate tensor"
    }

    view1, success, _ := device_tensor_manager.device_tensor_view(tensor, 0, 5000)
    if !success {
        return false, "Failed to create view 1"
    }

    view2, success, _ := device_tensor_manager.device_tensor_view(view1, 0, 2500)
    if !success {
        return false, "Failed to create view 2"
    }

    if view2.element_count != 2500 {
        return false, "View chaining: element count mismatch"
    }

    if view2.ref_count < 2 {
        return false, "View chaining: ref count not incremented"
    }

    return true, ""
}

func test_mixed_operations() (bool, string) {
    device_bridge.device_bridge_init()
    device_tensor_manager.device_tensor_manager_init(0, 1000000000)

    tensor, success, _ := device_tensor_manager.device_tensor_manager_allocate(100000, 0)
    if !success {
        return false, "Failed to allocate tensor"
    }

    view, success, _ := device_tensor_manager.device_tensor_view(tensor, 10000, 50000)
    if !success {
        return false, "Failed to create view"
    }

    new_shape := vec[int]()
    new_shape.push(100)
    new_shape.push(500)

    reshaped, success, _ := device_tensor_manager.device_tensor_reshape(view, new_shape)
    if !success {
        return false, "Failed to reshape view"
    }

    acquired := device_tensor_manager.device_tensor_ref_acquire(reshaped)
    memory_usage := device_tensor_manager.device_tensor_get_memory_usage(acquired)
    if memory_usage <= 0 {
        return false, "Mixed operations: memory usage calculation failed"
    }

    return true, ""
}

func run_all_tests() (int, int, string) {
    passed := 0
    failed := 0
    summary := ""

    success, err := test_tensor_reshape()
    if success {
        passed = passed + 1
        summary = summary + "\n✓ Test 1 (Reshape): Tensor reshape test passed"
    } else {
        failed = failed + 1
        summary = summary + "\n✗ Test 1 (Reshape): " + err
    }

    success, err = test_tensor_view()
    if success {
        passed = passed + 1
        summary = summary + "\n✓ Test 2 (View): Tensor view test passed"
    } else {
        failed = failed + 1
        summary = summary + "\n✗ Test 2 (View): " + err
    }

    success, err = test_tensor_transpose()
    if success {
        passed = passed + 1
        summary = summary + "\n✓ Test 3 (Transpose): Tensor transpose test passed"
    } else {
        failed = failed + 1
        summary = summary + "\n✗ Test 3 (Transpose): " + err
    }

    success, err = test_tensor_ref_counting()
    if success {
        passed = passed + 1
        summary = summary + "\n✓ Test 4 (Ref Counting): Tensor ref counting test passed"
    } else {
        failed = failed + 1
        summary = summary + "\n✗ Test 4 (Ref Counting): " + err
    }

    success, err = test_tensor_memory_pool()
    if success {
        passed = passed + 1
        summary = summary + "\n✓ Test 5 (Memory Pool): Tensor memory pool test passed"
    } else {
        failed = failed + 1
        summary = summary + "\n✗ Test 5 (Memory Pool): " + err
    }

    success, err = test_view_chaining()
    if success {
        passed = passed + 1
        summary = summary + "\n✓ Test 6 (View Chaining): Tensor view chaining test passed"
    } else {
        failed = failed + 1
        summary = summary + "\n✗ Test 6 (View Chaining): " + err
    }

    success, err = test_mixed_operations()
    if success {
        passed = passed + 1
        summary = summary + "\n✓ Test 7 (Mixed Ops): Mixed tensor operations test passed"
    } else {
        failed = failed + 1
        summary = summary + "\n✗ Test 7 (Mixed Ops): " + err
    }

    device_tensor_manager.device_tensor_manager_finalize()
    device_bridge.device_bridge_finalize()

    return passed, failed, summary
}

func main() {
    passed, failed, summary := run_all_tests()
    summary_line := "Gate 1A Integration Test Summary: " + "" + " passed, " + "" + " failed"
    println(summary_line)
    println(summary)
    println("Total: " + "" + "/" + "" + " tests passed")
}
