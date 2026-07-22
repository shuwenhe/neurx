



package neurx.attention.flash_compute


struct flash_attention_config {

    int block_size_q
    int block_size_kv


    bool use_online_softmax
    float q_scale


    bool use_recompute
    bool prefetch_k_v


    bool enable_sequence_parallel
    int sequence_parallel_rank
    int sequence_parallel_size
}


struct online_softmax_state {
    float max_val
    float sum_exp
    float normalization
}


struct flash_attention_state {
    int batch_size
    int seq_len
    int num_heads
    int head_dim


    vector q_blocks
    vector k_blocks
    vector v_blocks


    vector row_max
    vector row_sum


    flash_attention_config config
}


func new_flash_attention_config() flash_attention_config {
    return flash_attention_config {
        block_size_q: 128,
        block_size_kv: 128,
        use_online_softmax: true,
        q_scale: 0.0,
        use_recompute: false,
        prefetch_k_v: true,
        enable_sequence_parallel: false,
        sequence_parallel_rank: 0,
        sequence_parallel_size: 1
    }
}


func new_flash_attention_state(
    int batch_size,
    int seq_len,
    int num_heads,
    int head_dim,
    flash_attention_config config
) flash_attention_state {

    flash_attention_state state
    state.batch_size = batch_size
    state.seq_len = seq_len
    state.num_heads = num_heads
    state.head_dim = head_dim
    state.config = config


    state.q_blocks = allocate_blocks(batch_size, seq_len, num_heads, head_dim, config.block_size_q)
    state.k_blocks = allocate_blocks(batch_size, seq_len, num_heads, head_dim, config.block_size_kv)
    state.v_blocks = allocate_blocks(batch_size, seq_len, num_heads, head_dim, config.block_size_kv)


    state.row_max = allocate_vector(batch_size * num_heads * seq_len, -inf)
    state.row_sum = allocate_vector(batch_size * num_heads * seq_len, 0.0)

    return state
}




func flash_attention_forward(
    q: vector,
    k: vector,
    v: vector,
    mask: vector,
    state: flash_attention_state
): vector {

    var batch_size: int = state.batch_size
    var seq_len: int = state.seq_len
    var num_heads: int = state.num_heads
    var head_dim: int = state.head_dim


    var q_scale: float = 1.0 / sqrt(float(head_dim))


    var output: vector = allocate_vector(batch_size * seq_len * num_heads * head_dim, 0.0)
    var softmax_sum: vector = allocate_vector(batch_size * seq_len * num_heads, 0.0)


    for q_block_idx in range(0, seq_len, state.config.block_size_q) {
        var q_block_end: int = min(q_block_idx + state.config.block_size_q, seq_len)
        var q_block_size: int = q_block_end - q_block_idx


        var q_block: vector = load_block(q, q_block_idx, q_block_size, num_heads, head_dim)


        var output_block: vector = allocate_vector(q_block_size * num_heads * head_dim, 0.0)
        var row_max: vector = allocate_vector(q_block_size * num_heads, -inf)
        var row_sum: vector = allocate_vector(q_block_size * num_heads, 0.0)


        for kv_block_idx in range(0, seq_len, state.config.block_size_kv) {
            var kv_block_end: int = min(kv_block_idx + state.config.block_size_kv, seq_len)
            var kv_block_size: int = kv_block_end - kv_block_idx


            var k_block: vector = load_block(k, kv_block_idx, kv_block_size, num_heads, head_dim)
            var v_block: vector = load_block(v, kv_block_idx, kv_block_size, num_heads, head_dim)


            var scores: vector = block_matrix_multiply(
                q_block, k_block,
                q_block_size, kv_block_size, num_heads, head_dim,
                q_scale
            )


            apply_causal_mask(scores, q_block_idx, kv_block_idx,
                            q_block_size, kv_block_size, num_heads)


            var old_row_max: vector = copy_vector(row_max)


            update_row_max(row_max, scores, q_block_size, kv_block_size, num_heads)


            var exp_scores: vector = compute_online_exponentials(
                scores, old_row_max, row_max,
                q_block_size, kv_block_size, num_heads
            )


            var exp_exp: vector = allocate_vector(q_block_size * num_heads, 0.0)
            for i in range(0, q_block_size * num_heads) {
                if old_row_max[i] < row_max[i] {
                    exp_exp[i] = exp(old_row_max[i] - row_max[i])
                } else {
                    exp_exp[i] = 1.0
                }
            }

            scale_and_add(row_sum, exp_exp, q_block_size, num_heads)
            add_row_sum(row_sum, exp_scores, q_block_size, kv_block_size, num_heads)


            update_output_block(
                output_block, exp_scores, v_block,
                old_row_max, row_max,
                q_block_size, kv_block_size, num_heads, head_dim
            )
        }


        normalize_output_block(output_block, row_sum, q_block_size, num_heads, head_dim)


        store_block(output, output_block, q_block_idx, q_block_size, num_heads, head_dim)
    }

    return output
}


