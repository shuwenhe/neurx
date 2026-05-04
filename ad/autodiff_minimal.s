package neurx.ad

struct grad_node {
    int id
    []float data
    []int shape
    bool requires_grad
    string op
    int left
    int right
    []float grad
    bool has_grad
}

struct grad_graph {
    []grad_node nodes
}

func copy_float([]float data) []float {
    []float out = []float{cap: len(data)}
    int i = 0
    while i < len(data) {
        out.push(data[i])
        i = i + 1
    }
    out
}

func copy_int([]int data) []int {
    []int out = []int{cap: len(data)}
    int i = 0
    while i < len(data) {
        out.push(data[i])
        i = i + 1
    }
    out
}

func copy_node(grad_node node) grad_node {
    grad_node {
        id: node.id,
        data: copy_float(node.data),
        shape: copy_int(node.shape),
        requires_grad: node.requires_grad,
        op: node.op,
        left: node.left,
        right: node.right,
        grad: copy_float(node.grad),
        has_grad: node.has_grad,
    }
}

func copy_nodes([]grad_node nodes) []grad_node {
    []grad_node out = []grad_node{cap: len(nodes)}
    int i = 0
    while i < len(nodes) {
        out.push(copy_node(nodes[i]))
        i = i + 1
    }
    out
}

func zeros(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out.push(0.0)
        i = i + 1
    }
    out
}

func ones(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out.push(1.0)
        i = i + 1
    }
    out
}

func same_shape([]int a, []int b) bool {
    if len(a) != len(b) {
        return false
    }
    int i = 0
    while i < len(a) {
        if a[i] != b[i] {
            return false
        }
        i = i + 1
    }
    true
}

func add_values([]float a, []float b) []float {
    []float out = []float{cap: len(a)}
    int i = 0
    while i < len(a) {
        out.push(a[i] + b[i])
        i = i + 1
    }
    out
}

func sub_values([]float a, []float b) []float {
    []float out = []float{cap: len(a)}
    int i = 0
    while i < len(a) {
        out.push(a[i] - b[i])
        i = i + 1
    }
    out
}

func mul_values([]float a, []float b) []float {
    []float out = []float{cap: len(a)}
    int i = 0
    while i < len(a) {
        out.push(a[i] * b[i])
        i = i + 1
    }
    out
}

func div_values([]float a, []float b) []float {
    []float out = []float{cap: len(a)}
    int i = 0
    while i < len(a) {
        out.push(a[i] / b[i])
        i = i + 1
    }
    out
}

func fill(int n, float value) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out.push(value)
        i = i + 1
    }
    out
}

func scale_values([]float values, float scale) []float {
    []float out = []float{cap: len(values)}
    int i = 0
    while i < len(values) {
        out.push(values[i] * scale)
        i = i + 1
    }
    out
}

func new_graph() grad_graph {
    grad_graph {
        nodes: [],
    }
}

func node_count(grad_graph graph) int {
    len(graph.nodes)
}

func last_node_id(grad_graph graph) int {
    len(graph.nodes) - 1
}

func add_leaf(grad_graph graph, []float data, []int shape, bool requires_grad) grad_graph {
    []grad_node nodes = copy_nodes(graph.nodes)
    nodes.push(
        grad_node {
            id: len(nodes),
            data: copy_float(data),
            shape: copy_int(shape),
            requires_grad: requires_grad,
            op: "leaf",
            left: -1,
            right: -1,
            grad: zeros(len(data)),
            has_grad: false,
        }
    )
    grad_graph {
        nodes: nodes,
    }
}

func node_data(grad_graph graph, int id) []float {
    copy_float(graph.nodes[id].data)
}

func node_grad(grad_graph graph, int id) []float {
    copy_float(graph.nodes[id].grad)
}

func add_node(grad_graph graph, int left, int right) grad_graph {
    grad_node lhs = graph.nodes[left]
    grad_node rhs = graph.nodes[right]
    []grad_node nodes = copy_nodes(graph.nodes)
    nodes.push(
        grad_node {
            id: len(nodes),
            data: add_values(lhs.data, rhs.data),
            shape: copy_int(lhs.shape),
            requires_grad: lhs.requires_grad || rhs.requires_grad,
            op: "add",
            left: left,
            right: right,
            grad: zeros(len(lhs.data)),
            has_grad: false,
        }
    )
    grad_graph {
        nodes: nodes,
    }
}

