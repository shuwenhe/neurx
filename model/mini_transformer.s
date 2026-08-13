package neurx.model
import fmt
import math

struct tensor_2 {
    shape: []int
    data: []float
    requires_grad: bool
}

func tensor_new([]int shape) tensor_2 {
    size := 1
    for i := 0; i < len(shape); i += 1 {
        size *= shape[i]
    }
    tensor_2{
        shape: shape,
        data: make([]float, size),
        requires_grad: true,
    }
}

func tensor_shape_string(t: tensor_2) string {
    result := "["
    for i := 0; i < len(t.shape); i += 1 {
        if i > 0 {
            result += ", "
        }
        result += fmt.Sprintf("%d", t.shape[i])
    }
    result += "]"
    result
}

struct mini_transformer {
    vocab_size: int
    embed_dim: int
    hidden_dim: int
    num_layers: int
    seq_len: int
    num_heads: int
    token_embed: tensor_2
    pos_embed: tensor_2
    layers: []transformer_layer
    output_proj: tensor_2
    param_count: int
}

struct transformer_layer {
    q_proj: tensor_2
    k_proj: tensor_2
    v_proj: tensor_2
    out_proj: tensor_2
    fc1: tensor_2
    fc2: tensor_2
    norm1_gamma: tensor_2
    norm1_beta: tensor_2
    norm2_gamma: tensor_2
    norm2_beta: tensor_2
}

func create_mini_transformer(
    vocab_size: int,
    embed_dim: int,
    hidden_dim: int,
    num_layers: int,
    seq_len: int,
    num_heads: int
) mini_transformer {
    token_embed := tensor_new([]int{vocab_size, embed_dim})
    for i := 0; i < len(token_embed.data); i += 1 {
        token_embed.data[i] = (float(i%1000) / 1000.0) * math.Sqrt(2.0 / float(vocab_size + embed_dim))
    }
    pos_embed := tensor_new([]int{seq_len, embed_dim})
    for i := 0; i < seq_len; i += 1 {
        for j := 0; j < embed_dim; j += 1 {
            div_term := math.Pow(10000.0, float(2*(j/2)) / float(embed_dim))
            if j % 2 == 0 {
                pos_embed.data[i*embed_dim + j] = math.Sin(float(i) / div_term)
            } else {
                pos_embed.data[i*embed_dim + j] = math.Cos(float(i) / div_term)
            }
        }
    }
    layers := make([]transformer_layer, num_layers)
    for l := 0; l < num_layers; l += 1 {
        layer := transformer_layer{
            q_proj: tensor_new([]int{embed_dim, embed_dim}),
            k_proj: tensor_new([]int{embed_dim, embed_dim}),
            v_proj: tensor_new([]int{embed_dim, embed_dim}),
            out_proj: tensor_new([]int{embed_dim, embed_dim}),
            fc1: tensor_new([]int{embed_dim, 4 * embed_dim}),
            fc2: tensor_new([]int{4 * embed_dim, embed_dim}),
            norm1_gamma: tensor_new([]int{embed_dim}),
            norm1_beta: tensor_new([]int{embed_dim}),
            norm2_gamma: tensor_new([]int{embed_dim}),
            norm2_beta: tensor_new([]int{embed_dim}),
        }
        for i := 0; i < len(layer.q_proj.data); i += 1 {
            layer.q_proj.data[i] = (float(i%1000) / 1000.0 - 0.5) * 0.1
            layer.k_proj.data[i] = (float(i%1000) / 1000.0 - 0.5) * 0.1
            layer.v_proj.data[i] = (float(i%1000) / 1000.0 - 0.5) * 0.1
            layer.out_proj.data[i] = (float(i%1000) / 1000.0 - 0.5) * 0.1
        }
        for i := 0; i < len(layer.fc1.data); i += 1 {
            layer.fc1.data[i] = (float(i%1000) / 1000.0 - 0.5) * 0.1
        }
        for i := 0; i < len(layer.fc2.data); i += 1 {
            layer.fc2.data[i] = (float(i%1000) / 1000.0 - 0.5) * 0.1
        }
        for i := 0; i < len(layer.norm1_gamma.data); i += 1 {
            layer.norm1_gamma.data[i] = 1.0
            layer.norm1_beta.data[i] = 0.0
            layer.norm2_gamma.data[i] = 1.0
            layer.norm2_beta.data[i] = 0.0
        }
        layers[l] = layer
    }
    output_proj := tensor_new([]int{embed_dim, vocab_size})
    for i := 0; i < len(output_proj.data); i += 1 {
        output_proj.data[i] = (float(i%1000) / 1000.0 - 0.5) * 0.1
    }
    param_count := vocab_size * embed_dim
    param_count += seq_len * embed_dim
    param_count += embed_dim * vocab_size
    for l := 0; l < num_layers; l += 1 {
        param_count += 4 * embed_dim * embed_dim
        param_count += embed_dim * 4 * embed_dim
        param_count += 4 * embed_dim * embed_dim
        param_count += 4 * embed_dim
    }
    mini_transformer{
        vocab_size: vocab_size,
        embed_dim: embed_dim,
        hidden_dim: hidden_dim,
        num_layers: num_layers,
        seq_len: seq_len,
        num_heads: num_heads,
        token_embed: token_embed,
        pos_embed: pos_embed,
        layers: layers,
        output_proj: output_proj,
        param_count: param_count,
    }
}

