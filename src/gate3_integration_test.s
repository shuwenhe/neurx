package neurx.model

use neurx.model.transformer_block
use neurx.device.abi

func test_transformer_block_config() (int, int, string) {
    passed := 0
    failed := 0

    success, err := transformer_block.transformer_block_config_init(4096, 32, 11008)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    passed = passed + 1
    return passed, failed, "test_transformer_block_config passed"
}

func test_kv_cache_operations() (int, int, string) {
    passed := 0
    failed := 0

    cache, cache_success, cache_err := transformer_block.kv_cache_init(32, 128, 2048)
    if !cache_success {
        failed = failed + 1
        return passed, failed, "Failed to init cache: " + cache_err
    }

    if cache.seq_len != 0 {
        failed = failed + 1
        return passed, failed, "Initial seq_len should be 0"
    }

    key_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 4096,
        ref_count: 1,
        is_view: false,
    }

    value_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: 4096,
        ref_count: 1,
        is_view: false,
    }

    updated_cache, update_success, update_err := transformer_block.kv_cache_update(cache, key_tensor, value_tensor)
    if !update_success {
        failed = failed + 1
        return passed, failed, "Failed to update cache: " + update_err
    }

    if updated_cache.seq_len != 1 {
        failed = failed + 1
        return passed, failed, "seq_len should be 1 after update"
    }

    cleared_cache, clear_success, clear_err := transformer_block.kv_cache_clear(updated_cache)
    if !clear_success {
        failed = failed + 1
        return passed, failed, "Failed to clear cache: " + clear_err
    }

    if cleared_cache.seq_len != 0 {
        failed = failed + 1
        return passed, failed, "seq_len should be 0 after clear"
    }

    passed = passed + 1
    return passed, failed, "test_kv_cache_operations passed"
}

func test_embedding_lookup() (int, int, string) {
    passed := 0
    failed := 0

    token_ids := vec[int]()
    token_ids.push(1)
    token_ids.push(2)
    token_ids.push(3)

    embedding_matrix := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(32000 * 4096),
        ref_count: 1,
        is_view: false,
    }

    embeddings, emb_success, emb_err := transformer_block.embedding_lookup(token_ids, embedding_matrix)
    if !emb_success {
        failed = failed + 1
        return passed, failed, "Failed: " + emb_err
    }

    if embeddings.element_count != int64(token_ids.len() * 4096) {
        failed = failed + 1
        return passed, failed, "Embedding shape mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_embedding_lookup passed"
}

func test_multi_head_attention() (int, int, string) {
    passed := 0
    failed := 0

    input_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(2 * 32 * 128),
        ref_count: 1,
        is_view: false,
    }

    weights := transformer_block.transformer_block_weights {
        q_weight: input_tensor,
        k_weight: input_tensor,
        v_weight: input_tensor,
        o_weight: input_tensor,
        ff_gate_weight: input_tensor,
        ff_up_weight: input_tensor,
        ff_down_weight: input_tensor,
        norm1_weight: input_tensor,
        norm2_weight: input_tensor,
    }

    kv_cache, cache_success, cache_err := transformer_block.kv_cache_init(32, 128, 2048)
    if !cache_success {
        failed = failed + 1
        return passed, failed, "Failed to init cache: " + cache_err
    }

    output, attn_success, attn_err := transformer_block.multi_head_attention(input_tensor, weights, kv_cache)
    if !attn_success {
        failed = failed + 1
        return passed, failed, "Failed: " + attn_err
    }

    if output.element_count <= 0 {
        failed = failed + 1
        return passed, failed, "Invalid output tensor"
    }

    passed = passed + 1
    return passed, failed, "test_multi_head_attention passed"
}

func test_feed_forward_network() (int, int, string) {
    passed := 0
    failed := 0

    input_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(2 * 32 * 128),
        ref_count: 1,
        is_view: false,
    }

    weights := transformer_block.transformer_block_weights {
        q_weight: input_tensor,
        k_weight: input_tensor,
        v_weight: input_tensor,
        o_weight: input_tensor,
        ff_gate_weight: input_tensor,
        ff_up_weight: input_tensor,
        ff_down_weight: input_tensor,
        norm1_weight: input_tensor,
        norm2_weight: input_tensor,
    }

    output, ff_success, ff_err := transformer_block.feed_forward_network(input_tensor, weights)
    if !ff_success {
        failed = failed + 1
        return passed, failed, "Failed: " + ff_err
    }

    if output.element_count <= 0 {
        failed = failed + 1
        return passed, failed, "Invalid output tensor"
    }

    passed = passed + 1
    return passed, failed, "test_feed_forward_network passed"
}

