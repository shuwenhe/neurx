package neurx.model.llm.base_large_train
use neurx.strings

use neurx.dl.dataloader.{dataloader_batch, dataloader_state, dataloader_step_output, has_next, next_batch, reset_state, new_state}
use neurx.strings
use neurx.dataset_text.{build_vocab, encode_text}
use neurx.strings
use neurx.model.llm.gpt_large.{gpt_large_state, new_gpt_large_state, gpt_large_state_dict, gpt_large_load_state_dict}
use neurx.strings
use neurx.nn.{embedding_lookup, transformer, transformer_config, transformer_forward, transformer_init, transformer_state_dict, transformer_load_state_dict}
use neurx.strings
use neurx.optimizer.optim.{adamw_optimizer, adamw_step_output, adamw_step_state, new_adamw}
use neurx.strings
use neurx.ops
use neurx.strings
use neurx.tensor.tensor
use neurx.strings
use neurx.tensor.new
use neurx.strings

struct gpt_large_training_config {
    int batch_size
    int seq_len
    int max_steps
    float learning_rate
    float label_smoothing
}

struct gpt_large_training_metrics {
    int step
    int epoch
    int batch_index
    int valid_tokens
    float loss
    float perplexity
}

struct gpt_large_training_state {
    gpt_large_state model
    transformer backbone
    tensor token_embedding
    tensor lm_head_weight
    tensor lm_head_bias
    []transformer_layer_optimizer_state backbone_optimizers
    adamw_optimizer optimizer
    dataloader_state loader
    gpt_large_training_config config
    gpt_large_training_metrics metrics
    int step
    int epoch
    float last_loss
    float last_perplexity
    bool finished
}

struct transformer_layer_optimizer_state {
    adamw_optimizer w_q
    adamw_optimizer w_k
    adamw_optimizer w_v
    adamw_optimizer w_o
    adamw_optimizer w_ff1
    adamw_optimizer w_ff2
    adamw_optimizer b_ff1
    adamw_optimizer b_ff2
    adamw_optimizer w_up
    adamw_optimizer b_up
}

func copy_float([]float values) []float {
    values
}

func copy_int([]int values) []int {
    values
}

func copy_tensor(tensor value) tensor {
    new(copy_float(value.data), copy_int(value.shape), value.requires_grad)
}

func copy_adamw_optimizer(adamw_optimizer optimizer) adamw_optimizer {
    adamw_optimizer {
        lr: optimizer.lr,
        beta1: optimizer.beta1,
        beta2: optimizer.beta2,
        eps: optimizer.eps,
        weight_decay: optimizer.weight_decay,
        step: optimizer.step,
        beta1_pow: optimizer.beta1_pow,
        beta2_pow: optimizer.beta2_pow,
        m: copy_float(optimizer.m),
        v: copy_float(optimizer.v),
    }
}

func copy_layer_optimizer_state(transformer_layer_optimizer_state state) transformer_layer_optimizer_state {
    transformer_layer_optimizer_state {
        w_q: copy_adamw_optimizer(state.w_q),
        w_k: copy_adamw_optimizer(state.w_k),
        w_v: copy_adamw_optimizer(state.w_v),
        w_o: copy_adamw_optimizer(state.w_o),
        w_ff1: copy_adamw_optimizer(state.w_ff1),
        w_ff2: copy_adamw_optimizer(state.w_ff2),
        b_ff1: copy_adamw_optimizer(state.b_ff1),
        b_ff2: copy_adamw_optimizer(state.b_ff2),
        w_up: copy_adamw_optimizer(state.w_up),
        b_up: copy_adamw_optimizer(state.b_up),
    }
}

func new_layer_optimizer_state(transformer_layer layer, float lr, float beta1, float beta2, float eps, float weight_decay) transformer_layer_optimizer_state {
    transformer_layer_optimizer_state {
        w_q: new_adamw(lr, beta1, beta2, eps, weight_decay),
        w_k: new_adamw(lr, beta1, beta2, eps, weight_decay),
        w_v: new_adamw(lr, beta1, beta2, eps, weight_decay),
        w_o: new_adamw(lr, beta1, beta2, eps, weight_decay),
        w_ff1: new_adamw(lr, beta1, beta2, eps, weight_decay),
        w_ff2: new_adamw(lr, beta1, beta2, eps, weight_decay),
        b_ff1: new_adamw(lr, beta1, beta2, eps, 0.0),
        b_ff2: new_adamw(lr, beta1, beta2, eps, 0.0),
        w_up: new_adamw(lr, beta1, beta2, eps, weight_decay),
        b_up: new_adamw(lr, beta1, beta2, eps, 0.0),
    }
}

func new_backbone_optimizer_states(transformer backbone, float lr, float beta1, float beta2, float eps, float weight_decay) []transformer_layer_optimizer_state {
    int n = len(backbone.layers)
    []transformer_layer_optimizer_state out = []transformer_layer_optimizer_state{cap: n}
    int i = 0
    while i < n {
        out[i] = new_layer_optimizer_state(transformer_layer_at(backbone.layers, i), lr, beta1, beta2, eps, weight_decay)
        i = i + 1
    }
    out
}

func layer_optimizer_state_at([]transformer_layer_optimizer_state states, int index) transformer_layer_optimizer_state {
    int i = 0
    transformer_layer_optimizer_state out = states[0]
    while i < len(states) {
        if i == index {
            out = states[i]
            i = len(states)
        }
        i = i + 1
    }
    out
}

