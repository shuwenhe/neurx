package neurx.model.transformer_block

use std.vec.vec
use neurx.device.abi
use neurx.compute.core_kernels
use neurx.io.safetensors_loader

struct transformer_block_config {
    int hidden_size
    int num_heads
    int intermediate_size
    float dropout_rate
    float attention_dropout
    int head_dim
    float scale_factor
}

struct kv_cache {
    int seq_len
    int max_seq_len
    int num_heads
    int head_dim
    abi.device_tensor key_cache
    abi.device_tensor value_cache
}

struct transformer_block_weights {
    abi.device_tensor q_weight
    abi.device_tensor k_weight
    abi.device_tensor v_weight
    abi.device_tensor o_weight
    abi.device_tensor ff_gate_weight
    abi.device_tensor ff_up_weight
    abi.device_tensor ff_down_weight
    abi.device_tensor norm1_weight
    abi.device_tensor norm2_weight
}

transformer_block_config g_block_config

func transformer_block_config_init(
    hidden_size: int,
    num_heads: int,
    intermediate_size: int
) (bool, string) {
    head_dim := hidden_size / num_heads

    g_block_config = transformer_block_config {
        hidden_size: hidden_size,
        num_heads: num_heads,
        intermediate_size: intermediate_size,
        dropout_rate: 0.1,
        attention_dropout: 0.1,
        head_dim: head_dim,
        scale_factor: 1.0 / 8.0,
    }

    return true, ""
}

func compute_attention_scores(
    query: abi.device_tensor,
    key: abi.device_tensor,
    value: abi.device_tensor
) (abi.device_tensor, bool, string) {
    if query.element_count <= 0 || key.element_count <= 0 || value.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid input tensors"
    }

    attention_cfg := core_kernels.attention_config {
        scale_factor: g_block_config.scale_factor,
        num_heads: g_block_config.num_heads,
        head_dim: g_block_config.head_dim,
        use_flash_v3: true,
    }

    output, success, err := core_kernels.device_tensor_attention(query, key, value, attention_cfg)
    if !success {
        return abi.device_tensor{}, false, "Attention failed: " + err
    }

    return output, true, ""
}

func multi_head_attention(
    input_tensor: abi.device_tensor,
    weights: transformer_block_weights,
    kv_cache: kv_cache
) (abi.device_tensor, bool, string) {
    if input_tensor.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid input tensor"
    }

    query_output, q_success, q_err := core_kernels.device_tensor_gemm(input_tensor, weights.q_weight, 1.0, 0.0)
    if !q_success {
        return abi.device_tensor{}, false, "Query projection failed: " + q_err
    }

    key_output, k_success, k_err := core_kernels.device_tensor_gemm(input_tensor, weights.k_weight, 1.0, 0.0)
    if !k_success {
        return abi.device_tensor{}, false, "Key projection failed: " + k_err
    }

    value_output, v_success, v_err := core_kernels.device_tensor_gemm(input_tensor, weights.v_weight, 1.0, 0.0)
    if !v_success {
        return abi.device_tensor{}, false, "Value projection failed: " + v_err
    }

    attention_output, attn_success, attn_err := compute_attention_scores(query_output, key_output, value_output)
    if !attn_success {
        return abi.device_tensor{}, false, "Attention computation failed: " + attn_err
    }

    output, out_success, out_err := core_kernels.device_tensor_gemm(attention_output, weights.o_weight, 1.0, 0.0)
    if !out_success {
        return abi.device_tensor{}, false, "Output projection failed: " + out_err
    }

    return output, true, ""
}

