package neurx.model.transformer.transformer_forward
use neurx.model.transformer.layer_norm.{
    layer_norm_config,
    layer_norm_state,
    rms_norm_state,
    new_layer_norm,
    new_rms_norm,
    layer_normalize,
    rms_normalize
}
use neurx.model.transformer.position_encoding.{
    position_encoding_config,
    absolute_position_encoding,
    learned_position_encoding,
    rope_position_encoding,
    new_absolute_position_encoding,
    new_learned_position_encoding,
    new_rope_position_encoding,
    get_position_encoding,
    get_learned_position_encoding,
    apply_rope_position,
    add_position_encoding_to_hidden
}

struct transformer_forward_config {
    int vocab_size
    int hidden_dim
    int num_layers
    int num_heads
    int max_seq_len
    int intermediate_dim
    float attention_dropout
    float ffn_dropout
    string position_encoding_type
    bool use_causal_mask
    bool pre_norm
}

struct transformer_layer_state {
    float[] wq
    float[] wk
    float[] wv
    float[] wo
    float[] query_bias
    float[] key_bias
    float[] value_bias
    float[] output_bias
    float[] w_up
    float[] w_down
    float[] up_bias
    float[] down_bias
    layer_norm_state norm1
    layer_norm_state norm2
}

struct transformer_forward_state {
    int vocab_size
    int hidden_dim
    int num_layers
    int num_heads
    int head_dim
    int intermediate_dim
    float[] token_embedding
    float[] lm_head_weight
    []transformer_layer_state layers
    layer_norm_state final_norm
    absolute_position_encoding pos_encoding_abs
    learned_position_encoding pos_encoding_learned
    rope_position_encoding pos_encoding_rope
    transformer_forward_config config
}

struct forward_pass_output {
    float[] logits
    float[] hidden_states
    float[] layer_outputs
}

struct forward_pass_cache {
    float[][] attention_scores
    float[][] ffn_outputs
    float[][] layer_norms
}

func write_slice(float[] dst, int dst_offset, float[] src) {
    int i = 0
    for i < len(src) {
        dst[dst_offset + i] = src[i]
        i = i + 1
    }
}

func apply_rope_batch(
    rope_position_encoding rope_encoding,
    float[] q,
    float[] k,
    int batch_size,
    int seq_len,
    int hidden_dim
) float[][] {
    float[] q_out = copy_vector(q)
    float[] k_out = copy_vector(k)
    int b = 0
    for b < batch_size {
        int offset = b * seq_len * hidden_dim
        float[] q_slice = allocate_vector(seq_len * hidden_dim, 0.0)
        float[] k_slice = allocate_vector(seq_len * hidden_dim, 0.0)
        int i = 0
        for i < seq_len * hidden_dim {
            q_slice[i] = q_out[offset + i]
            k_slice[i] = k_out[offset + i]
            i = i + 1
        }
        float[][] rope_applied = apply_rope_position(rope_encoding, q_slice, k_slice, seq_len, 0)
        i = 0
        for i < seq_len * hidden_dim {
            q_out[offset + i] = rope_applied[0][i]
            k_out[offset + i] = rope_applied[1][i]
            i = i + 1
        }
        b = b + 1
    }
    float[][] result = floatmake([][], 2)
    result[0] = q_out
    result[1] = k_out
    result
}

func allocate_vector(int size, float init_val) []float {
    float[] v = make([]float, size)
    int i = 0
    for i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func copy_vector(float[] src) []float {
    float[] out = allocate_vector(len(src), 0.0)
    int i = 0
    for i < len(src) {
        out[i] = src[i]
        i = i + 1
    }
    out
}

func transformer_layer_at([]transformer_layer_state layers, int index) transformer_layer_state {
    int i = 0
    transformer_layer_state out = layers[0]
    for i < len(layers) {
        if i == index {
            out = layers[i]
            i = len(layers)
        }
        i = i + 1
    }
    out
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    float y = x
    int i = 0
    for i < 10 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    for i <= 12 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func softmax(float[] scores, int seq_len) []float {
    float[] output = copy_vector(scores)
    float max_score = scores[0]
    int i = 1
    for i < seq_len {
        if scores[i] > max_score {
            max_score = scores[i]
        }
        i = i + 1
    }
    float sum_exp = 0.0
    i = 0
    for i < seq_len {
        output[i] = exp_approx(scores[i] - max_score)
        sum_exp = sum_exp + output[i]
        i = i + 1
    }
    i = 0
    for i < seq_len {
        output[i] = output[i] / sum_exp
        i = i + 1
    }
    output
}

func gelu(float x) float {
    float pi = 3.141592653589793
    float sqrt_2_over_pi = sqrt_approx(2.0 / pi)
    float cdf = 0.5 * (1.0 + sqrt_2_over_pi * (x + 0.044715 * x * x * x))
    x * cdf
}

func project_rows(
    float[] input,
    float[] weight,
    float[] bias,
    int token_count,
    int in_dim,
    int out_dim
) []float {
    float[] output = allocate_vector(token_count * out_dim, 0.0)
    int token = 0
    for token < token_count {
        int input_base = token * in_dim
        int output_base = token * out_dim
        int o = 0
        for o < out_dim {
            float sum = 0.0
            if len(bias) > o {
                sum = bias[o]
            }
            int i = 0
            for i < in_dim {
                sum = sum + input[input_base + i] * weight[o * in_dim + i]
                i = i + 1
            }
            output[output_base + o] = sum
            o = o + 1
        }
        token = token + 1
    }
    output
}

func embed_tokens(
    float[] token_embedding,
    int[] token_ids,
    int batch_size,
    int seq_len,
    int hidden_dim
) []float {
    float[] output = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int token_id = token_ids[b * seq_len + s]
            if token_id >= 0 && token_id < 32000 {
                int src_base = token_id * hidden_dim
                int dst_base = (b * seq_len + s) * hidden_dim
                int d = 0
                for d < hidden_dim {
                    output[dst_base + d] = token_embedding[src_base + d]
                    d = d + 1
                }
            }
            s = s + 1
        }
        b = b + 1
    }
    output
}

