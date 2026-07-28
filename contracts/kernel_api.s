// NeurX Kernel API Interface
// Phase -1: Architecture Contracts
// Purpose: Define device-specific kernel execution interface

package contracts

// KernelType
type KernelType interface {
    name() string
}

type CPU_Kernel struct {}
type CUDA_Kernel struct {}
type CANN_Kernel struct {}
type Metal_Kernel struct {}

func (CPU_Kernel) name() string { return "cpu" }
func (CUDA_Kernel) name() string { return "cuda" }
func (CANN_Kernel) name() string { return "cann" }
func (Metal_Kernel) name() string { return "metal" }

// KernelMetadata - Information about a kernel
struct KernelMetadata {
    name: string
    operation: string         // "matmul", "softmax", etc.
    device_type: DeviceType
    compute_complexity: int   // O(n^3) for matmul
    memory_complexity: int
    supports_fp16: bool
    supports_bfloat16: bool
    estimated_flops: func(shapes: [][]int) -> int
}

// Kernel Interface - Device-specific implementation
interface Kernel {
    // Metadata
    func metadata() -> KernelMetadata
    func device_type() -> DeviceType
    
    // Execution
    // inputs: tensors to operate on
    // outputs: pre-allocated output tensors (caller manages memory)
    func execute(inputs: []Tensor, outputs: []Tensor)
    
    // Backward pass (for autograd)
    func backward(grad_output: Tensor, inputs: []Tensor, 
                 forward_outputs: []Tensor) -> []Tensor
    
    // Performance
    func estimated_time(shapes: [][]int) -> int  // microseconds
    func profile(inputs: []Tensor) -> map[string]float
}

// KernelRegistry - Manages kernel implementations
interface KernelRegistry {
    // Register a kernel
    func register(op_name: string, device_type: DeviceType, kernel: Kernel)
    
    // Query kernel
    func get(op_name: string, device_type: DeviceType) -> Kernel
    
    // Check availability
    func has_kernel(op_name: string, device_type: DeviceType) -> bool
    func list_kernels(op_name: string) -> []DeviceType
    
    // Performance hints
    func get_best_kernel(op_name: string, shapes: [][]int) -> Kernel
}

// Constraint from ARCHITECTURE_PRINCIPLES:
// Rule 1: Layering
//   Kernel is called ONLY by Dispatcher
//   Operator never calls Kernel directly

// Phase -1 Verification
// Once implemented, verify:
// [ ] CPU kernels execute correctly
// [ ] Backward pass computes gradients
// [ ] Can profile execution time
// [ ] Registry tracks all kernels
// [ ] Can fall back to CPU if device kernel unavailable