func sub_node(grad_graph graph, int left, int right) grad_graph {
    grad_node lhs = graph.nodes[left]
    grad_node rhs = graph.nodes[right]
    []grad_node nodes = copy_nodes(graph.nodes)
    nodes.push(
        grad_node {
            id: len(nodes),
            data: sub_values(lhs.data, rhs.data),
            shape: copy_int(lhs.shape),
            requires_grad: lhs.requires_grad || rhs.requires_grad,
            op: "sub",
            left: left,
            right: right,
            grad: zeros(len(lhs.data)),
            has_grad: false,
        }
    )
    grad_graph {
        nodes: nodes,
    }
}

func mul_node(grad_graph graph, int left, int right) grad_graph {
    grad_node lhs = graph.nodes[left]
    grad_node rhs = graph.nodes[right]
    []grad_node nodes = copy_nodes(graph.nodes)
    nodes.push(
        grad_node {
            id: len(nodes),
            data: mul_values(lhs.data, rhs.data),
            shape: copy_int(lhs.shape),
            requires_grad: lhs.requires_grad || rhs.requires_grad,
            op: "mul",
            left: left,
            right: right,
            grad: zeros(len(lhs.data)),
            has_grad: false,
        }
    )
    grad_graph {
        nodes: nodes,
    }
}

func div_node(grad_graph graph, int left, int right) grad_graph {
    grad_node lhs = graph.nodes[left]
    grad_node rhs = graph.nodes[right]
    []grad_node nodes = copy_nodes(graph.nodes)
    nodes.push(
        grad_node {
            id: len(nodes),
            data: div_values(lhs.data, rhs.data),
            shape: copy_int(lhs.shape),
            requires_grad: lhs.requires_grad || rhs.requires_grad,
            op: "div",
            left: left,
            right: right,
            grad: zeros(len(lhs.data)),
            has_grad: false,
        }
    )
    grad_graph {
        nodes: nodes,
    }
}

func sum_node(grad_graph graph, int input_id) grad_graph {
    grad_node input = graph.nodes[input_id]
    float total = 0.0
    int i = 0
    while i < len(input.data) {
        total = total + input.data[i]
        i = i + 1
    }
    []grad_node nodes = copy_nodes(graph.nodes)
    nodes.push(
        grad_node {
            id: len(nodes),
            data: [total],
            shape: [1],
            requires_grad: input.requires_grad,
            op: "sum",
            left: input_id,
            right: -1,
            grad: [0.0],
            has_grad: false,
        }
    )
    grad_graph {
        nodes: nodes,
    }
}

func mean_node(grad_graph graph, int input_id) grad_graph {
    grad_node input = graph.nodes[input_id]
    float total = 0.0
    int i = 0
    while i < len(input.data) {
        total = total + input.data[i]
        i = i + 1
    }
    []grad_node nodes = copy_nodes(graph.nodes)
    nodes.push(
        grad_node {
            id: len(nodes),
            data: [total / len(input.data)],
            shape: [1],
            requires_grad: input.requires_grad,
            op: "mean",
            left: input_id,
            right: -1,
            grad: [0.0],
            has_grad: false,
        }
    )
    grad_graph {
        nodes: nodes,
    }
}

func accumulate_grad([]grad_node nodes, int id, []float grad) []grad_node {
    if id < 0 {
        return nodes
    }
    if !nodes[id].requires_grad {
        return nodes
    }
    if nodes[id].has_grad {
        nodes[id].grad = add_values(nodes[id].grad, grad)
    } else {
        nodes[id].grad = copy_float(grad)
        nodes[id].has_grad = true
    }
    nodes
}

