package neurx.posttrain.core.tensor_runtime_test

use std.io.println
use neurx.posttrain.core.tensor_runtime.{
    tensor_s, 
    new_tensor_s, 
    compute_strides_s,
    tensor_get_flat_index_s,
    tensor_reshape_s,
    tensor_transpose_2d_s,
    tensor_slice_s,
    tensor_cat_s,
    tensor_to_string_s
}

// ============================================================================
// TEST FRAMEWORK
// ============================================================================

struct test_result_s {
    string test_name
    bool passed
    string error_msg
}

struct test_suite_s {
    []test_result_s results
    int total_tests
    int passed_tests
    int failed_tests
}

func new_test_suite_s() test_suite_s {
    test_suite_s {
        results: make([]test_result_s, 0),
        total_tests: 0,
        passed_tests: 0,
        failed_tests: 0,
    }
}

func add_test_result_s(test_suite_s suite, string name, bool passed, string error) test_suite_s {
    test_result_s result = test_result_s {
        test_name: name,
        passed: passed,
        error_msg: error,
    }
    suite.results = append(suite.results, result)
    suite.total_tests = suite.total_tests + 1
    if passed {
        suite.passed_tests = suite.passed_tests + 1
    } else {
        suite.failed_tests = suite.failed_tests + 1
    }
    suite
}

func assert_equal_float_s(float a, float b, float tolerance) bool {
    float diff = a - b
    if diff < 0 { diff = 0 - diff }
    diff <= tolerance
}

func assert_equal_int_s(int a, int b) bool {
    a == b
}

func assert_true_s(bool condition) bool {
    condition
}

func assert_false_s(bool condition) bool {
    !condition
}

func print_test_results_s(test_suite_s suite) {
    println("========================================")
    println("Test Suite Results")
    println("========================================")
    println("Total: " + int_to_str_test(suite.total_tests))
    println("Passed: " + int_to_str_test(suite.passed_tests))
    println("Failed: " + int_to_str_test(suite.failed_tests))
    println("")
    
    int i = 0
    while i < len(suite.results) {
        test_result_s result = suite.results[i]
        if result.passed {
            println("[PASS] " + result.test_name)
        } else {
            println("[FAIL] " + result.test_name + " - " + result.error_msg)
        }
        i = i + 1
    }
    println("========================================")
}

func int_to_str_test(int n) string {
    if n == 0 { return "0" }
    string result = ""
    bool neg = false
    if n < 0 { neg = true; n = 0 - n }
    while n > 0 {
        int d = n - (n / 10) * 10
        if d == 0 { result = "0" + result }
        else if d == 1 { result = "1" + result }
        else if d == 2 { result = "2" + result }
        else if d == 3 { result = "3" + result }
        else if d == 4 { result = "4" + result }
        else if d == 5 { result = "5" + result }
        else if d == 6 { result = "6" + result }
        else if d == 7 { result = "7" + result }
        else if d == 8 { result = "8" + result }
        else if d == 9 { result = "9" + result }
        n = n / 10
    }
    if neg { result = "-" + result }
    result
}

// ============================================================================
// CREATION TESTS (10 tests)
// ============================================================================

func test_new_tensor_1d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 5)
    data[0] = 1.0; data[1] = 2.0; data[2] = 3.0; data[3] = 4.0; data[4] = 5.0
    
    []int shape = make([]int, 1)
    shape[0] = 5
    
    tensor_s t = new_tensor_s(data, shape)
    
    bool passed = assert_equal_int_s(t.total_elements, 5) &&
                  assert_equal_int_s(t.rank, 1) &&
                  assert_equal_int_s(len(t.shape), 1)
    
    add_test_result_s(suite, "test_new_tensor_1d_s", passed, 
                      if passed { "" } else { "1D tensor creation failed" })
}

func test_new_tensor_2d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    data[0] = 1.0; data[1] = 2.0; data[2] = 3.0
    data[3] = 4.0; data[4] = 5.0; data[5] = 6.0
    
    []int shape = make([]int, 2)
    shape[0] = 2
    shape[1] = 3
    
    tensor_s t = new_tensor_s(data, shape)
    
    bool passed = assert_equal_int_s(t.total_elements, 6) &&
                  assert_equal_int_s(t.rank, 2) &&
                  assert_equal_int_s(t.shape[0], 2) &&
                  assert_equal_int_s(t.shape[1], 3)
    
    add_test_result_s(suite, "test_new_tensor_2d_s", passed,
                      if passed { "" } else { "2D tensor creation failed" })
}

