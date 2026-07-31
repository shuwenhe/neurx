package neurx.model.transformer.long_context
import "neurx.util.math"
enum context_type {
    SLIDING_WINDOW = 0
    PAGED_KV = 1
    FULL_ATTENTION = 2
    MIXED = 3
}
struct long_context_config {
    int max_context_length
    int sliding_window_size
    int kv_cache_block_size
    int num_kv_blocks
    bool use_sliding_window
    bool use_paged_kv_cache
    bool use_dynamic_position_encoding
    bool use_segment_aware_embedding
    int segment_size
    float rope_base
    float rope_scale
    int attention_chunk_size
}

struct sliding_window_state {
    []float keys
    []float values
    int window_size
    int current_position
    int buffer_start
    int buffer_end
    []int position_map
}

struct kv_cache_block {
    []float keys
    []float values
    int block_id
    int start_position
    int end_position
    bool is_valid
}

struct paged_kv_cache {
    []kv_cache_block blocks
    int block_size
    int num_blocks
    int num_heads
    int head_dim
    int current_block_idx
    []int block_mapping
}

struct segment_info {
    int segment_id
    int start_pos
    int end_pos
    []float segment_embedding
}

struct long_context_state {
    long_context_config config
    sliding_window_state sw_state
    paged_kv_cache kv_cache
    []segment_info segments
    int current_segment_idx
}
func new_long_context_config() long_context_config {
    long_context_config {
        max_context_length: 262144,
        sliding_window_size: 4096,
        kv_cache_block_size: 1024,
        num_kv_blocks: 256,
        use_sliding_window: true,
        use_paged_kv_cache: true,
        use_dynamic_position_encoding: true,
        use_segment_aware_embedding: true,
        segment_size: 8192,
        rope_base: 10000.0,
        rope_scale: 1.0,
        attention_chunk_size: 1024,
    }
}

func new_sliding_window_state(long_context_config config) sliding_window_state {
    int num_heads = 32
    int head_dim = config.max_context_length / num_heads
    sliding_window_state {
        keys: math.allocate_float(config.sliding_window_size * num_heads * head_dim, 0.0),
        values: math.allocate_float(config.sliding_window_size * num_heads * head_dim, 0.0),
        window_size: config.sliding_window_size,
        current_position: 0,
        buffer_start: 0,
        buffer_end: 0,
        position_map: math.allocate_int(config.sliding_window_size, -1),
    }
}

func new_kv_cache_block(int block_size, int num_heads, int head_dim) kv_cache_block {
    kv_cache_block {
        keys: math.allocate_float(block_size * num_heads * head_dim, 0.0),
        values: math.allocate_float(block_size * num_heads * head_dim, 0.0),
        block_id: -1,
        start_position: -1,
        end_position: -1,
        is_valid: false,
    }
}

func new_paged_kv_cache(long_context_config config) paged_kv_cache {
    int num_heads = 32
    int head_dim = config.max_context_length / num_heads
    paged_kv_cache cache {
        blocks: []kv_cache_block{cap: config.num_kv_blocks},
        block_size: config.kv_cache_block_size,
        num_blocks: config.num_kv_blocks,
        num_heads: num_heads,
        head_dim: head_dim,
        current_block_idx: 0,
        block_mapping: math.allocate_int(config.max_context_length / config.kv_cache_block_size, -1),
    }
    int i = 0
    while i < config.num_kv_blocks {
        cache.blocks.push(new_kv_cache_block(config.kv_cache_block_size, num_heads, head_dim))
        cache.blocks[i].block_id = i
        i = i + 1
    }
    cache
}

func new_long_context_state(long_context_config config) long_context_state {
    long_context_state {
        config: config,
        sw_state: new_sliding_window_state(config),
        kv_cache: new_paged_kv_cache(config),
        segments: []segment_info{cap: config.max_context_length / config.segment_size},
        current_segment_idx: 0,
    }
}

func compute_dynamic_position_encoding(int position, int segment_id, long_context_config config) []float {
    int hidden_dim = 8192
    []float encoding = math.allocate_float(hidden_dim, 0.0)
    float base = config.rope_base * math.exp_approx(float(segment_id) * 0.5)
    float scale = config.rope_scale * (1.0 + float(segment_id) * 0.1)
    int dim = 0
    while dim < hidden_dim {
        float inv_freq = 1.0 / math.exp_approx(float(dim) * math.log_approx(base) / float(hidden_dim))
        float pos_embedding = float(position) * inv_freq * scale
        if dim % 2 == 0 {
            encoding[dim] = math.cos_approx(pos_embedding)
        } else {
            encoding[dim] = math.sin_approx(pos_embedding)
        }
        dim = dim + 1
    }
    encoding
}