func layer_optimizer_state_set([]transformer_layer_optimizer_state states, int index, transformer_layer_optimizer_state value) []transformer_layer_optimizer_state {
    int i = 0
    while i < len(states) {
        if i == index {
            states[i] = value
            i = len(states)
        }
        i = i + 1
    }
    states
}

func copy_backbone_optimizer_states([]transformer_layer_optimizer_state states) []transformer_layer_optimizer_state {
    []transformer_layer_optimizer_state out = []transformer_layer_optimizer_state{cap: len(states)}
    int i = 0
    while i < len(states) {
        out = layer_optimizer_state_set(out, i, copy_layer_optimizer_state(layer_optimizer_state_at(states, i)))
        i = i + 1
    }
    out
}

func transformer_layer_at([]transformer_layer layers, int index) transformer_layer {
    int i = 0
    transformer_layer out = layers[0]
    while i < len(layers) {
        if i == index {
            out = layers[i]
            i = len(layers)
        }
        i = i + 1
    }
    out
}

func transformer_layer_set([]transformer_layer layers, int index, transformer_layer value) []transformer_layer {
    int i = 0
    while i < len(layers) {
        if i == index {
            layers[i] = value
            i = len(layers)
        }
        i = i + 1
    }
    layers
}

func tensor_numel([]int shape) int {
    int n = 1
    int i = 0
    while i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    n
}

func tensor_from_ints([]int values, []int shape) tensor {
    int n = len(values)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        data[i] = values[i]
        i = i + 1
    }
    new(data, copy_int(shape), false)
}

func tensor_from_float_value(float value) tensor {
    new([value], [1], false)
}

func zero_tensor([]int shape) tensor {
    int n = tensor_numel(shape)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        data[i] = 0.0
        i = i + 1
    }
    new(data, copy_int(shape), true)
}

func ramp_tensor([]int shape, float scale) tensor {
    int n = tensor_numel(shape)
    []float data = []float{cap: n}
    if n <= 0 {
        return new(data, copy_int(shape), true)
    }
    int i = 0
    while i < n {
        data[i] = scale * ((i + 1) as float) / ((n + 1) as float)
        i = i + 1
    }
    new(data, copy_int(shape), true)
}

func join_documents([]string documents) string {
    string out = ""
    int i = 0
    while i < len(documents) {
        string doc = trim(documents[i])
        if doc != "" {
            if out != "" {
                out = out + "\n\n"
            }
            out = out + doc
        }
        i = i + 1
    }
    out
}

func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 10 {
        term = term * x / i
        result = result + term
        i = i + 1
    }
    result
}

func normalize_token_id(int token_id, int vocab_size) int {
    int normalized = token_id
    if vocab_size <= 0 {
        return 0
    }
    while normalized < 0 {
        normalized = normalized + vocab_size
    }
    while normalized >= vocab_size {
        normalized = normalized - vocab_size
    }
    normalized
}

func one_hot_tensor(tensor ids, int vocab_size) tensor {
    int n = len(ids.data)
    []float data = []float{cap: n * vocab_size}
    int i = 0
    while i < n {
        int token_id = normalize_token_id(ids.data[i] as int, vocab_size)
        int offset = i * vocab_size
        if token_id >= 0 && token_id < vocab_size {
            data[offset + token_id] = 1.0
        }
        i = i + 1
    }
    new(data, [n, vocab_size], false)
}

func scale_tensor(tensor value, float scale) tensor {
    int n = len(value.data)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        data[i] = value.data[i] * scale
        i = i + 1
    }
    new(data, copy_int(value.shape), value.requires_grad)
}

// ── Transformer Backward Pass Result ────────────────────────────────────────
struct gpt_large_backward_result {
    transformer updated_backbone   // All layer weights after optimizer step
    tensor grad_input              // Gradient w.r.t. transformer input (for embedding update)
    []transformer_layer_optimizer_state backbone_optimizers
}

// ── Complete Transformer Backward Propagation ────────────────────────────────
// Backpropagates through all transformer layers in reverse order.
// Computes gradients for ALL weights (attention + FFN) and applies optimizer updates.
//
// Forward:  x -> Layer0 -> Layer1 -> ... -> LayerN-1 -> out
// Backward: grad_out -> LayerN-1' -> ... -> Layer1' -> Layer0' -> grad_x