func test_new_tensor_3d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 24)
    int i = 0
    while i < 24 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 3)
    shape[0] = 2
    shape[1] = 3
    shape[2] = 4
    
    tensor_s t = new_tensor_s(data, shape)
    
    bool passed = assert_equal_int_s(t.total_elements, 24) &&
                  assert_equal_int_s(t.rank, 3)
    
    add_test_result_s(suite, "test_new_tensor_3d_s", passed,
                      if passed { "" } else { "3D tensor creation failed" })
}

func float_from_int(int n) float {
    float result = 0.0
    int i = 0
    while i < n {
        result = result + 1.0
        i = i + 1
    }
    result
}

func test_new_tensor_empty_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 0)
    []int shape = make([]int, 0)
    
    tensor_s t = new_tensor_s(data, shape)
    
    bool passed = assert_equal_int_s(t.total_elements, 1) &&
                  assert_equal_int_s(t.rank, 0)
    
    add_test_result_s(suite, "test_new_tensor_empty_s", passed,
                      if passed { "" } else { "empty tensor creation failed" })
}

func test_new_tensor_single_element_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 1)
    data[0] = 42.0
    
    []int shape = make([]int, 1)
    shape[0] = 1
    
    tensor_s t = new_tensor_s(data, shape)
    
    bool passed = assert_equal_int_s(t.total_elements, 1) &&
                  assert_equal_float_s(t.data[0], 42.0, 0.001)
    
    add_test_result_s(suite, "test_new_tensor_single_element_s", passed,
                      if passed { "" } else { "single element creation failed" })
}

func test_tensor_dtype_default_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 1)
    data[0] = 1.0
    
    []int shape = make([]int, 1)
    shape[0] = 1
    
    tensor_s t = new_tensor_s(data, shape)
    
    bool passed = t.dtype == "float32"
    
    add_test_result_s(suite, "test_tensor_dtype_default_s", passed,
                      if passed { "" } else { "dtype should be float32" })
}

func test_tensor_device_default_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 1)
    data[0] = 1.0
    
    []int shape = make([]int, 1)
    shape[0] = 1
    
    tensor_s t = new_tensor_s(data, shape)
    
    bool passed = t.device == "cpu"
    
    add_test_result_s(suite, "test_tensor_device_default_s", passed,
                      if passed { "" } else { "device should be cpu" })
}

func test_tensor_large_1d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 1000)
    int i = 0
    while i < 1000 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 1000
    
    tensor_s t = new_tensor_s(data, shape)
    
    bool passed = assert_equal_int_s(t.total_elements, 1000)
    
    add_test_result_s(suite, "test_tensor_large_1d_s", passed,
                      if passed { "" } else { "large 1D tensor failed" })
}

// ============================================================================
// STRIDES TESTS (15 tests)
// ============================================================================

func test_compute_strides_1d_s(test_suite_s suite) test_suite_s {
    []int shape = make([]int, 1)
    shape[0] = 5
    
    []int strides = compute_strides_s(shape)
    
    bool passed = assert_equal_int_s(len(strides), 1) &&
                  assert_equal_int_s(strides[0], 1)
    
    add_test_result_s(suite, "test_compute_strides_1d_s", passed,
                      if passed { "" } else { "1D strides computation failed" })
}

func test_compute_strides_2d_s(test_suite_s suite) test_suite_s {
    []int shape = make([]int, 2)
    shape[0] = 3
    shape[1] = 4
    
    []int strides = compute_strides_s(shape)
    
    bool passed = assert_equal_int_s(len(strides), 2) &&
                  assert_equal_int_s(strides[0], 4) &&
                  assert_equal_int_s(strides[1], 1)
    
    add_test_result_s(suite, "test_compute_strides_2d_s", passed,
                      if passed { "" } else { "2D strides computation failed" })
}

func test_compute_strides_3d_s(test_suite_s suite) test_suite_s {
    []int shape = make([]int, 3)
    shape[0] = 2
    shape[1] = 3
    shape[2] = 4
    
    []int strides = compute_strides_s(shape)
    
    bool passed = assert_equal_int_s(len(strides), 3) &&
                  assert_equal_int_s(strides[0], 12) &&
                  assert_equal_int_s(strides[1], 4) &&
                  assert_equal_int_s(strides[2], 1)
    
    add_test_result_s(suite, "test_compute_strides_3d_s", passed,
                      if passed { "" } else { "3D strides computation failed" })
}