func compute_segment_embedding(int segment_id, int hidden_dim) []float {
    []float embedding = math.allocate_float(hidden_dim, 0.0)
    float base = 10000.0
    int dim = 0
    while dim < hidden_dim {
        float inv_freq = 1.0 / math.exp_approx(float(dim) * math.log_approx(base) / float(hidden_dim))
        float seg_embedding = float(segment_id) * inv_freq
        if dim % 2 == 0 {
            embedding[dim] = math.cos_approx(seg_embedding)
        } else {
            embedding[dim] = math.sin_approx(seg_embedding)
        }
        dim = dim + 1
    }
    embedding
}

func sliding_window_attention([]float queries, []float keys, []float values,
                              int num_heads, int head_dim, int seq_len,
                              int window_size, int current_position) []float {
    int hidden_dim = num_heads * head_dim
    []float output = math.allocate_float(seq_len * hidden_dim, 0.0)
    int effective_seq_len = math.min_int(seq_len, window_size)
    int start_pos = math.max_int(0, current_position - window_size + 1)
    int head = 0
    while head < num_heads {
        int i = 0
        while i < seq_len {
            int q_pos = current_position - seq_len + 1 + i
            []float attention_scores = math.allocate_float(effective_seq_len, 0.0)
            int j = 0
            while j < effective_seq_len {
                int k_pos = start_pos + j
                float score = 0.0
                int d = 0
                while d < head_dim {
                    score = score + queries[i * hidden_dim + head * head_dim + d] *
                                    keys[k_pos * hidden_dim + head * head_dim + d]
                    d = d + 1
                }
                attention_scores[j] = score / math.sqrt_approx(float(head_dim))
                j = j + 1
            }
            []float softmax_scores = math.softmax_1d(attention_scores)
            int d = 0
            while d < head_dim {
                float out_val = 0.0
                j = 0
                while j < effective_seq_len {
                    int k_pos = start_pos + j
                    out_val = out_val + softmax_scores[j] * values[k_pos * hidden_dim + head * head_dim + d]
                    j = j + 1
                }
                output[i * hidden_dim + head * head_dim + d] = out_val
                d = d + 1
            }
            i = i + 1
        }
        head = head + 1
    }
    output
}

func paged_kv_cache_append(paged_kv_cache cache, []float new_keys, []float new_values,
                           int start_position, int seq_len) paged_kv_cache {
    int block_size = cache.block_size
    int num_heads = cache.num_heads
    int head_dim = cache.head_dim
    int start_block = start_position / block_size
    int end_block = (start_position + seq_len - 1) / block_size
    int pos = start_position
    int data_idx = 0
    int block_idx = start_block
    while block_idx <= end_block {
        int block_offset = pos % block_size
        int remaining_in_block = block_size - block_offset
        int copy_size = math.min_int(remaining_in_block, seq_len - (pos - start_position))
        if cache.block_mapping[block_idx] < 0 {
            cache.block_mapping[block_idx] = cache.current_block_idx
            cache.current_block_idx = (cache.current_block_idx + 1) % cache.num_blocks
        }
        int physical_block_idx = cache.block_mapping[block_idx]
        kv_cache_block block = cache.blocks[physical_block_idx]
        block.start_position = block_idx * block_size
        block.end_position = (block_idx + 1) * block_size - 1
        block.is_valid = true
        int d = 0
        while d < copy_size * num_heads * head_dim {
            int block_pos = block_offset * num_heads * head_dim + d
            int data_pos = data_idx * num_heads * head_dim + d
            if block_pos < len(block.keys) && data_pos < len(new_keys) {
                block.keys[block_pos] = new_keys[data_pos]
                block.values[block_pos] = new_values[data_pos]
            }
            d = d + 1
        }
        cache.blocks[physical_block_idx] = block
        pos = pos + copy_size
        data_idx = data_idx + copy_size
        block_idx = block_idx + 1
    }
    cache
}

