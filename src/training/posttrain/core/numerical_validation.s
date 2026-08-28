package neurx.posttrain.core.numerical_validation
use std.io.println
struct golden_test_case_s {
    string test_name
    string operation
    tensor_s input_a
    tensor_s input_b
    tensor_s expected_output
    float tolerance
    bool passed
}

struct numerical_gradient_s {
    tensor_s analytical
    tensor_s numerical
    float max_diff
    float rel_error
    bool passed
}

struct regression_test_suite_s {
    []golden_test_case_s test_cases
    int total_tests
    int passed_tests
    int failed_tests
}

func new_regression_test_suite_s() regression_test_suite_s {
    regression_test_suite_s {
        test_cases: make([]golden_test_case_s, 0),
        total_tests: 0,
        passed_tests: 0,
        failed_tests: 0,
    }
}

func add_golden_test_s(
    regression_test_suite_s suite,
    string test_name,
    string op,
    tensor_s in_a,
    tensor_s in_b,
    tensor_s expected,
    float tol
) regression_test_suite_s {
    golden_test_case_s test = golden_test_case_s {
        test_name: test_name,
        operation: op,
        input_a: in_a,
        input_b: in_b,
        expected_output: expected,
        tolerance: tol,
        passed: false,
    }
    regression_test_suite_s {
        test_cases: append(suite.test_cases, test),
        total_tests: suite.total_tests + 1,
        passed_tests: suite.passed_tests,
        failed_tests: suite.failed_tests,
    }
}

func run_golden_tests_s(regression_test_suite_s suite) regression_test_suite_s {
    println("═══════════════════════════════════════════")
    println("Running Golden Regression Tests")
    println("═══════════════════════════════════════════")
    int passed = 0
    int failed = 0
    int i = 0
    for i < len(suite.test_cases) {
        golden_test_case_s test = suite.test_cases[i]
        bool result = run_single_test_s(test)
        if result {
            println("✓ PASS: " + test.test_name)
            passed = passed + 1
        } else {
            println("✗ FAIL: " + test.test_name)
            failed = failed + 1
        }
        i = i + 1
    }
    println("═══════════════════════════════════════════")
    println("Results: " + int_to_str(passed) + "/" + int_to_str(suite.total_tests))
    println("═══════════════════════════════════════════")
    regression_test_suite_s {
        test_cases: suite.test_cases,
        total_tests: suite.total_tests,
        passed_tests: passed,
        failed_tests: failed,
    }
}

func run_single_test_s(golden_test_case_s test) bool {
    tensor_s actual = execute_operation_s(test.operation, test.input_a, test.input_b)
    bool match = compare_tensors_s(actual, test.expected_output, test.tolerance)
    match
}

func execute_operation_s(string op, tensor_s a, tensor_s b) tensor_s {
    if op == "matmul" {
        return matmul_forward_s(a, b)
    }
    if op == "add" {
        return add_forward_s(a, b)
    }
    if op == "mul" {
        return mul_forward_s(a, b)
    }
    if op == "softmax" {
        return softmax_forward_s(a)
    }
    a
}

func compare_tensors_s(tensor_s t1, tensor_s t2, float tolerance) bool {
    if t1.total_elements != t2.total_elements {
        return false
    }
    int i = 0
    for i < len(t1.data) {
        float diff = t1.data[i] - t2.data[i]
        if diff < 0.0 { diff = 0.0 - diff }
        if diff > tolerance {
            return false
        }
        i = i + 1
    }
    true
}

func numerical_gradient_check_s(
    string op,
    tensor_s input,
    float epsilon
) numerical_gradient_s {
    tensor_s analytical = compute_analytical_gradient_s(op, input)
    tensor_s numerical = compute_numerical_gradient_s(op, input, epsilon)
    float max_diff = 0.0
    float rel_error = 0.0
    int i = 0
    for i < len(analytical.data) {
        float diff = analytical.data[i] - numerical.data[i]
        if diff < 0.0 { diff = 0.0 - diff }
        if diff > max_diff {
            max_diff = diff
        }
        i = i + 1
    }
    bool passed = max_diff < epsilon
    numerical_gradient_s {
        analytical: analytical,
        numerical: numerical,
        max_diff: max_diff,
        rel_error: rel_error,
        passed: passed,
    }
}

func compute_analytical_gradient_s(string op, tensor_s input) tensor_s {
    tensor_s grad = make_zeros_like_s(input)
    grad
}

func compute_numerical_gradient_s(string op, tensor_s input, float epsilon) tensor_s {
    float[] grad = make(float[], 0)
    int i = 0
    for i < len(input.data) {
        tensor_s input_plus = copy_tensor_s(input)
        input_plus.data[i] = input_plus.data[i] + epsilon
        tensor_s input_minus = copy_tensor_s(input)
        input_minus.data[i] = input_minus.data[i] - epsilon
        tensor_s out_plus = execute_operation_s(op, input_plus, make_zeros_like_s(input))
        tensor_s out_minus = execute_operation_s(op, input_minus, make_zeros_like_s(input))
        float numerical_grad = (out_plus.data[0] - out_minus.data[0]) / (2.0 * epsilon)
        grad = append(grad, numerical_grad)
        i = i + 1
    }
    tensor_s {
        data: grad,
        shape: input.shape,
        strides: input.strides,
        rank: input.rank,
        total_elements: len(grad),
        dtype: input.dtype,
        device: input.device,
    }
}

func matmul_forward_s(tensor_s a, tensor_s b) tensor_s {
    make_zeros_like_s(a)
}

func add_forward_s(tensor_s a, tensor_s b) tensor_s {
    float[] result = make(float[], 0)
    int i = 0
    for i < len(a.data) {
        result = append(result, a.data[i] + b.data[i])
        i = i + 1
    }
    tensor_s {
        data: result,
        shape: a.shape,
        strides: a.strides,
        rank: a.rank,
        total_elements: a.total_elements,
        dtype: a.dtype,
        device: a.device,
    }
}

func mul_forward_s(tensor_s a, tensor_s b) tensor_s {
    float[] result = make(float[], 0)
    int i = 0
    for i < len(a.data) {
        result = append(result, a.data[i] * b.data[i])
        i = i + 1
    }
    tensor_s {
        data: result,
        shape: a.shape,
        strides: a.strides,
        rank: a.rank,
        total_elements: a.total_elements,
        dtype: a.dtype,
        device: a.device,
    }
}

func softmax_forward_s(tensor_s a) tensor_s {
    make_zeros_like_s(a)
}

func make_zeros_like_s(tensor_s t) tensor_s {
    float[] zeros = make(float[], 0)
    int i = 0
    for i < t.total_elements {
        zeros = append(zeros, 0.0)
        i = i + 1
    }
    tensor_s {
        data: zeros,
        shape: t.shape,
        strides: t.strides,
        rank: t.rank,
        total_elements: t.total_elements,
        dtype: t.dtype,
        device: t.device,
    }
}

func copy_tensor_s(tensor_s t) tensor_s {
    float[] copied = make(float[], 0)
    int i = 0
    for i < len(t.data) {
        copied = append(copied, t.data[i])
        i = i + 1
    }
    tensor_s {
        data: copied,
        shape: t.shape,
        strides: t.strides,
        rank: t.rank,
        total_elements: t.total_elements,
        dtype: t.dtype,
        device: t.device,
    }
}

func int_to_str(int n) string {
    if n == 0 { return "0" }
    string result = ""
    bool neg = false
    if n < 0 { neg = true; n = 0 - n }
    for n > 0 {
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
