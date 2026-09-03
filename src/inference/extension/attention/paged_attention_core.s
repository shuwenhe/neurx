package neurx.attention.paged_attention_core
struct paged_block {
    []float key_data
    []float value_data
    int block_id
    int num_filled
    bool is_full
}

struct slot_mapping {
    int block_id
    int offset_in_block
}

struct paged_kv_cache {
    []paged_block blocks
    []slot_mapping token_to_slot
    int block_size
    int num_kv_heads
    int head_size
    int total_blocks
    int allocated_blocks
    int total_tokens
}

struct paged_attention_config {
    int block_size
    int num_kv_heads
    int head_size
    int max_blocks
    float scale
}

func new_paged_kv_cache(config paged_attention_config) paged_kv_cache {
    int normalized_block = config.block_size
    if normalized_block <= 0 {
        normalized_block = 16
    }
    int normalized_heads = config.num_kv_heads
    if normalized_heads <= 0 {
        normalized_heads = 8
    }
    int normalized_head_size = config.head_size
    if normalized_head_size <= 0 {
        normalized_head_size = 128
    }
    int normalized_max = config.max_blocks
    if normalized_max <= 0 {
        normalized_max = 1024
    }
    []paged_block blocks = []paged_block{}
    int i = 0
    for i < normalized_max {
        int kv_size = normalized_heads * normalized_head_size * normalized_block
        paged_block block = paged_block{
            key_data: new_float_array(kv_size),
            value_data: new_float_array(kv_size),
            block_id: i,
            num_filled: 0,
            is_full: false,
        }
        blocks = append(blocks, block)
        i = i + 1
    }
    paged_kv_cache{
        blocks: blocks,
        token_to_slot: []slot_mapping{},
        block_size: normalized_block,
        num_kv_heads: normalized_heads,
        head_size: normalized_head_size,
        total_blocks: normalized_max,
        allocated_blocks: 0,
        total_tokens: 0,
    }
}

func new_float_array(int size) []float {
    []float arr = make([]float, size)
    return arr
}

func reserve_tokens(cache paged_kv_cache, int num_new_tokens) paged_kv_cache {
    if num_new_tokens <= 0 {
        return cache
    }
    int current_tokens = cache.total_tokens
    int new_total = current_tokens + num_new_tokens
    int needed_blocks = (new_total + cache.block_size - 1) / cache.block_size
    if needed_blocks > cache.total_blocks {
        needed_blocks = cache.total_blocks
        new_total = cache.total_blocks * cache.block_size
        if new_total > current_tokens {
            num_new_tokens = new_total - current_tokens
        } else {
            num_new_tokens = 0
            new_total = current_tokens
        }
    }
    []slot_mapping slots = cache.token_to_slot
    int added = 0
    for added < num_new_tokens {
        int logical_pos = current_tokens + added
        int block_id = logical_pos / cache.block_size
        int offset_in_block = mod_int(logical_pos, cache.block_size)
        if block_id < 0 || block_id >= len(cache.blocks) {
            break
        }
        if offset_in_block == 0 && cache.blocks[block_id].num_filled > 0 {
            cache.blocks[block_id].num_filled = 0
            cache.blocks[block_id].is_full = false
        }
        slots = append(slots, slot_mapping{block_id: block_id, offset_in_block: offset_in_block})
        added = added + 1
    }
    paged_kv_cache{
        blocks: cache.blocks,
        token_to_slot: slots,
        block_size: cache.block_size,
        num_kv_heads: cache.num_kv_heads,
        head_size: cache.head_size,
        total_blocks: cache.total_blocks,
        allocated_blocks: needed_blocks,
        total_tokens: new_total,
    }
}

func mod_int(int a, int b) int {
    if b == 0 {
        return 0
    }
    a - (a / b) * b
}

