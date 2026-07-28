// Operator API - Device-agnostic operations
//
// Operators are high-level mathematical operations.
// They never touch device-specific code.
// They use Dispatcher to execute kernels.
//
// Architecture:
// Operator → Dispatcher → Kernel → Device
//
// Key Principle: Operator is PURE MATH
// - Same Operator code runs on CPU, CUDA, CANN, Metal unchanged
// - Only the Kernel changes per device

import "dispatcher_api"
import "autograd_api"

struct OperatorContext {
    requires_grad: bool
    dispatcher: Dispatcher
    device: Device
    profiler: Profiler
}

interface IOperator {
    // === Execution ===
    // inputs: input tensors (on same device)
    // output: result (on same device as inputs)
    forward(inputs: []Tensor, ctx: OperatorContext) -> Tensor
    
    // === Backward ===
    backward(grad_output: Tensor) -> []Tensor
    
    // === Metadata ===
    operator_name() -> string
    num_inputs() -> i64
    num_outputs() -> i64
    
    // === Device Support ===
    supports_device(device: Device) -> bool
    supports_dtype(dtype: DType) -> bool
}

// === MANDATORY DESIGN PATTERN FOR ALL OPERATORS ===
//
// Example: MatMul Operator
// ```s
// func matmul_forward(A: Tensor, B: Tensor, ctx: OperatorContext) -> Tensor {
//     // RULE 1: Get dispatcher from context
//     dispatcher := ctx.dispatcher
//     
//     // RULE 2: Select kernel via dispatcher (NOT directly from device)
//     kernel := dispatcher.select_kernel("matmul", A.device())
//     
//     // RULE 3: Execute kernel (pre-allocate output)
//     output_shape := compute_matmul_shape(A.shape(), B.shape())
//     output := allocate_tensor(output_shape, A.dtype(), A.device())
//     kernel.forward([A, B], [output])
//     
//     // RULE 4: Track for autograd
//     if ctx.requires_grad {
//         output.set_grad_fn(fn: (grad_output: Tensor) -> backward(...))
//     }
//     
//     return output
// }
// ```

interface IOperatorDeterminism {
    // === DETERMINISTIC CONSTRAINT ===
    // Operators MUST be deterministic:
    // - Same input + same seed → same output
    // - No malloc() (use pre-allocated tensors)
    // - No printf() (use logger if needed)
    // - No file I/O
    // - No CUDA API calls (use Kernel instead)
    // - No random numbers (use seeded RNG in context)
    // - No sleep() or timing
    // - No access to global state (thread-unsafe)
    
    // Verify determinism
    is_deterministic() -> bool
    
    // Set random seed (for deterministic RNG if needed)
    set_seed(seed: i64) -> void
}

interface IOperatorComposition {
    // Operators can call other operators
    // Enables: matmul + add = linear layer
    // Constraint: No circular dependencies
    // Constraint: All sub-operators use same dispatcher
    
    compose(operators: []IOperator) -> IOperator
}

interface IOperatorAutograd {
    // === Autograd Support ===
    // Every operator must support backward pass
    
    // Compute gradient w.r.t. input i
    gradient_wrt_input(i: i64, grad_output: Tensor, forward_inputs: []Tensor) -> Tensor
    
    // Check gradient numerically (for testing)
    check_gradient(forward_inputs: []Tensor, eps: f64) -> f64  // max error
}

interface IOperatorPerformance {
    // Query performance
    estimated_time_us(shapes: [][]i64) -> i64
    
    // Memory usage
    estimated_memory(shapes: [][]i64) -> i64
    
    // Profiling
    profile(inputs: []Tensor) -> map[string]f64
}

// === PROHIBITED IN OPERATORS ===
const ProhibitedInOperators = """
❌ malloc() / new() / allocate()        → pre-allocate tensors
❌ if device == CUDA                    → use Dispatcher
❌ CUDA API calls                       → use Kernel
❌ printf() / logging                   → use context logger
❌ File I/O                             → serialization_api
❌ Random numbers (unseeded)            → use seeded RNG
❌ sleep() / timing                     → use profiler
❌ Global state access                  → thread-unsafe
❌ Kernel direct calls                  → use Dispatcher
"""

// === REQUIRED IN OPERATORS ===
const RequiredInOperators = """
✅ Use Dispatcher.select_kernel()      → for kernel selection
✅ Pre-allocate output tensors         → caller decides memory
✅ Track computation graph             → for autograd
✅ Support all required dtypes         → (fp16, fp32, etc.)
✅ Implement backward()                → for gradients
✅ Be deterministic                    → same input → same output
✅ Validate device compatibility       → via supports_device()
✅ Document assumptions                → shapes, dtypes, etc.
"""
