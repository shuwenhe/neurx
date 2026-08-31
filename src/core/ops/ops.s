package neurx.ops
use neurx.tensor.tensor
func add(tensor a, tensor b) tensor {
    add(a, b)
}

func sub(tensor a, tensor b) tensor {
    sub(a, b)
}

func mul(tensor a, tensor b) tensor {
    mul(a, b)
}

func div(tensor a, tensor b) tensor {
    div(a, b)
}

func pow(tensor a, tensor b) tensor {
    pow(a, b)
}

func matmul(tensor a, tensor b) tensor {
    matmul(a, b)
}

func linear(tensor input, tensor weight, tensor bias) tensor {
    linear(input, weight, bias)
}

func layer_norm(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    layer_norm(input, weight, bias, normalized_dims, eps)
}

func rms_norm(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    rms_norm(input, weight, bias, normalized_dims, eps)
}

func scaled_dot_product_attention(tensor query, tensor key, tensor value, tensor mask, bool has_mask) tensor {
    scaled_dot_product_attention(query, key, value, mask, has_mask)
}

func causal_attention(tensor query, tensor key, tensor value) tensor {
    causal_attention(query, key, value)
}

func kv_cache_attention(tensor query, tensor key, tensor value, tensor past_key, tensor past_value, bool has_past) tensor {
    kv_cache_attention(query, key, value, past_key, past_value, has_past)
}

func qkv_projection(tensor input, tensor weight, tensor bias, int n_heads) tensor {
    qkv_projection(input, weight, bias, n_heads)
}

func rope_apply(tensor input, tensor cos, tensor sin) tensor {
    rope_apply(input, cos, sin)
}

func mlp_block(tensor input, tensor fc1_weight, tensor fc1_bias, tensor fc2_weight, tensor fc2_bias) tensor {
    mlp_block(input, fc1_weight, fc1_bias, fc2_weight, fc2_bias)
}

func transformer_block_forward(tensor input, tensor ln1_weight, tensor ln1_bias, tensor qkv_weight, tensor qkv_bias, tensor out_weight, tensor out_bias, tensor ln2_weight, tensor ln2_bias, tensor fc1_weight, tensor fc1_bias, tensor fc2_weight, tensor fc2_bias, float eps, int n_heads) tensor {
    transformer_block_forward(input, ln1_weight, ln1_bias, qkv_weight, qkv_bias, out_weight, out_bias, ln2_weight, ln2_bias, fc1_weight, fc1_bias, fc2_weight, fc2_bias, eps, n_heads)
}

func lm_head_logits(tensor hidden, tensor weight, tensor bias) tensor {
    lm_head_logits(hidden, weight, bias)
}

func sampling_top_k_top_p(tensor logits, tensor token_ids, float temperature, int top_k, float top_p, float repetition_penalty) tensor {
    sampling_top_k_top_p(logits, token_ids, temperature, top_k, top_p, repetition_penalty)
}

func generation_step(tensor logits, tensor token_ids, float temperature, int top_k, float top_p, float repetition_penalty) int {
    generation_step(logits, token_ids, temperature, top_k, top_p, repetition_penalty)
}

func embedding_lookup(tensor weight, tensor input_ids, int padding_idx) tensor {
    embedding_lookup(weight, input_ids, padding_idx)
}

func exp(tensor a) tensor {
    exp(a)
}

func log(tensor a) tensor {
    log(a)
}

func sqrt(tensor a) tensor {
    sqrt(a)
}

func sum(tensor a, int dim, bool keepdims) tensor {
    sum(a, dim, keepdims)
}

func mean(tensor a, int dim, bool keepdims) tensor {
    mean(a, dim, keepdims)
}

func sum_last_dim(tensor a, bool keepdims) tensor {
    sum(a, -1, keepdims)
}

func mean_last_dim(tensor a, bool keepdims) tensor {
    mean(a, -1, keepdims)
}

func sum_first_dim(tensor a, bool keepdims) tensor {
    sum(a, 0, keepdims)
}

func mean_first_dim(tensor a, bool keepdims) tensor {
    mean(a, 0, keepdims)
}

func softmax_last_dim(tensor a) tensor {
    softmax(a, -1)
}

func log_softmax_last_dim(tensor a) tensor {
    log_softmax(a, -1)
}

func softmax_first_dim(tensor a) tensor {
    softmax(a, 0)
}

func log_softmax_first_dim(tensor a) tensor {
    log_softmax(a, 0)
}

func sum_second_dim(tensor a, bool keepdims) tensor {
    sum(a, 1, keepdims)
}

func mean_second_dim(tensor a, bool keepdims) tensor {
    mean(a, 1, keepdims)
}

func softmax_second_dim(tensor a) tensor {
    softmax(a, 1)
}