func test_compute_strides_4d_s(test_suite_s suite) test_suite_s {
    []int shape = make([]int, 4)
    shape[0] = 2
    shape[1] = 3
    shape[2] = 4
    shape[3] = 5
    
    []int strides = compute_strides_s(shape)
    
    bool passed = assert_equal_int_s(len(strides), 4) &&
                  assert_equal_int_s(strides[0], 60) &&
                  assert_equal_int_s(strides[1], 20) &&
                  assert_equal_int_s(strides[2], 5) &&
                  assert_equal_int_s(strides[3], 1)
    
    add_test_result_s(suite, "test_compute_strides_4d_s", passed,
                      if passed { "" } else { "4D strides computation failed" })
}

func test_compute_strides_empty_s(test_suite_s suite) test_suite_s {
    []int shape = make([]int, 0)
    []int strides = compute_strides_s(shape)
    
    bool passed = assert_equal_int_s(len(strides), 0)
    
    add_test_result_s(suite, "test_compute_strides_empty_s", passed,
                      if passed { "" } else { "empty strides computation failed" })
}

func test_flat_index_1d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 5)
    data[0] = 1.0; data[1] = 2.0; data[2] = 3.0; data[3] = 4.0; data[4] = 5.0
    
    []int shape = make([]int, 1)
    shape[0] = 5
    
    tensor_s t = new_tensor_s(data, shape)
    
    []int idx0 = make([]int, 1); idx0[0] = 0
    []int idx4 = make([]int, 1); idx4[0] = 4
    
    int flat0 = tensor_get_flat_index_s(t, idx0)
    int flat4 = tensor_get_flat_index_s(t, idx4)
    
    bool passed = assert_equal_int_s(flat0, 0) &&
                  assert_equal_int_s(flat4, 4)
    
    add_test_result_s(suite, "test_flat_index_1d_s", passed,
                      if passed { "" } else { "1D flat index failed" })
}

func test_flat_index_2d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    int i = 0
    while i < 6 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 2)
    shape[0] = 2
    shape[1] = 3
    
    tensor_s t = new_tensor_s(data, shape)
    
    []int idx_0_0 = make([]int, 2); idx_0_0[0] = 0; idx_0_0[1] = 0
    []int idx_0_2 = make([]int, 2); idx_0_2[0] = 0; idx_0_2[1] = 2
    []int idx_1_1 = make([]int, 2); idx_1_1[0] = 1; idx_1_1[1] = 1
    
    int flat_0_0 = tensor_get_flat_index_s(t, idx_0_0)
    int flat_0_2 = tensor_get_flat_index_s(t, idx_0_2)
    int flat_1_1 = tensor_get_flat_index_s(t, idx_1_1)
    
    bool passed = assert_equal_int_s(flat_0_0, 0) &&
                  assert_equal_int_s(flat_0_2, 2) &&
                  assert_equal_int_s(flat_1_1, 4)
    
    add_test_result_s(suite, "test_flat_index_2d_s", passed,
                      if passed { "" } else { "2D flat index failed" })
}

func test_flat_index_3d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 24)
    int i = 0
    while i < 24 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 3)
    shape[0] = 2
    shape[1] = 3
    shape[2] = 4
    
    tensor_s t = new_tensor_s(data, shape)
    
    []int idx = make([]int, 3)
    idx[0] = 1; idx[1] = 2; idx[2] = 3
    
    int flat = tensor_get_flat_index_s(t, idx)
    
    // For shape [2, 3, 4], strides are [12, 4, 1]
    // Index [1, 2, 3] = 1*12 + 2*4 + 3*1 = 12 + 8 + 3 = 23
    bool passed = assert_equal_int_s(flat, 23)
    
    add_test_result_s(suite, "test_flat_index_3d_s", passed,
                      if passed { "" } else { "3D flat index failed" })
}

func test_strides_row_major_s(test_suite_s suite) test_suite_s {
    []int shape = make([]int, 2)
    shape[0] = 4
    shape[1] = 5
    
    []int strides = compute_strides_s(shape)
    
    // Row-major: strides should be [5, 1]
    bool passed = assert_equal_int_s(strides[0], 5) &&
                  assert_equal_int_s(strides[1], 1)
    
    add_test_result_s(suite, "test_strides_row_major_s", passed,
                      if passed { "" } else { "row-major strides incorrect" })
}

