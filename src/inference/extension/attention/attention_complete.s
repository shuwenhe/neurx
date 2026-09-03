package neurx.attention.complete
use neurx.tensor.{tensor, new, zeros, ones, fill, reshape}
use neurx.ml.math_ops.{softmax, softmax_backward, scale_tensor, add_tensors, matmul_2d, transpose_2d}

struct attention_cache {
    tensor q
    tensor k
    tensor v
    tensor q_heads
    tensor k_heads
    tensor v_heads
    tensor concat_output
    tensor output
    tensor scores
    tensor attention_weights
}

struct multihead_attention_state {
    int num_heads
    int d_model
    int head_dim
    tensor w_q
    tensor w_k
    tensor w_v
    tensor w_o
    tensor b_q
    tensor b_k
    tensor b_v
    tensor b_o
    attention_cache cache
    tensor grad_w_q
    tensor grad_w_k
    tensor grad_w_v
    tensor grad_w_o
    tensor grad_b_q
    tensor grad_b_k
    tensor grad_b_v
    tensor grad_b_o
}

func xavier_init_attention(int in_dim, int out_dim) tensor {
    float limit = sqrt(6.0 / float_from_int(in_dim + out_dim))
    int total = in_dim * out_dim
    []float data = make([]float, total)
    int i = 0
    for i < total {
        float val = limit * (2.0 * (float_from_int(i % 1000) / 1000.0) - 1.0)
        data = append(data, val)
        i = i + 1
    }
    tensor {
        data: data,
        shape: [in_dim, out_dim],
        requires_grad: true,
        dtype: 1,
        is_parameter: true,
    }
}

func zero_bias_attention(int dim) tensor {
    []float data = fill(dim, 0.0)
    tensor {
        data: data,
        shape: [dim],
        requires_grad: true,
        dtype: 1,
        is_parameter: true,
    }
}

func init_multihead_attention(int num_heads, int d_model) multihead_attention_state {
    if d_model % num_heads != 0 {
        panic("d_model must be divisible by num_heads")
    }
    int head_dim = d_model / num_heads
    multihead_attention_state {
        num_heads: num_heads,
        d_model: d_model,
        head_dim: head_dim,
        w_q: xavier_init_attention(d_model, d_model),
        w_k: xavier_init_attention(d_model, d_model),
        w_v: xavier_init_attention(d_model, d_model),
        w_o: xavier_init_attention(d_model, d_model),
        b_q: zero_bias_attention(d_model),
        b_k: zero_bias_attention(d_model),
        b_v: zero_bias_attention(d_model),
        b_o: zero_bias_attention(d_model),
        cache: attention_cache{},
        grad_w_q: zeros([d_model, d_model]),
        grad_w_k: zeros([d_model, d_model]),
        grad_w_v: zeros([d_model, d_model]),
        grad_w_o: zeros([d_model, d_model]),
        grad_b_q: zeros([d_model]),
        grad_b_k: zeros([d_model]),
        grad_b_v: zeros([d_model]),
        grad_b_o: zeros([d_model]),
    }
}

func split_heads(tensor x, int num_heads, int batch_size, int seq_len) tensor {
    int head_dim = x.shape[1] / num_heads
    int total_tokens = batch_size * seq_len
    reshape(x, [total_tokens * num_heads, head_dim])
}

func merge_heads(tensor x, int num_heads, int batch_size, int seq_len) tensor {
    int d_model = x.shape[1] * num_heads
    reshape(x, [batch_size * seq_len, d_model])
}

func linear_forward(tensor x, tensor w, tensor b) tensor {
    int rank = len(x.shape)
    int leading = 1
    int i = 0
    for i < rank - 1 {
        leading = leading * x.shape[i]
        i = i + 1
    }
    tensor flat_input = reshape(x, [leading, x.shape[rank - 1]])
    tensor output = matmul_2d(flat_input, w)
    i = 0
    for i < len(output.data) {
        output.data[i] = output.data[i] + b.data[i % len(b.data)]
        i = i + 1
    }
    output
}

func scaled_dot_product_attention(tensor q, tensor k, tensor v, float scale) tensor {
    tensor k_t = transpose_2d(k)
    tensor scores = matmul_2d(q, k_t)
    scores = scale_tensor(scores, scale)
    tensor attention_weights = softmax(scores)
    tensor output = matmul_2d(attention_weights, v)
    output
}

