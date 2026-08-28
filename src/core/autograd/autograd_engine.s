package neurx.autograd
use neurx.tensor.tensor
    INPUT,
    ADD,
    MUL,
    SUB,
    DIV,
    MATMUL,
    TRANSPOSE,
    RESHAPE,
    SUM,
    MEAN,
    SOFTMAX,
    LOG_SOFTMAX,
    RELU,
    GELU,
    SILU,
    LAYER_NORM,
    RMS_NORM,
    EMBEDDING,
    DROPOUT,
    CONCAT,
    SPLIT,
    VIEW,
    POW,
    EXP,
    LOG,
    SQRT,
    CLAMP,
    SCALE,
    ROPE,
    CROSS_ENTROPY_LOSS,
    SWIGLU,
    ATTENTION_SCORES,
    BROADCAST,
    REDUCE_SUM,
    REDUCE_MEAN,
    MASKED_FILL,
    NORM,
}
struct edge {
    int source_node_id
    int target_node_id
    tensor tensor_data
}
struct node {
    int id
    node_type op_type
    []tensor inputs
    tensor output
    int[] children_ids
    int[] parent_ids
    bool requires_grad
    map[string]tensor ctx
}
struct backward_result {
    []tensor input_grads
    bool success
}
struct computation_graph {
    []node nodes
    []edge edges
    int next_node_id
    bool is_recording
    int[] topo_order
}
func new_graph() computation_graph {
    computation_graph {
        nodes: [],
        edges: [],
        next_node_id: 0,
        is_recording: true,
        topo_order: [],
    }
}
func start_recording(computation_graph g) computation_graph {
    g.is_recording = true
    g
}
func stop_recording(computation_graph g) computation_graph {
    g.is_recording = false
    g
}
func add_node(
    computation_graph g,
    node_type op_type,
    []tensor inputs,
    tensor output,
    bool requires_grad
) (computation_graph, int) {
    int node_id = g.next_node_id
    node n {
        id: node_id,
        op_type: op_type,
        inputs: inputs,
        output: output,
        children_ids: [],
        parent_ids: [],
        requires_grad: requires_grad || output.requires_grad,
        ctx: {},
    }
    g.nodes = append(g.nodes, n)
    g.next_node_id = g.next_node_id + 1
    (g, node_id)
}
func add_edge(computation_graph g, int src_id, int dst_id, tensor t) computation_graph {
    edge e {
        source_node_id: src_id,
        target_node_id: dst_id,
        tensor_data: t,
    }
    g.edges = append(g.edges, e)
    for i in 0..len(g.nodes) {
        if g.nodes[i].id == src_id {
            g.nodes[i].children_ids = append(.children_ids, dst_id)
        }
        if g.nodes[i].id == dst_id {
            g.nodes[i].parent_ids = append(.parent_ids, src_id)
        }
    }
    g
}
func save_context(computation_graph g, int node_id, string key, tensor value) computation_graph {
    for i in 0..len(g.nodes) {
        if g.nodes[i].id == node_id {
            g.nodes[i].ctx[key] = value
            break
        }
    }
    g
}
func get_context(computation_graph g, int node_id, string key) tensor {
    for i in 0..len(g.nodes) {
        if g.nodes[i].id == node_id {
            if key in g.nodes[i].ctx {
                return g.nodes[i].ctx[key]
            }
        }
    }
    neurx.tensor.zeros_like(tensor {data: [], shape: []})
}
func compute_topological_order(computation_graph g) computation_graph {
    int n = len(g.nodes)
    if n == 0 {
        return g
    }
    int[] in_degree = int[]{cap: n}
    for i in 0..n {
        in_degree[i] = len(g.nodes[i].parent_ids)
    }
    int[] queue = []
    for i in 0..n {
        if in_degree[i] == 0 {
            queue = append(queue, i)
        }
    }
    int[] order = []
    int count = 0
    for len(queue) > 0 {
        int u = queue.pop_front()
        order = append(order, u)
        count = count + 1
        for child_id in g.nodes[u].children_ids {
            int child_idx = -1
            for j in 0..n {
                if g.nodes[j].id == child_id {
                    child_idx = j
                    break
                }
            }
            if child_idx >= 0 {
                in_degree[child_idx] = in_degree[child_idx] - 1
                if in_degree[child_idx] == 0 {
                    queue = append(queue, child_idx)
                }
            }
        }
    }
    if count != n {
        println("Warning: Cycle detected in computation graph!")
        order = []
        for i in n-1 .. 0 {
            order = append(order, i)
        }
    }
    int[] reversed = []
    for i in len(order)-1 .. 0 {
        reversed = append(reversed, order[i])
    }
    g.topo_order = reversed
    g
}
func backward(computation_graph g, tensor loss_tensor, float[] grad_output) computation_graph {
    if !loss_tensor.requires_grad {
        println("Warning: backward() called on tensor that doesn't require grad")
        return g
    }
    g = compute_topological_order(g)
    if len(g.topo_order) > 0 {
        int loss_node_idx = g.topo_order[0]
        if len(grad_output) == len(g.nodes[loss_node_idx].output.data) {
            g.nodes[loss_node_idx].output.grad = grad_output
        } else {
            int n_out = len(g.nodes[loss_node_idx].output.data)
            g.nodes[loss_node_idx].output.grad = ones_like_internal(g.nodes[loss_node_idx].output.data)
        }
    }
    for idx in g.topo_order {
        node current = g.nodes[idx]
        if !current.requires_grad || len(current.output.grad) == 0 {
            continue
        }
        tensor grad_output_tensor {
            data: current.output.grad,
            grad: [],
            shape: current.output.shape,
            requires_grad: false,
        }
        backward_result result = dispatch_backward(current, grad_output_tensor)
        if result.success  len(result.input_grads) > 0 {
            for grad_idx in 0..len(result.input_grads) {
                if grad_idx < len(current.inputs)  len(current.parent_ids) > grad_idx {
                    int parent_node_id = current.parent_ids[grad_idx]
                    for p_idx in 0..len(g.nodes) {
                        if g.nodes[p_idx].id == parent_node_id {
                            accumulate_to_node_output(g.nodes[p_idx], result.input_grads[grad_idx])
                            break
                        }
                    }
                }
            }
        }
    }
    g
}
func accumulate_to_node_output(node *n, tensor grad) {
    if len(n.output.grad) == 0 {
        n.output.grad = copy_tensor(grad.data)
    } else {
        for i in 0..min(len(n.output.grad), len(grad.data)) {
            n.output.grad[i] = n.output.grad[i] + grad.data[i]
        }
    }
}
func copy_tensor(float[] data) float[] {
    float[] out = float[]{cap: len(data)}
    for i in 0..len(data) {
        out[i] = data[i]
    }
    out
}
func min(int a, int b) int {
    if a < b { a } else { b }
}
func dispatch_backward(node n, tensor grad_output) backward_result {
    switch n.op_type {
        case node_type.MATMUL:
            backward_matmul(n, grad_output)
        case node_type.ADD:
            backward_add(n, grad_output)
        case node_type.MUL:
            backward_mul(n, grad_output)
        case node_type.SUB:
            backward_sub(n, grad_output)
        case node_type.DIV:
            backward_div(n, grad_output)
        case node_type.SOFTMAX:
            backward_softmax(n, grad_output)
        case node_type.LOG_SOFTMAX:
            backward_log_softmax(n, grad_output)
        case node_type.RELU:
            backward_relu(n, grad_output)
        case node_type.GELU:
            backward_gelu(n, grad_output)
        case node_type.SILU:
            backward_silu(n, grad_output)
        case node_type.LAYER_NORM:
            backward_layer_norm(n, grad_output)
        case node_type.RMS_NORM:
            backward_rms_norm(n, grad_output)
        case node_type.EMBEDDING:
            backward_embedding(n, grad_output)
        case node_type.SUM:
            backward_sum(n, grad_output)
        case node_type.MEAN:
            backward_mean(n, grad_output)
        case node_type.TRANSPOSE:
            backward_transpose(n, grad_output)
        case node_type.RESHAPE:
            backward_reshape(n, grad_output)
        case node_type.POW:
            backward_pow(n, grad_output)
        case node_type.EXP:
            backward_exp(n, grad_output)
        case node_type.LOG:
            backward_log(n, grad_output)
        case node_type.CONCAT:
            backward_concat(n, grad_output)
        case node_type.CROSS_ENTROPY_LOSS:
            backward_cross_entropy_loss(n, grad_output)
        case node_type.SWIGLU:
            backward_swiglu(n, grad_output)
        case node_type.ROPE:
            backward_rope(n, grad_output)
        case node_type.BROADCAST:
            backward_broadcast(n, grad_output)
        case node_type.REDUCE_SUM:
            backward_reduce_sum(n, grad_output)
        case node_type.REDUCE_MEAN:
            backward_reduce_mean(n, grad_output)
        case node_type.MASKED_FILL:
            backward_masked_fill(n, grad_output)
        default:
            backward_result {
                input_grads: [],
                success: false,
            }
    }
}
