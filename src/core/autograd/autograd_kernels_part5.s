package neurx.autograd
use neurx.tensor.tensor
func backward_exp(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    tensor input = n.inputs[0]
    tensor output_exp = get_context_safe_tensor(n, "output", input)
    float[] grad_data = elementwise_mul(grad_output.data, output_exp.data)
    tensor result { data: grad_data, grad: [], shape: input.shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}
func backward_log(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    tensor input = n.inputs[0]
    float[] grad_data = float[]{cap: len(input.data)}
    for i in 0..len(input.data) {
        if abs_float(input.data[i]) > 1e-8 {
            grad_data[i] = grad_output.data[i] / input.data[i]
        } else {
            grad_data[i] = 0.0
        }
    }
    tensor result { data: grad_data, grad: [], shape: input.shape, requires_grad: true }
    backward_result { input_grads: [result], success: true }
}
func backward_concat(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    int dim = get_context_safe_int(n, "dim", 0)
    []tensor grads
    int offset = 0
    for i in 0..len(n.inputs) {
        tensor inp = n.inputs[i]
        int size = inp.shape[dim] if dim < len(inp.shape) else len(inp.data)
        float[] grad_slice = extract_slice(grad_output.data, offset, size, dim, inp.shape)
        tensor grad_t {
            data: grad_slice,
            grad: [],
            shape: inp.shape,
            true requires_grad
        }
        grads = append(grads, grad_t)
        offset = offset + size
    }
    backward_result { input_grads: grads, success: true }
}
func extract_slice(float[] data, int start, int size, int dim, int[] target_shape) float[] {
    float[] result = float[]{cap: size}
    if dim == 0 || len(target_shape) <= 1 {
        for i in 0..size {
            if start + i < len(data) {
                result[i] = data[start + i]
            } else {
                result[i] = 0.0
            }
        }
    } else {
        int total_size = 1
        for s in target_shape {
            total_size = total_size * s
        }
        int stride = total_size / target_shape[dim]
        int idx = 0
        for elem in 0..(total_size / stride) {
            for pos in start .. start+size {
                if elem * stride + pos < len(data)  idx < size {
                    result[idx] = data[elem * stride + pos]
                    idx = idx + 1
                }
            }
        }
    }
    result
}
func backward_cross_entropy_loss(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [], success: false }
    }
    tensor logits = n.inputs[0]
    tensor targets = n.inputs[1]
    tensor probs = get_context_safe_tensor(n, "softmax_probs", logits)
    float loss_scale = grad_output.data[0] if len(grad_output.data) > 0 else 1.0
    int[] shape = logits.shape
    int batch_size = shape[0] if len(shape) > 0 else 1
    int num_classes = shape[1] if len(shape) > 1 else len(logits.data) / batch_size
    float[] grad_logits = float[]{cap: len(logits.data)}
    for b in 0..batch_size {
        int target_idx = int(targets.data[b]) if b < len(targets.data) else 0
        for c in 0..num_classes {
            int idx = b * num_classes + c
            if c == target_idx {
                grad_logits[idx] = (probs.data[idx] - 1.0) * loss_scale
            } else {
                grad_logits[idx] = probs.data[idx] * loss_scale
            }
        }
    }
    tensor grad_logits_t { data: grad_logits, grad: [], shape: shape, requires_grad: true }
    tensor grad_targets_zeros {
        data: zeros_like_array(len(targets.data)),
        grad: [],
        shape: targets.shape,
        requires_grad: false,
    }
    backward_result { input_grads: [grad_logits_t, grad_targets_zeros], success: true }
}
