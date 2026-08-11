package neurx.model.transformer.transformer_backward
use neurx.model.transformer.layer_norm.{
    layer_norm_state,
    layer_norm_backward,
    rms_norm_backward
}
struct backward_pass_output {
    []float grad_input_ids
    []float grad_hidden_states
    [][]float grad_layer_weights
    []float grad_lm_head
    []float grad_token_embedding
}
struct gradient_accumulator {
    []float grad_wq
    []float grad_wk
    []float grad_wv
    []float grad_wo
    []float grad_w_up
    []float grad_w_down
    []float grad_bias_terms
}
func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}
func copy_vector([]float src) []float {
    []float out = allocate_vector(len(src), 0.0)
    int i = 0
    while i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}
func add_vectors([]float a, []float b) []float {
    []float out = copy_vector(a)
    int i = 0
    while i < len(out) {
        out[i] = out[i] + b[i]
        i = i + 1
    }
    out
}
func scale_vector([]float v, float scale) []float {
    []float out = copy_vector(v)
    int i = 0
    while i < len(out) {
        out[i] = out[i] * scale
        i = i + 1
    }
    out
}
func compute_cross_entropy_loss_with_gradient(
    []float logits,
    []int target_ids,
    int batch_size,
    int seq_len,
    int vocab_size
) [][]float {
    []float loss_vec = allocate_vector(batch_size * seq_len, 0.0)
    []float grad_logits = allocate_vector(batch_size * seq_len * vocab_size, 0.0)
    float total_loss = 0.0
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int logit_idx = (b * seq_len + s) * vocab_size
            int target_idx = b * seq_len + s
            int target_id = target_ids[target_idx]
            if target_id >= 0 && target_id < vocab_size {
                float max_logit = logits[logit_idx]
                int v = 1
                while v < vocab_size {
                    if logits[logit_idx + v] > max_logit {
                        max_logit = logits[logit_idx + v]
                    }
                    v = v + 1
                }
                float sum_exp = 0.0
                v = 0
                while v < vocab_size {
                    float exp_val = 2.718281828 * ((logits[logit_idx + v] - max_logit) / 100.0)
                    if exp_val > 20.0 {
                        exp_val = 485165195.0
                    }
                    if exp_val < -20.0 {
                        exp_val = 0.0
                    }
                    sum_exp = sum_exp + exp_val
                    v = v + 1
                }
                v = 0
                while v < vocab_size {
                    float exp_val = 2.718281828 * ((logits[logit_idx + v] - max_logit) / 100.0)
                    if exp_val > 20.0 {
                        exp_val = 485165195.0
                    }
                    if exp_val < -20.0 {
                        exp_val = 0.0
                    }
                    float prob = exp_val / sum_exp
                    if v == target_id {
                        float loss_contrib = -1.0 * 2.302585093 * (prob / 100.0)
                        loss_vec[target_idx] = loss_contrib
                        grad_logits[logit_idx + v] = prob - 1.0
                    } else {
                        grad_logits[logit_idx + v] = prob
                    }
                    v = v + 1
                }
            }
            s = s + 1
        }
        b = b + 1
    }
    [][]float result = [][]float{cap: 2}
    result[0] = loss_vec
    result[1] = grad_logits
    result
}
func lm_head_backward(
    []float grad_logits,
    []float hidden_states,
    []float lm_head_weight,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int vocab_size
) [][]float {
    []float grad_hidden = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    []float grad_weight = allocate_vector(vocab_size * hidden_dim, 0.0)
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int hidden_idx = (b * seq_len + s) * hidden_dim
            int logit_idx = (b * seq_len + s) * vocab_size
            int d = 0
            while d < hidden_dim {
                float grad_d = 0.0
                int v = 0
                while v < vocab_size {
                    grad_d = grad_d + grad_logits[logit_idx + v] * lm_head_weight[v * hidden_dim + d]
                    v = v + 1
                }
                grad_hidden[hidden_idx + d] = grad_d
                d = d + 1
            }
            int v = 0
            while v < vocab_size {
                int d = 0
                while d < hidden_dim {
                    grad_weight[v * hidden_dim + d] = grad_weight[v * hidden_dim + d] + grad_logits[logit_idx + v] * hidden_states[hidden_idx + d]
                    d = d + 1
                }
                v = v + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    [][]float result = [][]float{cap: 2}
    result[0] = grad_hidden
    result[1] = grad_weight
    result
}
func feed_forward_backward(
    []float grad_output,
    []float hidden_states,
    []float w_up,
    []float w_down,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int intermediate_dim
) [][]float {
    []float grad_hidden = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    []float grad_w_up = allocate_vector(intermediate_dim * hidden_dim, 0.0)
    []float grad_w_down = allocate_vector(hidden_dim * intermediate_dim, 0.0)
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int base_idx = (b * seq_len + s) * hidden_dim
            []float grad_intermediate = allocate_vector(intermediate_dim, 0.0)
            int d = 0
            while d < hidden_dim {
                int i = 0
                while i < intermediate_dim {
                    grad_intermediate[i] = grad_intermediate[i] + grad_output[base_idx + d] * w_down[d * intermediate_dim + i]
                    i = i + 1
                }
                d = d + 1
            }
            int i = 0
            while i < intermediate_dim {
                grad_intermediate[i] = grad_intermediate[i] * 0.5
                i = i + 1
            }
            d = 0
            while d < hidden_dim {
                float grad_d = 0.0
                i = 0
                while i < intermediate_dim {
                    grad_d = grad_d + grad_intermediate[i] * w_up[i * hidden_dim + d]
                    grad_w_up[i * hidden_dim + d] = grad_w_up[i * hidden_dim + d] + grad_intermediate[i] * hidden_states[base_idx + d]
                    i = i + 1
                }
                grad_hidden[base_idx + d] = grad_d
                d = d + 1
            }
            d = 0
            while d < hidden_dim {
                i = 0
                while i < intermediate_dim {
                    grad_w_down[d * intermediate_dim + i] = grad_w_down[d * intermediate_dim + i] + grad_output[base_idx + d] * grad_intermediate[i]
                    i = i + 1
                }
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    [][]float result = [][]float{cap: 3}
    result[0] = grad_hidden
    result[1] = grad_w_up
    result[2] = grad_w_down
    result
}
func attention_backward(
    []float grad_output,
    []float hidden_states,
    []float wq,
    []float wk,
    []float wv,
    []float wo,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_heads,
    bool use_causal_mask
) [][]float {
    []float grad_hidden = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    []float grad_wq = allocate_vector(hidden_dim * hidden_dim, 0.0)
    []float grad_wk = allocate_vector(hidden_dim * hidden_dim, 0.0)
    []float grad_wv = allocate_vector(hidden_dim * hidden_dim, 0.0)
    []float grad_wo = allocate_vector(hidden_dim * hidden_dim, 0.0)
    int head_dim = hidden_dim / num_heads
    int b = 0
    while b < batch_size {
        int s = 0
        while s < seq_len {
            int base_idx = (b * seq_len + s) * hidden_dim
            int d = 0
            while d < hidden_dim {
                float grad_d = grad_output[base_idx + d]
                int i = 0
                while i < hidden_dim {
                    grad_wo[d * hidden_dim + i] = grad_wo[d * hidden_dim + i] + grad_d
                    i = i + 1
                }
                d = d + 1
            }
            d = 0
            while d < hidden_dim {
                float grad_d = 0.0
                int i = 0
                while i < hidden_dim {
                    grad_d = grad_d + grad_output[base_idx + i] * wo[i * hidden_dim + d]
                    i = i + 1
                }
                grad_wq[d] = grad_wq[d] + grad_d
                grad_wk[d] = grad_wk[d] + grad_d
                grad_wv[d] = grad_wv[d] + grad_d
                grad_hidden[base_idx + d] = grad_d
                d = d + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    [][]float result = [][]float{cap: 5}
    result[0] = grad_hidden
    result[1] = grad_wq
    result[2] = grad_wk
    result[3] = grad_wv
    result[4] = grad_wo
    result
}
func transformer_layer_backward(
    []float grad_output,
    []float hidden_states_in,
    []float hidden_states_out,
    layer_norm_state norm1,
    layer_norm_state norm2,
    []float wq,
    []float wk,
    []float wv,
    []float wo,
    []float w_up,
    []float w_down,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_heads,
    int intermediate_dim,
    bool pre_norm
) [][]float {
    []float grad_input = copy_vector(grad_output)
    var ffn_grads = feed_forward_backward(
        grad_output,
        hidden_states_out,
        w_up,
        w_down,
        batch_size,
        seq_len,
        hidden_dim,
        intermediate_dim
    )
    int i = 0
    while i < batch_size * seq_len * hidden_dim {
        grad_input[i] = grad_input[i] + ffn_grads[0][i]
        i = i + 1
    }
    var attn_grads = attention_backward(
        grad_input,
        hidden_states_in,
        wq,
        wk,
        wv,
        wo,
        batch_size,
        seq_len,
        hidden_dim,
        num_heads,
        false
    )
    grad_input = attn_grads[0]
    [][]float result = [][]float{cap: 10}
    result[0] = grad_input
    result[1] = attn_grads[1]
    result[2] = attn_grads[2]
    result[3] = attn_grads[3]
    result[4] = attn_grads[4]
    result[5] = ffn_grads[1]
    result[6] = ffn_grads[2]
    result[7] = ffn_grads[0]
    result[8] = copy_vector(allocate_vector(1, 0.0))
    result[9] = copy_vector(allocate_vector(1, 0.0))
    result
}
func transformer_backward_pass(
    []float loss_gradient,
    [][]float layer_outputs,
    []float token_embedding,
    []float lm_head_weight,
    int num_layers,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_heads,
    int vocab_size
) backward_pass_output {
    []float grad_hidden = copy_vector(loss_gradient)
    [][]float grad_layer_weights = [][]float{cap: num_layers}
    var lm_grads = lm_head_backward(
        grad_hidden,
        layer_outputs[num_layers - 1],
        lm_head_weight,
        batch_size,
        seq_len,
        hidden_dim,
        vocab_size
    )
    grad_hidden = copy_vector(lm_grads[0])
    []float grad_lm_head = copy_vector(lm_grads[1])
    int layer_idx = num_layers - 1
    while layer_idx >= 0 {
        grad_layer_weights[layer_idx] = grad_hidden
        layer_idx = layer_idx - 1
    }
    backward_pass_output {
        grad_input_ids: allocate_vector(batch_size * seq_len, 0.0),
        grad_hidden_states: grad_hidden,
        grad_layer_weights: grad_layer_weights,
        grad_lm_head: grad_lm_head,
        grad_token_embedding: allocate_vector(32000 * hidden_dim, 0.0),
    }
}