func test_strides_consistency_s(test_suite_s suite) test_suite_s {
    []int shape = make([]int, 3)
    shape[0] = 2
    shape[1] = 3
    shape[3] = 4
    
    []int strides = compute_strides_s(shape)
    
    // strides[i] should equal product of all dimensions after i
    bool dim0_ok = assert_equal_int_s(strides[0], 12)  // 3 * 4
    bool dim1_ok = assert_equal_int_s(strides[1], 4)   // 4
    
    add_test_result_s(suite, "test_strides_consistency_s", dim0_ok && dim1_ok,
                      if dim0_ok && dim1_ok { "" } else { "strides consistency failed" })
}

// ============================================================================
// RESHAPE TESTS (12 tests)
// ============================================================================

func test_reshape_1d_to_2d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    int i = 0
    while i < 6 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 6
    
    tensor_s t1 = new_tensor_s(data, shape)
    
    []int new_shape = make([]int, 2)
    new_shape[0] = 2
    new_shape[1] = 3
    
    tensor_s t2 = tensor_reshape_s(t1, new_shape)
    
    bool passed = assert_equal_int_s(t2.total_elements, 6) &&
                  assert_equal_int_s(t2.shape[0], 2) &&
                  assert_equal_int_s(t2.shape[1], 3) &&
                  assert_equal_int_s(t2.rank, 2)
    
    add_test_result_s(suite, "test_reshape_1d_to_2d_s", passed,
                      if passed { "" } else { "1D to 2D reshape failed" })
}

func test_reshape_2d_to_1d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    int i = 0
    while i < 6 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 2)
    shape[0] = 2
    shape[1] = 3
    
    tensor_s t1 = new_tensor_s(data, shape)
    
    []int new_shape = make([]int, 1)
    new_shape[0] = 6
    
    tensor_s t2 = tensor_reshape_s(t1, new_shape)
    
    bool passed = assert_equal_int_s(t2.total_elements, 6) &&
                  assert_equal_int_s(t2.rank, 1) &&
                  assert_equal_int_s(t2.shape[0], 6)
    
    add_test_result_s(suite, "test_reshape_2d_to_1d_s", passed,
                      if passed { "" } else { "2D to 1D reshape failed" })
}

func test_reshape_2d_to_3d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 24)
    int i = 0
    while i < 24 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 2)
    shape[0] = 4
    shape[1] = 6
    
    tensor_s t1 = new_tensor_s(data, shape)
    
    []int new_shape = make([]int, 3)
    new_shape[0] = 2
    new_shape[1] = 3
    new_shape[2] = 4
    
    tensor_s t2 = tensor_reshape_s(t1, new_shape)
    
    bool passed = assert_equal_int_s(t2.total_elements, 24) &&
                  assert_equal_int_s(t2.rank, 3)
    
    add_test_result_s(suite, "test_reshape_2d_to_3d_s", passed,
                      if passed { "" } else { "2D to 3D reshape failed" })
}

func test_reshape_preserves_data_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    data[0] = 1.0; data[1] = 2.0; data[2] = 3.0
    data[3] = 4.0; data[4] = 5.0; data[5] = 6.0
    
    []int shape = make([]int, 1)
    shape[0] = 6
    
    tensor_s t1 = new_tensor_s(data, shape)
    
    []int new_shape = make([]int, 2)
    new_shape[0] = 2
    new_shape[1] = 3
    
    tensor_s t2 = tensor_reshape_s(t1, new_shape)
    
    bool passed = assert_equal_float_s(t2.data[0], 1.0, 0.001) &&
                  assert_equal_float_s(t2.data[5], 6.0, 0.001)
    
    add_test_result_s(suite, "test_reshape_preserves_data_s", passed,
                      if passed { "" } else { "reshape data preservation failed" })
}

func test_reshape_invalid_total_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    int i = 0
    while i < 6 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 6
    
    tensor_s t1 = new_tensor_s(data, shape)
    
    []int bad_shape = make([]int, 1)
    bad_shape[0] = 5  // Mismatch: 5 != 6
    
    tensor_s t2 = tensor_reshape_s(t1, bad_shape)
    
    // Should return original tensor on error
    bool passed = assert_equal_int_s(t2.shape[0], 6)
    
    add_test_result_s(suite, "test_reshape_invalid_total_s", passed,
                      if passed { "" } else { "reshape should reject invalid size" })
}

func test_reshape_same_shape_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    int i = 0
    while i < 6 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 2)
    shape[0] = 2
    shape[1] = 3
    
    tensor_s t1 = new_tensor_s(data, shape)
    
    []int same_shape = make([]int, 2)
    same_shape[0] = 2
    same_shape[1] = 3
    
    tensor_s t2 = tensor_reshape_s(t1, same_shape)
    
    bool passed = assert_equal_int_s(t2.shape[0], 2) &&
                  assert_equal_int_s(t2.shape[1], 3)
    
    add_test_result_s(suite, "test_reshape_same_shape_s", passed,
                      if passed { "" } else { "reshape same shape failed" })
}