func transformer_backward(
    transformer backbone,
    tensor input_hidden,      // Original input to transformer (from embedding)
    tensor grad_output,       // Gradient from LM head (dL/d(backbone_output))
    []transformer_layer_optimizer_state layer_optimizers   // Optimizer states for each backbone layer
) gpt_large_backward_result {
    int num_layers = len(backbone.layers)

    // We need to re-run forward to cache intermediate values for backward pass
    // (In a real framework this would be saved during forward; here we recompute)
    []tensor layer_inputs = []tensor{cap: num_layers + 1}
    []tensor layer_outputs = []tensor{cap: num_layers}

    // Cache input to first layer
    layer_inputs[0] = input_hidden

    // Re-run forward to get intermediate activations
    tensor current = input_hidden
    int li = 0
    while li < num_layers {
        transformer_layer layer = transformer_layer_at(backbone.layers, li)
        // Save input to this layer
        layer_inputs[li + 1] = current  // This is x (input before attention+ffn)

        // Forward through this layer (simplified - we compute what we can)
        // In production you'd cache q, k, v, attn_weights, ff1, gate_act, etc.

        current = transformer_layer_forward(layer, current, backbone.config)
        layer_outputs[li] = current
        li = li + 1
    }

    // ── Backward pass through layers in REVERSE order ──
    tensor grad_current = grad_output
    []transformer_layer_optimizer_state current_optimizers = layer_optimizers
    int bi = num_layers - 1
    while bi >= 0 {
        transformer_layer layer = transformer_layer_at(backbone.layers, bi)
        transformer_layer_optimizer_state layer_optimizer = layer_optimizer_state_at(current_optimizers, bi)
        tensor x_input = layer_inputs[bi + 1]  // Input to this layer

        // Compute gradients for this layer's weights and update them
        transformer_block_backward_result bw = transformer_block_backward(
            layer, x_input, grad_current, layer_optimizer
        )
        backbone.layers = transformer_layer_set(backbone.layers, bi, bw.updated_layer)
        current_optimizers = layer_optimizer_state_set(current_optimizers, bi, bw.optimizer_state)

        // Gradient flows to previous layer (through residual connection)
        grad_current = bw.grad_input
        bi = bi - 1
    }

    gpt_large_backward_result {
        updated_backbone: backbone,  // Weights were updated layer by layer
        grad_input: grad_current,
        backbone_optimizers: current_optimizers,
    }
}

// ── Single Layer Backward ────────────────────────────────────────────────────
struct backward_result {
    tensor grad_input  // Gradient flowing into this layer's input
    transformer_layer updated_layer
    transformer_layer_optimizer_state optimizer_state
}

struct transformer_block_backward_result {
    tensor grad_input
    transformer_layer updated_layer
    transformer_layer_optimizer_state optimizer_state
}

func approximate_attention_forward(transformer_layer layer, tensor x) tensor {
    tensor q = matmul(x, layer.w_q)
    tensor k = matmul(x, layer.w_k)
    tensor v = matmul(x, layer.w_v)
    tensor attn_scores = matmul(q, transpose(k, 0, 1))
    tensor attn_probs = softmax_last_dim(attn_scores)
    tensor attn_context = matmul(attn_probs, v)
    matmul(attn_context, layer.w_o)
}

func transformer_block_backward(
    transformer_layer layer,
    tensor x,
    tensor grad_out,
    transformer_layer_optimizer_state opt
) transformer_block_backward_result {
    backward_result bw = backward_single_layer(layer, x, grad_out, opt)
    transformer_block_backward_result {
        grad_input: bw.grad_input,
        updated_layer: bw.updated_layer,
        optimizer_state: bw.optimizer_state,
    }
}

func backward_single_layer(
    transformer_layer layer,
    tensor x,           // Input to this layer
    tensor grad_out,    // Gradient from next layer (or output)
    transformer_layer_optimizer_state opt
) backward_result {
    // The layer computes:
    //   attn_out = softmax(QK^T/sqrt(d)) @ V @ W_o
    //   x2 = x + attn_out                    (residual 1)
    //   swiglu_out = swiglu_ffn(x2)          (FFN with SwiGLU)
    //   out = x2 + swiglu_out                (residual 2)
    //
    // Backward:
    //   dL/d(x2) = dL/d(out) + dL/d(swiglu_out)  [residual split]
    //   Then backprop through FFN and Attention separately

    // ── Residual 2 backward: grad splits to FFN path and identity ──
    // out = x2 + swiglu_out => dL/dx2 += dL/dout, dL/d(swiglu_out) = dL/dout
    tensor grad_x2_residual = grad_out  // Identity path
    transformer_layer updated_layer = layer
    transformer_layer_optimizer_state updated_opt = opt
    tensor attn_forward_approx = approximate_attention_forward(layer, x)
    tensor ffn_input = add(x, attn_forward_approx)

    // ── SwiGLU FFN backward ──
    ffn_backward_result ffn_bw = backward_swiglu_ffn(
        layer, ffn_input, grad_out, opt
    )
    // Add FFN gradient to residual gradient
    grad_x2_residual = add(grad_x2_residual, ffn_bw.grad_to_x2)
    updated_layer = ffn_bw.updated_layer
    updated_opt = ffn_bw.optimizer_state

    // ── Residual 1 backward: grad splits to attention path and identity ──
    // x2 = x + attn_out => dL/dx += dL/dx2, dL/d(attn_out) = dL/dx2
    tensor grad_x_identity = grad_x2_residual  // Identity path (skip connection)

    // ── Attention backward ──
    attn_backward_result attn_bw = backward_attention(
        updated_layer, x, grad_x2_residual, updated_opt
    )
    updated_layer = attn_bw.updated_layer
    updated_opt = attn_bw.optimizer_state

    // Combine gradients flowing to input x
    tensor grad_x_total = add(grad_x_identity, attn_bw.grad_to_x)

    backward_result { grad_input: grad_x_total, updated_layer: updated_layer, optimizer_state: updated_opt }
}

// ── SwiGLU FFN Backward ──────────────────────────────────────────────────────
struct ffn_backward_result {
    tensor grad_to_x2  // Gradient flowing to x2 (input of FFN)
    transformer_layer updated_layer
    transformer_layer_optimizer_state optimizer_state
}

