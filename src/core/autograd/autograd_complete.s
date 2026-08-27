package neurx.autograd.complete
use neurx.tensor.{tensor, zeros, ones, fill, new}

struct gradient_node {
    int id
    tensor value
    string operation
    int[] inputs
    tensor grad
}

struct gradient_tape {
    []gradient_node nodes
    int node_counter
    bool recording
}

func create_tape() gradient_tape {
    gradient_tape {
        nodes: []gradient_node{cap: 1000},
        node_counter: 0,
        recording: true,
    }
}

func add_node(gradient_tape tape, tensor value, string op, int[] inputs) (gradient_tape, int) {
    if !tape.recording {
        return tape, -1
    }
    gradient_node node = gradient_node {
        id: tape.node_counter,
        value: value,
        operation: op,
        inputs: inputs,
        grad: zeros(value.shape),
    }
    tape.nodes = append(tape.nodes, node)
    int node_id = tape.node_counter
    tape.node_counter = tape.node_counter + 1
    (tape, node_id)
}

func ad_add(gradient_tape tape, tensor a, tensor b) (gradient_tape, int, tensor) {
    tensor result = zeros(a.shape)
    int i = 0
    for i < len(a.data) {
        result.data[i] = a.data[i] + b.data[i]
        i = i + 1
    }
    result.requires_grad = a.requires_grad || b.requires_grad
    (tape, node_id) = add_node(tape, result, "add", [get_node_id(a), get_node_id(b)])
    (tape, node_id, result)
}

func ad_mul(gradient_tape tape, tensor a, tensor b) (gradient_tape, int, tensor) {
    tensor result = zeros(a.shape)
    int i = 0
    for i < len(a.data) {
        result.data[i] = a.data[i] * b.data[i]
        i = i + 1
    }
    result.requires_grad = a.requires_grad || b.requires_grad
    (tape, node_id) = add_node(tape, result, "mul", [get_node_id(a), get_node_id(b)])
    (tape, node_id, result)
}

func ad_matmul(gradient_tape tape, tensor a, tensor b) (gradient_tape, int, tensor) {
    int m = a.shape[0]
    int n = a.shape[1]
    int p = b.shape[1]
    tensor result = zeros([m, p])
    int i = 0
    for i < m {
        int j = 0
        for j < p {
            float sum = 0.0
            int k = 0
            for k < n {
                sum = sum + a.data[i * n + k] * b.data[k * p + j]
                k = k + 1
            }
            result.data[i * p + j] = sum
            j = j + 1
        }
        i = i + 1
    }
    result.requires_grad = a.requires_grad || b.requires_grad
    (tape, node_id) = add_node(tape, result, "matmul", [get_node_id(a), get_node_id(b)])
    (tape, node_id, result)
}

func ad_transpose(gradient_tape tape, tensor a) (gradient_tape, int, tensor) {
    int m = a.shape[0]
    int n = a.shape[1]
    tensor result = zeros([n, m])
    int i = 0
    for i < m {
        int j = 0
        for j < n {
            result.data[j * m + i] = a.data[i * n + j]
            j = j + 1
        }
        i = i + 1
    }
    result.requires_grad = a.requires_grad
    (tape, node_id) = add_node(tape, result, "transpose", [get_node_id(a)])
    (tape, node_id, result)
}

