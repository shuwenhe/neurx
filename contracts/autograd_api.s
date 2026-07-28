// Autograd API - Automatic differentiation system
//
// Comprehensive autograd design with:
// - Computation graph (Node, Edge)
// - Task scheduling (GraphTask, ReadyQueue)
// - Backward execution (Engine)
//
// This is pre-designed for Phase 3 implementation
// (Phase 1-2 will be simpler, but interfaces support full system)

struct GraphNode {
    id: i64
    operation_name: string
    forward_inputs: []Tensor
    forward_output: Tensor
    backward_fn: func(grad: Tensor) -> []Tensor
}

struct GraphEdge {
    from_node_id: i64
    to_node_id: i64
    tensor_index: i64
    prev_func: func(grad: Tensor) -> Tensor
}

struct ComputationGraph {
    nodes: map[i64]GraphNode
    edges: []GraphEdge
    leaf_tensors: []Tensor
    output_tensor: Tensor
}

struct GraphTask {
    id: i64
    node_id: i64
    grad_tensor: Tensor
    dependencies_remaining: i64
}

struct ReadyQueue {
    tasks: []GraphTask
}

struct AutogradEngine {
    graph: ComputationGraph
    ready_queue: ReadyQueue
    node_results: map[i64][]Tensor
}

interface IGraphBuilder {
    // Build computation graph from forward pass
    build_graph(output: Tensor) -> ComputationGraph
    
    // Get graph for debugging
    get_graph(tensor: Tensor) -> ComputationGraph
    
    // Clear graph (for new forward pass)
    clear_graph(tensor: Tensor) -> void
}

interface IGraphNode {
    // Node properties
    node_id() -> i64
    operation_name() -> string
    
    // Get inputs/outputs
    forward_inputs() -> []Tensor
    forward_output() -> Tensor
    
    // Register backward function
    set_backward_fn(fn: func(Tensor) -> []Tensor) -> void
    backward_fn() -> func(Tensor) -> []Tensor
}

interface IGraphEdge {
    // Edge properties
    from_node() -> i64
    to_node() -> i64
    tensor_index() -> i64
}

interface IGraphTask {
    // Task properties
    task_id() -> i64
    node_id() -> i64
    gradient() -> Tensor
    
    // Dependency tracking
    dependencies_remaining() -> i64
    decrement_dependencies() -> void
}

interface IReadyQueue {
    // Queue operations
    push_task(task: GraphTask) -> void
    pop_task() -> GraphTask
    is_empty() -> bool
    size() -> i64
}

interface IAutogradEngine {
    // === Build Phase ===
    build_from_tensor(output: Tensor) -> void
    
    // === Backward Execution ===
    backward(output: Tensor, grad: Tensor) -> void
    
    // === Access Results ===
    get_gradient(tensor: Tensor) -> Tensor
    get_all_gradients() -> map[string]Tensor  // tensor_id -> gradient
}

interface IAutograd {
    // === Core Backward ===
    // Compute gradients for all leaf tensors
    backward(loss: Tensor) -> void
    backward_with_gradient(loss: Tensor, gradient: Tensor) -> void
    
    // === Gradient Access ===
    get_gradient(tensor: Tensor) -> Tensor
    requires_grad() -> bool
    
    // === Gradient Checking ===
    check_gradient(fn: func(Tensor) -> Tensor, x: Tensor, eps: f64) -> f64  // max error
    
    // === Context Management ===
    enable_grad() -> void
    disable_grad() -> void
    is_grad_enabled() -> bool
    
    // === Graph Access ===
    get_computation_graph(tensor: Tensor) -> ComputationGraph
}

interface IGradientAccumulator {
    // Accumulate gradients for multiple backward passes
    add_gradient(tensor: Tensor, grad: Tensor) -> void
    
    // Get accumulated gradient
    get_gradient(tensor: Tensor) -> Tensor
    
    // Clear gradients
    zero_gradients() -> void
    
    // Synchronize (for distributed)
    synchronize() -> void
}

interface IGradientValidator {
    // Validate backward pass correctness
    // Using finite difference method
    
    // Check one operator
    check_operator(
        forward_fn: func([]Tensor) -> Tensor,
        backward_fn: func(Tensor) -> []Tensor,
        inputs: []Tensor,
        eps: f64
    ) -> f64  // returns max gradient error
    
    // Check full backward graph
    check_backward_graph(output: Tensor, eps: f64) -> f64
}

interface IAutogradCheckpoint {
    // Checkpoint for memory-efficient training
    // Save activations for checkpoint nodes only
    
    // Mark tensor for checkpointing
    checkpoint(tensor: Tensor) -> void
    
    // Recompute forward pass for backward
    recompute_forward(node_id: i64) -> Tensor
}

// === MANDATORY BACKWARD IMPLEMENTATION ===
//
// Every Kernel MUST implement:
// ```s
// func backward(grad_output: Tensor, forward_inputs: []Tensor) -> []Tensor {
//     // Compute gradients for each input using chain rule
//     
//     // Example: MatMul
//     A := forward_inputs[0]
//     B := forward_inputs[1]
//     
//     grad_A := matmul(grad_output, transpose(B))
//     grad_B := matmul(transpose(A), grad_output)
//     
//     return [grad_A, grad_B]
// }
// ```
//
// Constraints:
// ✅ Output must have same shape as corresponding input
// ✅ Use same dtype as grad_output
// ✅ Use same device as grad_output
// ❌ NO new Tensor allocation (pre-allocate)
// ❌ NO dispatch to other kernels (chain rule only)
// ✅ Must pass numerical gradient check