func release_tokens(cache paged_kv_cache, int num_release) paged_kv_cache {
    if num_release <= 0 {
        return cache
    }
    int new_total = cache.total_tokens - num_release
    if new_total < 0 {
        new_total = 0
    }
    int needed_blocks = (new_total + cache.block_size - 1) / cache.block_size
    if new_total == 0 {
        needed_blocks = 0
    }
    []slot_mapping truncated = cache.token_to_slot
    if new_total < len(cache.token_to_slot) {
        truncated = truncated[:new_total]
    }
    paged_kv_cache{
        blocks: cache.blocks,
        token_to_slot: truncated,
        block_size: cache.block_size,
        num_kv_heads: cache.num_kv_heads,
        head_size: cache.head_size,
        total_blocks: cache.total_blocks,
        allocated_blocks: needed_blocks,
        total_tokens: new_total,
    }
}

func reset_cache(cache paged_kv_cache) paged_kv_cache {
    paged_kv_cache{
        blocks: cache.blocks,
        token_to_slot: []slot_mapping{},
        block_size: cache.block_size,
        num_kv_heads: cache.num_kv_heads,
        head_size: cache.head_size,
        total_blocks: cache.total_blocks,
        allocated_blocks: 0,
        total_tokens: 0,
    }
}

func write_kv_to_cache(
    cache paged_kv_cache,
    []float keys,
    []float values,
    int start_token_idx
) paged_kv_cache {
    if len(keys) == 0 || len(values) == 0 {
        return cache
    }
    int kv_stride = cache.num_kv_heads * cache.head_size
    int num_new_tokens = len(keys) / kv_stride
    int token_offset = 0
    for token_offset < num_new_tokens {
        int logical_pos = start_token_idx + token_offset
        if logical_pos >= cache.total_tokens {
            break
        }
        if logical_pos >= len(cache.token_to_slot) {
            break
        }
        slot_mapping slot = cache.token_to_slot[logical_pos]
        int block_id = slot.block_id
        int offset_in_block = slot.offset_in_block
        if block_id < 0 || block_id >= len(cache.blocks) {
            break
        }
        paged_block block = cache.blocks[block_id]
        int base_src = token_offset * kv_stride
        int base_dst = offset_in_block * kv_stride
        int i = 0
        for i < kv_stride && base_src + i < len(keys) && base_dst + i < len(block.key_data) {
            block.key_data[base_dst + i] = keys[base_src + i]
            block.value_data[base_dst + i] = values[base_src + i]
            i = i + 1
        }
        block.num_filled = block.num_filled + 1
        if block.num_filled >= cache.block_size {
            block.is_full = true
        }
        cache.blocks[block_id] = block
        token_offset = token_offset + 1
    }
    return cache
}

