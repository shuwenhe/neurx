struct KernelMetadata {
    kernel_name: string
    operation_name: string
    device: Device
    supports_fp16: bool
    supports_bfloat16: bool
    supports_fp8: bool
    compute_complexity_str: string
    memory_complexity_str: string
}

interface IForwardKernel {

    metadata() -> KernelMetadata

    execute(input_tensors: []Tensor, output_tensors: []Tensor) -> void

    estimated_time_us(shapes: [][]i64) -> i64

    get_profile() -> map[string]f64
}

interface IBackwardKernel {

    metadata() -> KernelMetadata

    backward(
        grad_output: Tensor,
        forward_inputs: []Tensor,
        forward_outputs: []Tensor,
        grad_inputs: []Tensor
    ) -> bool

    estimated_time_us(shapes: [][]i64) -> i64
}

interface IKernelPair {

    forward_kernel() -> IForwardKernel
    backward_kernel() -> IBackwardKernel
}

interface IKernelRegistry {

    register_forward(op_name: string, device: Device, kernel: IForwardKernel) -> void
    register_backward(op_name: string, device: Device, kernel: IBackwardKernel) -> void
    register_pair(op_name: string, device: Device, kernel: IKernelPair) -> void

    get_forward(op_name: string, device: Device) -> IForwardKernel
    get_backward(op_name: string, device: Device) -> IBackwardKernel
    has_forward(op_name: string, device: Device) -> bool
    has_backward(op_name: string, device: Device) -> bool

    list_kernels(op_name: string) -> []Device
    list_operations(device: Device) -> []string

    unregister(op_name: string, device: Device) -> void
}

interface IKernelPerformance {

    get_kernel_time(op_name: string, device: Device, shapes: [][]i64) -> i64

    profile_kernel(op_name: string, device: Device, iterations: i64) -> map[string]f64

    compare_kernels(op_name: string, device: Device, iterations: i64) -> map[string]f64
}

interface IKernelValidator {

    validate_forward(kernel: IForwardKernel, test_shapes: [][]i64) -> bool

    validate_backward(kernel: IKernelPair, test_shapes: [][]i64, eps: f64) -> bool

    check_gradient(kernel: IKernelPair, tensor: Tensor, eps: f64) -> f64
}
