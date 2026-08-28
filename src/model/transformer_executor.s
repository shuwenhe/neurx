package neurx.model.transformer_executor
use neurx.device.abi
use neurx.device.tensor_manager
struct transformer_config {
    int hidden_size
    int num_attention_heads
    int num_layers
    int vocab_size
    int max_seq_length
    float attention_dropout
    bool use_flash_attention
}
struct transformer_weights {
    device_tensor[] embed_weight
    device_tensor[] ln_weight
    device_tensor[] ln_bias
    device_tensor[] q_weight
    device_tensor[] q_bias
    device_tensor[] k_weight
    device_tensor[] k_bias
    device_tensor[] v_weight
    device_tensor[] v_bias
    device_tensor[] o_weight
    device_tensor[] o_bias
    device_tensor[] mlp_gate_weight
    device_tensor[] mlp_gate_bias
    device_tensor[] mlp_up_weight
    device_tensor[] mlp_up_bias
    device_tensor[] mlp_down_weight
    device_tensor[] mlp_down_bias
    device_tensor final_ln_weight
    device_tensor lm_head_weight
}
struct transformer_executor {
    int device_id
    transformer_config config
    transformer_weights* weights
    device_tensor_manager* tensor_mgr
    stream_handle compute_stream
}
func create_transformer_executor(
    int device_id,
    transformer_config config,
    device_tensor_manager* tensor_mgr,
    stream_handle stream
) (transformer_executor, bool, string) {
    executor := transformer_executor {
        device_id: device_id,
        config: config,
        weights: 0,
        tensor_mgr: tensor_mgr,
        compute_stream: stream,
    }
    return executor, true, ""
}
func (transformer_executor* exec) allocate_weights() (bool, string) {
    head_dim := exec.config.hidden_size / exec.config.num_attention_heads
    config_shape := new int[2]
    config_shape[0] = exec.config.vocab_size
    config_shape[1] = exec.config.hidden_size
    embed_t, embed_ok, embed_err := exec.tensor_mgr.allocate_tensor(config_shape, 0)
    if !embed_ok {
        return false, embed_err
    }
    ln_shape := new int[1]
    ln_shape[0] = exec.config.hidden_size
    ln_t, ln_ok, ln_err := exec.tensor_mgr.allocate_tensor(ln_shape, 0)
    if !ln_ok {
        exec.tensor_mgr.free_tensor(&embed_t)
        return false, ln_err
    }
    qkv_shape := new int[2]
    qkv_shape[0] = exec.config.hidden_size
    qkv_shape[1] = exec.config.hidden_size
    q_t, q_ok, q_err := exec.tensor_mgr.allocate_tensor(qkv_shape, 0)
    if !q_ok {
        exec.tensor_mgr.free_tensor(&embed_t)
        exec.tensor_mgr.free_tensor(&ln_t)
        return false, q_err
    }
    return true, ""
}
func (transformer_executor* exec) embedding(
    device_tensor token_ids,
    device_tensor* output
) (bool, string) {
    if exec.weights == 0 {
        return false, "Weights not loaded"
    }
    embed_weight := exec.weights.embed_weight[0]
    return device_embedding(token_ids, embed_weight, output, exec.compute_stream)
}
func (transformer_executor* exec) rms_norm(
    device_tensor input,
    device_tensor weight,
    device_tensor* output,
    float epsilon
) (bool, string) {
    return device_rms_norm(input, weight, output, epsilon, exec.compute_stream)
}
func (transformer_executor* exec) linear_projection(
    device_tensor input,
    device_tensor weight,
    device_tensor* output
) (bool, string) {
    return device_matmul(input, weight, output, 1.0, 0.0, exec.compute_stream)
}
func (transformer_executor* exec) attention_forward(
    device_tensor q,
    device_tensor k,
    device_tensor v,
    device_tensor* output
) (bool, string) {
    if exec.config.use_flash_attention {
        return device_flash_attention_v3(q, k, v, output, exec.config.attention_dropout, true, exec.compute_stream)
    } else {
        return device_attention(q, k, v, output, exec.compute_stream)
    }
}
func (transformer_executor* exec) mlp_forward(
    device_tensor input,
    device_tensor gate_weight,
    device_tensor up_weight,
    device_tensor down_weight,
    device_tensor* output
) (bool, string) {
    batch_size := input.shape[0]
    hidden_size := input.shape[1]
    ffn_size := gate_weight.shape[1]
    gate_output_shape := new int[2]
    gate_output_shape[0] = batch_size
    gate_output_shape[1] = ffn_size
    gate_out, gate_ok, gate_err := exec.tensor_mgr.allocate_tensor(gate_output_shape, 0)
    if !gate_ok {
        return false, gate_err
    }
    gate_success, gate_err2 := exec.linear_projection(input, gate_weight, &gate_out)
    if !gate_success {
        exec.tensor_mgr.free_tensor(&gate_out)
        return false, gate_err2
    }
    gate_activated_shape := new int[2]
    gate_activated_shape[0] = batch_size
    gate_activated_shape[1] = ffn_size
    gate_act, gate_act_ok, gate_act_err := exec.tensor_mgr.allocate_tensor(gate_activated_shape, 0)
    if !gate_act_ok {
        exec.tensor_mgr.free_tensor(&gate_out)
        return false, gate_act_err
    }
    gate_silu_ok, gate_silu_err := device_silu(gate_out, &gate_act, exec.compute_stream)
    if !gate_silu_ok {
        exec.tensor_mgr.free_tensor(&gate_out)
        exec.tensor_mgr.free_tensor(&gate_act)
        return false, gate_silu_err
    }
    up_output_shape := new int[2]
    up_output_shape[0] = batch_size
    up_output_shape[1] = ffn_size
    up_out, up_ok, up_err := exec.tensor_mgr.allocate_tensor(up_output_shape, 0)
    if !up_ok {
        exec.tensor_mgr.free_tensor(&gate_out)
        exec.tensor_mgr.free_tensor(&gate_act)
        return false, up_err
    }
    up_success, up_err2 := exec.linear_projection(input, up_weight, &up_out)
    if !up_success {
        exec.tensor_mgr.free_tensor(&gate_out)
        exec.tensor_mgr.free_tensor(&gate_act)
        exec.tensor_mgr.free_tensor(&up_out)
        return false, up_err2
    }
    product_shape := new int[2]
    product_shape[0] = batch_size
    product_shape[1] = ffn_size
    product, product_ok, product_err := exec.tensor_mgr.allocate_tensor(product_shape, 0)
    if !product_ok {
        exec.tensor_mgr.free_tensor(&gate_out)
        exec.tensor_mgr.free_tensor(&gate_act)
        exec.tensor_mgr.free_tensor(&up_out)
        return false, product_err
    }
    final_success, final_err := exec.linear_projection(product, down_weight, output)
    exec.tensor_mgr.free_tensor(&gate_out)
    exec.tensor_mgr.free_tensor(&gate_act)
    exec.tensor_mgr.free_tensor(&up_out)
    exec.tensor_mgr.free_tensor(&product)
    return final_success, final_err
}
func (transformer_executor* exec) decoder_layer_forward(
    device_tensor input,
    int layer_idx,
    device_tensor* output
) (bool, string) {
    if layer_idx < 0 || layer_idx >= exec.config.num_layers {
        return false, "Invalid layer index"
    }
    batch_size := input.shape[0]
    seq_len := input.shape[1]
    hidden_size := input.shape[2]
    ln_shape := new int[3]
    ln_shape[0] = batch_size
    ln_shape[1] = seq_len
    ln_shape[2] = hidden_size
    ln_out, ln_ok, ln_err := exec.tensor_mgr.allocate_tensor(ln_shape, 0)
    if !ln_ok {
        return false, ln_err
    }
    ln_weight := exec.weights.ln_weight[layer_idx]
    ln_success, ln_err2 := exec.rms_norm(input, ln_weight, &ln_out, 1e-5)
    if !ln_success {
        exec.tensor_mgr.free_tensor(&ln_out)
        return false, ln_err2
    }
    head_dim := hidden_size / exec.config.num_attention_heads
    q_shape := new int[4]
    q_shape[0] = batch_size
    q_shape[1] = exec.config.num_attention_heads
    q_shape[2] = seq_len
    q_shape[3] = head_dim
    q, q_ok, q_err := exec.tensor_mgr.allocate_tensor(q_shape, 0)
    if !q_ok {
        exec.tensor_mgr.free_tensor(&ln_out)
        return false, q_err
    }
    q_weight := exec.weights.q_weight[layer_idx]
    q_success, q_err2 := exec.linear_projection(ln_out, q_weight, &q)
    if !q_success {
        exec.tensor_mgr.free_tensor(&ln_out)
        exec.tensor_mgr.free_tensor(&q)
        return false, q_err2
    }
    k, k_ok, k_err := exec.tensor_mgr.allocate_tensor(q_shape, 0)
    if !k_ok {
        exec.tensor_mgr.free_tensor(&ln_out)
        exec.tensor_mgr.free_tensor(&q)
        return false, k_err
    }
    k_weight := exec.weights.k_weight[layer_idx]
    k_success, k_err2 := exec.linear_projection(ln_out, k_weight, &k)
    if !k_success {
        exec.tensor_mgr.free_tensor(&ln_out)
        exec.tensor_mgr.free_tensor(&q)
        exec.tensor_mgr.free_tensor(&k)
        return false, k_err2
    }
    v, v_ok, v_err := exec.tensor_mgr.allocate_tensor(q_shape, 0)
    if !v_ok {
        exec.tensor_mgr.free_tensor(&ln_out)
        exec.tensor_mgr.free_tensor(&q)
        exec.tensor_mgr.free_tensor(&k)
        return false, v_err
    }
    v_weight := exec.weights.v_weight[layer_idx]
    v_success, v_err2 := exec.linear_projection(ln_out, v_weight, &v)
    if !v_success {
        exec.tensor_mgr.free_tensor(&ln_out)
        exec.tensor_mgr.free_tensor(&q)
        exec.tensor_mgr.free_tensor(&k)
        exec.tensor_mgr.free_tensor(&v)
        return false, v_err2
    }
    attn_out_shape := new int[4]
    attn_out_shape[0] = batch_size
    attn_out_shape[1] = exec.config.num_attention_heads
    attn_out_shape[2] = seq_len
    attn_out_shape[3] = head_dim
    attn_out, attn_ok, attn_err := exec.tensor_mgr.allocate_tensor(attn_out_shape, 0)
    if !attn_ok {
        exec.tensor_mgr.free_tensor(&ln_out)
        exec.tensor_mgr.free_tensor(&q)
        exec.tensor_mgr.free_tensor(&k)
        exec.tensor_mgr.free_tensor(&v)
        return false, attn_err
    }
    attn_success, attn_err2 := exec.attention_forward(q, k, v, &attn_out)
    if !attn_success {
        exec.tensor_mgr.free_tensor(&ln_out)
        exec.tensor_mgr.free_tensor(&q)
        exec.tensor_mgr.free_tensor(&k)
        exec.tensor_mgr.free_tensor(&v)
        exec.tensor_mgr.free_tensor(&attn_out)
        return false, attn_err2
    }
    final_shape := new int[3]
    final_shape[0] = batch_size
    final_shape[1] = seq_len
    final_shape[2] = hidden_size
    final_out, final_ok, final_err := exec.tensor_mgr.allocate_tensor(final_shape, 0)
    if !final_ok {
        exec.tensor_mgr.free_tensor(&ln_out)
        exec.tensor_mgr.free_tensor(&q)
        exec.tensor_mgr.free_tensor(&k)
        exec.tensor_mgr.free_tensor(&v)
        exec.tensor_mgr.free_tensor(&attn_out)
        return false, final_err
    }
    o_weight := exec.weights.o_weight[layer_idx]
    final_success, final_err2 := exec.linear_projection(attn_out, o_weight, &final_out)
    if !final_success {
        exec.tensor_mgr.free_tensor(&ln_out)
        exec.tensor_mgr.free_tensor(&q)
        exec.tensor_mgr.free_tensor(&k)
        exec.tensor_mgr.free_tensor(&v)
        exec.tensor_mgr.free_tensor(&attn_out)
        exec.tensor_mgr.free_tensor(&final_out)
        return false, final_err2
    }
    exec.tensor_mgr.free_tensor(&ln_out)
    exec.tensor_mgr.free_tensor(&q)
    exec.tensor_mgr.free_tensor(&k)
    exec.tensor_mgr.free_tensor(&v)
    exec.tensor_mgr.free_tensor(&attn_out)
    exec.tensor_mgr.free_tensor(&final_out)
    return true, ""
}
func (transformer_executor* exec) forward(
    device_tensor token_ids,
    device_tensor* logits
) (bool, string) {
    batch_size := token_ids.shape[0]
    seq_len := token_ids.shape[1]
    hidden_size := exec.config.hidden_size
    embed_shape := new int[3]
    embed_shape[0] = batch_size
    embed_shape[1] = seq_len
    embed_shape[2] = hidden_size
    x, x_ok, x_err := exec.tensor_mgr.allocate_tensor(embed_shape, 0)
    if !x_ok {
        return false, x_err
    }
    embed_ok, embed_err := exec.embedding(token_ids, &x)
    if !embed_ok {
        exec.tensor_mgr.free_tensor(&x)
        return false, embed_err
    }
    int layer_idx = 0
    for layer_idx < exec.config.num_layers {
        layer_out, layer_ok, layer_err := exec.tensor_mgr.allocate_tensor(embed_shape, 0)
        if !layer_ok {
            exec.tensor_mgr.free_tensor(&x)
            return false, layer_err
        }
        layer_success, layer_err2 := exec.decoder_layer_forward(x, layer_idx, &layer_out)
        if !layer_success {
            exec.tensor_mgr.free_tensor(&x)
            exec.tensor_mgr.free_tensor(&layer_out)
            return false, layer_err2
        }
        exec.tensor_mgr.free_tensor(&x)
        x = layer_out
        layer_idx = layer_idx + 1
    }
    ln_shape := new int[3]
    ln_shape[0] = batch_size
    ln_shape[1] = seq_len
    ln_shape[2] = hidden_size
    final_ln, final_ln_ok, final_ln_err := exec.tensor_mgr.allocate_tensor(ln_shape, 0)
    if !final_ln_ok {
        exec.tensor_mgr.free_tensor(&x)
        return false, final_ln_err
    }
    ln_ok, ln_err := exec.rms_norm(x, exec.weights.final_ln_weight, &final_ln, 1e-5)
    if !ln_ok {
        exec.tensor_mgr.free_tensor(&x)
        exec.tensor_mgr.free_tensor(&final_ln)
        return false, ln_err
    }
    logits_shape := new int[3]
    logits_shape[0] = batch_size
    logits_shape[1] = seq_len
    logits_shape[2] = exec.config.vocab_size
    head_ok, head_err := exec.linear_projection(final_ln, exec.weights.lm_head_weight, logits)
    exec.tensor_mgr.free_tensor(&x)
    exec.tensor_mgr.free_tensor(&final_ln)
    return head_ok, head_err
}
func (transformer_executor* exec) destroy() (bool, string) {
    return true, ""
}
