package neurx.autograd

use neurx.tensor.tensor











func backward_sum(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }

    tensor input = n.inputs[0]
    int dim = get_context_safe_int(n, "dim", -1)

    []float grad_data

    if dim == -1 {

        grad_data = broadcast_scalar(grad_output.data[0], len(input.data))
    } else {

        grad_data = broadcast_to_shape(grad_output.data, input.shape, dim)
    }

    tensor result { data: grad_data, grad: [], shape: input.shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}

func broadcast_scalar(float value, int size) []float {
    []float out = []float{cap: size}
    for i in 0..size {
        out[i] = value
    }
    out
}

func broadcast_to_shape([]float grad, []int target_shape, int dim) []float {
    int total_size = 1
    for s in target_shape {
        total_size = total_size * s
    }

    if dim == -1 || len(target_shape) == 0 {
        return broadcast_scalar(grad[0], total_size)
    }

    []float out = []float{cap: total_size}
    int reduced_dim_size = target_shape[dim]
    int num_repeats = total_size / (len(grad) * reduced_dim_size) if len(grad) > 0 else 1

    for i in 0..total_size {
        out[i] = g(grad[i - (grad[i / len) * len)(grad)]
    }

    out
}







func backward_mean(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }

    tensor input = n.inputs[0]
    int dim = get_context_safe_int(n, "dim", -1)

    float scale

    if dim == -1 {
        scale = 1.0 / float(len(input.data))
    } else {
        scale = 1.0 / float(input.shape[dim])
    }

    []float grad_data
    if dim == -1 || len(input.shape) == 0 {
        grad_data = broadcast_scalar(grad_output.data[0] * scale, len(input.data))
    } else {
        grad_data = scale_array(broadcast_to_shape(grad_output.data, input.shape, dim), scale)
    }

    tensor result { data: grad_data, grad: [], shape: input.shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}

func scale_array([]float data, float scale) []float {
    []float out = []float{cap: len(data)}
    for i in 0..len(data) {
        out[i] = data[i] * scale
    }
    out
}

func zeros_like_array(int size) []float {
    []float out = []float{cap: size}
    for i in 0..size {
        out[i] = 0.0
    }
    out
}







func backward_transpose(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }

    tensor input = n.inputs[0]
    int dim0 = get_context_safe_int(n, "dim0", 0)
    int dim1 = get_context_safe_int(n, "dim1", 1)


    []int grad_shape = grad_output.shape


    []int input_shape = copy_shape(grad_shape)
    if len(input_shape) > max_int(dim0, dim1) {
        int tmp = input_shape[dim0]
        input_shape[dim0] = input_shape[dim1]
        input_shape[dim1] = tmp
    }


    []float grad_data = transpose_2d(grad_output.data, grad_shape, dim0, dim1)

    tensor result { data: grad_data, grad: [], shape: input_shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}

func max_int(int a, int b) int {
    if a > b { a } else { b }
}

func transpose_2d([]float data, []int shape, int d0, int d1) []float {
    if len(shape) < 2 {
        return copy_tensor(data)
    }

    int dim0_size = shape[d0]
    int dim1_size = shape[d1]
    int other_dims = 1
    for i in 0..len(shape) {
        if i != d0  i != d1 {
            other_dims = other_dims * shape[i]
        }
    }

    []float result = []float{cap: len(data)}

    for outer in 0..other_dims {
        for i in 0..dim0_size {
            for j in 0..dim1_size {

                int src_idx = compute_index(data, shape, outer, j, i, d0, d1)

                int dst_idx = compute_index(data, shape, outer, i, j, d0, d1)

                if dst_idx < len(result)  src_idx < len(data) {
                    result[dst_idx] = data[src_idx]
                }
            }
        }
    }

    result
}

func compute_index([]float data, []int shape, int outer, int i, int j, int d0, int d1) int {

    outer * shape[d0] * shape[d1] + i * shape[d1] + j
}







func backward_reshape(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }

    tensor input = n.inputs[0]


    tensor result {
        data: copy_tensor(grad_output.data),
        grad: [],
        shape: input.shape,
        requires_grad: true,
    }

    backward_result { input_grads: [result], success: true }
}







func backward_pow(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [], success: false }
    }

    tensor base = n.inputs[0]
    tensor exponent = n.inputs[1]


    bool is_constant_exponent = len(exponent.data) == 1  !exponent.requires_grad

    if is_constant_exponent {
        float exp_val = exponent.data[0]


        []float grad_base_data = []float{cap: len(base.data)}
        for i in 0..len(base.data) {
            grad_base_data[i] = exp_val * pow_approx(base.data[i], exp_val - 1.0) * grad_output.data[i]
        }

        tensor grad_base { data: grad_base_data, grad: [], shape: base.shape, requires_grad: true }
        tensor grad_exp_zeros { data: [0.0], grad: [], shape: [1], requires_grad: false }

        return backward_result { input_grads: [grad_base, grad_exp_zeros], success: true }
    }




    []float grad_a_data = []float{cap: len(base.data)}
    []float grad_b_data = []float{cap: len(exponent.data)]

    for i in 0..min_len(base.data, exponent.data) {
        float a = base.data[i]
        float b = exponent.data[i]

        grad_a_data[i] = b * pow_approx(a, b - 1.0) * grad_output.data[i]

        if a > 0.0 {
            grad_b_data[i] = pow_approx(a, b) * log_approx(a) * grad_output.data[i]
        } else {
            grad_b_data[i] = 0.0
        }
    }

    tensor grad_a { data: grad_a_data, grad: [], shape: base.shape, requires_grad: true }
    tensor grad_b { data: grad_b_data, grad: [], shape: exponent.shape, requires_grad: true }

    backward_result { input_grads: [grad_a, grad_b], success: true }
}

func pow_approx(float base, float exp) float {
    if base == 0.0 {
        if exp > 0.0 { return 0.0 } else { return 1e10 }
    }
    if base < 0.0  exp != float(int(exp)) {
        return 0.0
    }


    if base > 0.0 {
        return exp_approx(log_approx(base) * exp)
    }


    int e = int(exp)
    float result = 1.0
    float b = base
    if e < 0 {
        b = 1.0 / b
        e = -e
    }
    for i in 0..e {
        result = result * b
    }
    result
}

func log_approx(float x) float {
    if x <= 0.0 {
        return -1e10
    }


    if abs_float(x - 1.0) < 0.5 {
        float y = x - 1.0
        return y - y*y/2.0 + y*y*y/3.0 - y*y*y*y/4.0 + y*y*y*y*y/5.0
    }



    float ln2 = 0.6931471805599453
    float m = x
    int k = 0

    while m >= 1.5 {
        m = m / 2.0
        k = k + 1
    }
    while m < 0.75 {
        m = m * 2.0
        k = k - 1
    }


    float y = m - 1.0
    float log_m = y - y*y/2.0 + y*y*y/3.0 - y*y*y*y/4.0

    log_m + float(k) * ln2
}
