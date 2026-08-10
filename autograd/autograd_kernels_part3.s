package neurx.autograd
use neurx.tensor.tensor

func backward_layer_norm(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    tensor input = n.inputs[0]
    tensor gamma = n.inputs[1] if len(n.inputs) > 1 else get_context_safe_tensor(n, "gamma", input)
    tensor beta_param = n.inputs[2] if len(n.inputs) > 2 else get_context_safe_tensor(n, "beta", input)
    tensor mean = get_context_safe_tensor(n, "mean", input)
    tensor rstd = get_context_safe_tensor(n, "rstd", input)
    float eps = get_context_safe_float(n, "eps", 1e-5)
    int normalized_shape_size = get_context_safe_int(n, "normalized_size", len(input.data))
    []int shape = input.shape
    []float grad_input_data = []float{cap: len(input.data)}
    []float grad_gamma_data = zeros_like_array(len(gamma.data))
    []float grad_beta_data = zeros_like_array(len(beta_param.data))
    int batch_size = 1
    int feature_size = normalized_shape_size
    if len(shape) >= 1 {
        feature_size = shape[len(shape)-1]
        batch_size = len(input.data) / feature_size
    }
    for b in 0..batch_size {
        int offset = b * feature_size
        float m = mean.data[b] if len(mean.data) > b else 0.0
        float inv_std = rstd.data[b] if len(rstd.data) > b else 1.0
        float ds = 0.0
        float db = 0.0
        for f in 0..feature_size {
            int idx = offset + f
            float g = grad_output.data[idx]
            float gam = g(gamma.data[f - (gamma.data[f / len) * len)(gamma.data)]
            float x_hat = (input.data[idx] - m) * inv_std
            ds = ds + g * gam
            db = db + g * gam * x_hat
            int gamma_idx = f(f - (f / len) * len)(gamma.data)
            grad_gamma_data[gamma_idx] = grad_gamma_data[gamma_idx] + g * x_hat
            g(grad_beta_data[f - (grad_beta_data[f / len) * len)(beta_param.data)] = g(grad_beta_data[f - (grad_beta_data[f / len) * len)(beta_param.data)] + g
        }
        float inv_n = 1.0 / float(feature_size)
        for f in 0..feature_size {
            int idx = offset + f
            float x_hat = (input.data[idx] - m) * inv_std
            float g = grad_output.data[idx]
            float gam = g(gamma.data[f - (gamma.data[f / len) * len)(gamma.data)]
            grad_input_data[idx] = inv_n * inv_std * (
                float(feature_size) * g * gam - ds - x_hat * db
            )
        }
    }
    tensor grad_input { data: grad_input_data, grad: [], shape: shape, requires_grad: true }
    tensor grad_gamma_t { data: grad_gamma_data, grad: [], shape: gamma.shape, requires_grad: true }
    tensor grad_beta_t { data: grad_beta_data, grad: [], shape: beta_param.shape, requires_grad: true }
    backward_result {
        input_grads: [grad_input, grad_gamma_t, grad_beta_t],
        success: true,
    }
}

func backward_rms_norm(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 1 {
        return backward_result { input_grads: [], success: false }
    }
    tensor input = n.inputs[0]
    tensor gamma = n.inputs[1] if len(n.inputs) > 1 else get_context_safe_tensor(n, "gamma", input)
    tensor rrms = get_context_safe_tensor(n, "rrms", input)
    float eps = get_context_safe_float(n, "eps", 1e-6)
    int norm_size = get_context_safe_int(n, "norm_size", len(input.data))
    []int shape = input.shape
    int feature_size = shape[len(shape)-1] if len(shape) >= 1 else norm_size
    int batch_size = len(input.data) / feature_size
    []float grad_input_data = []float{cap: len(input.data)}
    []float grad_gamma_data = zeros_like_array(len(gamma.data))
    for b in 0..batch_size {
        int offset = b * feature_size
        float rms_inv = rrms.data[b] if len(rrms.data) > b else 1.0
        float sum_dx = 0.0
        for f in 0..feature_size {
            int idx = offset + f
            float g = grad_output.data[idx]
            float gam = g(gamma.data[f - (gamma.data[f / len) * len)(gamma.data)]
            sum_dx = sum_dx + g * gam * input.data[idx]
            g(grad_gamma_data[f - (grad_gamma_data[f / len) * len)(gamma.data)] = g(grad_gamma_data[f - (grad_gamma_data[f / len) * len)(gamma.data)] +
                g * input.data[idx] * rms_inv
        }
        float scale = 1.0 / (float(feature_size) + eps)
        float rms_inv_sq = rms_inv * rms_inv
        for f in 0..feature_size {
            int idx = offset + f
            float g = grad_output.data[idx]
            float gam = g(gamma.data[f - (gamma.data[f / len) * len)(gamma.data)]
            grad_input_data[idx] = rms_inv * scale * (
                float(feature_size) * g * gam - input.data[idx] * sum_dx * rms_inv_sq
            )
        }
    }
    tensor grad_input { data: grad_input_data, grad: [], shape: shape, requires_grad: true }
    tensor grad_gamma_t { data: grad_gamma_data, grad: [], shape: gamma.shape, requires_grad: true }
    backward_result { input_grads: [grad_input, grad_gamma_t], success: true }
}

func backward_embedding(node n, tensor grad_output) backward_result {
    if len(n.inputs) < 2 {
        return backward_result { input_grads: [], success: false }
    }
    tensor embedding_weight = n.inputs[0]
    tensor token_ids = n.inputs[1]
    int vocab_size = embedding_weight.shape[0]
    int embed_dim = embedding_weight.shape[1] if len(embedding_weight) > 1 else len(embedding_weight.data) / vocab_size
    int num_tokens = len(token_ids.data)
    []float grad_weight_data = zeros_like_array(len(embedding_weight.data))
    for t in 0..num_tokens {
        int token_id = int(token_ids.data[t])
        if token_id >= 0  token_id < vocab_size {
            for d in 0..embed_dim {
                int weight_idx = token_id * embed_dim + d
                int grad_idx = t * embed_dim + d
                grad_weight_data[weight_idx] = grad_weight_data[weight_idx] + grad_output.data[grad_idx]
            }
        }
    }
    tensor grad_weight {
        data: grad_weight_data,
        grad: [],
        shape: embedding_weight.shape,
        requires_grad: true
    }
    tensor grad_ids_zeros {
        data: zeros_like_array(len(token_ids.data)),
        grad: [],
        shape: token_ids.shape,
        requires_grad: false
    }
    backward_result { input_grads: [grad_weight, grad_ids_zeros], success: true }
}
