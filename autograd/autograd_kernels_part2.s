package neurx.autograd

use neurx.tensor.tensor











func backward_softmax(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }

    tensor input = n.inputs[0]


    tensor softmax_output = get_context_safe_tensor(n, "softmax_output", input)


    int dim = get_context_safe_int(n, "dim", len(input.shape) - 1)


    []int shape = softmax_output.shape

    if dim == len(shape) - 1 || dim == -1 {

        int batch_size = 1
        int seq_len = 1
        int vocab_size = shape[len(shape)-1]


        if len(shape) >= 2 {
            batch_size = shape[0]
            seq_len = shape[1] if len(shape) > 2 else 1
            vocab_size = shape[len(shape)-1]
        }

        int row_size = vocab_size
        int total_rows = len(softmax_output.data) / row_size

        []float grad_input = []float{cap: len(softmax_output.data)}

        for row in 0..total_rows {

            float dot_product = 0.0
            for col in 0..row_size {
                int idx = row * row_size + col
                dot_product = dot_product + grad_output.data[idx] * softmax_output.data[idx]
            }


            for col in 0..row_size {
                int idx = row * row_size + col
                grad_input[idx] = softmax_output.data[idx] * (grad_output.data[idx] - dot_product)
            }
        }

        tensor result { data: grad_input, grad: [], shape: shape, requires_grad: true }
        return backward_result { input_grads: [result], success: true }
    }


    []float grad_data = []float{cap: len(input.data)}
    for i in 0..len(input.data) {
        float y = softmax_output.data[i]
        grad_data[i] = y * (grad_output.data[i] - y * grad_output.data[i])
    }

    tensor result { data: grad_data, grad: [], shape: shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}







func backward_log_softmax(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }

    tensor input = n.inputs[0]
    tensor softmax_output = get_context_safe_tensor(n, "softmax_output", input)
    int dim = get_context_safe_int(n, "dim", len(input.shape) - 1)

    []int shape = softmax_output.shape
    int row_size = shape[dim]
    int total_elements = len(softmax_output.data)
    int num_rows = total_elements / row_size

    []float grad_input = []float{cap: total_elements}

    for row in 0..num_rows {

        float grad_sum = 0.0
        for col in 0..row_size {
            int idx = row * row_size + col
            grad_sum = grad_sum + grad_output.data[idx]
        }


        for col in 0..row_size {
            int idx = row * row_size + col
            grad_input[idx] = grad_output.data[idx] - softmax_output.data[idx] * grad_sum
        }
    }

    tensor result { data: grad_input, grad: [], shape: shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}







func backward_relu(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }

    tensor input = n.inputs[0]
    []float grad_data = []float{cap: len(input.data)}

    for i in 0..len(input.data) {
        if input.data[i] > 0.0 {
            grad_data[i] = grad_output.data[i]
        } else {
            grad_data[i] = 0.0
        }
    }

    tensor result { data: grad_data, grad: [], shape: input.shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}








func backward_gelu(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }

    tensor input = n.inputs[0]
    []float grad_data = []float{cap: len(input.data)}

    float sqrt_2_over_pi = 0.7978845608028654
    float coeff = 0.044715

    for i in 0..len(input.data) {
        float x = input.data[i]
        float x_cubed = x * x * x
        float inner = sqrt_2_over_pi * (x + coeff * x_cubed)
        float tanh_val = tanh_approx(inner)
        float cdf = 0.5 * (1.0 + tanh_val)


        float pdf = exp_approx(-0.5 * x * x) / 2.5066282746310002


        float gelu_grad = cdf + x * pdf

        grad_data[i] = grad_output.data[i] * gelu_grad
    }

    tensor result { data: grad_data, grad: [], shape: input.shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}


func tanh_approx(float x) float {

    float sig = sigmoid_approx(2.0 * x)
    2.0 * sig - 1.0
}


func sigmoid_approx(float x) float {
    if x > 20.0 { return 1.0 }
    if x < -20.0 { return 0.0 }
    1.0 / (1.0 + exp_approx(-x))
}


func exp_approx(float x) float {
    if x > 700.0 { return 1e308 }
    if x < -700.0 { return 0.0 }


    float ln2 = 0.6931471805599453
    int k = int(float_to_int(x / ln2))
    float r = x - float(k) * ln2


    float result = 1.0 + r + r*r/2.0 + r*r*r/6.0 + r*r*r*r/24.0 + r*r*r*r*r/120.0


    float power_of_2 = 1.0
    if k > 0 {
        for i in 0..k {
            power_of_2 = power_of_2 * 2.0
        }
    } else if k < 0 {
        for i in 0..-k {
            power_of_2 = power_of_2 / 2.0
        }
    }

    result * power_of_2
}

func float_to_int(float x) int {
    int(x)
}

func float_to_array(float x) []float {
    []float{x}
}








func backward_silu(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }

    tensor input = n.inputs[0]
    []float grad_data = []float{cap: len(input.data)}

    for i in 0..len(input.data) {
        float x = input.data[i]
        float sig = sigmoid_approx(x)




        float silu_grad = sig * (1.0 + x * (1.0 - sig))

        grad_data[i] = grad_output.data[i] * silu_grad
    }

    tensor result { data: grad_data, grad: [], shape: input.shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}