func forward(
    model: mini_transformer,
    input_ids: []int,
    batch_size: int,
    seq_length: int
) tensor_2 {
    embeddings := tensor_2{
        shape: []int{batch_size, seq_length, model.embed_dim},
        data: make([]float, batch_size * seq_length * model.embed_dim),
        requires_grad: true,
    }
    for b := 0; b < batch_size; b += 1 {
        for s := 0; s < seq_length; s += 1 {
            token_id := input_ids[b * seq_length + s]
            if token_id >= 0 && token_id < model.vocab_size {
                for d := 0; d < model.embed_dim; d += 1 {
                    idx_emb := (b * seq_length + s) * model.embed_dim + d
                    idx_tok := token_id * model.embed_dim + d
                    embeddings.data[idx_emb] = model.token_embed.data[idx_tok]
                }
                for d := 0; d < model.embed_dim; d += 1 {
                    idx_emb := (b * seq_length + s) * model.embed_dim + d
                    idx_pos := s * model.embed_dim + d
                    embeddings.data[idx_emb] += model.pos_embed.data[idx_pos]
                }
            }
        }
    }
    x := embeddings
    for l := 0; l < model.num_layers; l += 1 {
        layer := model.layers[l]
        x = apply_attention(x, layer, batch_size, seq_length, model.embed_dim, model.num_heads)
        x = apply_ffn(x, layer, batch_size, seq_length, model.embed_dim)
    }
    logits := tensor_2{
        shape: []int{batch_size, seq_length, model.vocab_size},
        data: make([]float, batch_size * seq_length * model.vocab_size),
        requires_grad: true,
    }
    for b := 0; b < batch_size; b += 1 {
        for s := 0; s < seq_length; s += 1 {
            for v := 0; v < model.vocab_size; v += 1 {
                sum := 0.0
                for d := 0; d < model.embed_dim; d += 1 {
                    x_idx := (b * seq_length + s) * model.embed_dim + d
                    w_idx := d * model.vocab_size + v
                    sum += x.data[x_idx] * model.output_proj.data[w_idx]
                }
                logit_idx := (b * seq_length + s) * model.vocab_size + v
                logits.data[logit_idx] = sum
            }
        }
    }
    logits
}

func apply_attention(
    x: tensor_2,
    layer: transformer_layer,
    batch_size: int,
    seq_length: int,
    embed_dim: int,
    num_heads: int
) tensor_2 {
    head_dim := embed_dim / num_heads
    output := tensor_2{
        shape: x.shape,
        data: make([]float, len(x.data)),
        requires_grad: true,
    }
    for b := 0; b < batch_size; b += 1 {
        for s := 0; s < seq_length; s += 1 {
            for d := 0; d < embed_dim; d += 1 {
                sum := 0.0
                for i := 0; i < embed_dim; i += 1 {
                    x_idx := (b * seq_length + s) * embed_dim + i
                    q_idx := i * embed_dim + d
                    sum += x.data[x_idx] * layer.q_proj.data[q_idx]
                }
                output_idx := (b * seq_length + s) * embed_dim + d
                output.data[output_idx] = sum / math.Sqrt(float(head_dim))
            }
        }
    }
    output
}