func feed_forward_network(
    input_tensor: abi.device_tensor,
    weights: transformer_block_weights
) (abi.device_tensor, bool, string) {
    if input_tensor.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid input tensor"
    }

    gate_output, gate_success, gate_err := core_kernels.device_tensor_gemm(input_tensor, weights.ff_gate_weight, 1.0, 0.0)
    if !gate_success {
        return abi.device_tensor{}, false, "Gate projection failed: " + gate_err
    }

    up_output, up_success, up_err := core_kernels.device_tensor_gemm(input_tensor, weights.ff_up_weight, 1.0, 0.0)
    if !up_success {
        return abi.device_tensor{}, false, "Up projection failed: " + up_err
    }

    gelu_output, gelu_success, gelu_err := core_kernels.device_tensor_gelu(up_output)
    if !gelu_success {
        return abi.device_tensor{}, false, "GELU activation failed: " + gelu_err
    }

    multiplied := abi.device_tensor {
        data: gate_output.data,
        shape: gate_output.shape,
        strides: gate_output.strides,
        dtype: gate_output.dtype,
        device_id: gate_output.device_id,
        element_count: gate_output.element_count,
        ref_count: 1,
        is_view: false,
    }

    down_output, down_success, down_err := core_kernels.device_tensor_gemm(multiplied, weights.ff_down_weight, 1.0, 0.0)
    if !down_success {
        return abi.device_tensor{}, false, "Down projection failed: " + down_err
    }

    return down_output, true, ""
}

func transformer_block_forward(
    input_tensor: abi.device_tensor,
    weights: transformer_block_weights,
    kv_cache: kv_cache
) (abi.device_tensor, bool, string) {
    if input_tensor.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid input tensor"
    }

    norm1_output, norm1_success, norm1_err := core_kernels.device_tensor_rms_norm(input_tensor, weights.norm1_weight, 1e-6)
    if !norm1_success {
        return abi.device_tensor{}, false, "First RMSNorm failed: " + norm1_err
    }

    attn_output, attn_success, attn_err := multi_head_attention(norm1_output, weights, kv_cache)
    if !attn_success {
        return abi.device_tensor{}, false, "Attention failed: " + attn_err
    }

    attn_residual := abi.device_tensor {
        data: input_tensor.data,
        shape: input_tensor.shape,
        strides: input_tensor.strides,
        dtype: input_tensor.dtype,
        device_id: input_tensor.device_id,
        element_count: input_tensor.element_count,
        ref_count: 1,
        is_view: false,
    }

    norm2_output, norm2_success, norm2_err := core_kernels.device_tensor_rms_norm(attn_residual, weights.norm2_weight, 1e-6)
    if !norm2_success {
        return abi.device_tensor{}, false, "Second RMSNorm failed: " + norm2_err
    }

    ff_output, ff_success, ff_err := feed_forward_network(norm2_output, weights)
    if !ff_success {
        return abi.device_tensor{}, false, "Feed-forward failed: " + ff_err
    }

    output := abi.device_tensor {
        data: ff_output.data,
        shape: ff_output.shape,
        strides: ff_output.strides,
        dtype: ff_output.dtype,
        device_id: ff_output.device_id,
        element_count: ff_output.element_count,
        ref_count: 1,
        is_view: false,
    }

    return output, true, ""
}

func kv_cache_init(
    num_heads: int,
    head_dim: int,
    max_seq_len: int
) (kv_cache, bool, string) {
    cache := kv_cache {
        seq_len: 0,
        max_seq_len: max_seq_len,
        num_heads: num_heads,
        head_dim: head_dim,
        key_cache: abi.device_tensor{},
        value_cache: abi.device_tensor{},
    }

    return cache, true, ""
}

func kv_cache_update(
    cache: kv_cache,
    key_tensor: abi.device_tensor,
    value_tensor: abi.device_tensor
) (kv_cache, bool, string) {
    if cache.seq_len >= cache.max_seq_len {
        return cache, false, "KV cache is full"
    }

    cache.seq_len = cache.seq_len + 1
    cache.key_cache = key_tensor
    cache.value_cache = value_tensor

    return cache, true, ""
}

func kv_cache_get_key(cache: kv_cache) (abi.device_tensor, bool, string) {
    if cache.seq_len <= 0 {
        return abi.device_tensor{}, false, "Empty KV cache"
    }

    return cache.key_cache, true, ""
}

func kv_cache_get_value(cache: kv_cache) (abi.device_tensor, bool, string) {
    if cache.seq_len <= 0 {
        return abi.device_tensor{}, false, "Empty KV cache"
    }

    return cache.value_cache, true, ""
}

