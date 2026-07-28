package neurx.attention.complete
use neurx.tensor.{tensor, new, zeros, ones, fill, reshape}
use neurx.ml.math_ops.{softmax, softmax_backward, scale_tensor, add_tensors, matmul_2d, transpose_2d}

struct attention_cache {
    tensor Q
    tensor K
    tensor V
    tensor Q_heads
    tensor K_heads
    tensor V_heads
    tensor concat_output
    tensor output
    tensor scores
    tensor attention_weights
}

struct multihead_attention_state {
    int num_heads
    int d_model
    int head_dim
    tensor W_Q
    tensor W_K
    tensor W_V
    tensor W_O
    tensor b_Q
    tensor b_K
    tensor b_V
    tensor b_O
    attention_cache cache
    tensor grad_W_Q
    tensor grad_W_K
    tensor grad_W_V
    tensor grad_W_O
    tensor grad_b_Q
    tensor grad_b_K
    tensor grad_b_V
    tensor grad_b_O
}

func xavier_init_attention(int in_dim, int out_dim) tensor {
    float limit = sqrt(6.0 / float_from_int(in_dim + out_dim))
    int total = in_dim * out_dim
    []float data = []float{cap: total}
    int i = 0
    while i < total {
        float val = limit * (2.0 * (float_from_int(i % 1000) / 1000.0) - 1.0)
        data.push(val)
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
        W_Q: xavier_init_attention(d_model, d_model),
        W_K: xavier_init_attention(d_model, d_model),
        W_V: xavier_init_attention(d_model, d_model),
        W_O: xavier_init_attention(d_model, d_model),
        b_Q: zero_bias_attention(d_model),
        b_K: zero_bias_attention(d_model),
        b_V: zero_bias_attention(d_model),
        b_O: zero_bias_attention(d_model),
        cache: attention_cache{},
        grad_W_Q: zeros([d_model, d_model]),
        grad_W_K: zeros([d_model, d_model]),
        grad_W_V: zeros([d_model, d_model]),
        grad_W_O: zeros([d_model, d_model]),
        grad_b_Q: zeros([d_model]),
        grad_b_K: zeros([d_model]),
        grad_b_V: zeros([d_model]),
        grad_b_O: zeros([d_model]),
    }
}

func split_heads(tensor X, int num_heads, int batch_size, int seq_len) tensor {
    int head_dim = X.shape[1] / num_heads
    int total_tokens = batch_size * seq_len
    reshape(X, [total_tokens * num_heads, head_dim])
}

func merge_heads(tensor X, int num_heads, int batch_size, int seq_len) tensor {
    int d_model = X.shape[1] * num_heads
    reshape(X, [batch_size * seq_len, d_model])
}

func linear_forward(tensor X, tensor W, tensor b) tensor {
    int rank = len(X.shape)
    int leading = 1
    int i = 0
    while i < rank - 1 {
        leading = leading * X.shape[i]
        i = i + 1
    }
    tensor flat_input = reshape(X, [leading, X.shape[rank - 1]])
    tensor output = matmul_2d(flat_input, W)
    i = 0
    while i < len(output.data) {
        output.data[i] = output.data[i] + b.data[i % len(b.data)]
        i = i + 1
    }
    output
}

func scaled_dot_product_attention(tensor Q, tensor K, tensor V, float scale) tensor {
    tensor K_T = transpose_2d(K)
    tensor scores = matmul_2d(Q, K_T)
    scores = scale_tensor(scores, scale)
    tensor attention_weights = softmax(scores)
    tensor output = matmul_2d(attention_weights, V)
    output
}