func test_transformer_block_forward() (int, int, string) {
    passed := 0
    failed := 0

    input_tensor := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(2 * 32 * 128),
        ref_count: 1,
        is_view: false,
    }

    weights := transformer_block.transformer_block_weights {
        q_weight: input_tensor,
        k_weight: input_tensor,
        v_weight: input_tensor,
        o_weight: input_tensor,
        ff_gate_weight: input_tensor,
        ff_up_weight: input_tensor,
        ff_down_weight: input_tensor,
        norm1_weight: input_tensor,
        norm2_weight: input_tensor,
    }

    kv_cache, cache_success, cache_err := transformer_block.kv_cache_init(32, 128, 2048)
    if !cache_success {
        failed = failed + 1
        return passed, failed, "Failed to init cache: " + cache_err
    }

    output, block_success, block_err := transformer_block.transformer_block_forward(input_tensor, weights, kv_cache)
    if !block_success {
        failed = failed + 1
        return passed, failed, "Failed: " + block_err
    }

    if output.element_count <= 0 {
        failed = failed + 1
        return passed, failed, "Invalid output tensor"
    }

    passed = passed + 1
    return passed, failed, "test_transformer_block_forward passed"
}

func test_lm_head_forward() (int, int, string) {
    passed := 0
    failed := 0

    hidden_states := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(2 * 32 * 128),
        ref_count: 1,
        is_view: false,
    }

    lm_head_weight := abi.device_tensor {
        data: abi.device_ptr{},
        shape: vec[int](),
        strides: vec[int64](),
        dtype: 0,
        device_id: 0,
        element_count: int64(32000),
        ref_count: 1,
        is_view: false,
    }

    logits, success, err := transformer_block.lm_head_forward(hidden_states, lm_head_weight)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    if logits.element_count <= 0 {
        failed = failed + 1
        return passed, failed, "Invalid logits tensor"
    }

    passed = passed + 1
    return passed, failed, "test_lm_head_forward passed"
}

func test_autoregressive_generate() (int, int, string) {
    passed := 0
    failed := 0

    input_ids := vec[int]()
    input_ids.push(1)
    input_ids.push(29871)
    input_ids.push(13)

    output_ids, gen_success, gen_err := transformer_block.autoregressive_generate(input_ids, 24, 10)
    if !gen_success {
        failed = failed + 1
        return passed, failed, "Failed: " + gen_err
    }

    if output_ids.len() != input_ids.len() + 10 {
        failed = failed + 1
        return passed, failed, "Generated output has wrong length"
    }

    passed = passed + 1
    return passed, failed, "test_autoregressive_generate passed"
}

func test_transformer_stack_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := transformer_block.transformer_stack_init()
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    passed = passed + 1
    return passed, failed, "test_transformer_stack_init passed"
}

func run_all_tests() (int, int, string) {
    total_passed := 0
    total_failed := 0
    results := ""

    p1, f1, r1 := test_transformer_block_config()
    total_passed = total_passed + p1
    total_failed = total_failed + f1
    results = results + r1 + " | "

    p2, f2, r2 := test_kv_cache_operations()
    total_passed = total_passed + p2
    total_failed = total_failed + f2
    results = results + r2 + " | "

    p3, f3, r3 := test_embedding_lookup()
    total_passed = total_passed + p3
    total_failed = total_failed + f3
    results = results + r3 + " | "

    p4, f4, r4 := test_multi_head_attention()
    total_passed = total_passed + p4
    total_failed = total_failed + f4
    results = results + r4 + " | "

    p5, f5, r5 := test_feed_forward_network()
    total_passed = total_passed + p5
    total_failed = total_failed + f5
    results = results + r5 + " | "

    p6, f6, r6 := test_transformer_block_forward()
    total_passed = total_passed + p6
    total_failed = total_failed + f6
    results = results + r6 + " | "

    p7, f7, r7 := test_lm_head_forward()
    total_passed = total_passed + p7
    total_failed = total_failed + f7
    results = results + r7 + " | "

    p8, f8, r8 := test_autoregressive_generate()
    total_passed = total_passed + p8
    total_failed = total_failed + f8
    results = results + r8 + " | "

    p9, f9, r9 := test_transformer_stack_init()
    total_passed = total_passed + p9
    total_failed = total_failed + f9
    results = results + r9

    return total_passed, total_failed, results
}