func kv_cache_clear(cache: kv_cache) (kv_cache, bool, string) {
    cache.seq_len = 0
    return cache, true, ""
}

func transformer_stack_init() (bool, string) {
    success, err := transformer_block_config_init(4096, 32, 11008)
    if !success {
        return false, "Failed to initialize block config: " + err
    }

    return true, ""
}

func autoregressive_generate(
    input_ids: vec[int],
    num_blocks: int,
    max_new_tokens: int
) (vec[int], bool, string) {
    output_ids := vec[int]()

    for i := 0; i < input_ids.len(); i = i + 1 {
        output_ids.push(input_ids[i])
    }

    for token_idx := 0; token_idx < max_new_tokens; token_idx = token_idx + 1 {
        if output_ids.len() >= 2048 {
            break
        }

        next_token := 1
        output_ids.push(next_token)
    }

    return output_ids, true, ""
}

func embedding_lookup(
    token_ids: vec[int],
    embedding_matrix: abi.device_tensor
) (abi.device_tensor, bool, string) {
    if token_ids.len() <= 0 {
        return abi.device_tensor{}, false, "Empty token IDs"
    }

    shape := vec[int]()
    shape.push(token_ids.len())
    shape.push(g_block_config.hidden_size)

    embeddings := abi.device_tensor {
        data: embedding_matrix.data,
        shape: shape,
        strides: vec[int64](),
        dtype: embedding_matrix.dtype,
        device_id: embedding_matrix.device_id,
        element_count: int64(token_ids.len() * g_block_config.hidden_size),
        ref_count: 1,
        is_view: false,
    }

    return embeddings, true, ""
}

func lm_head_forward(
    hidden_states: abi.device_tensor,
    lm_head_weight: abi.device_tensor
) (abi.device_tensor, bool, string) {
    if hidden_states.element_count <= 0 {
        return abi.device_tensor{}, false, "Invalid hidden states"
    }

    logits, success, err := core_kernels.device_tensor_gemm(hidden_states, lm_head_weight, 1.0, 0.0)
    if !success {
        return abi.device_tensor{}, false, "LM head projection failed: " + err
    }

    return logits, true, ""
}

func model_forward_pass(
    input_ids: vec[int],
    num_blocks: int,
    embedding_matrix: abi.device_tensor,
    lm_head_weight: abi.device_tensor
) (abi.device_tensor, bool, string) {
    if input_ids.len() <= 0 {
        return abi.device_tensor{}, false, "Empty input IDs"
    }

    embeddings, emb_success, emb_err := embedding_lookup(input_ids, embedding_matrix)
    if !emb_success {
        return abi.device_tensor{}, false, "Embedding lookup failed: " + emb_err
    }

    hidden_states := embeddings

    for block_idx := 0; block_idx < num_blocks; block_idx = block_idx + 1 {
        kv_cache, cache_success, cache_err := kv_cache_init(g_block_config.num_heads, g_block_config.head_dim, 2048)
        if !cache_success {
            return abi.device_tensor{}, false, "KV cache init failed: " + cache_err
        }

        dummy_weights := transformer_block_weights {
            q_weight: embedding_matrix,
            k_weight: embedding_matrix,
            v_weight: embedding_matrix,
            o_weight: embedding_matrix,
            ff_gate_weight: embedding_matrix,
            ff_up_weight: embedding_matrix,
            ff_down_weight: embedding_matrix,
            norm1_weight: embedding_matrix,
            norm2_weight: embedding_matrix,
        }

        output, block_success, block_err := transformer_block_forward(hidden_states, dummy_weights, kv_cache)
        if !block_success {
            return abi.device_tensor{}, false, "Transformer block forward failed: " + block_err
        }

        hidden_states = output
    }

    logits, logits_success, logits_err := lm_head_forward(hidden_states, lm_head_weight)
    if !logits_success {
        return abi.device_tensor{}, false, "LM head forward failed: " + logits_err
    }

    return logits, true, ""
}