func flash_attention_backward(
    q: vector,
    k: vector,
    v: vector,
    output: vector,
    grad_output: vector,
    mask: vector,
    state: flash_attention_state
): (vector, vector, vector) {

    var batch_size: int = state.batch_size
    var seq_len: int = state.seq_len
    var num_heads: int = state.num_heads
    var head_dim: int = state.head_dim


    var grad_q: vector = allocate_vector(length(q), 0.0)
    var grad_k: vector = allocate_vector(length(k), 0.0)
    var grad_v: vector = allocate_vector(length(v), 0.0)


    if state.config.use_recompute {

    }


    var grad_softmax: vector = allocate_vector(batch_size * seq_len * seq_len * num_heads, 0.0)







    for q_block_idx in range(0, seq_len, state.config.block_size_q) {
        var q_block_end: int = min(q_block_idx + state.config.block_size_q, seq_len)

        for kv_block_idx in range(0, seq_len, state.config.block_size_kv) {
            var kv_block_end: int = min(kv_block_idx + state.config.block_size_kv, seq_len)


            compute_attention_gradients_block(
                grad_q, grad_k, grad_v,
                q, k, v, grad_output,
                q_block_idx, q_block_end,
                kv_block_idx, kv_block_end,
                num_heads, head_dim
            )
        }
    }

    return (grad_q, grad_k, grad_v)
}



func flash_attention_gqa(
    q: vector,
    k: vector,
    v: vector,
    mask: vector,
    num_heads: int,
    num_kv_heads: int,
    state: flash_attention_state
): vector {


    var k_expanded: vector = expand_kv_heads(k, num_heads, num_kv_heads)
    var v_expanded: vector = expand_kv_heads(v, num_heads, num_kv_heads)


    return flash_attention_forward(q, k_expanded, v_expanded, mask, state)
}



func flash_attention_sequence_parallel(
    q: vector,
    k: vector,
    v: vector,
    mask: vector,
    all_gather_k: vector,
    all_gather_v: vector,
    state: flash_attention_state
): vector {

    var seq_rank: int = state.config.sequence_parallel_rank
    var seq_size: int = state.config.sequence_parallel_size


    var local_output: vector = flash_attention_forward(q, k, v, mask, state)


    for remote_rank in range(0, seq_size) {
        if remote_rank != seq_rank {
            var remote_k: vector = get_chunk_from_all_gather(all_gather_k, remote_rank)
            var remote_v: vector = get_chunk_from_all_gather(all_gather_v, remote_rank)


            var cross_output: vector = flash_attention_forward(q, remote_k, remote_v,
                                                              get_cross_mask(seq_rank, remote_rank),
                                                              state)


            local_output = add_vectors(local_output, cross_output)
        }
    }

    return local_output
}


func compute_flash_attention_memory_savings(
    batch_size: int,
    seq_len: int,
    num_heads: int,
    head_dim: int
): (float, float) {


    var standard_memory: float = float(batch_size * seq_len * seq_len * num_heads) * 2.0 / (1024 * 1024 * 1024)


    var flash_memory: float = float(batch_size * seq_len * head_dim * num_heads) * 2.0 / (1024 * 1024 * 1024)

    var memory_savings: float = (1.0 - flash_memory / standard_memory) * 100.0
    var speedup: float = standard_memory / flash_memory

    return (memory_savings, speedup)
}


func load_block(data: vector, start_idx: int, block_size: int, num_heads: int, head_dim: int): vector {


    return allocate_vector(block_size * num_heads * head_dim, 0.0)
}


func store_block(output: vector, block: vector, start_idx: int, block_size: int, num_heads: int, head_dim: int): void {

}


