// NeurX Dispatcher API Interface
// Phase -1: Architecture Contracts
// Purpose: Smart kernel selection based on device and operation

package contracts

// Dispatcher - Routes operations to appropriate kernel
// Phase -1 design: SIMPLE switch(device)
// Phase 11 design: Complex dispatch key system (if needed)
interface Dispatcher {
    // Core functionality
    func select_kernel(op_name: string, device: Device) -> Kernel
    func execute(op_name: string, inputs: []Tensor, device: Device) -> Tensor
    
    // Registration
    func register_kernel(op_name: string, device_type: DeviceType, kernel: Kernel)
    func register_operator(op_name: string, impl: OperatorImpl)
    
    // Query
    func has_implementation(op_name: string, device_type: DeviceType) -> bool
    func list_operations() -> []string
    func list_devices_for_op(op_name: string) -> []DeviceType
    
    // Fallback
    func set_fallback_device(device_type: DeviceType)
    func get_fallback_device() -> DeviceType
}

// OperatorImpl - Implementation of an operator
interface OperatorImpl {
    func forward(inputs: []Tensor) -> Tensor
    func backward(grad_output: Tensor, inputs: []Tensor) -> []Tensor
    func supports_device(device: Device) -> bool
}

// DispatchContext - Thread-local dispatch configuration
struct DispatchContext {
    preferred_device: Device
    enable_autograd: bool
    enable_profiling: bool
}

// Phase -1 Implementation Notes:
// Dispatcher.select_kernel should be as simple as:
//
// func (d Dispatcher) select_kernel(op_name: string, device: Device) -> Kernel {
//     switch device.device_type().name() {
//     case "cpu":
//         return d.cpu_kernels[op_name]
//     case "cuda":
//         return d.cuda_kernels[op_name]
//     case "cann":
//         return d.cann_kernels[op_name]
//     default:
//         return d.fallback_device_kernels[op_name]
//     }
// }
//
// < 50 lines total for Phase -1
// Later (Phase 11+): Can add DispatchKey, composite rules, caching, etc.

// Constraint from ARCHITECTURE_PRINCIPLES:
// Rule 2: Device Agnosticism
//   Operator calls Dispatcher, never directly accesses device
//   Example: WRONG: if device == CUDA { cuda_matmul(...) }
//           RIGHT: kernel = dispatcher.select_kernel("matmul", device)
//                  kernel.execute(inputs, outputs)

// Phase -1 Verification
// Once implemented, verify:
// [ ] Dispatcher correctly selects CPU kernel
// [ ] Dispatcher correctly selects CUDA kernel (if available)
// [ ] Falling back to CPU works when device kernel unavailable
// [ ] Dispatcher returns error if operation not supported
// [ ] Same operation on different devices gives same results
