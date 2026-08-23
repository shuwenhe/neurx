package neurx.inference.kv.kv_event_stream

func kv_event_block_stored() int { 1 }

func kv_event_block_removed() int { 2 }

func kv_event_all_blocks_cleared() int { 3 }

func kv_medium_gpu() int { 1 }

func kv_medium_cpu() int { 2 }

func kv_medium_storage() int { 3 }

struct kv_event_stream_config {
    int capacity
    int data_parallel_rank
    int worker_count
    bool enabled
}

struct kv_event_stream_state {
    kv_event_stream_config config
    []int sequences
    []int event_types
    []int block_hashes
    []int parent_hashes
    []int mediums
    []int group_indices
    []int worker_masks
    int event_count
    int next_sequence
    int dropped_events
    int acknowledged_sequence
    bool initialized
}

struct kv_event_publish_result {
    kv_event_stream_state state
    int sequence
    bool published
}

struct kv_event_poll_result {
    []int sequences
    []int event_types
    []int block_hashes
    []int mediums
    []int group_indices
    int event_count
    int high_watermark
}

func kv_event_zero_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func kv_event_config_valid(kv_event_stream_config config) bool {
    if !config.enabled { return true }
    config.capacity > 0 && config.data_parallel_rank >= 0 && config.worker_count > 0
}

func init_kv_event_stream(kv_event_stream_config config) kv_event_stream_state {
    bool initialized = kv_event_config_valid(config)
    kv_event_stream_state {
        config: config,
        sequences: kv_event_zero_array(config.capacity),
        event_types: kv_event_zero_array(config.capacity),
        block_hashes: kv_event_zero_array(config.capacity),
        parent_hashes: kv_event_zero_array(config.capacity),
        mediums: kv_event_zero_array(config.capacity),
        group_indices: kv_event_zero_array(config.capacity),
        worker_masks: kv_event_zero_array(config.capacity),
        event_count: 0,
        next_sequence: 1,
        dropped_events: 0,
        acknowledged_sequence: 0,
        initialized: initialized,
    }
}

func kv_event_worker_marker(int worker_id) int {
    int marker = 1
    int i = 0
    while i < worker_id { marker = marker * 2; i = i + 1 }
    marker
}

func kv_event_marker_present(int mask, int marker) bool {
    int quotient = mask / marker
    quotient - (quotient / 2) * 2 == 1
}

func kv_event_worker_mask_complete(int mask, int worker_count) bool {
    int worker = 0
    while worker < worker_count {
        if !kv_event_marker_present(mask, kv_event_worker_marker(worker)) { return false }
        worker = worker + 1
    }
    true
}

func kv_event_shift_left(kv_event_stream_state state) kv_event_stream_state {
    int i = 1
    while i < state.event_count {
        state.sequences[i - 1] = state.sequences[i]
        state.event_types[i - 1] = state.event_types[i]
        state.block_hashes[i - 1] = state.block_hashes[i]
        state.parent_hashes[i - 1] = state.parent_hashes[i]
        state.mediums[i - 1] = state.mediums[i]
        state.group_indices[i - 1] = state.group_indices[i]
        state.worker_masks[i - 1] = state.worker_masks[i]
        i = i + 1
    }
    if state.event_count > 0 { state.event_count = state.event_count - 1 }
    state.dropped_events = state.dropped_events + 1
    state
}

func publish_kv_event(kv_event_stream_state state, int event_type, int block_hash, int parent_hash, int medium, int group_index, int worker_id) kv_event_publish_result {
    kv_event_stream_state current = state
    if !current.initialized || !current.config.enabled || event_type < kv_event_block_stored() || event_type > kv_event_all_blocks_cleared() || worker_id < 0 || worker_id >= current.config.worker_count {
        return kv_event_publish_result {state: current, sequence: 0, published: false}
    }
    int i = 0
    while i < current.event_count {
        if current.event_types[i] == event_type && current.block_hashes[i] == block_hash && current.mediums[i] == medium && current.group_indices[i] == group_index {
            int marker = kv_event_worker_marker(worker_id)
            if !kv_event_marker_present(current.worker_masks[i], marker) { current.worker_masks[i] = current.worker_masks[i] + marker }
            return kv_event_publish_result {state: current, sequence: current.sequences[i], published: true}
        }
        i = i + 1
    }
    if current.event_count >= current.config.capacity { current = kv_event_shift_left(current) }
    int slot = current.event_count
    int sequence = current.next_sequence
    current.sequences[slot] = sequence
    current.event_types[slot] = event_type
    current.block_hashes[slot] = block_hash
    current.parent_hashes[slot] = parent_hash
    current.mediums[slot] = medium
    current.group_indices[slot] = group_index
    current.worker_masks[slot] = kv_event_worker_marker(worker_id)
    current.event_count = current.event_count + 1
    current.next_sequence = sequence + 1
    kv_event_publish_result {state: current, sequence: sequence, published: true}
}

func poll_kv_events(kv_event_stream_state state, int after_sequence, bool common_only) kv_event_poll_result {
    []int sequences = kv_event_zero_array(state.event_count)
    []int types = kv_event_zero_array(state.event_count)
    []int hashes = kv_event_zero_array(state.event_count)
    []int mediums = kv_event_zero_array(state.event_count)
    []int groups = kv_event_zero_array(state.event_count)
    int count = 0
    int high_watermark = after_sequence
    int i = 0
    while i < state.event_count {
        bool common = kv_event_worker_mask_complete(state.worker_masks[i], state.config.worker_count)
        if state.sequences[i] > after_sequence && (!common_only || common) {
            sequences[count] = state.sequences[i]
            types[count] = state.event_types[i]
            hashes[count] = state.block_hashes[i]
            mediums[count] = state.mediums[i]
            groups[count] = state.group_indices[i]
            count = count + 1
            if state.sequences[i] > high_watermark { high_watermark = state.sequences[i] }
        }
        i = i + 1
    }
    kv_event_poll_result {sequences: sequences, event_types: types, block_hashes: hashes, mediums: mediums, group_indices: groups, event_count: count, high_watermark: high_watermark}
}

func acknowledge_kv_events(kv_event_stream_state state, int sequence) kv_event_stream_state {
    if sequence > state.acknowledged_sequence { state.acknowledged_sequence = sequence }
    state
}

func clear_kv_events(kv_event_stream_state state) kv_event_stream_state {
    state.event_count = 0
    state.acknowledged_sequence = state.next_sequence - 1
    state
}