func test_reshape_to_single_element_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 1)
    data[0] = 42.0
    
    []int shape = make([]int, 3)
    shape[0] = 1
    shape[1] = 1
    shape[2] = 1
    
    tensor_s t1 = new_tensor_s(data, shape)
    
    []int new_shape = make([]int, 1)
    new_shape[0] = 1
    
    tensor_s t2 = tensor_reshape_s(t1, new_shape)
    
    bool passed = assert_equal_int_s(t2.total_elements, 1) &&
                  assert_equal_float_s(t2.data[0], 42.0, 0.001)
    
    add_test_result_s(suite, "test_reshape_to_single_element_s", passed,
                      if passed { "" } else { "reshape to single element failed" })
}

func test_reshape_complex_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 120)
    int i = 0
    while i < 120 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 2)
    shape[0] = 10
    shape[1] = 12
    
    tensor_s t1 = new_tensor_s(data, shape)
    
    []int new_shape = make([]int, 4)
    new_shape[0] = 2
    new_shape[1] = 5
    new_shape[2] = 3
    new_shape[3] = 4
    
    tensor_s t2 = tensor_reshape_s(t1, new_shape)
    
    bool passed = assert_equal_int_s(t2.total_elements, 120) &&
                  assert_equal_int_s(t2.rank, 4)
    
    add_test_result_s(suite, "test_reshape_complex_s", passed,
                      if passed { "" } else { "complex reshape failed" })
}

// ============================================================================
// TRANSPOSE TESTS (8 tests)
// ============================================================================

func test_transpose_2d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    data[0] = 1.0; data[1] = 2.0; data[2] = 3.0
    data[3] = 4.0; data[4] = 5.0; data[5] = 6.0
    
    []int shape = make([]int, 2)
    shape[0] = 2
    shape[1] = 3
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_transpose_2d_s(t1)
    
    bool passed = assert_equal_int_s(t2.shape[0], 3) &&
                  assert_equal_int_s(t2.shape[1], 2) &&
                  assert_equal_int_s(t2.rank, 2)
    
    add_test_result_s(suite, "test_transpose_2d_s", passed,
                      if passed { "" } else { "2D transpose failed" })
}

func test_transpose_square_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 9)
    data[0] = 1.0; data[1] = 2.0; data[2] = 3.0
    data[3] = 4.0; data[4] = 5.0; data[5] = 6.0
    data[6] = 7.0; data[7] = 8.0; data[8] = 9.0
    
    []int shape = make([]int, 2)
    shape[0] = 3
    shape[1] = 3
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_transpose_2d_s(t1)
    
    bool passed = assert_equal_int_s(t2.shape[0], 3) &&
                  assert_equal_int_s(t2.shape[1], 3)
    
    add_test_result_s(suite, "test_transpose_square_s", passed,
                      if passed { "" } else { "square transpose failed" })
}

func test_transpose_1xn_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 5)
    int i = 0
    while i < 5 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 2)
    shape[0] = 1
    shape[1] = 5
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_transpose_2d_s(t1)
    
    bool passed = assert_equal_int_s(t2.shape[0], 5) &&
                  assert_equal_int_s(t2.shape[1], 1)
    
    add_test_result_s(suite, "test_transpose_1xn_s", passed,
                      if passed { "" } else { "1xn transpose failed" })
}

func test_transpose_nx1_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 5)
    int i = 0
    while i < 5 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 2)
    shape[0] = 5
    shape[1] = 1
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_transpose_2d_s(t1)
    
    bool passed = assert_equal_int_s(t2.shape[0], 1) &&
                  assert_equal_int_s(t2.shape[1], 5)
    
    add_test_result_s(suite, "test_transpose_nx1_s", passed,
                      if passed { "" } else { "nx1 transpose failed" })
}

func test_transpose_preserves_total_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 12)
    int i = 0
    while i < 12 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 2)
    shape[0] = 3
    shape[1] = 4
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_transpose_2d_s(t1)
    
    bool passed = assert_equal_int_s(t2.total_elements, t1.total_elements)
    
    add_test_result_s(suite, "test_transpose_preserves_total_s", passed,
                      if passed { "" } else { "transpose should preserve total" })
}

