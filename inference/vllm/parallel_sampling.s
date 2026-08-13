package neurx.inference.vllm.parallel_sampling
struct parallel_sampling_config {
    int maximum_parents
    int maximum_children
}
struct parallel_sampling_state {
    parallel_sampling_config config
    []int parent_request_ids
    []int child_counts
    []int completed_children
    []int maximum_generated_tokens
    []int final_only
    []int active
    []int child_finished
    []int child_cancelled
    []int child_token_counts
    []float child_scores
    int parent_count
    int completed_parents
    int cancelled_children
}
struct parallel_sampling_result {
    parallel_sampling_state state
    int parent_request_id
    int child_request_id
    int child_index
    int best_child_index
    bool emit
    bool parent_complete
    bool accepted
}
func parallel_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}
func parallel_float_array(int capacity) []float {
    []float values = []float{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0.0; i = i + 1 }
    values
}
func new_parallel_sampling_state(parallel_sampling_config config) parallel_sampling_state {
    if config.maximum_parents <= 0 { config.maximum_parents = 1 }
    if config.maximum_children <= 0 { config.maximum_children = 1 }
    if config.maximum_children > 128 { config.maximum_children = 128 }
    int child_capacity = config.maximum_parents * config.maximum_children
    parallel_sampling_state {config: config, parent_request_ids: parallel_int_array(config.maximum_parents), child_counts: parallel_int_array(config.maximum_parents), completed_children: parallel_int_array(config.maximum_parents), maximum_generated_tokens: parallel_int_array(config.maximum_parents), final_only: parallel_int_array(config.maximum_parents), active: parallel_int_array(config.maximum_parents), child_finished: parallel_int_array(child_capacity), child_cancelled: parallel_int_array(child_capacity), child_token_counts: parallel_int_array(child_capacity), child_scores: parallel_float_array(child_capacity), parent_count: 0, completed_parents: 0, cancelled_children: 0}
}
func parallel_parent_find(parallel_sampling_state state, int parent_request_id) int {
    int i = 0
    while i < state.config.maximum_parents {
        if state.active[i] == 1 && state.parent_request_ids[i] == parent_request_id { return i }
        i = i + 1
    }
    0 - 1
}
func parallel_child_offset(parallel_sampling_state state, int parent_slot, int child_index) int {
    parent_slot * state.config.maximum_children + child_index
}
func parallel_child_request_id(int parent_request_id, int child_index) int {
    parent_request_id * 1000 + child_index + 1
}
func parallel_sampling_create(parallel_sampling_state state, int parent_request_id, int child_count, bool final_only) parallel_sampling_state {
    if parent_request_id <= 0 || child_count <= 0 || child_count > state.config.maximum_children || parallel_parent_find(state, parent_request_id) >= 0 || state.parent_count >= state.config.maximum_parents { return state }
    int slot = 0 - 1
    int i = 0
    while i < state.config.maximum_parents {
        if slot < 0 && state.active[i] == 0 { slot = i }
        i = i + 1
    }
    if slot < 0 { return state }
    state.active[slot] = 1
    state.parent_request_ids[slot] = parent_request_id
    state.child_counts[slot] = child_count
    if final_only { state.final_only[slot] = 1 }
    state.parent_count = state.parent_count + 1
    state
}
func parallel_best_child(parallel_sampling_state state, int parent_slot) int {
    int best = 0 - 1
    int child = 0
    while child < state.child_counts[parent_slot] {
        int offset = parallel_child_offset(state, parent_slot, child)
        if state.child_finished[offset] == 1 && state.child_cancelled[offset] == 0 {
            if best < 0 || state.child_scores[offset] > state.child_scores[parallel_child_offset(state, parent_slot, best)] { best = child }
        }
        child = child + 1
    }
    best
}
func parallel_sampling_complete_child(parallel_sampling_state state, int parent_request_id, int child_index, int generated_tokens, float score) parallel_sampling_result {
    int slot = parallel_parent_find(state, parent_request_id)
    if slot < 0 || child_index < 0 || child_index >= state.child_counts[slot] { return parallel_sampling_result {state: state, parent_request_id: parent_request_id, child_request_id: 0, child_index: child_index, best_child_index: 0 - 1, emit: false, parent_complete: false, accepted: false} }
    int offset = parallel_child_offset(state, slot, child_index)
    if state.child_finished[offset] == 1 || state.child_cancelled[offset] == 1 { return parallel_sampling_result {state: state, parent_request_id: parent_request_id, child_request_id: parallel_child_request_id(parent_request_id, child_index), child_index: child_index, best_child_index: parallel_best_child(state, slot), emit: false, parent_complete: false, accepted: false} }
    state.child_finished[offset] = 1
    state.child_token_counts[offset] = generated_tokens
    state.child_scores[offset] = score
    state.completed_children[slot] = state.completed_children[slot] + 1
    if generated_tokens > state.maximum_generated_tokens[slot] { state.maximum_generated_tokens[slot] = generated_tokens }
    bool complete = state.completed_children[slot] == state.child_counts[slot]
    if complete { state.completed_parents = state.completed_parents + 1 }
    bool emit = state.final_only[slot] == 0 || complete
    parallel_sampling_result {state: state, parent_request_id: parent_request_id, child_request_id: parallel_child_request_id(parent_request_id, child_index), child_index: child_index, best_child_index: parallel_best_child(state, slot), emit: emit, parent_complete: complete, accepted: true}
}
func parallel_sampling_cancel_remaining(parallel_sampling_state state, int parent_request_id) parallel_sampling_state {
    int slot = parallel_parent_find(state, parent_request_id)
    if slot < 0 { return state }
    int child = 0
    while child < state.child_counts[slot] {
        int offset = parallel_child_offset(state, slot, child)
        if state.child_finished[offset] == 0 && state.child_cancelled[offset] == 0 {
            state.child_cancelled[offset] = 1
            state.cancelled_children = state.cancelled_children + 1
        }
        child = child + 1
    }
    state
}