func multihead_attention_forward(multihead_attention_state state, tensor x) multihead_attention_state {
    tensor q = linear_forward(x, state.w_q, state.b_q)
    tensor k = linear_forward(x, state.w_k, state.b_k)
    tensor v = linear_forward(x, state.w_v, state.b_v)
    int batch_size = 1
    int seq_len = 1
    if len(x.shape) >= 1 {
        batch_size = x.shape[0]
    }
    if len(x.shape) >= 2 {
        seq_len = x.shape[1]
    }
    tensor q_heads = split_heads(q, state.num_heads, batch_size, seq_len)
    tensor k_heads = split_heads(k, state.num_heads, batch_size, seq_len)
    tensor v_heads = split_heads(v, state.num_heads, batch_size, seq_len)
    float scale = 1.0 / sqrt(float_from_int(state.head_dim))
    tensor attn_output = scaled_dot_product_attention(q_heads, k_heads, v_heads, scale)
    tensor concat_output = merge_heads(attn_output, state.num_heads, batch_size, seq_len)
    tensor output = linear_forward(concat_output, state.w_o, state.b_o)
    state.cache = attention_cache{
        q: q,
        k: k,
        v: v,
        q_heads: q_heads,
        k_heads: k_heads,
        v_heads: v_heads,
        concat_output: concat_output,
        output: output,
        scores: scale_tensor(matmul_2d(q_heads, transpose_2d(k_heads)), scale),
        attention_weights: softmax(scale_tensor(matmul_2d(q_heads, transpose_2d(k_heads)), scale)),
    }
    state.cache.q = q
    state.cache.k = k
    state.cache.v = v
    state
}

func multihead_attention_backward(
    multihead_attention_state state,
    tensor grad_output,
    tensor input_x
) (multihead_attention_state, tensor) {
    state.grad_w_o = matmul_2d(transpose_2d(grad_output), state.cache.concat_output)
    state.grad_b_o = sum_columns(grad_output)
    tensor grad_concat = matmul_2d(grad_output, transpose_2d(state.w_o))
    tensor grad_concat_heads = split_heads(grad_concat, state.num_heads, batch_size_of(input_x), seq_len_of(input_x))
    tensor grad_attention_weights = matmul_2d(grad_concat_heads, transpose_2d(state.cache.v_heads))
    tensor grad_scores = softmax_backward(grad_attention_weights, state.cache.attention_weights)
    float scale = 1.0 / sqrt(float_from_int(state.head_dim))
    tensor grad_q_heads = matmul_2d(grad_scores, state.cache.k_heads)
    tensor grad_k_heads = matmul_2d(transpose_2d(grad_scores), state.cache.q_heads)
    tensor grad_v_heads = matmul_2d(transpose_2d(state.cache.attention_weights), grad_concat_heads)
    grad_q_heads = scale_tensor(grad_q_heads, scale)
    grad_k_heads = scale_tensor(grad_k_heads, scale)
    int batch_size = 1
    int seq_len = 1
    if len(input_x.shape) >= 1 {
        batch_size = input_x.shape[0]
    }
    if len(input_x.shape) >= 2 {
        seq_len = input_x.shape[1]
    }
    tensor input_flat = reshape(input_x, [batch_size * seq_len, state.d_model])
    tensor grad_q = reshape(grad_q_heads, [batch_size * seq_len, state.d_model])
    tensor grad_k = reshape(grad_k_heads, [batch_size * seq_len, state.d_model])
    tensor grad_v = reshape(grad_v_heads, [batch_size * seq_len, state.d_model])
    state.grad_w_q = matmul_2d(transpose_2d(grad_q), input_flat)
    state.grad_w_k = matmul_2d(transpose_2d(grad_k), input_flat)
    state.grad_w_v = matmul_2d(transpose_2d(grad_v), input_flat)
    state.grad_b_q = sum_columns(grad_q)
    state.grad_b_k = sum_columns(grad_k)
    state.grad_b_v = sum_columns(grad_v)
    tensor grad_input = add_tensors(
        add_tensors(
            matmul_2d(grad_q, transpose_2d(state.w_q)),
            matmul_2d(grad_k, transpose_2d(state.w_k))
        ),
        matmul_2d(grad_v, transpose_2d(state.w_v))
    )
    state, grad_input
}

func float_from_int(int x) float {
    0.0 + x
}

func sum_columns(tensor x) tensor {
    int cols = x.shape[1]
    []float out = make([]float, cols)
    int j = 0
    for j < cols {
        out[j] = 0.0
        j = j + 1
    }
    int i = 0
    for i < x.shape[0] {
        j = 0
        for j < cols {
            out[j] = out[j] + x.data[i * cols + j]
            j = j + 1
        }
        i = i + 1
    }
    tensor {
        data: out,
        shape: [cols],
        requires_grad: false,
        grad: none,
    }
}

func batch_size_of(tensor x) int {
    if len(x.shape) >= 1 {
        return x.shape[0]
    }
    1
}

func seq_len_of(tensor x) int {
    if len(x.shape) >= 2 {
        return x.shape[1]
    }
    1
}

func sqrt(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    for i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func panic(string msg) {
    println("ERROR: " + msg)
}
