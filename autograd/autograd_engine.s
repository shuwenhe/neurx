package neurx.autograd

use neurx.tensor.tensor

// ============================================================================
// Autograd Engine - Complete Automatic Differentiation System
// Supports: Computation graph construction, topological sort, backward pass
// Covers all Transformer operations: MatMul, Softmax, layer_norm, embedding,
// GELU/SiLU, RoPE, Attention, cross_entropy_loss, and more.
// ============================================================================

// ---- Node Types for Computation Graph ----
enum node_type {
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

// ---- Edge: Connects nodes in computation graph ----
struct edge {
    int source_node_id
    int target_node_id
    tensor tensor_data  // Tensor flowing through this edge
}

// ---- Node in computation graph ----
struct node {
    int id
    node_type op_type
    []tensor inputs       // Input tensors
    tensor output         // Output tensor
    []int children_ids    // Downstream node IDs
    []int parent_ids      // Upstream node IDs
    bool requires_grad
    // Context saved for backward (e.g., input values needed for gradient)
    map[string]tensor ctx
}

// ---- Backward Rule Result ----
struct backward_result {
    []tensor input_grads  // Gradients for each input
    bool success
}

// ---- Computation Graph ----
struct computation_graph {
    []node nodes
    []edge edges
    int next_node_id
    bool is_recording
    []int topo_order  // Topological order for backward
}

// Create new computation graph
func new_graph() computation_graph {
    computation_graph {
        nodes: [],
        edges: [],
        next_node_id: 0,
        is_recording: true,
        topo_order: [],
    }
}

// Start recording operations
func start_recording(computation_graph g) computation_graph {
    g.is_recording = true
    g
}

// Stop recording
func stop_recording(computation_graph g) computation_graph {
    g.is_recording = false
    g
}

// Add node to graph
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
    
    g.nodes.push(n)
    g.next_node_id = g.next_node_id + 1
    
    (g, node_id)
}

// Add edge between nodes
func add_edge(computation_graph g, int src_id, int dst_id, tensor t) computation_graph {
    edge e {
        source_node_id: src_id,
        target_node_id: dst_id,
        tensor_data: t,
    }
    
    g.edges.push(e)
    
    // Update node connections
    for i in 0..len(g.nodes) {
        if g.nodes[i].id == src_id {
            g.nodes[i].children_ids.push(dst_id)
        }
        if g.nodes[i].id == dst_id {
            g.nodes[i].parent_ids.push(src_id)
        }
    }
    
    g
}

// Save context for backward
func save_context(computation_graph g, int node_id, string key, tensor value) computation_graph {
    for i in 0..len(g.nodes) {
        if g.nodes[i].id == node_id {
            g.nodes[i].ctx[key] = value
            break
        }
    }
    g
}

// Get context
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

// ========================================================================
// TOPOLOGICAL SORT for Backward Pass (Kahn's algorithm with DFS fallback)
// ========================================================================

func compute_topological_order(computation_graph g) computation_graph {
    int n = len(g.nodes)
    if n == 0 {
        return g
    }
    
    // Compute in-degree for each node
    []int in_degree = []int{cap: n}
    for i in 0..n {
        in_degree[i] = len(g.nodes[i].parent_ids)
    }
    
    // Find all nodes with in-degree 0 (root/leaf nodes for forward)
    []int queue = []
    for i in 0..n {
        if in_degree[i] == 0 {
            queue.push(i)
        }
    }
    
    []int order = []
    int count = 0
    
    while len(queue) > 0 {
        int u = queue.pop_front()
        order.push(u)
        count = count + 1
        
        // For each child
        for child_id in g.nodes[u].children_ids {
            // Find child index
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
                    queue.push(child_idx)
                }
            }
        }
    }
    
    // If not all nodes processed, there's a cycle (shouldn't happen in valid graphs)
    if count != n {
        println("Warning: Cycle detected in computation graph!")
        // Fallback: just use reverse order
        order = []
        for i in n-1 .. 0 {
            order.push(i)
        }
    }
    
    // Reverse for backward pass (we need to process in reverse topological order)
    []int reversed = []
    for i in len(order)-1 .. 0 {
        reversed.push(order[i])
    }
    
    g.topo_order = reversed
    g
}

// ========================================================================
// BACKWARD PASS ENGINE
// ========================================================================

// Main backward function - triggers full backward pass
func backward(computation_graph g, tensor loss_tensor, []float grad_output) computation_graph {
    if !loss_tensor.requires_grad {
        println("Warning: backward() called on tensor that doesn't require grad")
        return g
    }
    
    // Step 1: Compute topological order
    g = compute_topological_order(g)
    
    // Step 2: Initialize gradient of loss node
    // Find the loss node (last node in forward order, first in backward)
    if len(g.topo_order) > 0 {
        int loss_node_idx = g.topo_order[0]
        
        // Set gradient of loss output to grad_output (usually all 1s)
        if len(grad_output) == len(g.nodes[loss_node_idx].output.data) {
            g.nodes[loss_node_idx].output.grad = grad_output
        } else {
            // Default: initialize with ones
            int n_out = len(g.nodes[loss_node_idx].output.data)
            g.nodes[loss_node_idx].output.grad = ones_like_internal(g.nodes[loss_node_idx].output.data)
        }
    }
    
    // Step 3: Process each node in reverse topological order
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
        
        // Dispatch to appropriate backward kernel
        backward_result result = dispatch_backward(current, grad_output_tensor)
        
        if result.success  len(result.input_grads) > 0 {
            // Propagate gradients to inputs (parents)
            for grad_idx in 0..len(result.input_grads) {
                if grad_idx < len(current.inputs)  len(current.parent_ids) > grad_idx {
                    int parent_node_id = current.parent_ids[grad_idx]
                    
                    // Find parent node and accumulate gradient
                    for p_idx in 0..len(g.nodes) {
                        if g.nodes[p_idx].id == parent_node_id {
                            // Accumulate gradient (handle multiple consumers)
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

// Helper: Accumulate gradient to a node's output
func accumulate_to_node_output(node *n, tensor grad) {
    if len(n.output.grad) == 0 {
        n.output.grad = copy_tensor(grad.data)
    } else {
        // Gradient accumulation (add gradients from different paths)
        for i in 0..min(len(n.output.grad), len(grad.data)) {
            n.output.grad[i] = n.output.grad[i] + grad.data[i]
        }
    }
}

// Copy tensor data
func copy_tensor([]float data) []float {
    []float out = []float{cap: len(data)}
    for i in 0..len(data) {
        out[i] = data[i]
    }
    out
}

// Min helper
func min(int a, int b) int {
    if a < b { a } else { b }
}

// Dispatch backward based on operation type
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
