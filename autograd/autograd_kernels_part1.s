package neurx.autograd

use neurx.tensor.tensor












func backward_matmul(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [], success: false }
    }

    tensor a = n.inputs[0]
    tensor b = n.inputs[1]


    []int shape_a = get_context_safe(n, "shape_a", a.shape)
    []int shape_b = get_context_safe(n, "shape_b", b.shape)


    tensor grad_a = matmul_transpose_b(grad_output.data, b.data, shape_a, shape_b)


    tensor grad_b = matmul_transpose_a(a.data, grad_output.data, shape_a, shape_b)

    backward_result {
        input_grads: [grad_a, grad_b],
        success: true,
    }
}


func matmul_transpose_b([]float grad, []float b, []int shape_grad, []int shape_b) tensor {


    int M = shape_grad[0]
    int K = shape_grad[1] if len(shape_grad) > 1 else shape_b[0]
    int N = shape_b[1] if len(shape_b) > 1 else K

    []float result = []float{cap: M * N}
    for i in 0..M*N {
        result[i] = 0.0
    }

    for m in 0..M {
        for n in 0..N {
            float sum = 0.0
            for k in 0..K {

                sum = sum + grad[m * K + k] * b[n * K + k]
            }
            result[m * N + n] = sum
        }
    }

    tensor { data: result, grad: [], shape: [M, N], requires_grad: true }
}


func matmul_transpose_a([]float a, []float grad, []int shape_a, []int shape_grad) tensor {


    int M = shape_a[0]
    int K = shape_a[1] if len(shape_a) > 1 else shape_grad[0]
    int N = shape_grad[1] if len(shape_grad) > 1 else K

    []float result = []float{cap: M * N}
    for i in 0..M*N {
        result[i] = 0.0
    }

    for m in 0..M {
        for n in 0..N {
            float sum = 0.0
            for k in 0..K {

                sum = sum + a[k * M + m] * grad[k * N + n]
            }
            result[m * N + n] = sum
        }
    }

    tensor { data: result, grad: [], shape: [M, N], requires_grad: true }
}







func backward_add(node n, tensor grad_output) backward_result {
    []tensor grads

    if len(n.inputs) == 1 {

        grads = [copy_tensor_with_grad(grad_output)]
    } else if len(n.inputs) == 2 {
        tensor grad_a = copy_tensor_with_grad(grad_output)
        tensor grad_b = copy_tensor_with_grad(grad_output)


        if len(n.inputs[0].shape) != len(grad_output.shape) ||
           !shapes_equal(n.inputs[0].shape, grad_output.shape) {
            grad_a = broadcast_gradient(grad_a, n.inputs[0].shape, grad_output.shape)
        }
        if len(n.inputs[1].shape) != len(grad_output.shape) ||
           !shapes_equal(n.inputs[1].shape, grad_output.shape) {
            grad_b = broadcast_gradient(grad_b, n.inputs[1].shape, grad_output.shape)
        }

        grads = [grad_a, grad_b]
    } else {
        grads = []
        for i in 0..len(n.inputs) {
            grads.push(copy_tensor_with_grad(grad_output))
        }
    }

    backward_result { input_grads: grads, success: true }
}

func copy_tensor_with_grad(tensor t) tensor {
    []float data = []float{cap: len(t.data)}
    for i in 0..len(t.data) {
        data[i] = t.data[i]
    }
    tensor { data: data, grad: [], shape: copy_shape(t.shape), requires_grad: true }
}

func copy_shape([]int s) []int {
    []int out = []int{cap: len(s)}
    for i in 0..len(s) {
        out[i] = s[i]
    }
    out
}

func shapes_equal([]int a, []int b) bool {
    if len(a) != len(b) { return false }
    for i in 0..len(a) {
        if a[i] != b[i] { return false }
    }
    true
}







func backward_mul(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [copy_tensor_with_grad(grad_output)], success: true }
    }

    tensor a = n.inputs[0]
    tensor b = n.inputs[1]


    []float grad_a_data = elementwise_mul(grad_output.data, b.data)
    tensor grad_a { data: grad_a_data, grad: [], shape: a.shape, requires_grad: true }


    []float grad_b_data = elementwise_mul(grad_output.data, a.data)
    tensor grad_b { data: grad_b_data, grad: [], shape: b.shape, requires_grad: true }

    backward_result { input_grads: [grad_a, grad_b], success: true }
}

func elementwise_mul([]float a, []float b) []float {
    int n = min_len(a, b)
    []float out = []float{cap: n}
    for i in 0..n {
        out[i] = a[i] * b[i]
    }
    out
}

func min_len([]float a, []float b) int {
    if len(a) < len(b) { len(a) } else { len(b) }
}







func backward_sub(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [copy_tensor_with_grad(grad_output)], success: true }
    }

    tensor grad_a = copy_tensor_with_grad(grad_output)


    []float neg_grad = negate(grad_output.data)
    tensor grad_b { data: neg_grad, grad: [], shape: n.inputs[1].shape, requires_grad: true }

    backward_result { input_grads: [grad_a, grad_b], success: true }
}

func negate([]float data) []float {
    []float out = []float{cap: len(data)}
    for i in 0..len(data) {
        out[i] = -data[i]
    }
    out
}







func backward_div(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [copy_tensor_with_grad(grad_output)], success: true }
    }

    tensor a = n.inputs[0]
    tensor b = n.inputs[1]


    []float grad_a_data = elementwise_div(grad_output.data, b.data)
    tensor grad_a { data: grad_a_data, grad: [], shape: a.shape, requires_grad: true }


    []float b_squared = elementwise_mul(b.data, b.data)
    []float numerator = elementwise_mul(elementwise_mul(grad_output.data, a.data), float_to_array(-1.0))
    []float grad_b_data = elementwise_div(numerator, b_squared)
    tensor grad_b { data: grad_b_data, grad: [], shape: b.shape, requires_grad: true }

    backward_result { input_grads: [grad_a, grad_b], success: true }
}

func elementwise_div([]float a, []float b) []float {
    int n = min_len(a, b)
    []float out = []float{cap: n}
    for i in 0..n {
        if abs_float(b[i]) > 1e-8 {
            out[i] = a[i] / b[i]
        } else {
            out[i] = 0.0
        }
    }
    out
}

func abs_float(float x) float {
    if x < 0.0 { -x } else { x }
}