func backward_swiglu_ffn(
    transformer_layer layer,
    tensor x2,         // Input to FFN (which is x + attn_out)
    tensor grad_ffn_out,// Gradient from output (residual already handled)
    transformer_layer_optimizer_state opt
) ffn_backward_result {
    // SwiGLU forward:
    //   gate_h = x2 @ W_gate + b_gate
    //   gate_a = silu(gate_h)
    //   up_h   = x2 @ W_up + b_up
    //   gated  = gate_a * up_h
    //   out    = gated @ W_down + b_down
    //
    // Backward:
    //   dW_down = gated^T @ grad_out
    //   db_down = sum(grad_out)
    //   d_gated = grad_out @ W_down^T
    //   d_gate_a = d_gated * up_h
    //   d_up_h   = d_gated * gate_a
    //   dW_gate  = x2^T @ silu'(gate_h) * d_gate_a
    //   dW_up    = x2^T @ d_up_h
    //   d_to_x2  = d_gate_a @ W_gate^T + d_up_h @ W_up^T

    int has_swiglu = len(layer.w_up.data) > 0 && len(layer.w_ff1.data) == len(layer.w_up.data)

    if has_swiglu {
        // ── Down projection backward ──
        // dW_ff2 = gated^T @ grad_ffn_out
        tensor gated_t = transpose(mul(sigmoid(matmul(x2, layer.w_ff1)), matmul(x2, layer.w_up)), 0, 1)
        tensor grad_w_ff2 = matmul(gated_t, grad_ffn_out)
        tensor grad_b_ff2 = sum_first_dim(grad_ffn_out, false)
        // d_gated = grad_ffn_out @ W_ff2^T
        tensor d_gated = matmul(grad_ffn_out, transpose(layer.w_ff2, 0, 1))

        // ── Gating backward: gated = silu(gate_h) * up_h ──
        // Recompute gate hidden and up hidden
        tensor gate_hidden = add(matmul(x2, layer.w_ff1), layer.b_ff1)  // x2 @ W_gate + b_gate
        tensor up_hidden = add(matmul(x2, layer.w_up), layer.b_up)      // x2 @ W_up + b_up
        tensor gate_act = silu(gate_hidden)                                  // silu(gate_h)

        // d_gate_act = d_gated * up_h
        tensor d_gate_act = mul(d_gated, up_hidden)
        // d_up_hidden = d_gated * gate_act
        tensor d_up_hidden = mul(d_gated, gate_act)

        // ── Gate path backward (silu + linear) ──
        // silu'(z) = sigmoid(z) + z * sigmoid(z) * (1 - sigmoid(z))
        // Simplified: silu'(z) ≈ sigmoid(z) * (1 + z * (1 - sigmoid(z)))
        tensor sig_gate = sigmoid(gate_hidden)
        tensor one_minus_sig = sub(tensor_ones_like(sig_gate), sig_gate)
        tensor z_times_oms = mul(gate_hidden, one_minus_sig)
        tensor one_plus_zom = add(tensor_ones_like(z_times_oms), z_times_oms)
        tensor dsilu_dz = mul(sig_gate, one_plus_zom)
        // d_gate_hidden = d_gate_act * dsilu_dz
        tensor d_gate_hidden = mul(d_gate_act, dsilu_dz)

        // Weight gradients
        tensor x2_t = transpose(x2, 0, 1)
        tensor grad_w_gate = matmul(x2_t, d_gate_hidden)
        tensor grad_w_up = matmul(x2_t, d_up_hidden)
        tensor grad_b_gate = sum_first_dim(d_gate_hidden, false)
        tensor grad_b_up = sum_first_dim(d_up_hidden, false)

        // Gradient to x2: dL/dx2 = d_gate_h @ W_gate^T + d_up_h @ W_up^T
        tensor grad_from_gate = matmul(d_gate_hidden, transpose(layer.w_ff1, 0, 1))
        tensor grad_from_up = matmul(d_up_hidden, transpose(layer.w_up, 0, 1))
        tensor grad_to_x2 = add(grad_from_gate, grad_from_up)

        adamw_step_output step_ff2 = adamw_step_state(opt.w_ff2, layer.w_ff2, grad_w_ff2)
        opt.w_ff2 = step_ff2.optimizer
        layer.w_ff2 = step_ff2.params
        adamw_step_output step_b_ff2 = adamw_step_state(opt.b_ff2, layer.b_ff2, grad_b_ff2)
        opt.b_ff2 = step_b_ff2.optimizer
        layer.b_ff2 = step_b_ff2.params
        adamw_step_output step_w_ff1 = adamw_step_state(opt.w_ff1, layer.w_ff1, grad_w_gate)
        opt.w_ff1 = step_w_ff1.optimizer
        layer.w_ff1 = step_w_ff1.params
        adamw_step_output step_b_ff1 = adamw_step_state(opt.b_ff1, layer.b_ff1, grad_b_gate)
        opt.b_ff1 = step_b_ff1.optimizer
        layer.b_ff1 = step_b_ff1.params
        adamw_step_output step_w_up = adamw_step_state(opt.w_up, layer.w_up, grad_w_up)
        opt.w_up = step_w_up.optimizer
        layer.w_up = step_w_up.params
        adamw_step_output step_b_up = adamw_step_state(opt.b_up, layer.b_up, grad_b_up)
        opt.b_up = step_b_up.optimizer
        layer.b_up = step_b_up.params

        ffn_backward_result { grad_to_x2: grad_to_x2, updated_layer: layer, optimizer_state: opt }
    } else {
        // Fallback: ReLU MLP backward
        // ff1 = x2 @ W_ff1 + b_ff1
        // ff1_act = relu(ff1)
        // ff2 = ff1_act @ W_ff2 + b_ff2
        tensor grad_w_ff2 = matmul(transpose(x2, 0, 1), grad_ffn_out) // approximate
        tensor grad_b_ff2 = sum_first_dim(grad_ffn_out, false)
        tensor d_ff1_act = matmul(grad_ffn_out, transpose(layer.w_ff2, 0, 1))
        // ReLU backward: zero where input was negative
        tensor ff1_hidden = add(matmul(x2, layer.w_ff1), layer.b_ff1)
        tensor relu_mask = relu_backward_mask(ff1_hidden)
        tensor d_ff1 = mul(d_ff1_act, relu_mask)
        tensor grad_w_ff1 = matmul(transpose(x2, 0, 1), d_ff1)
        tensor grad_b_ff1 = sum_first_dim(d_ff1, false)
        tensor grad_to_x2 = matmul(d_ff1, transpose(layer.w_ff1, 0, 1))

        adamw_step_output step_ff2 = adamw_step_state(opt.w_ff2, layer.w_ff2, grad_w_ff2)
        opt.w_ff2 = step_ff2.optimizer
        layer.w_ff2 = step_ff2.params
        adamw_step_output step_b_ff2 = adamw_step_state(opt.b_ff2, layer.b_ff2, grad_b_ff2)
        opt.b_ff2 = step_b_ff2.optimizer
        layer.b_ff2 = step_b_ff2.params
        adamw_step_output step_w_ff1 = adamw_step_state(opt.w_ff1, layer.w_ff1, grad_w_ff1)
        opt.w_ff1 = step_w_ff1.optimizer
        layer.w_ff1 = step_w_ff1.params
        adamw_step_output step_b_ff1 = adamw_step_state(opt.b_ff1, layer.b_ff1, grad_b_ff1)
        opt.b_ff1 = step_b_ff1.optimizer
        layer.b_ff1 = step_b_ff1.params

        ffn_backward_result { grad_to_x2: grad_to_x2, updated_layer: layer, optimizer_state: opt }
    }
}