func block_matrix_multiply(
    q_block: vector, k_block: vector,
    q_size: int, kv_size: int, num_heads: int, head_dim: int,
    q_scale: float
): vector {
    var result: vector = allocate_vector(q_size * kv_size * num_heads, 0.0)


    for h in range(0, num_heads) {
        for qi in range(0, q_size) {
            for ki in range(0, kv_size) {
                var score: float = 0.0


                for d in range(0, head_dim) {
                    var q_val: float = q_block[h * q_size * head_dim + qi * head_dim + d]
                    var k_val: float = k_block[h * kv_size * head_dim + ki * head_dim + d]
                    score = score + q_val * k_val
                }

                result[h * q_size * kv_size + qi * kv_size + ki] = score * q_scale
            }
        }
    }

    return result
}


func apply_causal_mask(
    scores: vector,
    q_start: int, kv_start: int,
    q_size: int, kv_size: int, num_heads: int
): void {


    for h in range(0, num_heads) {
        for qi in range(0, q_size) {
            for ki in range(0, kv_size) {
                var q_pos: int = q_start + qi
                var k_pos: int = kv_start + ki

                if k_pos > q_pos {
                    scores[h * q_size * kv_size + qi * kv_size + ki] = -inf
                }
            }
        }
    }
}


func update_row_max(row_max: vector, scores: vector, q_size: int, kv_size: int, num_heads: int): void {
    for h in range(0, num_heads) {
        for qi in range(0, q_size) {
            var row_idx: int = h * q_size + qi
            var current_max: float = row_max[row_idx]

            for ki in range(0, kv_size) {
                var score: float = scores[h * q_size * kv_size + qi * kv_size + ki]
                if score > current_max {
                    current_max = score
                }
            }

            row_max[row_idx] = current_max
        }
    }
}


func compute_online_exponentials(
    scores: vector, old_max: vector, new_max: vector,
    q_size: int, kv_size: int, num_heads: int
): vector {
    var result: vector = allocate_vector(q_size * kv_size * num_heads, 0.0)

    for h in range(0, num_heads) {
        for qi in range(0, q_size) {
            var row_idx: int = h * q_size + qi

            for ki in range(0, kv_size) {
                var score: float = scores[h * q_size * kv_size + qi * kv_size + ki]
                var stabilized_score: float = score - new_max[row_idx]
                result[h * q_size * kv_size + qi * kv_size + ki] = exp(stabilized_score)
            }
        }
    }

    return result
}


func add_row_sum(row_sum: vector, exp_scores: vector, q_size: int, kv_size: int, num_heads: int): void {
    for h in range(0, num_heads) {
        for qi in range(0, q_size) {
            var row_idx: int = h * q_size + qi
            var sum_val: float = 0.0

            for ki in range(0, kv_size) {
                sum_val = sum_val + exp_scores[h * q_size * kv_size + qi * kv_size + ki]
            }

            row_sum[row_idx] = row_sum[row_idx] + sum_val
        }
    }
}


func update_output_block(
    output: vector, exp_scores: vector, v_block: vector,
    old_max: vector, new_max: vector,
    q_size: int, kv_size: int, num_heads: int, head_dim: int
): void {

    for h in range(0, num_heads) {
        for qi in range(0, q_size) {
            var row_idx: int = h * q_size + qi


            var scale_factor: float = exp(old_max[row_idx] - new_max[row_idx])

            for d in range(0, head_dim) {
                output[h * q_size * head_dim + qi * head_dim + d] =
                    output[h * q_size * head_dim + qi * head_dim + d] * scale_factor
            }


            for ki in range(0, kv_size) {
                var attn_weight: float = exp_scores[h * q_size * kv_size + qi * kv_size + ki]

                for d in range(0, head_dim) {
                    var v_val: float = v_block[h * kv_size * head_dim + ki * head_dim + d]
                    output[h * q_size * head_dim + qi * head_dim + d] =
                        output[h * q_size * head_dim + qi * head_dim + d] + attn_weight * v_val
                }
            }
        }
    }
}


func normalize_output_block(output: vector, row_sum: vector, q_size: int, num_heads: int, head_dim: int): void {
    for h in range(0, num_heads) {
        for qi in range(0, q_size) {
            var row_idx: int = h * q_size + qi
            var norm_factor: float = 1.0 / row_sum[row_idx]

            for d in range(0, head_dim) {
                output[h * q_size * head_dim + qi * head_dim + d] =
                    output[h * q_size * head_dim + qi * head_dim + d] * norm_factor
            }
        }
    }
}


