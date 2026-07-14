// =====================================================================
// Multi-Head Attention - Complete Implementation with Backward Pass
// 多头注意力机制 - 包含完整的反向传播
// =====================================================================

package neurx.ml.attention

use neurx.tensor.{tensor, new, zeros, ones, fill, reshape}
use neurx.ml.math_ops.{softmax, softmax_backward, scale_tensor, add_tensors, matmul_2d, transpose_2d}

struct attention_cache {
    tensor Q           // [batch, seq, d]
    tensor K           // [batch, seq, d]
    tensor V           // [batch, seq, d]
    tensor Q_heads     // [batch*seq*num_heads, head_dim]
    tensor K_heads     // [batch*seq*num_heads, head_dim]
    tensor V_heads     // [batch*seq*num_heads, head_dim]
    tensor concat_output // [batch*seq, d_model]
    tensor output      // [batch*seq, d_model]
    tensor scores      // [batch, heads, seq, seq]
    tensor attention_weights  // [batch, heads, seq, seq] - softmax output
}

struct multihead_attention_state {
    int num_heads
    int d_model
    int head_dim
    
    tensor W_Q         // Query weight [d_model, d_model]
    tensor W_K         // Key weight [d_model, d_model]
    tensor W_V         // Value weight [d_model, d_model]
    tensor W_O         // Output weight [d_model, d_model]
    
    tensor b_Q         // Query bias [d_model]
    tensor b_K         // Key bias [d_model]
    tensor b_V         // Value bias [d_model]
    tensor b_O         // Output bias [d_model]
    
    attention_cache cache
    
    // 梯度缓存
    tensor grad_W_Q
    tensor grad_W_K
    tensor grad_W_V
    tensor grad_W_O
    tensor grad_b_Q
    tensor grad_b_K
    tensor grad_b_V
    tensor grad_b_O
}

// =====================================================================
// 初始化
// =====================================================================

func xavier_init_attention(int in_dim, int out_dim) tensor {
    float limit = sqrt(6.0 / float_from_int(in_dim + out_dim))
    int total = in_dim * out_dim
    []float data = []float{cap: total}
    int i = 0
    while i < total {
        // 简化的均匀分布初始化
        float val = limit * (2.0 * (float_from_int(i % 1000) / 1000.0) - 1.0)
        data.push(val)
        i = i + 1
    }
    tensor {
        data: data,
        shape: [in_dim, out_dim],
        requires_grad: true,
        dtype: 1,  // float32
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

// =====================================================================
// 前向传播 Forward Pass
// =====================================================================

// Split [batch*seq, d_model] into [batch, seq, num_heads, head_dim]
func split_heads(tensor X, int num_heads, int batch_size, int seq_len) tensor {
    int head_dim = X.shape[1] / num_heads
    int total_tokens = batch_size * seq_len
    reshape(X, [total_tokens * num_heads, head_dim])
}

func merge_heads(tensor X, int num_heads, int batch_size, int seq_len) tensor {
    int d_model = X.shape[1] * num_heads
    reshape(X, [batch_size * seq_len, d_model])
}

// 扩展矩阵乘法支持更高维度
func linear_forward(tensor X, tensor W, tensor b) tensor {
    // X: [batch, seq, d_in]
    // W: [d_in, d_out]
    // b: [d_out]
    // Output: [tokens, d_out]

    int rank = len(X.shape)
    int leading = 1
    int i = 0
    while i < rank - 1 {
        leading = leading * X.shape[i]
        i = i + 1
    }

    tensor flat_input = reshape(X, [leading, X.shape[rank - 1]])
    tensor output = matmul_2d(flat_input, W)

    // 广播加偏置
    i = 0
    while i < len(output.data) {
        output.data[i] = output.data[i] + b.data[i % len(b.data)]
        i = i + 1
    }

    output
}

func scaled_dot_product_attention(tensor Q, tensor K, tensor V, float scale) tensor {
    // Q: [batch, heads, seq, head_dim]
    // K: [batch, heads, seq, head_dim]
    // V: [batch, heads, seq, head_dim]
    
    // Scores = Q @ K^T / sqrt(d_k)
    tensor K_T = transpose_2d(K)
    tensor scores = matmul_2d(Q, K_T)
    scores = scale_tensor(scores, scale)
    
    // Apply softmax over last dimension
    tensor attention_weights = softmax(scores)
    
    // Output = attention_weights @ V
    tensor output = matmul_2d(attention_weights, V)
    
    output
}

func multihead_attention_forward(multihead_attention_state state, tensor X) multihead_attention_state {
    // X: [batch, seq, d_model]
    
    // 1. Linear projections
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
    
    // 2. Split into multiple heads
    tensor Q_heads = split_heads(Q, state.num_heads, batch_size, seq_len)
    tensor K_heads = split_heads(K, state.num_heads, batch_size, seq_len)
    tensor V_heads = split_heads(V, state.num_heads, batch_size, seq_len)
    
    // 3. Scale factor
    float scale = 1.0 / sqrt(float_from_int(state.head_dim))
    
    // 4. Scaled dot-product attention
    tensor attn_output = scaled_dot_product_attention(Q_heads, K_heads, V_heads, scale)
    
    // 5. Concatenate heads
    tensor concat_output = merge_heads(attn_output, state.num_heads, batch_size, seq_len)
    
    // 6. Final linear projection
    tensor output = linear_forward(concat_output, state.W_O, state.b_O)
    
    // 缓存中间结果用于反向传播
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

// =====================================================================
// 反向传播 Backward Pass
// =====================================================================

func multihead_attention_backward(
    multihead_attention_state state,
    tensor grad_output,
    tensor input_X
) (multihead_attention_state, tensor) {
    // grad_output: gradient from next layer
    // 返回: 更新后的state和关于输入的梯度
    
    // 1. 反向通过输出投影
    // dL/dW_O = grad_output^T @ concat_output
    state.grad_W_O = matmul_2d(transpose_2d(grad_output), state.cache.concat_output)
    state.grad_b_O = sum_columns(grad_output)
    tensor grad_concat = matmul_2d(grad_output, transpose_2d(state.W_O))
    tensor grad_concat_heads = split_heads(grad_concat, state.num_heads, batch_size_of(input_X), seq_len_of(input_X))
    
    // 2. 反向通过attention weights
    tensor grad_attention_weights = matmul_2d(grad_concat_heads, transpose_2d(state.cache.V_heads))
    
    // 3. 反向通过softmax
    tensor grad_scores = softmax_backward(grad_attention_weights, state.cache.attention_weights)
    
    // 4. 反向通过scaled dot product
    float scale = 1.0 / sqrt(float_from_int(state.head_dim))
    tensor grad_Q_heads = matmul_2d(grad_scores, state.cache.K_heads)
    tensor grad_K_heads = matmul_2d(transpose_2d(grad_scores), state.cache.Q_heads)
    tensor grad_V_heads = matmul_2d(transpose_2d(state.cache.attention_weights), grad_concat_heads)
    
    // Scale gradients
    grad_Q_heads = scale_tensor(grad_Q_heads, scale)
    grad_K_heads = scale_tensor(grad_K_heads, scale)
    
    // 5. 反向通过线性投影 (Query, Key, Value)
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
    
    // 6. 计算关于输入的梯度
    tensor grad_input = add_tensors(
        add_tensors(
            matmul_2d(grad_Q, transpose_2d(state.W_Q)),
            matmul_2d(grad_K, transpose_2d(state.W_K))
        ),
        matmul_2d(grad_V, transpose_2d(state.W_V))
    )
    
    (state, grad_input)
}

// =====================================================================
// 辅助函数
// =====================================================================

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