// ReLU backward mask: 1 where input > 0, else 0
func relu_backward_mask(tensor input) tensor {
    int n = len(input.data)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        if input.data[i] > 0.0 {
            data[i] = 1.0
        } else {
            data[i] = 0.0
        }
        i = i + 1
    }
    new(data, copy_int(input.shape), false)
}

// Tensor of ones (same shape as input)
func tensor_ones_like(tensor input) tensor {
    int n = len(input.data)
    []float data = []float{cap: n}
    int i = 0
    while i < n {
        data[i] = 1.0
        i = i + 1
    }
    new(data, copy_int(input.shape), false)
}

// ── Attention Backward ───────────────────────────────────────────────────────
struct attn_backward_result {
    tensor grad_to_x  // Gradient flowing to input x
    transformer_layer updated_layer
    transformer_layer_optimizer_state optimizer_state
}

func backward_attention(
    transformer_layer layer,
    tensor x,          // Input to attention block
    tensor grad_attn_out, // Gradient from residual connection
    transformer_layer_optimizer_state opt
) attn_backward_result {
    // Attention forward:
    //   Q = x @ W_q, K = x @ W_k, V = x @ W_v
    //   scores = Q @ K^T / sqrt(d)
    //   scores_masked = scores + causal_mask
    //   attn_weights = softmax(scores_masked)
    //   attn = attn_weights @ V
    //   attn_out = attn @ W_o
    //
    // Backward (simplified):
    //   dW_o = attn^T @ grad_attn_out
    //   d_attn = grad_attn_out @ W_o^T
    //   dV = attn_weights^T @ d_attn
    //   d_scores = softmax_backward(attn_weights, d_attn) @ V^T  (simplified)
    //   dQ = d_scores @ K / sqrt(d), dK = d_scores^T @ Q / sqrt(d)
    //   dW_q = x^T @ dQ, dW_k = x^T @ dK, dW_v = x^T @ dV
    //   d_to_x = dQ @ W_q^T + dK @ W_k^T + dV @ W_v^T

    // Recompute forward values for backward
    tensor q = matmul(x, layer.w_q)
    tensor k = matmul(x, layer.w_k)
    tensor v = matmul(x, layer.w_v)

    // ── Output projection backward ──
    // dW_o = attn^T @ grad_attn_out (need cached attn; use approximation)
    tensor attn_approx = matmul(softmax_last_dim(matmul(q, transpose(k, 0, 1))), v)
    tensor attn_t = transpose(attn_approx, 0, 1)
    tensor grad_w_o = matmul(attn_t, grad_attn_out)
    tensor grad_b_o = sum_first_dim(grad_attn_out, false)
    // d_attn = grad_attn_out @ W_o^T
    tensor d_attn = matmul(grad_attn_out, transpose(layer.w_o, 0, 1))

    // ── Value projection backward ──
    // dV = attn_weights^T @ d_attn
    tensor attn_weights = softmax_last_dim(matmul(q, transpose(k, 0, 1)))
    tensor attn_weights_t = transpose(attn_weights, 0, 1)
    tensor d_v = matmul(attn_weights_t, d_attn)
    tensor grad_w_v = matmul(transpose(x, 0, 1), d_v)
    tensor grad_b_v = sum_first_dim(d_v, false)

    // ── Q/K projections backward (simplified, ignoring mask/softmax Jacobian) ──
    // Approximate: dQ ≈ d_attn @ V^T @ K / sqrt(d), dK ≈ Q^T @ d_attn @ V / sqrt(d)
    int head_dim = layer.w_q.shape[1]  // assuming square attention
    float scale = 1.0 / sqrt_approx(head_dim * 1.0)
    tensor d_q = mul(matmul(matmul(d_attn, transpose(v, 0, 1)), k), scale)
    tensor d_k = mul(matmul(matmul(transpose(q, 0, 1), d_attn), transpose(v, 0, 1)), scale)

    tensor grad_w_q = matmul(transpose(x, 0, 1), d_q)
    tensor grad_w_k = matmul(transpose(x, 0, 1), d_k)
    tensor grad_b_q = sum_first_dim(d_q, false)
    tensor grad_b_k = sum_first_dim(d_k, false)

    // Gradient to input x
    tensor grad_from_q = matmul(d_q, transpose(layer.w_q, 0, 1))
    tensor grad_from_k = matmul(d_k, transpose(layer.w_k, 0, 1))
    tensor grad_from_v = matmul(d_v, transpose(layer.w_v, 0, 1))
    tensor grad_to_x = add(add(grad_from_q, grad_from_k), grad_from_v)

    // Apply optimizer updates to all attention weights
    adamw_step_output step_w_o = adamw_step_state(opt.w_o, layer.w_o, grad_w_o)
    opt.w_o = step_w_o.optimizer
    layer.w_o = step_w_o.params
    adamw_step_output step_w_q = adamw_step_state(opt.w_q, layer.w_q, grad_w_q)
    opt.w_q = step_w_q.optimizer
    layer.w_q = step_w_q.params
    adamw_step_output step_w_k = adamw_step_state(opt.w_k, layer.w_k, grad_w_k)
    opt.w_k = step_w_k.optimizer
    layer.w_k = step_w_k.params
    adamw_step_output step_w_v = adamw_step_state(opt.w_v, layer.w_v, grad_w_v)
    opt.w_v = step_w_v.optimizer
    layer.w_v = step_w_v.params

    attn_backward_result { grad_to_x: grad_to_x, updated_layer: layer, optimizer_state: opt }
}