func paged_kv_cache_get_block(paged_kv_cache cache, int position) kv_cache_block {
    int block_idx = position / cache.block_size
    if block_idx >= len(cache.block_mapping) || cache.block_mapping[block_idx] < 0 {
        return new_kv_cache_block(cache.block_size, cache.num_heads, cache.head_dim)
    }
    int physical_block_idx = cache.block_mapping[block_idx]
    cache.blocks[physical_block_idx]
}

func paged_kv_cache_attention([]float queries, paged_kv_cache cache, int query_position,
                              int num_heads, int head_dim, int seq_len) []float {
    int hidden_dim = num_heads * head_dim
    []float output = math.allocate_float(seq_len * hidden_dim, 0.0)
    int window_size = cache.block_size * 4
    int head = 0
    while head < num_heads {
        int i = 0
        while i < seq_len {
            int q_pos = query_position - seq_len + 1 + i
            int start_pos = math.max_int(0, q_pos - window_size + 1)
            int effective_len = q_pos - start_pos + 1
            []float attention_scores = math.allocate_float(effective_len, 0.0)
            []float v_buffer = math.allocate_float(effective_len * head_dim, 0.0)
            int k_pos = start_pos
            int idx = 0
            while k_pos <= q_pos {
                kv_cache_block block = paged_kv_cache_get_block(cache, k_pos)
                int block_start = math.max_int(block.start_position, k_pos)
                int block_end = math.min_int(block.end_position, q_pos)
                int b_pos = block_start
                while b_pos <= block_end {
                    int block_offset = b_pos - block.start_position
                    float score = 0.0
                    int d = 0
                    while d < head_dim {
                        score = score + queries[i * hidden_dim + head * head_dim + d] *
                                        block.keys[block_offset * num_heads * head_dim + head * head_dim + d]
                        d = d + 1
                    }
                    attention_scores[idx] = score / math.sqrt_approx(float(head_dim))
                    d = 0
                    while d < head_dim {
                        v_buffer[idx * head_dim + d] = block.values[block_offset * num_heads * head_dim + head * head_dim + d]
                        d = d + 1
                    }
                    idx = idx + 1
                    b_pos = b_pos + 1
                }
                k_pos = block_end + 1
            }
            []float softmax_scores = math.softmax_1d(attention_scores)
            int d = 0
            while d < head_dim {
                float out_val = 0.0
                idx = 0
                while idx < effective_len {
                    out_val = out_val + softmax_scores[idx] * v_buffer[idx * head_dim + d]
                    idx = idx + 1
                }
                output[i * hidden_dim + head * head_dim + d] = out_val
                d = d + 1
            }
            i = i + 1
        }
        head = head + 1
    }
    output
}

func long_context_attention(long_context_state state, []float queries, []float keys, []float values,
                            int num_heads, int head_dim, int seq_len, int current_position) []float {
    long_context_config config = state.config
    if config.use_sliding_window && !config.use_paged_kv_cache {
        return sliding_window_attention(queries, keys, values, num_heads, head_dim, seq_len,
                                       config.sliding_window_size, current_position)
    }
    if config.use_paged_kv_cache {
        state.kv_cache = paged_kv_cache_append(state.kv_cache, keys, values, current_position - seq_len + 1, seq_len)
        return paged_kv_cache_attention(queries, state.kv_cache, current_position, num_heads, head_dim, seq_len)
    }
    int hidden_dim = num_heads * head_dim
    []float output = math.allocate_float(seq_len * hidden_dim, 0.0)
    int head = 0
    while head < num_heads {
        int i = 0
        while i < seq_len {
            []float attention_scores = math.allocate_float(seq_len, 0.0)
            int j = 0
            while j < seq_len {
                float score = 0.0
                int d = 0
                while d < head_dim {
                    score = score + queries[i * hidden_dim + head * head_dim + d] *
                                    keys[j * hidden_dim + head * head_dim + d]
                    d = d + 1
                }
                attention_scores[j] = score / math.sqrt_approx(float(head_dim))
                j = j + 1
            }
            []float softmax_scores = math.softmax_1d(attention_scores)
            int d = 0
            while d < head_dim {
                float out_val = 0.0
                j = 0
                while j < seq_len {
                    out_val = out_val + softmax_scores[j] * values[j * hidden_dim + head * head_dim + d]
                    j = j + 1
                }
                output[i * hidden_dim + head * head_dim + d] = out_val
                d = d + 1
            }
            i = i + 1
        }
        head = head + 1
    }
    output
}