func expand_kv_heads(kv: vector, num_heads: int, num_kv_heads: int): vector {

    var expansion_factor: int = num_heads / num_kv_heads
    var expanded_size: int = length(kv) * expansion_factor
    var result: vector = allocate_vector(expanded_size, 0.0)

    for i in range(0, length(kv)) {
        for j in range(0, expansion_factor) {
            result[i * expansion_factor + j] = kv[i]
        }
    }

    return result
}


func get_chunk_from_all_gather(all_gathered: vector, rank: int): vector {

    return allocate_vector(length(all_gathered) / rank, 0.0)
}


func get_cross_mask(from_rank: int, to_rank: int): vector {

    return allocate_vector(1, 0.0)
}


func scale_and_add(result: vector, scale_vec: vector, q_size: int, num_heads: int): void {
    for h in range(0, num_heads) {
        for qi in range(0, q_size) {
            result[h * q_size + qi] = result[h * q_size + qi] * scale_vec[h * q_size + qi]
        }
    }
}


func compute_attention_gradients_block(
    grad_q: vector, grad_k: vector, grad_v: vector,
    q: vector, k: vector, v: vector, grad_output: vector,
    q_start: int, q_end: int,
    kv_start: int, kv_end: int,
    num_heads: int, head_dim: int
): void {

}


func benchmark_flash_attention(
    seq_lengths: vector,
    num_heads: int,
    head_dim: int
): vector {

    var results: vector = allocate_vector(length(seq_lengths), 0.0)

    for i in range(0, length(seq_lengths)) {
        var seq_len: int = seq_lengths[i]

        var config: flash_attention_config = new_flash_attention_config()
        var state: flash_attention_state = new_flash_attention_state(1, seq_len, num_heads, head_dim, config)

        var q: vector = allocate_vector(seq_len * num_heads * head_dim, 0.0)
        var k: vector = allocate_vector(seq_len * num_heads * head_dim, 0.0)
        var v: vector = allocate_vector(seq_len * num_heads * head_dim, 0.0)
        var mask: vector = allocate_vector(seq_len * seq_len, 0.0)


        var _ = flash_attention_forward(q, k, v, mask, state)



    }

    return results
}


func verify_flash_attention_correctness(
    q: vector, k: vector, v: vector, mask: vector,
    seq_len: int, num_heads: int, head_dim: int
): bool {

    var config: flash_attention_config = new_flash_attention_config()
    var state: flash_attention_state = new_flash_attention_state(1, seq_len, num_heads, head_dim, config)


    var flash_output: vector = flash_attention_forward(q, k, v, mask, state)


    var ref_output: vector = standard_attention(q, k, v, mask, seq_len, num_heads, head_dim)


    var tolerance: float = 1e-5
    var max_diff: float = 0.0

    for i in range(0, length(flash_output)) {
        var diff: float = abs(flash_output[i] - ref_output[i])
        if diff > max_diff {
            max_diff = diff
        }
    }

    return max_diff < tolerance
}


func standard_attention(q: vector, k: vector, v: vector, mask: vector,
                     seq_len: int, num_heads: int, head_dim: int): vector {

    var q_scale: float = 1.0 / sqrt(float(head_dim))
    var output: vector = allocate_vector(seq_len * num_heads * head_dim, 0.0)


    for h in range(0, num_heads) {
        for qi in range(0, seq_len) {
            for ki in range(0, seq_len) {
                var score: float = 0.0

                for d in range(0, head_dim) {
                    var q_val: float = q[h * seq_len * head_dim + qi * head_dim + d]
                    var k_val: float = k[h * seq_len * head_dim + ki * head_dim + d]
                    score = score + q_val * k_val
                }

                score = score * q_scale
                if mask[qi * seq_len + ki] == 0.0 {
                    score = -inf
                }


                var exp_score: float = exp(score)

                for d in range(0, head_dim) {
                    var v_val: float = v[h * seq_len * head_dim + ki * head_dim + d]
                    output[h * seq_len * head_dim + qi * head_dim + d] =
                        output[h * seq_len * head_dim + qi * head_dim + d] + exp_score * v_val
                }
            }
        }
    }

    return output
}


func recommended_flash_attention_config_2t(): flash_attention_config {
    var config: flash_attention_config = new_flash_attention_config()
    config.block_size_q = 128
    config.block_size_kv = 128
    config.use_online_softmax = true
    config.use_recompute = false
    config.prefetch_k_v = true
    config.enable_sequence_parallel = true
    config.sequence_parallel_rank = 0
    config.sequence_parallel_size = 4

    return config
}