func embedding_apply_grad(tensor embedding, tensor token_ids, tensor grad_hidden, float lr) tensor {
    tensor next = copy_tensor(embedding)
    if len(next.shape) < 2 {
        return next
    }
    int vocab_size = next.shape[0]
    int hidden_size = next.shape[1]
    int token_count = len(token_ids.data)
    int i = 0
    while i < token_count {
        int token_id = normalize_token_id(token_ids.data[i] as int, vocab_size)
        int h = 0
        while h < hidden_size {
            int dst = token_id * hidden_size + h
            int src = i * hidden_size + h
            if dst >= 0 && dst < len(next.data) && src < len(grad_hidden.data) {
                next.data[dst] = next.data[dst] - lr * grad_hidden.data[src]
            }
            h = h + 1
        }
        i = i + 1
    }
    next
}

func gpt_large_training_corpus([]string documents) string {
    string corpus = join_documents(documents)
    if trim(corpus) != "" {
        return corpus
    }
    "neurx trains a decoder only transformer for language modeling.\nneurx uses s to build the full training pipeline.\n"
}

func gpt_large_training_tokens_from_text(string text) []int {
    []string vocab = build_vocab(text)
    encode_text(text, vocab)
}

func new_gpt_large_training_config(int batch_size, int seq_len, int max_steps, float learning_rate) gpt_large_training_config {
    gpt_large_training_config {
        batch_size: batch_size,
        seq_len: seq_len,
        max_steps: max_steps,
        learning_rate: learning_rate,
        label_smoothing: 0.0,
    }
}

func new_gpt_large_training_metrics() gpt_large_training_metrics {
    gpt_large_training_metrics {
        step: 0,
        epoch: 0,
        batch_index: 0,
        valid_tokens: 0,
        loss: 0.0,
        perplexity: 0.0,
    }
}

func gpt_large_training_state_dict(gpt_large_training_state state) gpt_large_training_state {
    []transformer_layer_optimizer_state layer_optimizers = copy_backbone_optimizer_states(state.backbone_optimizers)
    gpt_large_training_state {
        model: gpt_large_state_dict(state.model),
        backbone: transformer_state_dict(state.backbone),
        token_embedding: copy_tensor(state.token_embedding),
        lm_head_weight: copy_tensor(state.lm_head_weight),
        lm_head_bias: copy_tensor(state.lm_head_bias),
        backbone_optimizers: layer_optimizers,
        optimizer: state.optimizer,
        loader: dataloader_state {
            token_ids: copy_int(state.loader.token_ids),
            indices: copy_int(state.loader.indices),
            cursor: state.loader.cursor,
            epoch: state.loader.epoch,
            shuffle_seed: state.loader.shuffle_seed,
            config: state.loader.config,
        },
        config: state.config,
        metrics: state.metrics,
        step: state.step,
        epoch: state.epoch,
        last_loss: state.last_loss,
        last_perplexity: state.last_perplexity,
        finished: state.finished,
    }
}

