package neurx.nn

use neurx.backends.compute_backend
use neurx.tensor.tensor
use neurx.nn.activations
use neurx.nn.conv
use neurx.nn.pooling

struct linear {
    int in_features
    int out_features
    []float weight
    []float bias
    bool has_bias
    bool training
}

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    return out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    return out
}

func shape1(int n) []int {
    []int shape = []int{cap: 1}
    shape[0] = n
    return shape
}

func shape2(int m, int n) []int {
    []int shape = []int{cap: 2}
    shape[0] = m
    shape[1] = n
    return shape
}

func shape3(int a, int b, int c) []int {
    []int shape = []int{cap: 3}
    shape[0] = a
    shape[1] = b
    shape[2] = c
    return shape
}

func numel([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    return n
}

func exp_approx(float x) float {
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    return 1.0 + x + (x2 / 2.0) + (x3 / 6.0) + (x4 / 24.0) + (x5 / 120.0)
}

func sqrt_approx(float x) float {
    float v = x
    if v < 0.0 {
        v = 0.0
    }
    if v == 0.0 {
        return 0.0
    }
    float guess = v
    int i = 0
    while i < 6 {
        guess = 0.5 * (guess + v / guess)
        i = i + 1
    }
    return guess
}

func clone_tensor(tensor a) tensor {
    neurx.tensor.new(copy_float(a.data), copy_int(a.shape), a.requires_grad)
}

func matmul2d(tensor a, tensor b) tensor {
    int rows = a.shape[0]
    int inner = a.shape[1]
    int cols = b.shape[1]
    []float out = []float{cap: rows * cols}
    int r = 0
    while r < rows {
        int c = 0
        while c < cols {
            float acc = 0.0
            int i = 0
            while i < inner {
                acc = acc + a.data[r * inner + i] * b.data[i * cols + c]
                i = i + 1
            }
            out[r * cols + c] = acc
            c = c + 1
        }
        r = r + 1
    }
    neurx.tensor.new(out, shape2(rows, cols), a.requires_grad || b.requires_grad)
}

func softmax_1d([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    float max_v = values[0]
    int i = 1
    while i < n {
        if values[i] > max_v {
            max_v = values[i]
        }
        i = i + 1
    }
    float denom = 0.0
    i = 0
    while i < n {
        float shifted = values[i] - max_v
        float v = 1.0 / (1.0 + 0.0)
        v = 1.0
        int j = 0
        float term = 1.0
        while j < 6 {
            term = term * shifted / (j + 1)
            v = v + term
            j = j + 1
        }
        out[i] = v
        denom = denom + v
        i = i + 1
    }
    if denom == 0.0 {
        denom = 1.0
    }
    i = 0
    while i < n {
        out[i] = out[i] / denom
        i = i + 1
    }
    return out
}

func layer_norm_impl(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    int ndim = len(input.shape)
    int start = ndim - normalized_dims
    if start < 0 {
        start = 0
    }
    int outer = 1
    int i = 0
    while i < start {
        outer = outer * input.shape[i]
        i = i + 1
    }
    int inner = 1
    while i < ndim {
        inner = inner * input.shape[i]
        i = i + 1
    }
    []float out = []float{cap: len(input.data)}
    int o = 0
    while o < outer {
        int base = o * inner
        float mean = 0.0
        int j = 0
        while j < inner {
            mean = mean + input.data[base + j]
            j = j + 1
        }
        mean = mean / inner
        float variance = 0.0
        j = 0
        while j < inner {
            float diff = input.data[base + j] - mean
            variance = variance + diff * diff
            j = j + 1
        }
        variance = variance / inner
        j = 0
        while j < inner {
            float norm = (input.data[base + j] - mean) / sqrt_approx(variance + eps)
            out[base + j] = norm * weight.data[j] + bias.data[j]
            j = j + 1
        }
        o = o + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad || weight.requires_grad || bias.requires_grad)
}

func rms_norm_impl(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    int ndim = len(input.shape)
    int start = ndim - normalized_dims
    if start < 0 {
        start = 0
    }
    int outer = 1
    int i = 0
    while i < start {
        outer = outer * input.shape[i]
        i = i + 1
    }
    int inner = 1
    while i < ndim {
        inner = inner * input.shape[i]
        i = i + 1
    }
    []float out = []float{cap: len(input.data)}
    int o = 0
    while o < outer {
        int base = o * inner
        float mean_sq = 0.0
        int j = 0
        while j < inner {
            float v = input.data[base + j]
            mean_sq = mean_sq + v * v
            j = j + 1
        }
        mean_sq = mean_sq / inner
        float denom = mean_sq + eps
        j = 0
        while j < inner {
            float norm = input.data[base + j] / sqrt_approx(denom)
            out[base + j] = norm * weight.data[j] + bias.data[j]
            j = j + 1
        }
        o = o + 1
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad || weight.requires_grad || bias.requires_grad)
}

func mlp_block_impl(tensor input, tensor fc1_weight, tensor fc1_bias, tensor fc2_weight, tensor fc2_bias) tensor {
    int batch = input.shape[0]
    int in_features = input.shape[1]
    int hidden_features = fc1_bias.shape[0]
    []float hidden = []float{cap: batch * hidden_features}
    int b = 0
    while b < batch {
        int j = 0
        while j < hidden_features {
            float acc = fc1_bias.data[j]
            int i = 0
            while i < in_features {
                acc = acc + input.data[b * in_features + i] * fc1_weight.data[i * hidden_features + j]
                i = i + 1
            }
            float gate = 1.0 / (1.0 + exp_approx(-1.702 * acc))
            hidden[b * hidden_features + j] = acc * gate
            j = j + 1
        }
        b = b + 1
    }
    int out_features = fc2_bias.shape[0]
    []float out = []float{cap: batch * out_features}
    b = 0
    while b < batch {
        int j = 0
        while j < out_features {
            float acc = fc2_bias.data[j]
            int i = 0
            while i < hidden_features {
                acc = acc + hidden[b * hidden_features + i] * fc2_weight.data[i * out_features + j]
                i = i + 1
            }
            out[b * out_features + j] = acc
            j = j + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape2(batch, out_features), input.requires_grad || fc1_weight.requires_grad || fc1_bias.requires_grad || fc2_weight.requires_grad || fc2_bias.requires_grad)
}

func qkv_projection_impl(tensor input, tensor weight, tensor bias, int n_heads) tensor {
    int batch = input.shape[0]
    int seq_len = input.shape[1]
    int channels = input.shape[2]
    int head_dim = channels / n_heads
    int proj_channels = channels * 3
    []float out = []float{cap: batch * seq_len * proj_channels}
    int b = 0
    while b < batch {
        int s = 0
        while s < seq_len {
            int c = 0
            while c < proj_channels {
                float acc = bias.data[c]
                int i = 0
                while i < channels {
                    acc = acc + input.data[(b * seq_len + s) * channels + i] * weight.data[i * proj_channels + c]
                    i = i + 1
                }
                out[(b * seq_len + s) * proj_channels + c] = acc
                c = c + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape3(batch, seq_len, proj_channels), input.requires_grad || weight.requires_grad || bias.requires_grad)
}

func rope_apply_impl(tensor input, tensor cos, tensor sin) tensor {
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        if i + 1 < n {
            out[i] = input.data[i] * cos.data[i] - input.data[i + 1] * sin.data[i]
            out[i + 1] = input.data[i] * sin.data[i] + input.data[i + 1] * cos.data[i]
        } else {
            out[i] = input.data[i]
        }
        i = i + 2
    }
    neurx.tensor.new(out, copy_int(input.shape), input.requires_grad || cos.requires_grad || sin.requires_grad)
}

func embedding_lookup_impl(tensor weight, tensor input_ids, int padding_idx) tensor {
    int vocab = weight.shape[0]
    int dim = weight.shape[1]
    int n = len(input_ids.data)
    []float out = []float{cap: n * dim}
    int i = 0
    while i < n {
        int idx = input_ids.data[i]
        if idx == padding_idx {
            idx = 0
        }
        if idx < 0 {
            idx = 0
        }
        if idx >= vocab {
            idx = vocab - 1
        }
        int d = 0
        while d < dim {
            out[i * dim + d] = weight.data[idx * dim + d]
            d = d + 1
        }
        i = i + 1
    }
    neurx.tensor.new(out, shape2(n, dim), weight.requires_grad || input_ids.requires_grad)
}

func new_linear(int in_features, int out_features) linear {
    int weight_size = in_features * out_features
    []float weight = []float{cap: weight_size}
    []float bias = []float{cap: out_features}
    int i = 0
    while i < weight_size {
        weight[i] = 0.0
        i = i + 1
    }
    i = 0
    while i < out_features {
        bias[i] = 0.0
        i = i + 1
    }
    return linear {
        in_features: in_features,
        out_features: out_features,
        weight: weight,
        bias: bias,
        has_bias: true,
        training: true,
    }
}

func linear_train(linear layer) linear {
    return linear {
        in_features: layer.in_features,
        out_features: layer.out_features,
        weight: copy_float(layer.weight),
        bias: copy_float(layer.bias),
        has_bias: layer.has_bias,
        training: true,
    }
}

func linear_eval(linear layer) linear {
    return linear {
        in_features: layer.in_features,
        out_features: layer.out_features,
        weight: copy_float(layer.weight),
        bias: copy_float(layer.bias),
        has_bias: layer.has_bias,
        training: false,
    }
}

func linear_state_dict(linear layer) linear {
    return linear {
        in_features: layer.in_features,
        out_features: layer.out_features,
        weight: copy_float(layer.weight),
        bias: copy_float(layer.bias),
        has_bias: layer.has_bias,
        training: layer.training,
    }
}

func linear_load_state_dict(linear layer, linear other) linear {
    return linear {
        in_features: other.in_features,
        out_features: other.out_features,
        weight: copy_float(other.weight),
        bias: copy_float(other.bias),
        has_bias: other.has_bias,
        training: other.training,
    }
}

func linear_parameters(linear layer) []tensor {
    []tensor params = []tensor{cap: 2}
    params[0] = neurx.tensor.new(copy_float(layer.weight), shape2(layer.in_features, layer.out_features), true)
    params[1] = neurx.tensor.new(copy_float(layer.bias), shape1(layer.out_features), true)
    return params
}

func linear_module(linear layer) module {
    return linear_as_module(layer)
}

func linear_forward(linear layer, tensor input) tensor {
    compute_context ctx = resolve_compute_context("", "")
    return linear_forward_backend(layer, input, ctx)
}

func linear_forward_backend(linear layer, tensor input, compute_context ctx) tensor {
    tensor weight = neurx.tensor.new(copy_float(layer.weight), shape2(layer.in_features, layer.out_features), false)
    int rows = input.shape[0]
    int inner = input.shape[1]
    []float out_data = backend_matmul_dispatch(ctx, input.data, weight.data, rows, inner, layer.out_features)
    tensor out = neurx.tensor.new(out_data, shape2(rows, layer.out_features), input.requires_grad)
    if layer.has_bias {
        tensor bias = neurx.tensor.new(copy_float(layer.bias), shape1(layer.out_features), false)
        tensor bias_view = neurx.tensor.broadcast_to(bias, out.shape)
        out = neurx.tensor.add(out, bias_view)
    }
    return out
}

func layer_norm(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    return layer_norm_impl(input, weight, bias, normalized_dims, eps)
}

func rms_norm(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    return rms_norm_impl(input, weight, bias, normalized_dims, eps)
}

func mlp_block(tensor input, tensor fc1_weight, tensor fc1_bias, tensor fc2_weight, tensor fc2_bias) tensor {
    return mlp_block_impl(input, fc1_weight, fc1_bias, fc2_weight, fc2_bias)
}

func transformer_block_forward(tensor input, tensor ln1_weight, tensor ln1_bias, tensor qkv_weight, tensor qkv_bias, tensor out_weight, tensor out_bias, tensor ln2_weight, tensor ln2_bias, tensor fc1_weight, tensor fc1_bias, tensor fc2_weight, tensor fc2_bias, float eps, int n_heads) tensor {
    tensor norm1 = layer_norm_impl(input, ln1_weight, ln1_bias, 1, eps)
    tensor qkv = qkv_projection_impl(norm1, qkv_weight, qkv_bias, n_heads)
    tensor attn = clone_tensor(qkv)
    tensor proj = clone_tensor(attn)
    tensor resid1 = clone_tensor(input)
    int i = 0
    while i < len(proj.data) && i < len(out_weight.data) {
        proj.data[i] = proj.data[i] * out_weight.data[i]
        i = i + 1
    }
    i = 0
    while i < len(proj.data) && i < len(out_bias.data) {
        proj.data[i] = proj.data[i] + out_bias.data[i]
        i = i + 1
    }
    tensor x = clone_tensor(resid1)
    i = 0
    while i < len(x.data) && i < len(proj.data) {
        x.data[i] = x.data[i] + proj.data[i]
        i = i + 1
    }
    tensor norm2 = layer_norm_impl(x, ln2_weight, ln2_bias, 1, eps)
    tensor mlp = mlp_block_impl(norm2, fc1_weight, fc1_bias, fc2_weight, fc2_bias)
    tensor out = clone_tensor(x)
    i = 0
    while i < len(out.data) && i < len(mlp.data) {
        out.data[i] = out.data[i] + mlp.data[i]
        i = i + 1
    }
    return out
}

func qkv_projection(tensor input, tensor weight, tensor bias, int n_heads) tensor {
    return qkv_projection_impl(input, weight, bias, n_heads)
}

func rope_apply(tensor input, tensor cos, tensor sin) tensor {
    return rope_apply_impl(input, cos, sin)
}

func embedding_lookup(tensor weight, tensor input_ids, int padding_idx) tensor {
    return embedding_lookup_impl(weight, input_ids, padding_idx)
}

func relu(tensor input) tensor {
    return neurx.tensor.relu(input)
}

func sigmoid(tensor input) tensor {
    return neurx.tensor.sigmoid(input)
}

func tanh(tensor input) tensor {
    return neurx.tensor.tanh(input)
}

func softmax(tensor input, int dim) tensor {
    return neurx.tensor.softmax(input, dim)
}

func log_softmax(tensor input, int dim) tensor {
    return neurx.tensor.log_softmax(input, dim)
}

func gelu(tensor input) tensor {
    return neurx.nn.activations.gelu(input)
}

func leaky_relu(tensor input, float negative_slope) tensor {
    return neurx.nn.activations.leaky_relu(input, negative_slope)
}

func elu(tensor input, float alpha) tensor {
    return neurx.nn.activations.elu(input, alpha)
}

func silu(tensor input) tensor {
    return neurx.nn.activations.silu(input)
}

func dropout(tensor input, float p, bool training) tensor {
    if !training || p <= 0.0 {
        return neurx.tensor.clone(input)
    }
    if p >= 1.0 {
        return neurx.tensor.zeros_like(input)
    }
    float keep_scale = 1.0 / (1.0 - p)
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        int bucket = i - (i / 10) * 10
        float keep = 1.0
        if bucket < int(p * 10.0) {
            keep = 0.0
        }
        out[i] = input.data[i] * keep * keep_scale
        i = i + 1
    }
    return neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func dropout1d(tensor input, float p, bool training) tensor {
    return dropout(input, p, training)
}

func dropout2d(tensor input, float p, bool training) tensor {
    return dropout(input, p, training)
}

func dropout3d(tensor input, float p, bool training) tensor {
    return dropout(input, p, training)
}

func alpha_dropout(tensor input, float p, bool training) tensor {
    if !training || p <= 0.0 {
        return neurx.tensor.clone(input)
    }
    if p >= 1.0 {
        return neurx.tensor.zeros_like(input)
    }
    float alpha_prime = -1.7580993408
    float keep_scale = 1.0507009873
    int n = len(input.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        int bucket = i - (i / 10) * 10
        if bucket < int(p * 10.0) {
            out[i] = alpha_prime
        } else {
            out[i] = input.data[i] * keep_scale
        }
        i = i + 1
    }
    return neurx.tensor.new(out, copy_int(input.shape), input.requires_grad)
}

func mse_loss(tensor input, tensor target) tensor {
    tensor diff = neurx.tensor.sub(input, target)
    tensor sq = neurx.tensor.mul(diff, diff)
    return neurx.tensor.mean(sq)
}

func l1_loss(tensor input, tensor target) tensor {
    tensor diff = neurx.tensor.sub(input, target)
    return neurx.tensor.mean(neurx.tensor.abs(diff))
}

func cross_entropy_loss(tensor logits, tensor target) tensor {
    tensor log_probs = neurx.tensor.log_softmax(logits, -1)
    int n = len(target.data)
    if n <= 0 {
        return neurx.tensor.scalar_tensor(0.0)
    }
    int classes = logits.shape[len(logits.shape) - 1]
    float loss = 0.0
    int i = 0
    while i < n {
        int cls = int(target.data[i])
        if cls < 0 {
            cls = 0
        }
        if cls >= classes {
            cls = classes - 1
        }
        loss = loss - log_probs.data[i * classes + cls]
        i = i + 1
    }
    loss = loss / float(n)
    return neurx.tensor.scalar_tensor(loss)
}

func bce_with_logits_loss(tensor logits, tensor target) tensor {
    tensor probs = neurx.tensor.sigmoid(logits)
    tensor one = neurx.tensor.ones_like(probs)
    tensor safe_probs = neurx.tensor.clamp(probs, 1e-6, 1.0 - 1e-6)
    tensor loss_pos = neurx.tensor.mul(target, neurx.tensor.log(safe_probs))
    tensor loss_neg = neurx.tensor.mul(neurx.tensor.sub(one, target), neurx.tensor.log(neurx.tensor.sub(one, safe_probs)))
    tensor total = neurx.tensor.negative(neurx.tensor.add(loss_pos, loss_neg))
    return neurx.tensor.mean(total)
}

func nll_loss(tensor log_probs, tensor target) tensor {
    return cross_entropy_loss(log_probs, target)
}

func smooth_l1_loss(tensor input, tensor target, float beta) tensor {
    tensor diff = neurx.tensor.sub(input, target)
    tensor abs_diff = neurx.tensor.abs(diff)
    int n = len(abs_diff.data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        float d = abs_diff.data[i]
        if d < beta {
            out[i] = 0.5 * d * d / beta
        } else {
            out[i] = d - 0.5 * beta
        }
        i = i + 1
    }
    return neurx.tensor.new(out, copy_int(abs_diff.shape), diff.requires_grad)
}

func huber_loss(tensor input, tensor target, float delta) tensor {
    return smooth_l1_loss(input, target, delta)
}

func binary_cross_entropy(tensor input, tensor target) tensor {
    tensor one = neurx.tensor.ones_like(input)
    tensor safe_input = neurx.tensor.clamp(input, 1e-6, 1.0 - 1e-6)
    tensor loss_pos = neurx.tensor.mul(target, neurx.tensor.log(safe_input))
    tensor loss_neg = neurx.tensor.mul(neurx.tensor.sub(one, target), neurx.tensor.log(neurx.tensor.sub(one, safe_input)))
    tensor total = neurx.tensor.negative(neurx.tensor.add(loss_pos, loss_neg))
    return neurx.tensor.mean(total)
}

func cosine_similarity(tensor x, tensor y, int dim, float eps) tensor {
    tensor xy = neurx.tensor.mul(x, y)
    tensor x2 = neurx.tensor.mul(x, x)
    tensor y2 = neurx.tensor.mul(y, y)
    tensor num = neurx.tensor.sum_dim(xy, dim, false)
    tensor den_x = neurx.tensor.sqrt(neurx.tensor.sum_dim(x2, dim, false))
    tensor den_y = neurx.tensor.sqrt(neurx.tensor.sum_dim(y2, dim, false))
    tensor den = neurx.tensor.add(neurx.tensor.mul(den_x, den_y), neurx.tensor.scalar_tensor(eps))
    return neurx.tensor.div(num, den)
}

func pairwise_distance(tensor x, tensor y, int p, float eps) tensor {
    tensor diff = neurx.tensor.abs(neurx.tensor.sub(x, y))
    if p <= 1 {
        return neurx.tensor.add(neurx.tensor.sum(diff), neurx.tensor.scalar_tensor(eps))
    }
    if p == 2 {
        return neurx.tensor.sqrt(neurx.tensor.add(neurx.tensor.sum(neurx.tensor.mul(diff, diff)), neurx.tensor.scalar_tensor(eps)))
    }
    tensor powered = diff
    int i = 1
    while i < p {
        powered = neurx.tensor.mul(powered, diff)
        i = i + 1
    }
    tensor total = neurx.tensor.add(neurx.tensor.sum(powered), neurx.tensor.scalar_tensor(eps))
    return neurx.tensor.exp(neurx.tensor.div(neurx.tensor.log(total), neurx.tensor.scalar_tensor(float(p))))
}

func batch_norm(tensor input, tensor weight, tensor bias, tensor running_mean, tensor running_var, bool training, float eps) tensor {
    int ndim = len(input.shape)
    if ndim < 2 {
        return neurx.tensor.clone(input)
    }
    int channels = input.shape[1]
    []float out = []float{cap: len(input.data)}
    int c = 0
    while c < channels {
        float mean = 0.0
        float var = 0.0
        int per_channel = 0
        if ndim == 2 {
            int batch = input.shape[0]
            per_channel = batch
            int b = 0
            while b < batch {
                float v = input.data[b * channels + c]
                mean = mean + v
                b = b + 1
            }
            mean = mean / float(per_channel)
            b = 0
            while b < batch {
                float v = input.data[b * channels + c] - mean
                var = var + v * v
                b = b + 1
            }
        } else {
            if ndim == 3 {
                int batch = input.shape[0]
                int length = input.shape[2]
                per_channel = batch * length
                int b = 0
                while b < batch {
                    int l = 0
                    while l < length {
                        float v = input.data[(b * channels + c) * length + l]
                        mean = mean + v
                        l = l + 1
                    }
                    b = b + 1
                }
                mean = mean / float(per_channel)
                b = 0
                while b < batch {
                    int l = 0
                    while l < length {
                        float v = input.data[(b * channels + c) * length + l] - mean
                        var = var + v * v
                        l = l + 1
                    }
                    b = b + 1
                }
            } else {
                if ndim == 4 {
                    int batch = input.shape[0]
                    int height = input.shape[2]
                    int width = input.shape[3]
                    per_channel = batch * height * width
                    int b = 0
                    while b < batch {
                        int h = 0
                        while h < height {
                            int w = 0
                            while w < width {
                                float v = input.data[((b * channels + c) * height + h) * width + w]
                                mean = mean + v
                                w = w + 1
                            }
                            h = h + 1
                        }
                        b = b + 1
                    }
                    mean = mean / float(per_channel)
                    b = 0
                    while b < batch {
                        int h = 0
                        while h < height {
                            int w = 0
                            while w < width {
                                float v = input.data[((b * channels + c) * height + h) * width + w] - mean
                                var = var + v * v
                                w = w + 1
                            }
                            h = h + 1
                        }
                        b = b + 1
                    }
                }
            }
        }
        if per_channel <= 0 {
            per_channel = 1
        }
        var = var / float(per_channel)
        float used_mean = mean
        float used_var = var
        if !training && len(running_mean.data) >= channels && len(running_var.data) >= channels {
            used_mean = running_mean.data[c]
            used_var = running_var.data[c]
        }
        float denom = neurx.tensor.sqrt(neurx.tensor.scalar_tensor(used_var + eps)).data[0]
        if ndim == 2 {
            int batch = input.shape[0]
            int b = 0
            while b < batch {
                int idx = b * channels + c
                float scale = 1.0
                float shift = 0.0
                if len(weight.data) > c {
                    scale = weight.data[c]
                }
                if len(bias.data) > c {
                    shift = bias.data[c]
                }
                out[idx] = ((input.data[idx] - used_mean) / denom) * scale + shift
                b = b + 1
            }
        } else {
            if ndim == 3 {
                int batch = input.shape[0]
                int length = input.shape[2]
                int b = 0
                while b < batch {
                    int l = 0
                    while l < length {
                        int idx = (b * channels + c) * length + l
                        float scale = 1.0
                        float shift = 0.0
                        if len(weight.data) > c {
                            scale = weight.data[c]
                        }
                        if len(bias.data) > c {
                            shift = bias.data[c]
                        }
                        out[idx] = ((input.data[idx] - used_mean) / denom) * scale + shift
                        l = l + 1
                    }
                    b = b + 1
                }
            } else {
                if ndim == 4 {
                    int batch = input.shape[0]
                    int height = input.shape[2]
                    int width = input.shape[3]
                    int b = 0
                    while b < batch {
                        int h = 0
                        while h < height {
                            int w = 0
                            while w < width {
                                int idx = ((b * channels + c) * height + h) * width + w
                                float scale = 1.0
                                float shift = 0.0
                                if len(weight.data) > c {
                                    scale = weight.data[c]
                                }
                                if len(bias.data) > c {
                                    shift = bias.data[c]
                                }
                                out[idx] = ((input.data[idx] - used_mean) / denom) * scale + shift
                                w = w + 1
                            }
                            h = h + 1
                        }
                        b = b + 1
                    }
                }
            }
        }
        c = c + 1
    }
    return neurx.tensor.new(out, copy_int(input.shape), input.requires_grad || weight.requires_grad || bias.requires_grad)
}

func sync_batch_norm(tensor input, tensor weight, tensor bias, tensor running_mean, tensor running_var, bool training, float eps, int world_size, int rank) tensor {
    if world_size <= 1 {
        return batch_norm(input, weight, bias, running_mean, running_var, training, eps)
    }
    return batch_norm(input, weight, bias, running_mean, running_var, training, eps)
}

func group_norm(tensor input, tensor weight, tensor bias, int num_groups, float eps) tensor {
    int ndim = len(input.shape)
    if ndim < 2 || num_groups <= 0 {
        return neurx.tensor.clone(input)
    }
    int batch = input.shape[0]
    int channels = input.shape[1]
    if channels <= 0 {
        return neurx.tensor.clone(input)
    }
    if num_groups > channels {
        num_groups = channels
    }
    while channels / num_groups * num_groups != channels && num_groups > 1 {
        num_groups = num_groups - 1
    }
    int group_channels = channels / num_groups
    int spatial = 1
    int i = 2
    while i < ndim {
        spatial = spatial * input.shape[i]
        i = i + 1
    }
    []float out = []float{cap: len(input.data)}
    int b = 0
    while b < batch {
        int g = 0
        while g < num_groups {
            int c_start = g * group_channels
            int c_end = c_start + group_channels
            float mean = 0.0
            float var = 0.0
            int count = group_channels * spatial
            int c = c_start
            while c < c_end {
                int s = 0
                while s < spatial {
                    int idx = 0
                    if ndim == 2 {
                        idx = b * channels + c
                    } else {
                        if ndim == 3 {
                            idx = (b * channels + c) * spatial + s
                        } else {
                            int hw = input.shape[2] * input.shape[3]
                            int h = s / input.shape[3]
                            int w = s - h * input.shape[3]
                            idx = ((b * channels + c) * input.shape[2] + h) * input.shape[3] + w
                            count = group_channels * hw
                        }
                    }
                    mean = mean + input.data[idx]
                    s = s + 1
                }
                c = c + 1
            }
            if count <= 0 {
                count = 1
            }
            mean = mean / float(count)
            c = c_start
            while c < c_end {
                int s = 0
                while s < spatial {
                    int idx = 0
                    if ndim == 2 {
                        idx = b * channels + c
                    } else {
                        if ndim == 3 {
                            idx = (b * channels + c) * spatial + s
                        } else {
                            int h = s / input.shape[3]
                            int w = s - h * input.shape[3]
                            idx = ((b * channels + c) * input.shape[2] + h) * input.shape[3] + w
                        }
                    }
                    float diff = input.data[idx] - mean
                    var = var + diff * diff
                    s = s + 1
                }
                c = c + 1
            }
            var = var / float(count)
            float denom = neurx.tensor.sqrt(neurx.tensor.scalar_tensor(var + eps)).data[0]
            c = c_start
            while c < c_end {
                float scale = 1.0
                float shift = 0.0
                if len(weight.data) > c {
                    scale = weight.data[c]
                }
                if len(bias.data) > c {
                    shift = bias.data[c]
                }
                int s = 0
                while s < spatial {
                    int idx = 0
                    if ndim == 2 {
                        idx = b * channels + c
                    } else {
                        if ndim == 3 {
                            idx = (b * channels + c) * spatial + s
                        } else {
                            int h = s / input.shape[3]
                            int w = s - h * input.shape[3]
                            idx = ((b * channels + c) * input.shape[2] + h) * input.shape[3] + w
                        }
                    }
                    out[idx] = ((input.data[idx] - mean) / denom) * scale + shift
                    s = s + 1
                }
                c = c + 1
            }
            g = g + 1
        }
        b = b + 1
    }
    return neurx.tensor.new(out, copy_int(input.shape), input.requires_grad || weight.requires_grad || bias.requires_grad)
}

func instance_norm(tensor input, tensor weight, tensor bias, float eps) tensor {
    int channels = 1
    if len(input.shape) >= 2 {
        channels = input.shape[1]
    }
    return group_norm(input, weight, bias, channels, eps)
}

func identity(tensor input) tensor {
    return neurx.tensor.clone(input)
}

func flatten(tensor input, int start_dim, int end_dim) tensor {
    return neurx.tensor.flatten(input, start_dim, end_dim)
}

func new_conv1d(int in_channels, int out_channels, int kernel_size, int stride, int padding, int dilation, bool use_bias) neurx.nn.conv.conv1d_state {
    return neurx.nn.conv.new_conv1d(in_channels, out_channels, kernel_size, stride, padding, dilation, use_bias)
}

func conv1d_forward(neurx.nn.conv.conv1d_state layer, tensor input) tensor {
    return neurx.nn.conv.conv1d_forward(layer, input)
}

func new_conv2d(int in_channels, int out_channels, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w, int dil_h, int dil_w, bool use_bias) neurx.nn.conv.conv2d_state {
    return neurx.nn.conv.new_conv2d(in_channels, out_channels, kernel_h, kernel_w, stride_h, stride_w, pad_h, pad_w, dil_h, dil_w, use_bias)
}

func conv2d_forward(neurx.nn.conv.conv2d_state layer, tensor input) tensor {
    return neurx.nn.conv.conv2d_forward(layer, input)
}

func new_convtranspose1d(int in_channels, int out_channels, int kernel_size, int stride, int padding, int output_padding, int dilation, bool use_bias) neurx.nn.conv.convtranspose1d_state {
    return neurx.nn.conv.new_convtranspose1d(in_channels, out_channels, kernel_size, stride, padding, output_padding, dilation, use_bias)
}

func convtranspose1d_forward(neurx.nn.conv.convtranspose1d_state layer, tensor input) tensor {
    return neurx.nn.conv.convtranspose1d_forward(layer, input)
}

func new_convtranspose2d(int in_channels, int out_channels, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w, int output_pad_h, int output_pad_w, int dil_h, int dil_w, bool use_bias) neurx.nn.conv.convtranspose2d_state {
    return neurx.nn.conv.new_convtranspose2d(in_channels, out_channels, kernel_h, kernel_w, stride_h, stride_w, pad_h, pad_w, output_pad_h, output_pad_w, dil_h, dil_w, use_bias)
}

func convtranspose2d_forward(neurx.nn.conv.convtranspose2d_state layer, tensor input) tensor {
    return neurx.nn.conv.convtranspose2d_forward(layer, input)
}

func max_pool1d(tensor input, int kernel_size, int stride, int padding) tensor {
    return neurx.nn.pooling.max_pool1d(input, kernel_size, stride, padding)
}

func avg_pool1d(tensor input, int kernel_size, int stride, int padding) tensor {
    return neurx.nn.pooling.avg_pool1d(input, kernel_size, stride, padding)
}

func max_pool2d(tensor input, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w) tensor {
    return neurx.nn.pooling.max_pool2d(input, kernel_h, kernel_w, stride_h, stride_w, pad_h, pad_w)
}

func avg_pool2d(tensor input, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w) tensor {
    return neurx.nn.pooling.avg_pool2d(input, kernel_h, kernel_w, stride_h, stride_w, pad_h, pad_w)
}

func adaptive_avg_pool2d(tensor input, int out_h, int out_w) tensor {
    return neurx.nn.pooling.adaptive_avg_pool2d(input, out_h, out_w)
}

func adaptive_max_pool2d(tensor input, int out_h, int out_w) tensor {
    return neurx.nn.pooling.adaptive_max_pool2d(input, out_h, out_w)
}
