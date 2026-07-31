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

    build_graph(output: Tensor) -> ComputationGraph

    get_graph(tensor: Tensor) -> ComputationGraph

    clear_graph(tensor: Tensor) -> void
}

interface IGraphNode {

    node_id() -> i64
    operation_name() -> string

    forward_inputs() -> []Tensor
    forward_output() -> Tensor

    set_backward_fn(fn: func(Tensor) -> []Tensor) -> void
    backward_fn() -> func(Tensor) -> []Tensor
}

interface IGraphEdge {

    from_node() -> i64
    to_node() -> i64
    tensor_index() -> i64
}

interface IGraphTask {

    task_id() -> i64
    node_id() -> i64
    gradient() -> Tensor

    dependencies_remaining() -> i64
    decrement_dependencies() -> void
}

interface IReadyQueue {

    push_task(task: GraphTask) -> void
    pop_task() -> GraphTask
    is_empty() -> bool
    size() -> i64
}

interface IAutogradEngine {

    build_from_tensor(output: Tensor) -> void

    backward(output: Tensor, grad: Tensor) -> void

    get_gradient(tensor: Tensor) -> Tensor
    get_all_gradients() -> map[string]Tensor
}

interface IAutograd {

    backward(loss: Tensor) -> void
    backward_with_gradient(loss: Tensor, gradient: Tensor) -> void

    get_gradient(tensor: Tensor) -> Tensor
    requires_grad() -> bool

    check_gradient(fn: func(Tensor) -> Tensor, x: Tensor, eps: f64) -> f64

    enable_grad() -> void
    disable_grad() -> void
    is_grad_enabled() -> bool

    get_computation_graph(tensor: Tensor) -> ComputationGraph
}

interface IGradientAccumulator {

    add_gradient(tensor: Tensor, grad: Tensor) -> void

    get_gradient(tensor: Tensor) -> Tensor

    zero_gradients() -> void

    synchronize() -> void
}

interface IGradientValidator {

    check_operator(
        forward_fn: func([]Tensor) -> Tensor,
        backward_fn: func(Tensor) -> []Tensor,
        inputs: []Tensor,
        eps: f64
    ) -> f64

    check_backward_graph(output: Tensor, eps: f64) -> f64
}

interface IAutogradCheckpoint {

    checkpoint(tensor: Tensor) -> void

    recompute_forward(node_id: i64) -> Tensor
}