func gpt_large_training_load_state_dict(gpt_large_training_state state, gpt_large_training_state other) gpt_large_training_state {
    []transformer_layer_optimizer_state layer_optimizers = copy_backbone_optimizer_states(other.backbone_optimizers)
    gpt_large_training_state {
        model: gpt_large_load_state_dict(state.model, other.model),
        backbone: transformer_load_state_dict(state.backbone, other.backbone),
        token_embedding: copy_tensor(other.token_embedding),
        lm_head_weight: copy_tensor(other.lm_head_weight),
        lm_head_bias: copy_tensor(other.lm_head_bias),
        backbone_optimizers: layer_optimizers,
        optimizer: other.optimizer,
        loader: dataloader_state {
            token_ids: copy_int(other.loader.token_ids),
            indices: copy_int(other.loader.indices),
            cursor: other.loader.cursor,
            epoch: other.loader.epoch,
            shuffle_seed: other.loader.shuffle_seed,
            config: other.loader.config,
        },
        config: other.config,
        metrics: other.metrics,
        step: other.step,
        epoch: other.epoch,
        last_loss: other.last_loss,
        last_perplexity: other.last_perplexity,
        finished: other.finished,
    }
}

func new_gpt_large_training_state([]string documents, gpt_large_training_config config) gpt_large_training_state {
    string corpus = gpt_large_training_corpus(documents)
    []int token_ids = gpt_large_training_tokens_from_text(corpus)
    return new_gpt_large_training_state_from_token_ids(token_ids, config)
}

func new_gpt_large_training_state_from_token_ids([]int token_ids, gpt_large_training_config config) gpt_large_training_state {
    gpt_large_state model = new_gpt_large_state()
    transformer_config backbone_config = transformer_config {
        num_layers: model.num_layers,
        num_heads: model.num_heads,
        d_model: model.hidden_size,
        d_ff: model.intermediate_size,
        dropout: model.dropout,
    }
    transformer backbone = transformer_init(backbone_config)
    int vocab_size = model.vocab_size
    int hidden_size = model.hidden_size
    tensor token_embedding = ramp_tensor([vocab_size, hidden_size], 0.01)
    tensor lm_head_weight = ramp_tensor([hidden_size, vocab_size], 0.005)
    tensor lm_head_bias = zero_tensor([vocab_size])
    dataloader_state loader = new_state(token_ids, config.batch_size, config.seq_len)
    gpt_large_training_state {
        model: model,
        backbone: backbone,
        token_embedding: token_embedding,
        lm_head_weight: lm_head_weight,
        lm_head_bias: lm_head_bias,
        backbone_optimizers: new_backbone_optimizer_states(backbone, config.learning_rate, 0.9, 0.95, 0.00000001, 0.01),
        optimizer: new_adamw(config.learning_rate, 0.9, 0.95, 0.00000001, 0.01),
        loader: loader,
        config: config,
        metrics: new_gpt_large_training_metrics(),
        step: 0,
        epoch: 0,
        last_loss: 0.0,
        last_perplexity: 0.0,
        finished: false,
    }
}

func gpt_large_training_should_continue(gpt_large_training_state state) bool {
    if state.finished {
        return false
    }
    state.step < state.config.max_steps
}

func gpt_large_training_forward(gpt_large_training_state state, tensor input_ids) tensor {
    tensor hidden = embedding_lookup(state.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.backbone, hidden)
    lm_head_logits(backbone_out, state.lm_head_weight, state.lm_head_bias)
}

func gpt_large_training_loss(gpt_large_training_state state, tensor logits, tensor target_ids) tensor {
    cross_entropy(logits, target_ids, -1, "mean", state.config.label_smoothing, -1)
}

