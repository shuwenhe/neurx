package neurx.nn

use neurx.backends.compute_backend
use neurx.tensor.tensor

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
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func shape1(int n) []int {
    []int shape = []int{cap: 1}
    shape[0] = n
    shape
}

func shape2(int m, int n) []int {
    []int shape = []int{cap: 2}
    shape[0] = m
    shape[1] = n
    shape
}

func shape3(int a, int b, int c) []int {
    []int shape = []int{cap: 3}
    shape[0] = a
    shape[1] = b
    shape[2] = c
    shape
}

func numel([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    n
}

func exp_approx(float x) float {
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    1.0 + x + (x2 / 2.0) + (x3 / 6.0) + (x4 / 24.0) + (x5 / 120.0)
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
    guess
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
    out
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
    linear {
        in_features: in_features,
        out_features: out_features,
        weight: weight,
        bias: bias,
        has_bias: true,
        training: true,
    }
}

func linear_train(linear layer) linear {
    linear {
        in_features: layer.in_features,
        out_features: layer.out_features,
        weight: copy_float(layer.weight),
        bias: copy_float(layer.bias),
        has_bias: layer.has_bias,
        training: true,
    }
}

func linear_eval(linear layer) linear {
    linear {
        in_features: layer.in_features,
        out_features: layer.out_features,
        weight: copy_float(layer.weight),
        bias: copy_float(layer.bias),
        has_bias: layer.has_bias,
        training: false,
    }
}

func linear_state_dict(linear layer) linear {
    linear {
        in_features: layer.in_features,
        out_features: layer.out_features,
        weight: copy_float(layer.weight),
        bias: copy_float(layer.bias),
        has_bias: layer.has_bias,
        training: layer.training,
    }
}

func linear_load_state_dict(linear layer, linear other) linear {
    linear {
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
    params
}

func linear_forward(linear layer, tensor input) tensor {
    compute_context ctx = resolve_compute_context("", "")
    linear_forward_backend(layer, input, ctx)
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
    out
}

func layer_norm(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    layer_norm_impl(input, weight, bias, normalized_dims, eps)
}

func rms_norm(tensor input, tensor weight, tensor bias, int normalized_dims, float eps) tensor {
    rms_norm_impl(input, weight, bias, normalized_dims, eps)
}

func mlp_block(tensor input, tensor fc1_weight, tensor fc1_bias, tensor fc2_weight, tensor fc2_bias) tensor {
    mlp_block_impl(input, fc1_weight, fc1_bias, fc2_weight, fc2_bias)
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
    out
}

func qkv_projection(tensor input, tensor weight, tensor bias, int n_heads) tensor {
    qkv_projection_impl(input, weight, bias, n_heads)
}

func rope_apply(tensor input, tensor cos, tensor sin) tensor {
    rope_apply_impl(input, cos, sin)
}

func embedding_lookup(tensor weight, tensor input_ids, int padding_idx) tensor {
    embedding_lookup_impl(weight, input_ids, padding_idx)
}