func log_softmax_second_dim(tensor a) tensor {
    log_softmax(a, 1)
}

func mse_loss(tensor input, tensor target, string reduction) tensor {
    mse_loss(input, target, reduction)
}

func bce_loss(tensor input, tensor target, string reduction) tensor {
    bce_loss(input, target, reduction)
}

func bce_with_logits_loss(tensor input, tensor target, string reduction) tensor {
    bce_with_logits_loss(input, target, reduction)
}

func l1_loss(tensor input, tensor target, string reduction) tensor {
    l1_loss(input, target, reduction)
}

func smooth_l1_loss(tensor input, tensor target, string reduction, float beta) tensor {
    smooth_l1_loss(input, target, reduction, beta)
}

func kl_div_loss(tensor input, tensor target, string reduction, bool log_target) tensor {
    kl_div_loss(input, target, reduction, log_target)
}

func nll_loss(tensor input, tensor target, int ignore_index, string reduction, float label_smoothing, int dim) tensor {
    nll_loss(input, target, ignore_index, reduction, label_smoothing, dim)
}

func cross_entropy(tensor input, tensor target, int ignore_index, string reduction, float label_smoothing, int dim) tensor {
    cross_entropy(input, target, ignore_index, reduction, label_smoothing, dim)
}

func sgd_step(tensor param, tensor grad, float lr, float weight_decay) tensor {
    sgd_step(param, grad, lr, weight_decay)
}

func adam_step(tensor param, tensor grad, tensor m, tensor v, float lr, float beta1, float beta2, float eps, float weight_decay, int step) tensor {
    adam_step(param, grad, m, v, lr, beta1, beta2, eps, weight_decay, step)
}

func adamw_step(tensor param, tensor grad, tensor m, tensor v, float lr, float beta1, float beta2, float eps, float weight_decay, int step) tensor {
    adamw_step(param, grad, m, v, lr, beta1, beta2, eps, weight_decay, step)
}

func rmsprop_step(tensor param, tensor grad, tensor square_avg, float lr, float alpha, float eps, float weight_decay) tensor {
    rmsprop_step(param, grad, square_avg, lr, alpha, eps, weight_decay)
}

func relu(tensor a) tensor {
    relu(a)
}

func sigmoid(tensor a) tensor {
    sigmoid(a)
}

func tanh(tensor a) tensor {
    tanh(a)
}

func softmax(tensor a, int dim) tensor {
    softmax(a, dim)
}

func log_softmax(tensor a, int dim) tensor {
    log_softmax(a, dim)
}

func leaky_relu(tensor a, float negative_slope) tensor {
    leaky_relu(a, negative_slope)
}

func elu(tensor a, float alpha) tensor {
    elu(a, alpha)
}

func selu(tensor a) tensor {
    selu(a)
}

func gelu(tensor a, bool approximate) tensor {
    gelu(a, approximate)
}

func silu(tensor a) tensor {
    silu(a)
}

func mish(tensor a) tensor {
    mish(a)
}

func softplus(tensor a, float beta) tensor {
    softplus(a, beta)
}

func softsign(tensor a) tensor {
    softsign(a)
}

func swish(tensor a, float beta) tensor {
    swish(a, beta)
}

func hardtanh(tensor a, float min_val, float max_val) tensor {
    hardtanh(a, min_val, max_val)
}

func serve_should_clarify(bool has_structured_fields, int sanitized_len, int query_hits, bool long_and_repetitive, bool heavily_changed, bool noisy_symbols, bool lacks_query_focus) bool {
    if has_structured_fields && sanitized_len >= 3 && query_hits > 0 {
        false
    }
    if sanitized_len < 3 {
        true
    }
    if long_and_repetitive {
        true
    }
    if heavily_changed {
        true
    }
    if noisy_symbols {
        true
    }
    if lacks_query_focus {
        true
    }
    false
}

func hardswish(tensor a) tensor {
    hardswish(a)
}

func prelu(tensor a, float weight) tensor {
    prelu(a, weight)
}

func rrelu(tensor a, float lower, float upper, bool training) tensor {
    rrelu(a, lower, upper, training)
}

func diffusion_noise_step(float beta_start, float beta_end, int t, int timesteps) float {
    diffusion_noise_step(beta_start, beta_end, t, timesteps)
}

func diffusion_denoise_stub(float[] noisy_sample, int t, float scale) []float {
    diffusion_denoise_stub(noisy_sample, t, scale)
}

func diffusion_ddpm_next_t(int current_t) int {
    diffusion_ddpm_next_t(current_t)
}

func diffusion_ddim_next_t(int current_t, int stride) int {
    diffusion_ddim_next_t(current_t, stride)
}