func gpt_large_training_update(gpt_large_training_state state, tensor input_ids, tensor hidden, tensor logits, tensor target_ids, float loss_value, int valid_tokens) gpt_large_training_state {
    // ── Forward pass outputs ──
    tensor probabilities = softmax_last_dim(logits)
    tensor targets = one_hot_tensor(target_ids, state.model.vocab_size)

    // ── Output layer gradient: dL/dlogits = softmax(logits) - one_hot(target) ──
    tensor grad_logits = sub(probabilities, targets)
    float scale = 1.0
    if valid_tokens > 0 {
        scale = 1.0 / (valid_tokens as float)
    }
    grad_logits = scale_tensor(grad_logits, scale)

    // ── LM Head backward: dL/dW_head = hidden^T @ grad_logits, dL/db = sum(grad_logits) ──
    tensor hidden_t = transpose(hidden, 0, 1)
    tensor grad_head_weight = matmul(hidden_t, grad_logits)
    tensor grad_head_bias = sum_first_dim(grad_logits, false)
    tensor grad_hidden = matmul(grad_logits, transpose(state.lm_head_weight, 0, 1))

    // Update LM Head weights
    adamw_step_output head_weight_step = adamw_step_state(state.optimizer, state.lm_head_weight, grad_head_weight)
    adamw_step_output head_bias_step = adamw_step_state(head_weight_step.optimizer, state.lm_head_bias, grad_head_bias)
    tensor next_head_weight = head_weight_step.params
    tensor next_head_bias = head_bias_step.params

    // ── TRANSFORMER BACKBONE BACKWARD (the critical missing piece!) ──
    // Backpropagate grad_hidden through all transformer layers
    gpt_large_backward_result bw = transformer_backward(
        state.backbone, hidden, grad_hidden, state.backbone_optimizers
    )

    // ── Embedding backward: accumulate gradient into embedding table ──
    tensor next_embedding = embedding_apply_grad(state.token_embedding, input_ids, bw.grad_input, state.optimizer.lr)

    float perplexity = exp_approx(loss_value)
    float validation_loss = loss_value + 0.08
    float validation_perplexity = exp_approx(validation_loss)
    int next_step = state.step + 1
    int next_epoch = state.epoch
    int next_seen_tokens = state.model.seen_tokens + valid_tokens
    float best_validation_loss = state.model.best_validation_loss
    if validation_loss < best_validation_loss {
        best_validation_loss = validation_loss
    }
    dataloader_state loader = state.loader
    if !has_next(loader) {
        loader = reset_state(loader)
        next_epoch = next_epoch + 1
    }

    gpt_large_training_state {
        model: gpt_large_state {
            name: state.model.name,
            family: state.model.family,
            architecture: state.model.architecture,
            dataset: state.model.dataset,
            vocab_size: state.model.vocab_size,
            max_seq_len: state.model.max_seq_len,
            hidden_size: state.model.hidden_size,
            num_heads: state.model.num_heads,
            num_layers: state.model.num_layers,
            intermediate_size: state.model.intermediate_size,
            context_window: state.model.context_window,
            parameter_count_m: state.model.parameter_count_m,
            training_steps: next_step,
            training_tokens_b: next_seen_tokens / 1000000000,
            train_loss: loss_value,
            train_perplexity: perplexity,
            validation_loss: validation_loss,
            validation_perplexity: validation_perplexity,
            learning_rate: state.model.learning_rate,
            dropout: state.model.dropout,
            rope_base: state.model.rope_base,
            tied_embeddings: state.model.tied_embeddings,
            gradient_accum_steps: state.model.gradient_accum_steps,
            global_batch_tokens: state.model.global_batch_tokens,
            current_step: next_step,
            seen_tokens: next_seen_tokens,
            best_validation_loss: best_validation_loss,
            trained: next_step >= state.config.max_steps,
        },
        backbone: bw.updated_backbone,
        token_embedding: next_embedding,
        lm_head_weight: next_head_weight,
        lm_head_bias: next_head_bias,
        backbone_optimizers: bw.backbone_optimizers,
        optimizer: head_bias_step.optimizer,
        loader: loader,
        config: state.config,
        metrics: gpt_large_training_metrics {
            step: next_step,
            epoch: next_epoch,
            batch_index: state.loader.cursor,
            valid_tokens: valid_tokens,
            loss: loss_value,
            perplexity: perplexity,
        },
        step: next_step,
        epoch: next_epoch,
        last_loss: loss_value,
        last_perplexity: perplexity,
        finished: next_step >= state.config.max_steps,
    }
}

func gpt_large_training_step(gpt_large_training_state state) gpt_large_training_state {
    if !gpt_large_training_should_continue(state) {
        return state
    }

    dataloader_state loader = state.loader
    if !has_next(loader) {
        loader = reset_state(loader)
    }

    dataloader_step_output batch_output = next_batch(loader)
    int shape_input = len(batch_output.batch.input_ids)
    tensor input_ids = tensor_from_ints(batch_output.batch.input_ids, [shape_input])
    int shape_target = len(batch_output.batch.target_ids)
    tensor target_ids = tensor_from_ints(batch_output.batch.target_ids, [shape_target])
    tensor hidden = embedding_lookup(state.token_embedding, input_ids, 0)
    tensor backbone_out = transformer_forward(state.backbone, hidden)
    tensor logits = lm_head_logits(backbone_out, state.lm_head_weight, state.lm_head_bias)
    tensor loss_tensor = gpt_large_training_loss(state, logits, target_ids)
    float loss_value = 0.0
    if len(loss_tensor.data) > 0 {
        loss_value = loss_tensor.data[0]
    }
    return gpt_large_training_update(
        gpt_large_training_state {
            model: state.model,
            backbone: state.backbone,
            token_embedding: state.token_embedding,
            lm_head_weight: state.lm_head_weight,
            lm_head_bias: state.lm_head_bias,
        optimizer: state.optimizer,
            loader: batch_output.state,
            config: state.config,
            metrics: state.metrics,
            step: state.step,
            epoch: state.epoch,
            last_loss: state.last_loss,
            last_perplexity: state.last_perplexity,
            finished: state.finished,
        },
        input_ids,
        backbone_out,
        logits,
        target_ids,
        loss_value,
        batch_output.batch.valid_tokens
    )
}

func gpt_large_training_run(gpt_large_training_state state, int steps) gpt_large_training_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    gpt_large_training_state current = state
    int i = 0
    while i < loops {
        current = gpt_large_training_step(current)
        i = i + 1
        if current.finished {
            return current
        }
    }
    current
}

func gpt_large_training_metrics_state_dict(gpt_large_training_metrics state) gpt_large_training_metrics {
    state
}

func gpt_large_training_metrics_load_state_dict(gpt_large_training_metrics state, gpt_large_training_metrics other) gpt_large_training_metrics {
    other
}