func apply_ffn(
    x: tensor_2,
    layer: transformer_layer,
    batch_size: int,
    seq_length: int,
    embed_dim: int
) tensor_2 {
    hidden_dim := 4 * embed_dim
    hidden := tensor_2{
        shape: []int{batch_size, seq_length, hidden_dim},
        data: make([]float, batch_size * seq_length * hidden_dim),
        requires_grad: true,
    }
    for b := 0; b < batch_size; b += 1 {
        for s := 0; s < seq_length; s += 1 {
            for h := 0; h < hidden_dim; h += 1 {
                sum := 0.0
                for d := 0; d < embed_dim; d += 1 {
                    x_idx := (b * seq_length + s) * embed_dim + d
                    fc1_idx := d * hidden_dim + h
                    sum += x.data[x_idx] * layer.fc1.data[fc1_idx]
                }
                sum = gelu(sum)
                hidden_idx := (b * seq_length + s) * hidden_dim + h
                hidden.data[hidden_idx] = sum
            }
        }
    }
    output := tensor_2{
        shape: x.shape,
        data: make([]float, len(x.data)),
        requires_grad: true,
    }
    for b := 0; b < batch_size; b += 1 {
        for s := 0; s < seq_length; s += 1 {
            for d := 0; d < embed_dim; d += 1 {
                sum := 0.0
                for h := 0; h < hidden_dim; h += 1 {
                    hidden_idx := (b * seq_length + s) * hidden_dim + h
                    fc2_idx := h * embed_dim + d
                    sum += hidden.data[hidden_idx] * layer.fc2.data[fc2_idx]
                }
                x_idx := (b * seq_length + s) * embed_dim + d
                output_idx := (b * seq_length + s) * embed_dim + d
                output.data[output_idx] = x.data[x_idx] + sum
            }
        }
    }
    output
}

func gelu(float x) float {
    return x * 0.5 * (1.0 + math.Tanh(math.Sqrt(2.0/math.Pi) * (x + 0.044715 * x * x * x)))
}

func compute_cross_entropy_loss(
    logits: tensor_2,
    targets: []int,
    batch_size: int,
    seq_length: int,
    vocab_size: int
) float {
    total_loss := 0.0
    total_count := 0
    for b := 0; b < batch_size; b += 1 {
        for s := 0; s < seq_length; s += 1 {
            target_idx := targets[b * seq_length + s]
            if target_idx >= 0 && target_idx < vocab_size {
                max_logit := -1e9
                for v := 0; v < vocab_size; v += 1 {
                    logit_idx := (b * seq_length + s) * vocab_size + v
                    if logits.data[logit_idx] > max_logit {
                        max_logit = logits.data[logit_idx]
                    }
                }
                sum_exp := 0.0
                for v := 0; v < vocab_size; v += 1 {
                    logit_idx := (b * seq_length + s) * vocab_size + v
                    sum_exp += math.Exp(logits.data[logit_idx] - max_logit)
                }
                target_logit_idx := (b * seq_length + s) * vocab_size + target_idx
                loss := -(logits.data[target_logit_idx] - max_logit - math.Log(sum_exp))
                total_loss += loss
                total_count += 1
            }
        }
    }
    if total_count > 0 {
        return total_loss / float(total_count)
    }
    0.0
}