func compute_paged_attention(
    cache paged_kv_cache,
    []float queries,
    []float output,
    []slot_mapping slot_mappings,
    int num_heads,
    int head_size,
    float scale
) []float {
    if len(queries) == 0 {
        return output
    }
    int q_stride = num_heads * head_size
    int num_query_tokens = len(queries) / q_stride
    int context_len = len(slot_mappings)
    int kv_stride = cache.num_kv_heads * cache.head_size
    int q_idx = 0
    for q_idx < num_query_tokens {
        int h = 0
        for h < num_heads {
            int kv_head = h
            if kv_head >= cache.num_kv_heads {
                kv_head = mod_int(kv_head, cache.num_kv_heads)
            }
            int q_head_base = q_idx * q_stride + h * head_size
            []float scores = make([]float, context_len)
            int k_pos = 0
            for k_pos < context_len {
                if k_pos > q_idx {
                    scores[k_pos] = -1.0e30
                    k_pos = k_pos + 1
                    continue
                }
                slot_mapping slot = slot_mappings[k_pos]
                int block_id = slot.block_id
                int offset_in_block = slot.offset_in_block
                if block_id < 0 || block_id >= len(cache.blocks) {
                    scores[k_pos] = -1.0e30
                    k_pos = k_pos + 1
                    continue
                }
                paged_block block = cache.blocks[block_id]
                int kv_base = offset_in_block * kv_stride + kv_head * head_size
                float qk = 0.0
                int d = 0
                for d < head_size {
                    float q_val = queries[q_head_base + d]
                    float k_val = 0.0
                    if kv_base + d < len(block.key_data) {
                        k_val = block.key_data[kv_base + d]
                    }
                    qk = qk + q_val * k_val
                    d = d + 1
                }
                scores[k_pos] = qk * scale
                k_pos = k_pos + 1
            }
            []float probs = compute_softmax(scores)
            int out_base = q_head_base
            int d = 0
            for d < head_size {
                float acc = 0.0
                int k_pos2 = 0
                for k_pos2 < context_len {
                    slot_mapping slot = slot_mappings[k_pos2]
                    int block_id = slot.block_id
                    int offset_in_block = slot.offset_in_block
                    if block_id < 0 || block_id >= len(cache.blocks) {
                        k_pos2 = k_pos2 + 1
                        continue
                    }
                    paged_block block = cache.blocks[block_id]
                    int kv_base = offset_in_block * kv_stride + kv_head * head_size
                    float v_val = 0.0
                    if kv_base + d < len(block.value_data) {
                        v_val = block.value_data[kv_base + d]
                    }
                    acc = acc + probs[k_pos2] * v_val
                    k_pos2 = k_pos2 + 1
                }
                for out_base + d >= len(output) {
                    output = append(output, 0.0)
                }
                output[out_base + d] = acc
                d = d + 1
            }
            h = h + 1
        }
        q_idx = q_idx + 1
    }
    return output
}

func apply_attention_mask(
    []float attention_scores,
    string mask_type,
    int context_len
) []float {
    if mask_type != "causal" {
        return attention_scores
    }
    int i = 0
    for i < len(attention_scores) {
        i = i + 1
    }
    return attention_scores
}