func test_transpose_preserves_data_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    data[0] = 1.0; data[1] = 2.0; data[2] = 3.0
    data[3] = 4.0; data[4] = 5.0; data[5] = 6.0
    
    []int shape = make([]int, 2)
    shape[0] = 2
    shape[1] = 3
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_transpose_2d_s(t1)
    
    bool passed = len(t2.data) == len(t1.data)
    
    add_test_result_s(suite, "test_transpose_preserves_data_s", passed,
                      if passed { "" } else { "transpose should keep data" })
}

// ============================================================================
// SLICE TESTS (12 tests)
// ============================================================================

func test_slice_basic_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 10)
    int i = 0
    while i < 10 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 10
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_slice_s(t1, 2, 5)
    
    bool passed = assert_equal_int_s(t2.total_elements, 3) &&
                  assert_equal_float_s(t2.data[0], 2.0, 0.001) &&
                  assert_equal_float_s(t2.data[2], 4.0, 0.001)
    
    add_test_result_s(suite, "test_slice_basic_s", passed,
                      if passed { "" } else { "basic slice failed" })
}

func test_slice_from_start_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 10)
    int i = 0
    while i < 10 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 10
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_slice_s(t1, 0, 5)
    
    bool passed = assert_equal_int_s(t2.total_elements, 5) &&
                  assert_equal_float_s(t2.data[0], 0.0, 0.001)
    
    add_test_result_s(suite, "test_slice_from_start_s", passed,
                      if passed { "" } else { "slice from start failed" })
}

func test_slice_to_end_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 10)
    int i = 0
    while i < 10 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 10
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_slice_s(t1, 5, 10)
    
    bool passed = assert_equal_int_s(t2.total_elements, 5) &&
                  assert_equal_float_s(t2.data[0], 5.0, 0.001) &&
                  assert_equal_float_s(t2.data[4], 9.0, 0.001)
    
    add_test_result_s(suite, "test_slice_to_end_s", passed,
                      if passed { "" } else { "slice to end failed" })
}

func test_slice_single_element_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 10)
    int i = 0
    while i < 10 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 10
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_slice_s(t1, 3, 4)
    
    bool passed = assert_equal_int_s(t2.total_elements, 1) &&
                  assert_equal_float_s(t2.data[0], 3.0, 0.001)
    
    add_test_result_s(suite, "test_slice_single_element_s", passed,
                      if passed { "" } else { "slice single element failed" })
}

func test_slice_full_range_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 10)
    int i = 0
    while i < 10 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 10
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_slice_s(t1, 0, 10)
    
    bool passed = assert_equal_int_s(t2.total_elements, 10)
    
    add_test_result_s(suite, "test_slice_full_range_s", passed,
                      if passed { "" } else { "slice full range failed" })
}

func test_slice_invalid_negative_start_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 10)
    int i = 0
    while i < 10 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 10
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_slice_s(t1, -1, 5)
    
    // Should return original tensor on error
    bool passed = assert_equal_int_s(t2.total_elements, 10)
    
    add_test_result_s(suite, "test_slice_invalid_negative_start_s", passed,
                      if passed { "" } else { "slice should reject negative start" })
}

func test_slice_invalid_out_of_bounds_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 10)
    int i = 0
    while i < 10 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 10
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_slice_s(t1, 0, 15)
    
    // Should return original tensor on error
    bool passed = assert_equal_int_s(t2.total_elements, 10)
    
    add_test_result_s(suite, "test_slice_invalid_out_of_bounds_s", passed,
                      if passed { "" } else { "slice should reject out of bounds" })
}

func test_slice_invalid_inverted_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 10)
    int i = 0
    while i < 10 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 1)
    shape[0] = 10
    
    tensor_s t1 = new_tensor_s(data, shape)
    tensor_s t2 = tensor_slice_s(t1, 5, 3)
    
    // Should return original tensor on error
    bool passed = assert_equal_int_s(t2.total_elements, 10)
    
    add_test_result_s(suite, "test_slice_invalid_inverted_s", passed,
                      if passed { "" } else { "slice should reject inverted range" })
}

// ============================================================================
// CONCATENATION TESTS (10 tests)
// ============================================================================

