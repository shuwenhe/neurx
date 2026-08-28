package neurx.compute

use neurx.compute.core_kernels
use neurx.device.abi

func test_rms_norm_basic() (int, int, string) {
    passed := 0
    failed := 0

    input_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 1024,
        ref_count: 1,
        is_view: false,
    }

    weight_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 1024,
        ref_count: 1,
        is_view: false,
    }

    output_tensor, success, err := core_kernels.device_tensor_rms_norm(input_tensor, weight_tensor, 1e-6)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if output_tensor.element_count != 1024 {
        failed = failed + 1
        return passed, failed, "RMSNorm output element count mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_rms_norm_basic passed"
}

func test_gemm_basic() (int, int, string) {
    passed := 0
    failed := 0

    shape_a := vec[int]()
    shape_a.push(64)
    shape_a.push(32)

    shape_b := vec[int]()
    shape_b.push(32)
    shape_b.push(128)

    matrix_a := abi.device_tensor {
        data: abi.device_ptr{},
        shape: shape_a,
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(64 * 32),
        ref_count: 1,
        is_view: false,
    }

    matrix_b := abi.device_tensor {
        data: abi.device_ptr{},
        shape: shape_b,
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(32 * 128),
        ref_count: 1,
        is_view: false,
    }

    output_tensor, success, err := core_kernels.device_tensor_gemm(matrix_a, matrix_b, 1.0, 0.0)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if output_tensor.element_count != int64(64 * 128) {
        failed = failed + 1
        return passed, failed, "GEMM output element count mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_gemm_basic passed"
}

func test_rope_basic() (int, int, string) {
    passed := 0
    failed := 0

    shape := vec[int]()
    shape.push(2)
    shape.push(32)
    shape.push(64)

    input_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: shape,
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(2 * 32 * 64),
        ref_count: 1,
        is_view: false,
    }

    output_tensor, success, err := core_kernels.device_tensor_rope(input_tensor, 0, 32, 10000.0)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if output_tensor.element_count != int64(2 * 32 * 64) {
        failed = failed + 1
        return passed, failed, "RoPE output element count mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_rope_basic passed"
}

func test_attention_basic() (int, int, string) {
    passed := 0
    failed := 0

    shape := vec[int]()
    shape.push(2)
    shape.push(8)
    shape.push(32)
    shape.push(64)

    query_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: shape,
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(2 * 8 * 32 * 64),
        ref_count: 1,
        is_view: false,
    }

    key_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: shape,
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(2 * 8 * 32 * 64),
        ref_count: 1,
        is_view: false,
    }

    value_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: shape,
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(2 * 8 * 32 * 64),
        ref_count: 1,
        is_view: false,
    }

    attention_cfg := core_kernels.attention_config {
        scale_factor: 0.125,
        num_heads: 8,
        head_dim: 64,
        use_flash_v3: true,
    }

    output_tensor, success, err := core_kernels.device_tensor_attention(query_tensor, key_tensor, value_tensor, attention_cfg)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if output_tensor.element_count != int64(2 * 8 * 32 * 64) {
        failed = failed + 1
        return passed, failed, "Attention output element count mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_attention_basic passed"
}

func test_gelu_activation() (int, int, string) {
    passed := 0
    failed := 0

    input_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 2048,
        ref_count: 1,
        is_view: false,
    }

    output_tensor, success, err := core_kernels.device_tensor_gelu(input_tensor)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if output_tensor.element_count != 2048 {
        failed = failed + 1
        return passed, failed, "GELU output element count mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_gelu_activation passed"
}

func test_layer_norm() (int, int, string) {
    passed := 0
    failed := 0

    input_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 4096,
        ref_count: 1,
        is_view: false,
    }

    gamma_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 4096,
        ref_count: 1,
        is_view: false,
    }

    beta_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 4096,
        ref_count: 1,
        is_view: false,
    }

    output_tensor, success, err := core_kernels.device_tensor_layer_norm(input_tensor, gamma_tensor, beta_tensor, 1e-6)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if output_tensor.element_count != 4096 {
        failed = failed + 1
        return passed, failed, "LayerNorm output element count mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_layer_norm passed"
}

func test_softmax() (int, int, string) {
    passed := 0
    failed := 0

    shape := vec[int]()
    shape.push(8)
    shape.push(32)

    input_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: shape,
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(8 * 32),
        ref_count: 1,
        is_view: false,
    }

    output_tensor, success, err := core_kernels.device_tensor_softmax(input_tensor, 1)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if output_tensor.element_count != int64(8 * 32) {
        failed = failed + 1
        return passed, failed, "Softmax output element count mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_softmax passed"
}

func test_dropout() (int, int, string) {
    passed := 0
    failed := 0

    input_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 8192,
        ref_count: 1,
        is_view: false,
    }

    output_tensor, success, err := core_kernels.device_tensor_dropout(input_tensor, 0.1)

    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if output_tensor.element_count != 8192 {
        failed = failed + 1
        return passed, failed, "Dropout output element count mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_dropout passed"
}

func test_kernel_config() (int, int, string) {
    passed := 0
    failed := 0

    success, err := core_kernels.compute_kernel_config_init(256, 256)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init config: " + err
    }

    block_size, bs_success, bs_err := core_kernels.kernel_config_get_block_size()
    if !bs_success {
        failed = failed + 1
        return passed, failed, "Failed to get block size: " + bs_err
    }

    if block_size != 256 {
        failed = failed + 1
        return passed, failed, "Block size mismatch"
    }

    grid_size, gs_success, gs_err := core_kernels.kernel_config_get_grid_size(1024 * 1024)
    if !gs_success {
        failed = failed + 1
        return passed, failed, "Failed to get grid size: " + gs_err
    }

    if grid_size <= 0 {
        failed = failed + 1
        return passed, failed, "Invalid grid size"
    }

    passed = passed + 1
    return passed, failed, "test_kernel_config passed"
}

func run_all_tests() (int, int, string) {
    total_passed := 0
    total_failed := 0
    results := ""

    p1, f1, r1 := test_rms_norm_basic()
    total_passed = total_passed + p1
    total_failed = total_failed + f1
    results = results + r1 + " | "

    p2, f2, r2 := test_gemm_basic()
    total_passed = total_passed + p2
    total_failed = total_failed + f2
    results = results + r2 + " | "

    p3, f3, r3 := test_rope_basic()
    total_passed = total_passed + p3
    total_failed = total_failed + f3
    results = results + r3 + " | "

    p4, f4, r4 := test_attention_basic()
    total_passed = total_passed + p4
    total_failed = total_failed + f4
    results = results + r4 + " | "

    p5, f5, r5 := test_gelu_activation()
    total_passed = total_passed + p5
    total_failed = total_failed + f5
    results = results + r5 + " | "

    p6, f6, r6 := test_layer_norm()
    total_passed = total_passed + p6
    total_failed = total_failed + f6
    results = results + r6 + " | "

    p7, f7, r7 := test_softmax()
    total_passed = total_passed + p7
    total_failed = total_failed + f7
    results = results + r7 + " | "

    p8, f8, r8 := test_dropout()
    total_passed = total_passed + p8
    total_failed = total_failed + f8
    results = results + r8 + " | "

    p9, f9, r9 := test_kernel_config()
    total_passed = total_passed + p9
    total_failed = total_failed + f9
    results = results + r9

    return total_passed, total_failed, results
}