func multihead_attention_forward(multihead_attention_state state, tensor X) multihead_attention_state {
    tensor Q = linear_forward(X, state.W_Q, state.b_Q)
    tensor K = linear_forward(X, state.W_K, state.b_K)
    tensor V = linear_forward(X, state.W_V, state.b_V)
    int batch_size = 1
    int seq_len = 1
    if len(X.shape) >= 1 {
        batch_size = X.shape[0]
    }
    if len(X.shape) >= 2 {
        seq_len = X.shape[1]
    }
    tensor Q_heads = split_heads(Q, state.num_heads, batch_size, seq_len)
    tensor K_heads = split_heads(K, state.num_heads, batch_size, seq_len)
    tensor V_heads = split_heads(V, state.num_heads, batch_size, seq_len)
    float scale = 1.0 / sqrt(float_from_int(state.head_dim))
    tensor attn_output = scaled_dot_product_attention(Q_heads, K_heads, V_heads, scale)
    tensor concat_output = merge_heads(attn_output, state.num_heads, batch_size, seq_len)
    tensor output = linear_forward(concat_output, state.W_O, state.b_O)
    state.cache = attention_cache{
        Q: Q,
        K: K,
        V: V,
        Q_heads: Q_heads,
        K_heads: K_heads,
        V_heads: V_heads,
        concat_output: concat_output,
        output: output,
        scores: scale_tensor(matmul_2d(Q_heads, transpose_2d(K_heads)), scale),
        attention_weights: softmax(scale_tensor(matmul_2d(Q_heads, transpose_2d(K_heads)), scale)),
    }
    state.cache.Q = Q
    state.cache.K = K
    state.cache.V = V
    state
}

func multihead_attention_backward(
    multihead_attention_state state,
    tensor grad_output,
    tensor input_X
) (multihead_attention_state, tensor) {
    state.grad_W_O = matmul_2d(transpose_2d(grad_output), state.cache.concat_output)
    state.grad_b_O = sum_columns(grad_output)
    tensor grad_concat = matmul_2d(grad_output, transpose_2d(state.W_O))
    tensor grad_concat_heads = split_heads(grad_concat, state.num_heads, batch_size_of(input_X), seq_len_of(input_X))
    tensor grad_attention_weights = matmul_2d(grad_concat_heads, transpose_2d(state.cache.V_heads))
    tensor grad_scores = softmax_backward(grad_attention_weights, state.cache.attention_weights)
    float scale = 1.0 / sqrt(float_from_int(state.head_dim))
    tensor grad_Q_heads = matmul_2d(grad_scores, state.cache.K_heads)
    tensor grad_K_heads = matmul_2d(transpose_2d(grad_scores), state.cache.Q_heads)
    tensor grad_V_heads = matmul_2d(transpose_2d(state.cache.attention_weights), grad_concat_heads)
    grad_Q_heads = scale_tensor(grad_Q_heads, scale)
    grad_K_heads = scale_tensor(grad_K_heads, scale)
    int batch_size = 1
    int seq_len = 1
    if len(input_X.shape) >= 1 {
        batch_size = input_X.shape[0]
    }
    if len(input_X.shape) >= 2 {
        seq_len = input_X.shape[1]
    }
    tensor input_flat = reshape(input_X, [batch_size * seq_len, state.d_model])
    tensor grad_Q = reshape(grad_Q_heads, [batch_size * seq_len, state.d_model])
    tensor grad_K = reshape(grad_K_heads, [batch_size * seq_len, state.d_model])
    tensor grad_V = reshape(grad_V_heads, [batch_size * seq_len, state.d_model])
    state.grad_W_Q = matmul_2d(transpose_2d(grad_Q), input_flat)
    state.grad_W_K = matmul_2d(transpose_2d(grad_K), input_flat)
    state.grad_W_V = matmul_2d(transpose_2d(grad_V), input_flat)
    state.grad_b_Q = sum_columns(grad_Q)
    state.grad_b_K = sum_columns(grad_K)
    state.grad_b_V = sum_columns(grad_V)
    tensor grad_input = add_tensors(
        add_tensors(
            matmul_2d(grad_Q, transpose_2d(state.W_Q)),
            matmul_2d(grad_K, transpose_2d(state.W_K))
        ),
        matmul_2d(grad_V, transpose_2d(state.W_V))
    )
    (state, grad_input)
}

func float_from_int(int x) float {
    0.0 + x
}

func sum_columns(tensor X) tensor {
    int cols = X.shape[1]
    []float out = []float{cap: cols}
    int j = 0
    while j < cols {
        out[j] = 0.0
        j = j + 1
    }
    int i = 0
    while i < X.shape[0] {
        j = 0
        while j < cols {
            out[j] = out[j] + X.data[i * cols + j]
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

func batch_size_of(tensor X) int {
    if len(X.shape) >= 1 {
        return X.shape[0]
    }
    1
}

func seq_len_of(tensor X) int {
    if len(X.shape) >= 2 {
        return X.shape[1]
    }
    1
}

func sqrt(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func panic(string msg) {
    println("ERROR: " + msg)
}