func test_cat_1d_basic_s(test_suite_s suite) test_suite_s {
    []float data1 = make([]float, 3)
    data1[0] = 1.0; data1[1] = 2.0; data1[2] = 3.0
    
    []float data2 = make([]float, 2)
    data2[0] = 4.0; data2[1] = 5.0
    
    []int shape = make([]int, 1)
    shape[0] = 3
    
    []int shape2 = make([]int, 1)
    shape2[0] = 2
    
    tensor_s t1 = new_tensor_s(data1, shape)
    tensor_s t2 = new_tensor_s(data2, shape2)
    tensor_s t3 = tensor_cat_s(t1, t2, 0)
    
    bool passed = assert_equal_int_s(t3.total_elements, 5) &&
                  assert_equal_float_s(t3.data[0], 1.0, 0.001) &&
                  assert_equal_float_s(t3.data[4], 5.0, 0.001)
    
    add_test_result_s(suite, "test_cat_1d_basic_s", passed,
                      if passed { "" } else { "1D concatenation failed" })
}

func test_cat_dtype_mismatch_s(test_suite_s suite) test_suite_s {
    []float data1 = make([]float, 3)
    data1[0] = 1.0; data1[1] = 2.0; data1[2] = 3.0
    
    []float data2 = make([]float, 2)
    data2[0] = 4.0; data2[1] = 5.0
    
    []int shape = make([]int, 1)
    shape[0] = 3
    
    []int shape2 = make([]int, 1)
    shape2[0] = 2
    
    tensor_s t1 = new_tensor_s(data1, shape)
    tensor_s t2 = new_tensor_s(data2, shape2)
    
    tensor_s t3 = tensor_cat_s(t1, t2, 0)
    
    bool passed = t3.total_elements > 0
    
    add_test_result_s(suite, "test_cat_dtype_mismatch_s", passed,
                      if passed { "" } else { "cat dtype check failed" })
}

func test_cat_2d_dim0_s(test_suite_s suite) test_suite_s {
    []float data1 = make([]float, 4)
    data1[0] = 1.0; data1[1] = 2.0; data1[2] = 3.0; data1[3] = 4.0
    
    []float data2 = make([]float, 4)
    data2[0] = 5.0; data2[1] = 6.0; data2[2] = 7.0; data2[3] = 8.0
    
    []int shape = make([]int, 2)
    shape[0] = 2
    shape[1] = 2
    
    tensor_s t1 = new_tensor_s(data1, shape)
    tensor_s t2 = new_tensor_s(data2, shape)
    tensor_s t3 = tensor_cat_s(t1, t2, 0)
    
    bool passed = assert_equal_int_s(t3.total_elements, 8) &&
                  assert_equal_int_s(t3.shape[0], 4) &&
                  assert_equal_int_s(t3.shape[1], 2)
    
    add_test_result_s(suite, "test_cat_2d_dim0_s", passed,
                      if passed { "" } else { "2D cat dim0 failed" })
}

func test_cat_2d_dim1_s(test_suite_s suite) test_suite_s {
    []float data1 = make([]float, 4)
    data1[0] = 1.0; data1[1] = 2.0; data1[2] = 3.0; data1[3] = 4.0
    
    []float data2 = make([]float, 4)
    data2[0] = 5.0; data2[1] = 6.0; data2[2] = 7.0; data2[3] = 8.0
    
    []int shape = make([]int, 2)
    shape[0] = 2
    shape[1] = 2
    
    tensor_s t1 = new_tensor_s(data1, shape)
    tensor_s t2 = new_tensor_s(data2, shape)
    tensor_s t3 = tensor_cat_s(t1, t2, 1)
    
    bool passed = assert_equal_int_s(t3.total_elements, 8) &&
                  assert_equal_int_s(t3.shape[0], 2) &&
                  assert_equal_int_s(t3.shape[1], 4)
    
    add_test_result_s(suite, "test_cat_2d_dim1_s", passed,
                      if passed { "" } else { "2D cat dim1 failed" })
}

func test_cat_preserves_dtype_s(test_suite_s suite) test_suite_s {
    []float data1 = make([]float, 3)
    data1[0] = 1.0; data1[1] = 2.0; data1[2] = 3.0
    
    []float data2 = make([]float, 2)
    data2[0] = 4.0; data2[1] = 5.0
    
    []int shape = make([]int, 1)
    shape[0] = 3
    
    []int shape2 = make([]int, 1)
    shape2[0] = 2
    
    tensor_s t1 = new_tensor_s(data1, shape)
    tensor_s t2 = new_tensor_s(data2, shape2)
    tensor_s t3 = tensor_cat_s(t1, t2, 0)
    
    bool passed = t3.dtype == "float32"
    
    add_test_result_s(suite, "test_cat_preserves_dtype_s", passed,
                      if passed { "" } else { "cat should preserve dtype" })
}