func backward(grad_graph graph, int output_id) grad_graph {
    []grad_node nodes = copy_nodes(graph.nodes)
    if output_id < 0 || output_id >= len(nodes) {
        return graph
    }
    if !nodes[output_id].requires_grad {
        return graph
    }
    nodes[output_id].grad = ones(len(nodes[output_id].data))
    nodes[output_id].has_grad = true
    int i = output_id
    while i >= 0 {
        grad_node node = nodes[i]
        if node.has_grad {
            if node.op == "add" {
                nodes = accumulate_grad(nodes, node.left, node.grad)
                nodes = accumulate_grad(nodes, node.right, node.grad)
            }
            if node.op == "sub" {
                nodes = accumulate_grad(nodes, node.left, node.grad)
                nodes = accumulate_grad(nodes, node.right, scale_values(node.grad, -1.0))
            }
            if node.op == "mul" {
                []float left_grad = mul_values(node.grad, nodes[node.right].data)
                []float right_grad = mul_values(node.grad, nodes[node.left].data)
                nodes = accumulate_grad(nodes, node.left, left_grad)
                nodes = accumulate_grad(nodes, node.right, right_grad)
            }
            if node.op == "div" {
                []float left_grad = div_values(node.grad, nodes[node.right].data)
                []float denom_sq = mul_values(nodes[node.right].data, nodes[node.right].data)
                []float right_grad = div_values(mul_values(node.grad, nodes[node.left].data), denom_sq)
                nodes = accumulate_grad(nodes, node.left, left_grad)
                nodes = accumulate_grad(nodes, node.right, scale_values(right_grad, -1.0))
            }
            if node.op == "sum" {
                float upstream = node.grad[0]
                []float input_grad = fill(len(nodes[node.left].data), upstream)
                nodes = accumulate_grad(nodes, node.left, input_grad)
            }
            if node.op == "mean" {
                float upstream = node.grad[0] / len(nodes[node.left].data)
                []float input_grad = fill(len(nodes[node.left].data), upstream)
                nodes = accumulate_grad(nodes, node.left, input_grad)
            }
            if node.op == "matmul" {

                []float left_grad = []float{cap: len(nodes[node.left].data)}
                []float right_grad = []float{cap: len(nodes[node.right].data)}
                nodes = accumulate_grad(nodes, node.left, left_grad)
                nodes = accumulate_grad(nodes, node.right, right_grad)
            }
        }
        i = i - 1
    }
    grad_graph {
        nodes: nodes,
    }
}

func ready_for_binary_op(grad_graph graph, int left, int right) bool {
    if left < 0 || right < 0 {
        return false
    }
    if left >= len(graph.nodes) || right >= len(graph.nodes) {
        return false
    }
    same_shape(graph.nodes[left].shape, graph.nodes[right].shape)
}


func matmul_node(grad_graph graph, int left, int right) grad_graph {
    grad_node lhs = graph.nodes[left]
    grad_node rhs = graph.nodes[right]
    []grad_node nodes = copy_nodes(graph.nodes)

    []float result = []float{cap: len(lhs.data)}
    nodes.push(
        grad_node {
            id: len(nodes),
            data: result,
            shape: [lhs.shape[0], rhs.shape[1]],
            requires_grad: lhs.requires_grad || rhs.requires_grad,
            op: "matmul",
            left: left,
            right: right,
            grad: zeros(len(result)),
            has_grad: false,
        }
    )
    grad_graph {
        nodes: nodes,
    }
}


func create_dynamic_graph() grad_graph {
    grad_graph {
        nodes: []grad_node{},
    }
}

func add_node_dynamic(grad_graph graph, grad_node node) grad_graph {
    []grad_node nodes = copy_nodes(graph.nodes)
    node.id = len(nodes)
    nodes.push(node)
    grad_graph {
        nodes: nodes,
    }
}

func execute_dynamic_graph(grad_graph graph, int output_id) []float {
    []float out = []float{cap: 0}
    if output_id < 0 || output_id >= len(graph.nodes) {
        out = []float{cap: 0}
    } else {
        grad_node output_node = graph.nodes[output_id]
        out = copy_float(output_node.data)
    }
    out
}


func compute_higher_order_grad(grad_graph graph, int output_id) grad_graph {
    grad_graph first_order_graph = backward(graph, output_id)
    []grad_node nodes = copy_nodes(first_order_graph.nodes)
    int i = 0
    while i < len(nodes) {
        if nodes[i].requires_grad && nodes[i].has_grad {
            nodes[i].grad = ones(len(nodes[i].grad))
            nodes[i].has_grad = true
        }
        i = i + 1
    }
    grad_graph {
        nodes: nodes,
    }
}

func synchronize_gradients([]grad_node nodes, int num_workers) []grad_node {
    int i = 0
    while i < len(nodes) {
        if nodes[i].requires_grad && nodes[i].has_grad {
            nodes[i].grad = scale_values(nodes[i].grad, 1.0 / num_workers)
        }
        i = i + 1
    }
    nodes
}

func distributed_backward(grad_graph graph, int output_id, int num_workers) grad_graph {
    grad_graph local_graph = backward(graph, output_id)
    []grad_node synchronized_nodes = synchronize_gradients(local_graph.nodes, num_workers)
    grad_graph {
        nodes: synchronized_nodes,
    }
}
