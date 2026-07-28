// NeurX Autograd API Interface
// Phase -1: Architecture Contracts
// Purpose: Automatic differentiation (backward pass)

package contracts

// Gradient type
type Gradient struct {
    tensor: Tensor
    requires_grad: bool
}

// Autograd Interface - Compute gradients via chain rule
interface Autograd {
    // Core backward pass
    func backward(loss: Tensor, wrt: Tensor) -> Tensor
    func backward_graph(loss: Tensor) -> map[string]Tensor
    
    // Gradient access
    func get_gradient(param: Tensor) -> Tensor
    func accumulate_gradient(param: Tensor, grad: Tensor)
    
    // Graph management
    func build_graph(output: Tensor) -> ComputationGraph
    func topological_sort(graph: ComputationGraph) -> []Tensor
    
    // Gradient checking
    func check_gradient(fn: func(Tensor) -> Tensor, x: Tensor, eps: float = 1e-4) -> bool
}

// ComputationGraph - Tracks operations for backward pass
struct ComputationGraph {
    nodes: []GraphNode
    edges: []GraphEdge
    leaf_tensors: []Tensor
    output_tensor: Tensor
}

// GraphNode - A single operation in the graph
struct GraphNode {
    operation: Operation
    inputs: []Tensor
    output: Tensor
    backward_fn: func(grad: Tensor) -> []Tensor
}

// GraphEdge - Dependency between nodes
struct GraphEdge {
    from_node: int    // index in nodes array
    to_node: int
    tensor_index: int // which output/input
}

// GradientBuffer - Stores accumulated gradients
interface GradientBuffer {
    func add_gradient(param_id: string, grad: Tensor)
    func get_gradient(param_id: string) -> Tensor
    func zero_gradients()
    func synchronize()  // For distributed training
}

// Phase -1 Design Pattern for Backward Pass:
//
// Every Kernel must implement backward:
//
// ```s
// func (k CPU_MatMul) backward(grad_output: Tensor, inputs: []Tensor) -> []Tensor {
//     // grad_output = dL/dC where C = A @ B
//     A := inputs[0]
//     B := inputs[1]
//     
//     // Chain rule:
//     // dL/dA = (dL/dC) @ B^T
//     // dL/dB = A^T @ (dL/dC)
//     
//     grad_A := matmul(grad_output, transpose(B))
//     grad_B := matmul(transpose(A), grad_output)
//     
//     return []Tensor{grad_A, grad_B}
// }
// ```

// Phase -1 Verification Checklist:
// For each Operator:
// [ ] Forward pass implemented correctly (vs PyTorch)
// [ ] Backward pass implements chain rule
// [ ] Gradient Check passes (numeric vs symbolic, eps < 1e-3)
//
// To run Gradient Check:
// ```s
// autograd := ctx.autograd
// x := tensor_randn([2, 3])
// fn := func(x_test: Tensor) -> Tensor {
//     return some_operator(x_test)
// }
// passed := autograd.check_gradient(fn, x)
// ```

// Constraint from ARCHITECTURE_PRINCIPLES:
// Rule 4: Gradient Support
//   "不允许有'仅支持前向'的 Operator"
//   "每个 Operator 必须实现 backward()"
//   "Backward 计算必须经过 Dispatcher"
//
// Example of correct design:
// ```s
// func softmax(x: Tensor) -> Tensor {
//     kernel := dispatcher.select_kernel("softmax", x.device)
//     output := kernel.execute(x)
//     
//     // Also register backward kernel
//     output.op = SoftmaxOp(x)
//     
//     return output
// }
// ```

// Phase -1 Verification
// Once implemented, verify:
// [ ] All operators support backward()
// [ ] Gradient Check passes for all operators (eps < 1e-3)
// [ ] Complex graphs compute correct gradients
// [ ] Gradients flow correctly through multiple operations