func chunked_attention([]float queries, []float keys, []float values,
                       int num_heads, int head_dim, int seq_len, int chunk_size) []float {
    int hidden_dim = num_heads * head_dim
    []float output = math.allocate_float(seq_len * hidden_dim, 0.0)
    int num_chunks = (seq_len + chunk_size - 1) / chunk_size
    int head = 0
    while head < num_heads {
        int i = 0
        while i < seq_len {
            []float attention_scores = math.allocate_float(seq_len, 0.0)
            []float v_buffer = math.allocate_float(seq_len * head_dim, 0.0)
            int chunk_idx = 0
            while chunk_idx < num_chunks {
                int chunk_start = chunk_idx * chunk_size
                int chunk_end = math.min_int((chunk_idx + 1) * chunk_size, seq_len)
                int j = chunk_start
                while j < chunk_end {
                    float score = 0.0
                    int d = 0
                    while d < head_dim {
                        score = score + queries[i * hidden_dim + head * head_dim + d] *
                                        keys[j * hidden_dim + head * head_dim + d]
                        d = d + 1
                    }
                    attention_scores[j] = score / math.sqrt_approx(float(head_dim))
                    d = 0
                    while d < head_dim {
                        v_buffer[j * head_dim + d] = values[j * hidden_dim + head * head_dim + d]
                        d = d + 1
                    }
                    j = j + 1
                }
                chunk_idx = chunk_idx + 1
            }
            []float softmax_scores = math.softmax_1d(attention_scores)
            int d = 0
            while d < head_dim {
                float out_val = 0.0
                int j = 0
                while j < seq_len {
                    out_val = out_val + softmax_scores[j] * v_buffer[j * head_dim + d]
                    j = j + 1
                }
                output[i * hidden_dim + head * head_dim + d] = out_val
                d = d + 1
            }
            i = i + 1
        }
        head = head + 1
    }
    output
}

func long_context_compute_position_ids(int start_pos, int seq_len, long_context_config config) []int {
    []int position_ids = math.allocate_int(seq_len, 0)
    int i = 0
    while i < seq_len {
        position_ids[i] = start_pos + i
        i = i + 1
    }
    position_ids
}

func long_context_compute_segment_ids(int start_pos, int seq_len, int segment_size) []int {
    []int segment_ids = math.allocate_int(seq_len, 0)
    int i = 0
    while i < seq_len {
        segment_ids[i] = (start_pos + i) / segment_size
        i = i + 1
    }
    segment_ids
}

func long_context_update_state(long_context_state state, int new_position) long_context_state {
    state.sw_state.current_position = new_position
    state.sw_state.buffer_end = (state.sw_state.buffer_end + 1) % state.sw_state.window_size
    if state.sw_state.buffer_end == state.sw_state.buffer_start {
        state.sw_state.buffer_start = (state.sw_state.buffer_start + 1) % state.sw_state.window_size
    }
    int i = 0
    while i < state.sw_state.window_size {
        int actual_pos = (state.sw_state.buffer_start + i) % state.sw_state.window_size
        state.sw_state.position_map[actual_pos] = new_position - state.sw_state.window_size + 1 + i
        i = i + 1
    }
    if state.config.use_segment_aware_embedding {
        int new_segment_idx = new_position / state.config.segment_size
        if new_segment_idx != state.current_segment_idx {
            state.current_segment_idx = new_segment_idx
            segment_info seg_info {
                segment_id: new_segment_idx,
                start_pos: new_segment_idx * state.config.segment_size,
                end_pos: (new_segment_idx + 1) * state.config.segment_size - 1,
                segment_embedding: compute_segment_embedding(new_segment_idx, 8192),
            }
            state.segments.push(seg_info)
        }
    }
    state
}

func long_context_reset(long_context_state state) long_context_state {
    state.sw_state.current_position = 0
    state.sw_state.buffer_start = 0
    state.sw_state.buffer_end = 0
    int i = 0
    while i < len(state.sw_state.position_map) {
        state.sw_state.position_map[i] = -1
        i = i + 1
    }
    state.kv_cache.current_block_idx = 0
    i = 0
    while i < len(state.kv_cache.block_mapping) {
        state.kv_cache.block_mapping[i] = -1
        i = i + 1
    }
    state.segments = []segment_info{cap: state.config.max_context_length / state.config.segment_size}
    state.current_segment_idx = 0
    state
}