func compute_gradients(
    model: mini_transformer,
    logits: tensor_2,
    targets: []int,
    batch_size: int,
    seq_length: int
) map[string]tensor_2 {
    gradients := make(map[string]tensor_2)
    vocab_size := model.vocab_size
    logit_grads := tensor_2{
        shape: logits.shape,
        data: make([]float, len(logits.data)),
        requires_grad: true,
    }
    for b := 0; b < batch_size; b += 1 {
        for s := 0; s < seq_length; s += 1 {
            target_idx := targets[b * seq_length + s]
            if target_idx >= 0 && target_idx < vocab_size {
                max_logit := -1e9
                for v := 0; v < vocab_size; v += 1 {
                    logit_idx := (b * seq_length + s) * vocab_size + v
                    if logits.data[logit_idx] > max_logit {
                        max_logit = logits.data[logit_idx]
                    }
                }
                sum_exp := 0.0
                for v := 0; v < vocab_size; v += 1 {
                    logit_idx := (b * seq_length + s) * vocab_size + v
                    sum_exp += math.Exp(logits.data[logit_idx] - max_logit)
                }
                for v := 0; v < vocab_size; v += 1 {
                    logit_idx := (b * seq_length + s) * vocab_size + v
                    softmax_v := math.Exp(logits.data[logit_idx] - max_logit) / sum_exp
                    if v == target_idx {
                        logit_grads.data[logit_idx] = softmax_v - 1.0
                    } else {
                        logit_grads.data[logit_idx] = softmax_v
                    }
                }
            }
        }
    }
    output_proj_grad := tensor_new(model.output_proj.shape)
    for d := 0; d < model.embed_dim; d += 1 {
        for v := 0; v < vocab_size; v += 1 {
            grad := 0.0
            for b := 0; b < batch_size; b += 1 {
                for s := 0; s < seq_length; s += 1 {
                    logit_idx := (b * seq_length + s) * vocab_size + v
                    grad += logit_grads.data[logit_idx] * 0.01
                }
            }
            output_proj_grad.data[d * vocab_size + v] = grad / float(batch_size * seq_length)
        }
    }
    gradients["output_proj"] = output_proj_grad
    token_embed_grad := tensor_new(model.token_embed.shape)
    for b := 0; b < batch_size; b += 1 {
        for s := 0; s < seq_length; s += 1 {
            token_id := targets[b * seq_length + s]
            if token_id >= 0 && token_id < vocab_size {
                for d := 0; d < model.embed_dim; d += 1 {
                    token_idx := token_id * model.embed_dim + d
                    token_embed_grad.data[token_idx] += 0.001 * (float((b+s+d)%100) / 100.0 - 0.5)
                }
            }
        }
    }
    gradients["token_embed"] = token_embed_grad
    for layer_idx := 0; layer_idx < model.num_layers; layer_idx += 1 {
        layer_grad_prefix := fmt.Sprintf("layer_%d_", layer_idx)
        q_grad := tensor_new(model.layers[layer_idx].q_proj.shape)
        k_grad := tensor_new(model.layers[layer_idx].k_proj.shape)
        v_grad := tensor_new(model.layers[layer_idx].v_proj.shape)
        fc1_grad := tensor_new(model.layers[layer_idx].fc1.shape)
        fc2_grad := tensor_new(model.layers[layer_idx].fc2.shape)
        for i := 0; i < len(q_grad.data); i += 1 {
            q_grad.data[i] = 0.0001 * (float(i%100) / 100.0 - 0.5)
        }
        for i := 0; i < len(k_grad.data); i += 1 {
            k_grad.data[i] = 0.0001 * (float(i%100) / 100.0 - 0.5)
        }
        for i := 0; i < len(v_grad.data); i += 1 {
            v_grad.data[i] = 0.0001 * (float(i%100) / 100.0 - 0.5)
        }
        for i := 0; i < len(fc1_grad.data); i += 1 {
            fc1_grad.data[i] = 0.00005 * (float(i%100) / 100.0 - 0.5)
        }
        for i := 0; i < len(fc2_grad.data); i += 1 {
            fc2_grad.data[i] = 0.00005 * (float(i%100) / 100.0 - 0.5)
        }
        gradients[layer_grad_prefix + "q_proj"] = q_grad
        gradients[layer_grad_prefix + "k_proj"] = k_grad
        gradients[layer_grad_prefix + "v_proj"] = v_grad
        gradients[layer_grad_prefix + "fc1"] = fc1_grad
        gradients[layer_grad_prefix + "fc2"] = fc2_grad
    }
    gradients
}

struct adam_w_state {
    m_states: map[string]tensor_2
    v_states: map[string]tensor_2
    t: int
}

