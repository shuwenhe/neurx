// Kernel API - Device-specific operation implementations
//
// Kernels are the lowest-level execution interface.
// Separate ForwardKernel and BackwardKernel for clarity.
//
// Dispatcher -> Kernel -> Device
//
// Constraint: Kernel is called ONLY by Dispatcher
// Kernel never calls Operator
// Kernel never calls Device directly (uses helper)

struct KernelMetadata {
    kernel_name: string
    operation_name: string    // "matmul", "softmax", etc.
    device: Device
    supports_fp16: bool
    supports_bfloat16: bool
    supports_fp8: bool
    compute_complexity_str: string  // "O(n^3)", "O(n^2)", etc.
    memory_complexity_str: string
}

interface IForwardKernel {
    // === Metadata ===
    metadata() -> KernelMetadata
    
    // === Execution ===
    // input_tensors: []Tensor - input data
    // output_tensors: []Tensor - pre-allocated, caller manages memory
    // 
    // Constraint: Kernel MUST NOT allocate memory
    // Constraint: Kernel MUST NOT create new Tensors
    execute(input_tensors: []Tensor, output_tensors: []Tensor) -> void
    
    // === Performance Hints ===
    estimated_time_us(shapes: [][]i64) -> i64
    
    // === Profiling ===
    get_profile() -> map[string]f64  // {"kernel_time": 123.45, "memory": ...}
}

interface IBackwardKernel {
    // === Metadata ===
    metadata() -> KernelMetadata
    
    // === Backward Execution ===
    // grad_output: gradient from downstream
    // forward_inputs: original inputs to forward pass
    // forward_outputs: outputs from forward pass (for checkpointing)
    // grad_inputs: pre-allocated gradient tensors for inputs
    //
    // Returns: bool (true if backward succeeded)
    backward(
        grad_output: Tensor,
        forward_inputs: []Tensor,
        forward_outputs: []Tensor,
        grad_inputs: []Tensor
    ) -> bool
    
    // === Gradient Correctness ===
    // Use numerical gradient checking in tests
    // Constraint: backward() MUST match forward() numerically
    
    // === Performance ===
    estimated_time_us(shapes: [][]i64) -> i64
}

interface IKernelPair {
    // Forward and Backward as a pair
    forward_kernel() -> IForwardKernel
    backward_kernel() -> IBackwardKernel
}

interface IKernelRegistry {
    // === Register ===
    register_forward(op_name: string, device: Device, kernel: IForwardKernel) -> void
    register_backward(op_name: string, device: Device, kernel: IBackwardKernel) -> void
    register_pair(op_name: string, device: Device, kernel: IKernelPair) -> void
    
    // === Query ===
    get_forward(op_name: string, device: Device) -> IForwardKernel
    get_backward(op_name: string, device: Device) -> IBackwardKernel
    has_forward(op_name: string, device: Device) -> bool
    has_backward(op_name: string, device: Device) -> bool
    
    // === List ===
    list_kernels(op_name: string) -> []Device
    list_operations(device: Device) -> []string
    
    // === Unregister ===
    unregister(op_name: string, device: Device) -> void
}

interface IKernelPerformance {
    // Query kernel performance
    get_kernel_time(op_name: string, device: Device, shapes: [][]i64) -> i64
    
    // Profile kernel
    profile_kernel(op_name: string, device: Device, iterations: i64) -> map[string]f64
    
    // Compare kernels
    compare_kernels(op_name: string, device: Device, iterations: i64) -> map[string]f64
}

interface IKernelValidator {
    // Validate kernel correctness
    validate_forward(kernel: IForwardKernel, test_shapes: [][]i64) -> bool
    
    // Validate backward using numerical differentiation
    validate_backward(kernel: IKernelPair, test_shapes: [][]i64, eps: f64) -> bool
    
    // Check gradient correctness (finite diff vs analytical)
    check_gradient(kernel: IKernelPair, tensor: Tensor, eps: f64) -> f64  // max error
}

// Architectural Constraints (enforced by Dispatcher):
// - Kernel is called ONLY by Dispatcher
// - Kernel never touches Operator layer
// - Kernel never calls Device.allocate() directly
// - Kernel must be deterministic (same input → same output)
// - Kernel output tensors are pre-allocated by caller
