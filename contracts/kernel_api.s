struct kernel_metadata {
    kernel_name: string
    operation_name: string
    device: device
    supports_fp16: bool
    supports_bfloat16: bool
    supports_fp8: bool
    compute_complexity_str: string
    memory_complexity_str: string
}
interface IForwardKernel {
    metadata() -> kernel_metadata
    execute(input_tensors: []tensor, output_tensors: []tensor) -> void
    estimated_time_us(shapes: [][]i64) -> i64
    get_profile() -> map[string]f64
}
interface IBackwardKernel {
    metadata() -> kernel_metadata
    backward(
        grad_output: tensor,
        forward_inputs: []tensor,
        forward_outputs: []tensor,
        grad_inputs: []tensor
    ) -> bool
    estimated_time_us(shapes: [][]i64) -> i64
}
interface IKernelPair {
    forward_kernel() -> IForwardKernel
    backward_kernel() -> IBackwardKernel
}
interface IKernelRegistry {
    register_forward(op_name: string, device: device, kernel: IForwardKernel) -> void
    register_backward(op_name: string, device: device, kernel: IBackwardKernel) -> void
    register_pair(op_name: string, device: device, kernel: IKernelPair) -> void
    get_forward(op_name: string, device: device) -> IForwardKernel
    get_backward(op_name: string, device: device) -> IBackwardKernel
    has_forward(op_name: string, device: device) -> bool
    has_backward(op_name: string, device: device) -> bool
    list_kernels(op_name: string) -> []device
    list_operations(device: device) -> []string
    unregister(op_name: string, device: device) -> void
}
interface IKernelPerformance {
    get_kernel_time(op_name: string, device: device, shapes: [][]i64) -> i64
    profile_kernel(op_name: string, device: device, iterations: i64) -> map[string]f64
    compare_kernels(op_name: string, device: device, iterations: i64) -> map[string]f64
}
interface IKernelValidator {
    validate_forward(kernel: IForwardKernel, test_shapes: [][]i64) -> bool
    validate_backward(kernel: IKernelPair, test_shapes: [][]i64, eps: f64) -> bool
    check_gradient(kernel: IKernelPair, tensor: tensor, eps: f64) -> f64
}