func multi_head_attention_forward(
    transformer_layer_state layer,
    float[] hidden_states,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_heads,
    bool use_causal_mask,
    bool use_rope,
    rope_position_encoding rope_encoding
) []float {
    int head_dim = hidden_dim / num_heads
    int token_count = batch_size * seq_len
    if head_dim <= 0 || token_count <= 0 {
        return copy_vector(hidden_states)
    }
    float[] q = project_rows(hidden_states, layer.wq, layer.query_bias, token_count, hidden_dim, hidden_dim)
    float[] k = project_rows(hidden_states, layer.wk, layer.key_bias, token_count, hidden_dim, hidden_dim)
    float[] v = project_rows(hidden_states, layer.wv, layer.value_bias, token_count, hidden_dim, hidden_dim)
    if use_rope {
        float[][] rope_applied = apply_rope_batch(rope_encoding, q, k, batch_size, seq_len, hidden_dim)
        q = rope_applied[0]
        k = rope_applied[1]
    }
    float[] context = allocate_vector(token_count * hidden_dim, 0.0)
    float[] output = allocate_vector(token_count * hidden_dim, 0.0)
    float scale = 1.0 / sqrt_approx(head_dim * 1.0)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int token_idx = b * seq_len + s
            int q_base = token_idx * hidden_dim
            int h = 0
            for h < num_heads {
                int head_offset = h * head_dim
                float[] scores = allocate_vector(seq_len, -1.0e9)
                int t = 0
                for t < seq_len {
                    if !use_causal_mask || t <= s {
                        int key_token_idx = b * seq_len + t
                        int k_base = key_token_idx * hidden_dim + head_offset
                        float score = 0.0
                        int d = 0
                        for d < head_dim {
                            score = score + q[q_base + head_offset + d] * k[k_base + d]
                            d = d + 1
                        }
                        scores[t] = score * scale
                    }
                    t = t + 1
                }
                float[] probs = softmax(scores, seq_len)
                int d = 0
                for d < head_dim {
                    float acc = 0.0
                    int t2 = 0
                    for t2 < seq_len {
                        if !use_causal_mask || t2 <= s {
                            int value_token_idx = b * seq_len + t2
                            int v_base = value_token_idx * hidden_dim + head_offset
                            acc = acc + probs[t2] * v[v_base + d]
                        }
                        t2 = t2 + 1
                    }
                    context[q_base + head_offset + d] = acc
                    d = d + 1
                }
                h = h + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    output = project_rows(context, layer.wo, layer.output_bias, token_count, hidden_dim, hidden_dim)
    output
}

func feed_forward_forward(
    transformer_layer_state layer,
    float[] hidden_states,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int intermediate_dim
) []float {
    float[] output = allocate_vector(batch_size * seq_len * hidden_dim, 0.0)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int base_idx = (b * seq_len + s) * hidden_dim
            int i = 0
            for i < intermediate_dim {
                float val = 0.0
                int d = 0
                for d < hidden_dim {
                    val = val + hidden_states[base_idx + d] * layer.w_up[i * hidden_dim + d]
                    d = d + 1
                }
                if i < intermediate_dim {
                    val = gelu(val)
                }
                int out_d = i % hidden_dim
                output[base_idx + out_d] = output[base_idx + out_d] + val * layer.w_down[out_d * intermediate_dim + i] / (intermediate_dim * 1.0)
                i = i + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    output
}

func transformer_layer_forward(
    transformer_layer_state layer,
    float[] hidden_states,
    int batch_size,
    int seq_len,
    int hidden_dim,
    int num_heads,
    int intermediate_dim,
    bool use_causal_mask,
    bool pre_norm,
    bool use_rope,
    rope_position_encoding rope_encoding
) []float {
    float[] output = copy_vector(hidden_states)
    if pre_norm {
        normalized := layer_normalize(layer.norm1, hidden_states, batch_size, seq_len)
        attn_output := multi_head_attention_forward(
            layer,
            normalized.normalized,
            batch_size,
            seq_len,
            hidden_dim,
            num_heads,
            use_causal_mask,
            use_rope,
            rope_encoding
        )
        int i = 0
        for i < batch_size * seq_len * hidden_dim {
            output[i] = hidden_states[i] + attn_output[i]
            i = i + 1
        }
        normalized = layer_normalize(layer.norm2, output, batch_size, seq_len)
        ffn_output := feed_forward_forward(
            layer,
            normalized.normalized,
            batch_size,
            seq_len,
            hidden_dim,
            intermediate_dim
        )
        i = 0
        for i < batch_size * seq_len * hidden_dim {
            output[i] = output[i] + ffn_output[i]
            i = i + 1
        }
    } else {
        attn_output := multi_head_attention_forward(
            layer,
            hidden_states,
            batch_size,
            seq_len,
            hidden_dim,
            num_heads,
            use_causal_mask,
            use_rope,
            rope_encoding
        )
        int i = 0
        for i < batch_size * seq_len * hidden_dim {
            output[i] = hidden_states[i] + attn_output[i]
            i = i + 1
        }
        normalized := layer_normalize(layer.norm1, output, batch_size, seq_len)
        output = copy_vector(normalized.normalized)
        ffn_output := feed_forward_forward(
            layer,
            output,
            batch_size,
            seq_len,
            hidden_dim,
            intermediate_dim
        )
        i = 0
        for i < batch_size * seq_len * hidden_dim {
            output[i] = output[i] + ffn_output[i]
            i = i + 1
        }
        normalized = layer_normalize(layer.norm2, output, batch_size, seq_len)
        output = copy_vector(normalized.normalized)
    }
    output
}

func transformer_forward_pass(
    transformer_forward_state model_state,
    int[] input_ids,
    int batch_size,
    int seq_len
) forward_pass_output {
    int hidden_dim = model_state.hidden_dim
    int num_layers = model_state.num_layers
    hidden_states := embed_tokens(
        model_state.token_embedding,
        input_ids,
        batch_size,
        seq_len,
        hidden_dim
    )
    bool use_rope = model_state.config.position_encoding_type == "rope"
    if !use_rope {
        pos_encoding := get_position_encoding(
            model_state.pos_encoding_abs,
            0,
            seq_len
        )
        hidden_states = add_position_encoding_to_hidden(
            hidden_states,
            pos_encoding,
            batch_size,
            seq_len,
            hidden_dim
        )
    }
    float[] layer_outputs = allocate_vector(num_layers * 2 * batch_size * seq_len * hidden_dim, 0.0)
    int layer_output_offset = 0
    int layer_idx = 0
    for layer_idx < num_layers {
        transformer_layer_state layer = transformer_layer_at(model_state.layers, layer_idx)
        write_slice(layer_outputs, layer_output_offset, hidden_states)
        hidden_states = transformer_layer_forward(
            layer,
            hidden_states,
            batch_size,
            seq_len,
            hidden_dim,
            model_state.num_heads,
            model_state.intermediate_dim,
            model_state.config.use_causal_mask,
            model_state.config.pre_norm,
            use_rope,
            model_state.pos_encoding_rope
        )
        layer_output_offset = layer_output_offset + batch_size * seq_len * hidden_dim
        write_slice(layer_outputs, layer_output_offset, hidden_states)
        layer_output_offset = layer_output_offset + batch_size * seq_len * hidden_dim
        layer_idx = layer_idx + 1
    }
    final_norm_output := layer_normalize(
        model_state.final_norm,
        hidden_states,
        batch_size,
        seq_len
    )
    hidden_states = copy_vector(final_norm_output.normalized)
    float[] logits = allocate_vector(batch_size * seq_len * model_state.vocab_size, 0.0)
    int b = 0
    for b < batch_size {
        int s = 0
        for s < seq_len {
            int src_idx = (b * seq_len + s) * hidden_dim
            int dst_idx = (b * seq_len + s) * model_state.vocab_size
            int v = 0
            for v < model_state.vocab_size {
                float val = 0.0
                int d = 0
                for d < hidden_dim {
                    val = val + hidden_states[src_idx + d] * model_state.lm_head_weight[v * hidden_dim + d]
                    d = d + 1
                }
                logits[dst_idx + v] = val
                v = v + 1
            }
            s = s + 1
        }
        b = b + 1
    }
    forward_pass_output {
        logits: logits,
        hidden_states: hidden_states,
        layer_outputs: layer_outputs,
    }
}
