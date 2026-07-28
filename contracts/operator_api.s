// NeurX Operator API Interface
// Phase -1: Architecture Contracts
// Purpose: Device-agnostic operations that use Dispatcher for execution

package contracts

// OperatorType enum
type OpType interface {
    name() string
}

type MatMulOp struct {}
type LinearOp struct {}
type SoftmaxOp struct {}
type LayerNormOp struct {}
type CrossEntropyOp struct {}
type AddOp struct {}
type MulOp struct {}
type ReLUOp struct {}

func (MatMulOp) name() string { return "matmul" }
func (LinearOp) name() string { return "linear" }
func (SoftmaxOp) name() string { return "softmax" }
func (LayerNormOp) name() string { return "layer_norm" }
func (CrossEntropyOp) name() string { return "cross_entropy" }
func (AddOp) name() string { return "add" }
func (MulOp) name() string { return "mul" }
func (ReLUOp) name() string { return "relu" }

// Operator Interface - All operators follow this pattern
interface Operator {
    func forward(inputs: []Tensor) -> Tensor
    func backward(grad_output: Tensor) -> []Tensor
    func op_type() -> OpType
    func supports_device(device: Device) -> bool
}

// OperatorContext - Configuration for operator execution
struct OperatorContext {
    requires_grad: bool
    dispatcher: Dispatcher
    device: Device
    profiler: Profiler
}

// Phase -1 Design Pattern for Operators:
//
// All operators MUST follow this pattern:
//
// ```s
// func linear(x: Tensor, weight: Tensor, bias: Tensor, ctx: OperatorContext) -> Tensor {
//     // 1. Get dispatcher
//     dispatcher := ctx.dispatcher
//     device := x.device()
//     
//     // 2. Use dispatcher to execute matmul
//     kernel_matmul := dispatcher.select_kernel("matmul", device)
//     output := kernel_matmul.execute(x, weight)
//     
//     // 3. Add bias (another dispatcher call)
//     kernel_add := dispatcher.select_kernel("add", device)
//     output := kernel_add.execute(output, bias)
//     
//     // 4. Track for autograd
//     if ctx.requires_grad {
//         output.op = LinearOperation(x, weight, bias)
//     }
//     
//     return output
// }
// ```
//
// Key Points:
//   - Operator NEVER calls device API directly
//   - Operator NEVER contains "if device == CUDA"
//   - Operator ALWAYS uses Dispatcher
//   - Same code works on CPU, CUDA, CANN, Metal
//   - Only thing that changes: underlying kernel

// Constraint from ARCHITECTURE_PRINCIPLES:
// Rule 2: Device Agnosticism
//   "不允许在 Operator 中写 if device == CUDA_DEVICE"
//   "不允许在 Operator 中直接调用 CUDA 函数"
//
// Rule 1: Layering
//   Operator can only call:
//     - Dispatcher
//     - Other Operators
//     - Autograd
//   
//   Operator CANNOT call:
//     - Device API
//     - Kernel directly
//     - Compiler

// Phase 1 Operator List (Minimal Set)
//   MatMul
//   Add
//   Mul
//   Sum
//   Mean
//   Transpose
//   View
//   Reshape
//   Softmax
//   LayerNorm
//   Embedding
//
// Phase 2+ Operators (Added later based on need):
//   Linear (composite: MatMul + Add)
//   CrossEntropy (composite: Softmax + NLL)
//   ReLU, GeLU, SwiGLU
//   Conv2D
//   Attention
//   etc.

// Phase -1 Verification
// Once implemented, verify:
// [ ] Operator code has NO "if device == ..."
// [ ] Operator calls Dispatcher for all operations
// [ ] Same operator works on CPU and CUDA
// [ ] Code review enforces this constraint
