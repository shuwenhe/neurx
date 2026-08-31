package neurx.inference.scheduler.queue.gpu_input_batch
func input_batch_padding_slot() int { 0 - 1 }

struct gpu_input_batch_config {
    int maximum_requests
    int maximum_tokens
    int maximum_blocks_per_request
    int block_size
}

struct gpu_input_batch_state {
    gpu_input_batch_config config
    int[] request_ids
    int[] sequence_lengths
    int[] computed_tokens
    int[] scheduled_tokens
    int[] block_counts
    int[] block_ids
    int[] active
    int request_count
}

struct gpu_input_batch_view {
    gpu_input_batch_state state
    int[] batch_request_ids
    int[] query_start_locations
    int[] positions
    int[] slot_mappings
    int request_count
    int token_count
    bool valid
}

func input_batch_int_array(int capacity) []int {
    int[] values = make([]int, capacity)
    int i = 0
    for i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_gpu_input_batch(gpu_input_batch_config config) gpu_input_batch_state {
    if config.maximum_requests <= 0 { config.maximum_requests = 1 }
    if config.maximum_requests > 4096 { config.maximum_requests = 4096 }
    if config.maximum_tokens <= 0 { config.maximum_tokens = 1 }
    if config.maximum_blocks_per_request <= 0 { config.maximum_blocks_per_request = 1 }
    if config.block_size <= 0 { config.block_size = 1 }
    gpu_input_batch_state {config: config, request_ids: input_batch_int_array(config.maximum_requests), sequence_lengths: input_batch_int_array(config.maximum_requests), computed_tokens: input_batch_int_array(config.maximum_requests), scheduled_tokens: input_batch_int_array(config.maximum_requests), block_counts: input_batch_int_array(config.maximum_requests), block_ids: input_batch_int_array(config.maximum_requests * config.maximum_blocks_per_request), active: input_batch_int_array(config.maximum_requests), request_count: 0}
}

func input_batch_find(gpu_input_batch_state state, int request_id) int {
    int i = 0
    for i < state.config.maximum_requests {
        if state.active[i] == 1 && state.request_ids[i] == request_id { return i }
        i = i + 1
    }
    0 - 1
}

func input_batch_add_request(gpu_input_batch_state state, int request_id, int sequence_length, int computed_tokens, int scheduled_tokens) gpu_input_batch_state {
    if request_id <= 0 || sequence_length < 0 || computed_tokens < 0 || computed_tokens > sequence_length || scheduled_tokens <= 0 || input_batch_find(state, request_id) >= 0 || state.request_count >= state.config.maximum_requests { return state }
    int slot = 0 - 1
    int i = 0
    for i < state.config.maximum_requests {
        if slot < 0 && state.active[i] == 0 { slot = i }
        i = i + 1
    }
    if slot < 0 { return state }
    state.active[slot] = 1
    state.request_ids[slot] = request_id
    state.sequence_lengths[slot] = sequence_length
    state.computed_tokens[slot] = computed_tokens
    state.scheduled_tokens[slot] = scheduled_tokens
    state.request_count = state.request_count + 1
    state
}

func input_batch_append_block(gpu_input_batch_state state, int request_id, int block_id, bool overwrite) gpu_input_batch_state {
    int slot = input_batch_find(state, request_id)
    if slot < 0 || block_id < 0 { return state }
    if overwrite { state.block_counts[slot] = 0 }
    int count = state.block_counts[slot]
    if count >= state.config.maximum_blocks_per_request { return state }
    int offset = slot * state.config.maximum_blocks_per_request + count
    state.block_ids[offset] = block_id
    state.block_counts[slot] = count + 1
    state
}

func input_batch_block_id(gpu_input_batch_state state, int slot, int logical_block) int {
    if slot < 0 || slot >= state.config.maximum_requests || logical_block < 0 || logical_block >= state.block_counts[slot] { return input_batch_padding_slot() }
    state.block_ids[slot * state.config.maximum_blocks_per_request + logical_block]
}

func input_batch_build(gpu_input_batch_state state) gpu_input_batch_view {
    int[] batch_ids = input_batch_int_array(state.config.maximum_requests)
    int[] query_starts = input_batch_int_array(state.config.maximum_requests + 1)
    int[] positions = input_batch_int_array(state.config.maximum_tokens)
    int[] mappings = input_batch_int_array(state.config.maximum_tokens)
    int request_index = 0
    int token_index = 0
    bool valid = true
    int slot = 0
    for slot < state.config.maximum_requests {
        if state.active[slot] == 1 {
            batch_ids[request_index] = state.request_ids[slot]
            query_starts[request_index] = token_index
            int local = 0
            for local < state.scheduled_tokens[slot] {
                if token_index >= state.config.maximum_tokens {
                    valid = false
                    break
                }
                int position = state.computed_tokens[slot] + local
                positions[token_index] = position
                int logical_block = position / state.config.block_size
                int block_id = input_batch_block_id(state, slot, logical_block)
                if block_id < 0 {
                    mappings[token_index] = input_batch_padding_slot()
                    valid = false
                } else {
                    mappings[token_index] = block_id * state.config.block_size + position % state.config.block_size
                }
                token_index = token_index + 1
                local = local + 1
            }
            request_index = request_index + 1
        }
        slot = slot + 1
    }
    query_starts[request_index] = token_index
    gpu_input_batch_view {state: state, batch_request_ids: batch_ids, query_start_locations: query_starts, positions: positions, slot_mappings: mappings, request_count: request_index, token_count: token_index, valid: valid}
}

func input_batch_commit(gpu_input_batch_state state, int request_id, int processed_tokens) gpu_input_batch_state {
    int slot = input_batch_find(state, request_id)
    if slot < 0 || processed_tokens <= 0 { return state }
    int processed = processed_tokens
    if processed > state.scheduled_tokens[slot] { processed = state.scheduled_tokens[slot] }
    state.computed_tokens[slot] = state.computed_tokens[slot] + processed
    state.sequence_lengths[slot] = state.sequence_lengths[slot] + processed
    state
}

func input_batch_remove_request(gpu_input_batch_state state, int request_id) gpu_input_batch_state {
    int slot = input_batch_find(state, request_id)
    if slot < 0 { return state }
    state.active[slot] = 0
    state.block_counts[slot] = 0
    state.scheduled_tokens[slot] = 0
    state.request_count = state.request_count - 1
    state
}