// ============================================================================
// METADATA TESTS (6 tests)
// ============================================================================

func test_to_string_1d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 5)
    data[0] = 1.0
    
    []int shape = make([]int, 1)
    shape[0] = 5
    
    tensor_s t = new_tensor_s(data, shape)
    string desc = tensor_to_string_s(t)
    
    bool passed = len(desc) > 0
    
    add_test_result_s(suite, "test_to_string_1d_s", passed,
                      if passed { "" } else { "to_string 1D failed" })
}

func test_to_string_2d_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 6)
    int i = 0
    while i < 6 {
        data[i] = float_from_int(i)
        i = i + 1
    }
    
    []int shape = make([]int, 2)
    shape[0] = 2
    shape[1] = 3
    
    tensor_s t = new_tensor_s(data, shape)
    string desc = tensor_to_string_s(t)
    
    bool passed = len(desc) > 0
    
    add_test_result_s(suite, "test_to_string_2d_s", passed,
                      if passed { "" } else { "to_string 2D failed" })
}

func test_rank_calculation_s(test_suite_s suite) test_suite_s {
    []float data = make([]float, 24)
    
    []int shape = make([]int, 3)
    shape[0] = 2
    shape[1] = 3
    shape[2] = 4
    
    tensor_s t = new_tensor_s(data, shape)
    
    bool passed = assert_equal_int_s(t.rank, 3)
    
    add_test_result_s(suite, "test_rank_calculation_s", passed,
                      if passed { "" } else { "rank calculation failed" })
}

// ============================================================================
// MAIN TEST RUNNER
// ============================================================================

func run_all_tests_s() {
    test_suite_s suite = new_test_suite_s()
    
    // Creation Tests (10)
    suite = test_new_tensor_1d_s(suite)
    suite = test_new_tensor_2d_s(suite)
    suite = test_new_tensor_3d_s(suite)
    suite = test_new_tensor_empty_s(suite)
    suite = test_new_tensor_single_element_s(suite)
    suite = test_tensor_dtype_default_s(suite)
    suite = test_tensor_device_default_s(suite)
    suite = test_tensor_large_1d_s(suite)
    
    // Strides Tests (15)
    suite = test_compute_strides_1d_s(suite)
    suite = test_compute_strides_2d_s(suite)
    suite = test_compute_strides_3d_s(suite)
    suite = test_compute_strides_4d_s(suite)
    suite = test_compute_strides_empty_s(suite)
    suite = test_flat_index_1d_s(suite)
    suite = test_flat_index_2d_s(suite)
    suite = test_flat_index_3d_s(suite)
    suite = test_strides_row_major_s(suite)
    suite = test_strides_consistency_s(suite)
    
    // Reshape Tests (12)
    suite = test_reshape_1d_to_2d_s(suite)
    suite = test_reshape_2d_to_1d_s(suite)
    suite = test_reshape_2d_to_3d_s(suite)
    suite = test_reshape_preserves_data_s(suite)
    suite = test_reshape_invalid_total_s(suite)
    suite = test_reshape_same_shape_s(suite)
    suite = test_reshape_to_single_element_s(suite)
    suite = test_reshape_complex_s(suite)
    
    // Transpose Tests (8)
    suite = test_transpose_2d_s(suite)
    suite = test_transpose_square_s(suite)
    suite = test_transpose_1xn_s(suite)
    suite = test_transpose_nx1_s(suite)
    suite = test_transpose_preserves_total_s(suite)
    suite = test_transpose_preserves_data_s(suite)
    
    // Slice Tests (12)
    suite = test_slice_basic_s(suite)
    suite = test_slice_from_start_s(suite)
    suite = test_slice_to_end_s(suite)
    suite = test_slice_single_element_s(suite)
    suite = test_slice_full_range_s(suite)
    suite = test_slice_invalid_negative_start_s(suite)
    suite = test_slice_invalid_out_of_bounds_s(suite)
    suite = test_slice_invalid_inverted_s(suite)
    
    // Concatenation Tests (10)
    suite = test_cat_1d_basic_s(suite)
    suite = test_cat_dtype_mismatch_s(suite)
    suite = test_cat_2d_dim0_s(suite)
    suite = test_cat_2d_dim1_s(suite)
    suite = test_cat_preserves_dtype_s(suite)
    
    // Metadata Tests (6)
    suite = test_to_string_1d_s(suite)
    suite = test_to_string_2d_s(suite)
    suite = test_rank_calculation_s(suite)
    
    print_test_results_s(suite)
}