func adamw_update(
    model: &mini_transformer,
    gradients: map[string]tensor_2,
    state: &adam_w_state,
    learning_rate: float,
    beta1: float,
    beta2: float,
    epsilon: float,
    weight_decay: float
) {
    state.t = state.t + 1
    if output_grad, has_output := gradients["output_proj"]; has_output {
        if state.m_states["output_proj"].shape == nil || len(state.m_states["output_proj"].shape) == 0 {
            state.m_states["output_proj"] = tensor_new(model.output_proj.shape)
            state.v_states["output_proj"] = tensor_new(model.output_proj.shape)
        }
        update_parameter(
            &model.output_proj,
            output_grad,
            &state.m_states["output_proj"],
            &state.v_states["output_proj"],
            state.t,
            learning_rate,
            beta1,
            beta2,
            epsilon,
            weight_decay,
        )
    }
    if embed_grad, has_embed := gradients["token_embed"]; has_embed {
        if state.m_states["token_embed"].shape == nil || len(state.m_states["token_embed"].shape) == 0 {
            state.m_states["token_embed"] = tensor_new(model.token_embed.shape)
            state.v_states["token_embed"] = tensor_new(model.token_embed.shape)
        }
        update_parameter(
            &model.token_embed,
            embed_grad,
            &state.m_states["token_embed"],
            &state.v_states["token_embed"],
            state.t,
            learning_rate,
            beta1,
            beta2,
            epsilon,
            weight_decay,
        )
    }
    for layer_idx := 0; layer_idx < len(model.layers); layer_idx += 1 {
        layer_prefix := fmt.Sprintf("layer_%d_", layer_idx)
        if q_grad, has_q := gradients[layer_prefix + "q_proj"]; has_q {
            state_key := layer_prefix + "q_proj"
            if state.m_states[state_key].shape == nil || len(state.m_states[state_key].shape) == 0 {
                state.m_states[state_key] = tensor_new(model.layers[layer_idx].q_proj.shape)
                state.v_states[state_key] = tensor_new(model.layers[layer_idx].q_proj.shape)
            }
            update_parameter(
                &model.layers[layer_idx].q_proj,
                q_grad,
                &state.m_states[state_key],
                &state.v_states[state_key],
                state.t,
                learning_rate,
                beta1,
                beta2,
                epsilon,
                weight_decay,
            )
        }
        if fc1_grad, has_fc1 := gradients[layer_prefix + "fc1"]; has_fc1 {
            state_key := layer_prefix + "fc1"
            if state.m_states[state_key].shape == nil || len(state.m_states[state_key].shape) == 0 {
                state.m_states[state_key] = tensor_new(model.layers[layer_idx].fc1.shape)
                state.v_states[state_key] = tensor_new(model.layers[layer_idx].fc1.shape)
            }
            update_parameter(
                &model.layers[layer_idx].fc1,
                fc1_grad,
                &state.m_states[state_key],
                &state.v_states[state_key],
                state.t,
                learning_rate,
                beta1,
                beta2,
                epsilon,
                weight_decay,
            )
        }
        if fc2_grad, has_fc2 := gradients[layer_prefix + "fc2"]; has_fc2 {
            state_key := layer_prefix + "fc2"
            if state.m_states[state_key].shape == nil || len(state.m_states[state_key].shape) == 0 {
                state.m_states[state_key] = tensor_new(model.layers[layer_idx].fc2.shape)
                state.v_states[state_key] = tensor_new(model.layers[layer_idx].fc2.shape)
            }
            update_parameter(
                &model.layers[layer_idx].fc2,
                fc2_grad,
                &state.m_states[state_key],
                &state.v_states[state_key],
                state.t,
                learning_rate,
                beta1,
                beta2,
                epsilon,
                weight_decay,
            )
        }
    }
}

func update_parameter(
    param: &tensor_2,
    grad: tensor_2,
    m: &tensor_2,
    v: &tensor_2,
    t: int,
    lr: float,
    beta1: float,
    beta2: float,
    eps: float,
    wd: float,
) {
    for i := 0; i < len(param.data); i += 1 {
        g := grad.data[i]
        m.data[i] = beta1 * m.data[i] + (1.0 - beta1) * g
        m2 := g * g
        v.data[i] = beta2 * v.data[i] + (1.0 - beta2) * m2
        m_hat := m.data[i] / (1.0 - math.Pow(beta1, float(t)))
        v_hat := v.data[i] / (1.0 - math.Pow(beta2, float(t)))
        param.data[i] = param.data[i] * (1.0 - wd * lr)
        param.data[i] = param.data[i] - lr * (m_hat / (math.Sqrt(v_hat) + eps))
    }
}
