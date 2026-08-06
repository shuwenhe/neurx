struct graph_node {
    id: i64
    operation_name: string
    forward_inputs: []tensor
    forward_output: tensor
    backward_fn: func(grad: tensor) -> []tensor
}
struct graph_edge {
    from_node_id: i64
    to_node_id: i64
    tensor_index: i64
    prev_func: func(grad: tensor) -> tensor
}
struct computation_graph {
    nodes: map[i64]graph_node
    edges: []graph_edge
    leaf_tensors: []tensor
    output_tensor: tensor
}
struct graph_task {
    id: i64
    node_id: i64
    grad_tensor: tensor
    dependencies_remaining: i64
}
struct ready_queue {
    tasks: []graph_task
}
struct autograd_engine {
    graph: computation_graph
    ready_queue: ready_queue
    node_results: map[i64][]tensor
}
interface IGraphBuilder {
    build_graph(output: tensor) -> computation_graph
    get_graph(tensor: tensor) -> computation_graph
    clear_graph(tensor: tensor) -> void
}
interface IGraphNode {
    node_id() -> i64
    operation_name() -> string
    forward_inputs() -> []tensor
    forward_output() -> tensor
    set_backward_fn(fn: func(tensor) -> []tensor) -> void
    backward_fn() -> func(tensor) -> []tensor
}
interface IGraphEdge {
    from_node() -> i64
    to_node() -> i64
    tensor_index() -> i64
}
interface IGraphTask {
    task_id() -> i64
    node_id() -> i64
    gradient() -> tensor
    dependencies_remaining() -> i64
    decrement_dependencies() -> void
}
interface IReadyQueue {
    push_task(task: graph_task) -> void
    pop_task() -> graph_task
    is_empty() -> bool
    size() -> i64
}
interface IAutogradEngine {
    build_from_tensor(output: tensor) -> void
    backward(output: tensor, grad: tensor) -> void
    get_gradient(tensor: tensor) -> tensor
    get_all_gradients() -> map[string]tensor
}
interface IAutograd {
    backward(loss: tensor) -> void
    backward_with_gradient(loss: tensor, gradient: tensor) -> void
    get_gradient(tensor: tensor) -> tensor
    requires_grad() -> bool
    check_gradient(fn: func(tensor) -> tensor, x: tensor, eps: f64) -> f64
    enable_grad() -> void
    disable_grad() -> void
    is_grad_enabled() -> bool
    get_computation_graph(tensor: tensor) -> computation_graph
}
interface IGradientAccumulator {
    add_gradient(tensor: tensor, grad: tensor) -> void
    get_gradient(tensor: tensor) -> tensor
    zero_gradients() -> void
    synchronize() -> void
}
interface IGradientValidator {
    check_operator(
        forward_fn: func([]tensor) -> tensor,
        backward_fn: func(tensor) -> []tensor,
        inputs: []tensor,
        eps: f64
    ) -> f64
    check_backward_graph(output: tensor, eps: f64) -> f64
}
interface IAutogradCheckpoint {
    checkpoint(tensor: tensor) -> void
    recompute_forward(node_id: i64) -> tensor
}
