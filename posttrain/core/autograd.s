package neurx.posttrain.core.autograd
use std.io.println

struct computation_node_s {
    string op_name
    tensor_s output
    []tensor_s inputs
    int node_id
    bool requires_grad
}

struct gradient_tape_s {
    []computation_node_s operations
    int op_count
    bool is_recording
}

struct backward_context_s {
    tensor_s grad_output
    []tensor_s grad_inputs
    string op_type
    int tensor_id
}

struct autograd_state_s {
    gradient_tape_s tape
    []tensor_s gradient_buffer
    bool grad_enabled
    int tape_depth
}

func new_gradient_tape_s() gradient_tape_s {
    gradient_tape_s {
        operations: make([]computation_node_s, 0),
        op_count: 0,
        is_recording: true,
    }
}

func new_computation_node_s(string op, tensor_s out, []tensor_s ins) computation_node_s {
    computation_node_s {
        op_name: op,
        output: out,
        inputs: ins,
        node_id: 0,
        requires_grad: true,
    }
}

func record_operation_s(gradient_tape_s tape, string op_name, tensor_s output, []tensor_s inputs) gradient_tape_s {
    computation_node_s node = new_computation_node_s(op_name, output, inputs)
    node.node_id = tape.op_count
    gradient_tape_s {
        operations: append(tape.operations, node),
        op_count: tape.op_count + 1,
        is_recording: tape.is_recording,
    }
}

func enable_grad_s() {
    println("[Autograd] Gradient tracking enabled")
}

func disable_grad_s() {
    println("[Autograd] Gradient tracking disabled")
}

func backward_matmul_s(tensor_s grad_output, tensor_s input_a, tensor_s input_b) []tensor_s {
    []tensor_s grads
    tensor_s grad_a = make_zeros_like_s(input_a)
    tensor_s grad_b = make_zeros_like_s(input_b)
    grads = append(grads, grad_a)
    grads = append(grads, grad_b)
    grads
}

func backward_add_s(tensor_s grad_output, tensor_s input_a, tensor_s input_b) []tensor_s {
    []tensor_s grads
    tensor_s grad_a = copy_tensor_s(grad_output)
    tensor_s grad_b = copy_tensor_s(grad_output)
    grads = append(grads, grad_a)
    grads = append(grads, grad_b)
    grads
}

func backward_mul_s(tensor_s grad_output, tensor_s input_a, tensor_s input_b) []tensor_s {
    []tensor_s grads
    tensor_s grad_a = mul_tensors_s(grad_output, input_b)
    tensor_s grad_b = mul_tensors_s(grad_output, input_a)
    grads = append(grads, grad_a)
    grads = append(grads, grad_b)
    grads
}

func backward_softmax_s(tensor_s grad_output, tensor_s forward_output) tensor_s {
    println("[Autograd] Softmax backward")
    grad_output
}

func backward_layer_norm_s(tensor_s grad_output, tensor_s input, float epsilon) tensor_s {
    println("[Autograd] LayerNorm backward")
    grad_output
}

func backward_relu_s(tensor_s grad_output, tensor_s input) tensor_s {
    []float grad_data = make([]float, 0)
    int i = 0
    while i < len(input.data) {
        if input.data[i] > 0.0 {
            grad_data = append(grad_data, grad_output.data[i])
        } else {
            grad_data = append(grad_data, 0.0)
        }
        i = i + 1
    }
    tensor_s {
        data: grad_data,
        shape: grad_output.shape,
        strides: grad_output.strides,
        rank: grad_output.rank,
        total_elements: grad_output.total_elements,
        dtype: grad_output.dtype,
        device: grad_output.device,
    }
}

func backward_linear_s(tensor_s grad_output, tensor_s input, tensor_s weight) []tensor_s {
    []tensor_s grads
    tensor_s grad_input = matmul_s(grad_output, transpose_s(weight))
    tensor_s grad_weight = matmul_s(transpose_s(input), grad_output)
    grads = append(grads, grad_input)
    grads = append(grads, grad_weight)
    grads
}

func chain_rule_s(tensor_s upstream_grad, string op_type, tensor_s input) tensor_s {
    if op_type == "relu" {
        return backward_relu_s(upstream_grad, input)
    }
    upstream_grad
}

func make_zeros_like_s(tensor_s t) tensor_s {
    []float zeros = make([]float, 0)
    int i = 0
    while i < t.total_elements {
        zeros = append(zeros, 0.0)
        i = i + 1
    }
    tensor_s {
        data: zeros,
        shape: t.shape,
        strides: t.strides,
        rank: t.rank,
        total_elements: t.total_elements,
        dtype: t.dtype,
        device: t.device,
    }
}

func copy_tensor_s(tensor_s t) tensor_s {
    []float copied = make([]float, 0)
    int i = 0
    while i < len(t.data) {
        copied = append(copied, t.data[i])
        i = i + 1
    }
    tensor_s {
        data: copied,
        shape: t.shape,
        strides: t.strides,
        rank: t.rank,
        total_elements: t.total_elements,
        dtype: t.dtype,
        device: t.device,
    }
}

func mul_tensors_s(tensor_s a, tensor_s b) tensor_s {
    []float result = make([]float, 0)
    int i = 0
    while i < len(a.data) {
        result = append(result, a.data[i] * b.data[i])
        i = i + 1
    }
    tensor_s {
        data: result,
        shape: a.shape,
        strides: a.strides,
        rank: a.rank,
        total_elements: a.total_elements,
        dtype: a.dtype,
        device: a.device,
    }
}

func matmul_s(tensor_s a, tensor_s b) tensor_s {
    []float result = make([]float, 0)
    tensor_s {
        data: result,
        shape: make([]int, 0),
        strides: make([]int, 0),
        rank: 2,
        total_elements: 0,
        dtype: "float32",
        device: "cpu",
    }
}

func transpose_s(tensor_s t) tensor_s {
    t
}