func ad_softmax(gradient_tape tape, tensor logits) (gradient_tape, int, tensor) {
    tensor exp_logits = zeros(logits.shape)
    float max_val = logits.data[0]
    int i = 0
    for i < len(logits.data) {
        if logits.data[i] > max_val {
            max_val = logits.data[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    for i < len(logits.data) {
        exp_logits.data[i] = exp_approx(logits.data[i] - max_val)
        sum_exp = sum_exp + exp_logits.data[i]
        i = i + 1
    }
    tensor result = zeros(logits.shape)
    i = 0
    for i < len(exp_logits.data) {
        result.data[i] = exp_logits.data[i] / sum_exp
        i = i + 1
    }
    result.requires_grad = logits.requires_grad
    (tape, node_id) = add_node(tape, result, "softmax", [get_node_id(logits)])
    (tape, node_id, result)
}

func ad_relu(gradient_tape tape, tensor x) (gradient_tape, int, tensor) {
    tensor result = zeros(x.shape)
    int i = 0
    for i < len(x.data) {
        if x.data[i] > 0.0 {
            result.data[i] = x.data[i]
        } else {
            result.data[i] = 0.0
        }
        i = i + 1
    }
    result.requires_grad = x.requires_grad
    (tape, node_id) = add_node(tape, result, "relu", [get_node_id(x)])
    (tape, node_id, result)
}

func ad_layer_norm(gradient_tape tape, tensor x, float eps) (gradient_tape, int, tensor) {
    float mean = 0.0
    int i = 0
    for i < len(x.data) {
        mean = mean + x.data[i]
        i = i + 1
    }
    mean = mean / float_from_int(len(x.data))
    float variance = 0.0
    i = 0
    for i < len(x.data) {
        float diff = x.data[i] - mean
        variance = variance + diff * diff
        i = i + 1
    }
    variance = variance / float_from_int(len(x.data))
    tensor result = zeros(x.shape)
    i = 0
    for i < len(x.data) {
        result.data[i] = (x.data[i] - mean) / sqrt_approx(variance + eps)
        i = i + 1
    }
    result.requires_grad = x.requires_grad
    (tape, node_id) = add_node(tape, result, "layer_norm", [get_node_id(x)])
    (tape, node_id, result)
}

func backward_add(tensor grad, tensor a, tensor b, tensor grad_a, tensor grad_b) (tensor, tensor) {
    int i = 0
    for i < len(grad.data) {
        grad_a.data[i] = grad_a.data[i] + grad.data[i]
        grad_b.data[i] = grad_b.data[i] + grad.data[i]
        i = i + 1
    }
    (grad_a, grad_b)
}

func backward_mul(tensor grad, tensor a, tensor b, tensor grad_a, tensor grad_b) (tensor, tensor) {
    int i = 0
    for i < len(grad.data) {
        grad_a.data[i] = grad_a.data[i] + grad.data[i] * b.data[i]
        grad_b.data[i] = grad_b.data[i] + grad.data[i] * a.data[i]
        i = i + 1
    }
    (grad_a, grad_b)
}

func backward_matmul(tensor grad, tensor a, tensor b, tensor grad_a, tensor grad_b) (tensor, tensor) {
    int m = a.shape[0]
    int n = a.shape[1]
    int p = b.shape[1]
    int i = 0
    for i < m {
        int j = 0
        for j < n {
            float sum = 0.0
            int k = 0
            for k < p {
                sum = sum + grad.data[i * p + k] * b.data[j * p + k]
                k = k + 1
            }
            grad_a.data[i * n + j] = grad_a.data[i * n + j] + sum
            j = j + 1
        }
        i = i + 1
    }
    i = 0
    for i < n {
        int j = 0
        for j < p {
            float sum = 0.0
            int k = 0
            for k < m {
                sum = sum + a.data[k * n + i] * grad.data[k * p + j]
                k = k + 1
            }
            grad_b.data[i * p + j] = grad_b.data[i * p + j] + sum
            j = j + 1
        }
        i = i + 1
    }
    (grad_a, grad_b)
}

func backward_softmax(tensor grad, tensor softmax_output, tensor grad_input) tensor {
    int i = 0
    for i < len(grad.data) {
        float grad_dot_softmax = 0.0
        int j = 0
        for j < len(grad.data) {
            grad_dot_softmax = grad_dot_softmax + softmax_output.data[j] * grad.data[j]
            j = j + 1
        }
        grad_input.data[i] = grad_input.data[i] +
            softmax_output.data[i] * (grad.data[i] - grad_dot_softmax)
        i = i + 1
    }
    grad_input
}

func backward_relu(tensor grad, tensor x, tensor grad_input) tensor {
    int i = 0
    for i < len(grad.data) {
        if x.data[i] > 0.0 {
            grad_input.data[i] = grad_input.data[i] + grad.data[i]
        }
        i = i + 1
    }
    grad_input
}

func backward_tape(
    gradient_tape tape,
    tensor final_grad
) []tensor {
    int num_nodes = tape.node_counter
    []tensor gradients = []tensor{cap: num_nodes}
    int i = 0
    for i < num_nodes {
        gradients = append(gradients, zeros(tape.nodes[i].value.shape))
        i = i + 1
    }
    i = num_nodes - 1
    for i >= 0 {
        gradient_node node = tape.nodes[i]
        tensor grad = gradients[i]
        if node.operation == "add" {
            int input_a = node.inputs[0]
            int input_b = node.inputs[1]
            (gradients[input_a], gradients[input_b]) =
                backward_add(grad, tape.nodes[input_a].value, tape.nodes[input_b].value,
                            gradients[input_a], gradients[input_b])
        }
        if node.operation == "mul" {
            int input_a = node.inputs[0]
            int input_b = node.inputs[1]
            (gradients[input_a], gradients[input_b]) =
                backward_mul(grad, tape.nodes[input_a].value, tape.nodes[input_b].value,
                            gradients[input_a], gradients[input_b])
        }
        if node.operation == "matmul" {
            int input_a = node.inputs[0]
            int input_b = node.inputs[1]
            (gradients[input_a], gradients[input_b]) =
                backward_matmul(grad, tape.nodes[input_a].value, tape.nodes[input_b].value,
                               gradients[input_a], gradients[input_b])
        }
        if node.operation == "relu" {
            int input_id = node.inputs[0]
            gradients[input_id] = backward_relu(grad, tape.nodes[input_id].value, gradients[input_id])
        }
        if node.operation == "softmax" {
            int input_id = node.inputs[0]
            gradients[input_id] = backward_softmax(grad, node.value, gradients[input_id])
        }
        i = i - 1
    }
    gradients
}

func get_node_id(tensor t) int {
    0
}

func float_from_int(int x) float {
    0.0 + x
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    for i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i <= 12 {
        term = term * x / float_from_int(i)
        result = result + term
        i = i + 1
    }
    result
}
