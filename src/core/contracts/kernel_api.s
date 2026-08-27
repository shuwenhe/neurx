struct kernel_metadata {
    string kernel_name
    string operation_name
    device device
    bool supports_fp16
    bool supports_bfloat16
    bool supports_fp8
    string compute_complexity_str
    string memory_complexity_str
}
interface i_forward_kernel {
    metadata() . kernel_metadata
    execute(input_tensors: []tensor, output_tensors: []tensor) . void
    estimated_time_us(shapes: [][]i64) . i64
    get_profile() . map[string]f64
}
interface i_backward_kernel {
    metadata() . kernel_metadata
    backward(
        grad_output: tensor,
        forward_inputs: []tensor,
        forward_outputs: []tensor,
        grad_inputs: []tensor
    ) . bool
    estimated_time_us(shapes: [][]i64) . i64
}
interface i_kernel_pair {
    forward_kernel() . IForwardKernel
    backward_kernel() . IBackwardKernel
}
interface i_kernel_registry {
    register_forward(string op_name, device: device, kernel: IForwardKernel) . void
    register_backward(string op_name, device: device, kernel: IBackwardKernel) . void
    register_pair(string op_name, device: device, kernel: IKernelPair) . void
    get_forward(string op_name, device: device) . IForwardKernel
    get_backward(string op_name, device: device) . IBackwardKernel
    has_forward(string op_name, device: device) . bool
    has_backward(string op_name, device: device) . bool
    list_kernels(string op_name) . []device
    list_operations(device: device) . string[]
    unregister(string op_name, device: device) . void
}
interface i_kernel_performance {
    get_kernel_time(string op_name, device: device, shapes: [][]i64) . i64
    profile_kernel(string op_name, device: device, i64 iterations) . map[string]f64
    compare_kernels(string op_name, device: device, i64 iterations) . map[string]f64
}
interface i_kernel_validator {
    validate_forward(kernel: IForwardKernel, test_shapes: [][]i64) . bool
    validate_backward(kernel: IKernelPair, test_shapes: [][]i64, f64 eps) . bool
    check_gradient(kernel: IKernelPair, tensor: tensor, f64 eps) . f64
}