func compute_softmax([]float scores) []float {
    if len(scores) == 0 {
        return scores
    }
    float max_score = scores[0]
    int i = 1
    for i < len(scores) {
        if scores[i] > max_score {
            max_score = scores[i]
        }
        i = i + 1
    }
    []float exp_scores = []float{}
    float sum_exp = 0.0
    i = 0
    for i < len(scores) {
        float exp_val = math_exp(scores[i] - max_score)
        exp_scores = append(exp_scores, exp_val)
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    []float softmax_scores = []float{}
    i = 0
    for i < len(exp_scores) {
        if sum_exp > 0.0 {
            softmax_scores = append(softmax_scores, exp_scores[i] / sum_exp)
        } else {
            softmax_scores = append(softmax_scores, 0.0)
        }
        i = i + 1
    }
    return softmax_scores
}

func math_exp(float x) float {
    if x > 88.0 {
        return 6.5623733e37
    }
    if x < -88.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    for i < 24 {
        term = term * x / float(i)
        result = result + term
        if term < 0.0 {
            term = 0.0 - term
        }
        if term < 1.0e-12 {
            break
        }
        i = i + 1
    }
    return result
}

func factorial(int n) float {
    if n <= 1 {
        return 1.0
    }
    float result = 1.0
    int i = 2
    for i <= n {
        result = result * float(i)
        i = i + 1
    }
    return result
}

struct paged_cache_stats {
    int total_tokens
    int allocated_blocks
    int memory_used_mb
    float utilization_percent
}

func get_cache_stats(cache paged_kv_cache) paged_cache_stats {
    int bytes_per_token = cache.num_kv_heads * cache.head_size * 4 * 2
    int memory_used = cache.total_tokens * bytes_per_token
    int memory_mb = memory_used / (1024 * 1024)
    float utilization = 0.0
    int max_capacity = cache.total_blocks * cache.block_size
    if max_capacity > 0 {
        utilization = f(cache.total_tokens) / f(max_capacity) * 100.0
    }
    paged_cache_stats{
        total_tokens: cache.total_tokens,
        allocated_blocks: cache.allocated_blocks,
        memory_used_mb: memory_mb,
        utilization_percent: utilization,
    }
}

func debug_print_cache_state(cache paged_kv_cache) string {
    stats = get_cache_stats(cache)
    result = ""
    result = result + "PagedAttention Cache State:\n"
    result = result + "  Total Tokens: " + str(stats.total_tokens) + "\n"
    result = result + "  Allocated Blocks: " + str(stats.allocated_blocks) + "/" + str(cache.total_blocks) + "\n"
    result = result + "  Memory Used: " + str(stats.memory_used_mb) + " MB\n"
    result = result + "  Utilization: " + str(stats.utilization_percent) + "%\n"
    return result
}

func compute_paged_attention_gqa(
    cache paged_kv_cache,
    []float queries,
    []float output,
    []slot_mapping slot_mappings,
    int num_heads,
    int num_kv_heads,
    int head_size,
    float scale
) []float {
    if len(queries) == 0 {
        return output
    }
    if num_kv_heads >= num_heads {
        return compute_paged_attention(cache, queries, output, slot_mappings, num_heads, head_size, scale)
    }
    int group_size = num_heads / num_kv_heads
    int q_stride = num_heads * head_size
    int num_query_tokens = len(queries) / q_stride
    int context_len = len(slot_mappings)
    int kv_stride = num_kv_heads * head_size
    int q_idx = 0
    for q_idx < num_query_tokens {
        int h = 0
        for h < num_heads {
            int kv_head = h / group_size
            int q_head_base = q_idx * q_stride + h * head_size
            []float scores = make([]float, context_len)
            int k_pos = 0
            for k_pos < context_len {
                if k_pos > q_idx {
                    scores[k_pos] = -1.0e30
                    k_pos = k_pos + 1
                    continue
                }
                slot_mapping slot = slot_mappings[k_pos]
                int block_id = slot.block_id
                int offset_in_block = slot.offset_in_block
                if block_id < 0 || block_id >= len(cache.blocks) {
                    scores[k_pos] = -1.0e30
                    k_pos = k_pos + 1
                    continue
                }
                paged_block block = cache.blocks[block_id]
                int kv_base = offset_in_block * kv_stride + kv_head * head_size
                float qk = 0.0
                int d = 0
                for d < head_size {
                    float q_val = queries[q_head_base + d]
                    float k_val = 0.0
                    if kv_base + d < len(block.key_data) {
                        k_val = block.key_data[kv_base + d]
                    }
                    qk = qk + q_val * k_val
                    d = d + 1
                }
                scores[k_pos] = qk * scale
                k_pos = k_pos + 1
            }
            []float probs = compute_softmax(scores)
            int out_base = q_head_base
            int d = 0
            for d < head_size {
                float acc = 0.0
                int k_pos2 = 0
                for k_pos2 < context_len {
                    slot_mapping slot = slot_mappings[k_pos2]
                    int block_id = slot.block_id
                    int offset_in_block = slot.offset_in_block
                    if block_id < 0 || block_id >= len(cache.blocks) {
                        k_pos2 = k_pos2 + 1
                        continue
                    }
                    paged_block block = cache.blocks[block_id]
                    int kv_base = offset_in_block * kv_stride + kv_head * head_size
                    float v_val = 0.0
                    if kv_base + d < len(block.value_data) {
                        v_val = block.value_data[kv_base + d]
                    }
                    acc = acc + probs[k_pos2] * v_val
                    k_pos2 = k_pos2 + 1
                }
                for out_base + d >= len(output) {
                    output = append(output, 0.0)
                }
                output[out_base + d] = acc
                d = d + 1
            }
            h = h + 1
        }
        q_idx = q_idx + 1
    }
    output
}
