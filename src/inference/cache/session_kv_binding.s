package neurx.inference.cache.session_kv_binding

func kv_owner_none() int { 0 }

func kv_owner_request() int { 1 }

func kv_owner_session() int { 2 }

struct session_kv_binding_config {
    int capacity
    int page_size
    int maximum_pages_per_session
}

struct session_kv_binding_state {
    session_kv_binding_config config
    []int session_ids
    []int request_ids
    []int request_pool_indices
    []int committed_tokens
    []int allocated_tokens
    []int page_counts
    []int first_page_ids
    []int page_ids
    []int ownership
    []int active
    int binding_count
    int saved_count
    int restored_count
    int freed_tail_pages
    int released_pages
}

struct session_kv_result {
    session_kv_binding_state state
    int slot
    int request_pool_index
    int committed_tokens
    int page_count
    bool success
}

func session_kv_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_session_kv_binding(session_kv_binding_config config) session_kv_binding_state {
    if config.capacity <= 0 { config.capacity = 1 }
    if config.capacity > 1024 { config.capacity = 1024 }
    if config.page_size <= 0 { config.page_size = 1 }
    if config.maximum_pages_per_session <= 0 { config.maximum_pages_per_session = 1 }
    session_kv_binding_state {config: config, session_ids: session_kv_int_array(config.capacity), request_ids: session_kv_int_array(config.capacity), request_pool_indices: session_kv_int_array(config.capacity), committed_tokens: session_kv_int_array(config.capacity), allocated_tokens: session_kv_int_array(config.capacity), page_counts: session_kv_int_array(config.capacity), first_page_ids: session_kv_int_array(config.capacity), page_ids: session_kv_int_array(config.capacity * config.maximum_pages_per_session), ownership: session_kv_int_array(config.capacity), active: session_kv_int_array(config.capacity), binding_count: 0, saved_count: 0, restored_count: 0, freed_tail_pages: 0, released_pages: 0}
}

func session_kv_page_offset(session_kv_binding_state state, int slot, int page_index) int {
    slot * state.config.maximum_pages_per_session + page_index
}

func session_kv_find(session_kv_binding_state state, int session_id) int {
    int i = 0
    while i < state.config.capacity {
        if state.active[i] == 1 && state.session_ids[i] == session_id { return i }
        i = i + 1
    }
    0 - 1
}

func session_kv_result_of(session_kv_binding_state state, int slot, bool success) session_kv_result {
    if slot < 0 { return session_kv_result {state: state, slot: slot, request_pool_index: 0, committed_tokens: 0, page_count: 0, success: success} }
    session_kv_result {state: state, slot: slot, request_pool_index: state.request_pool_indices[slot], committed_tokens: state.committed_tokens[slot], page_count: state.page_counts[slot], success: success}
}

func session_kv_save(session_kv_binding_state state, int session_id, int request_id, int request_pool_index, int committed_tokens, int allocated_tokens, int first_page_id) session_kv_result {
    if session_id <= 0 || request_id <= 0 || request_pool_index < 0 || committed_tokens < 0 || allocated_tokens < committed_tokens { return session_kv_result_of(state, -1, false) }
    int pages = (allocated_tokens + state.config.page_size - 1) / state.config.page_size
    if pages > state.config.maximum_pages_per_session { return session_kv_result_of(state, -1, false) }
    int slot = session_kv_find(state, session_id)
    if slot < 0 {
        int i = 0
        while i < state.config.capacity {
            if slot < 0 && state.active[i] == 0 { slot = i }
            i = i + 1
        }
        if slot < 0 { return session_kv_result_of(state, slot, false) }
        state.active[slot] = 1
        state.session_ids[slot] = session_id
        state.binding_count = state.binding_count + 1
    }
    state.request_ids[slot] = request_id
    state.request_pool_indices[slot] = request_pool_index
    state.committed_tokens[slot] = committed_tokens
    state.allocated_tokens[slot] = allocated_tokens
    state.page_counts[slot] = pages
    state.first_page_ids[slot] = first_page_id
    int page_index = 0
    while page_index < state.config.maximum_pages_per_session {
        int offset = session_kv_page_offset(state, slot, page_index)
        state.page_ids[offset] = 0
        if page_index < pages && first_page_id > 0 { state.page_ids[offset] = first_page_id + page_index }
        page_index = page_index + 1
    }
    state.ownership[slot] = kv_owner_session()
    state.saved_count = state.saved_count + 1
    session_kv_result_of(state, slot, true)
}

func session_kv_restore(session_kv_binding_state state, int session_id, int request_id, int requested_prefix_tokens) session_kv_result {
    int slot = session_kv_find(state, session_id)
    if slot < 0 || state.ownership[slot] != kv_owner_session() { return session_kv_result_of(state, slot, false) }
    int prefix = requested_prefix_tokens
    if prefix > state.committed_tokens[slot] { prefix = state.committed_tokens[slot] }
    if prefix < 0 { prefix = 0 }
    int old_pages = state.page_counts[slot]
    int kept_pages = (prefix + state.config.page_size - 1) / state.config.page_size
    if kept_pages < old_pages { state.freed_tail_pages = state.freed_tail_pages + old_pages - kept_pages }
    int page_index = kept_pages
    while page_index < old_pages {
        state.page_ids[session_kv_page_offset(state, slot, page_index)] = 0
        page_index = page_index + 1
    }
    state.request_ids[slot] = request_id
    state.committed_tokens[slot] = prefix
    state.allocated_tokens[slot] = prefix
    state.page_counts[slot] = kept_pages
    state.ownership[slot] = kv_owner_request()
    state.restored_count = state.restored_count + 1
    session_kv_result_of(state, slot, true)
}

func session_kv_bind_page(session_kv_binding_state state, int session_id, int page_index, int page_id) session_kv_binding_state {
    int slot = session_kv_find(state, session_id)
    if slot < 0 || page_index < 0 || page_index >= state.page_counts[slot] || page_id < 0 { return state }
    state.page_ids[session_kv_page_offset(state, slot, page_index)] = page_id
    if page_index == 0 { state.first_page_ids[slot] = page_id }
    state
}

func session_kv_page_id(session_kv_binding_state state, int session_id, int page_index) int {
    int slot = session_kv_find(state, session_id)
    if slot < 0 || page_index < 0 || page_index >= state.page_counts[slot] { return 0 - 1 }
    state.page_ids[session_kv_page_offset(state, slot, page_index)]
}

func session_kv_return_to_session(session_kv_binding_state state, int session_id, int committed_tokens, int allocated_tokens) session_kv_binding_state {
    int slot = session_kv_find(state, session_id)
    if slot < 0 || state.ownership[slot] != kv_owner_request() { return state }
    state.committed_tokens[slot] = committed_tokens
    state.allocated_tokens[slot] = allocated_tokens
    state.page_counts[slot] = (allocated_tokens + state.config.page_size - 1) / state.config.page_size
    state.ownership[slot] = kv_owner_session()
    state
}

func session_kv_release(session_kv_binding_state state, int session_id) session_kv_binding_state {
    int slot = session_kv_find(state, session_id)
    if slot < 0 { return state }
    state.released_pages = state.released_pages + state.page_counts[slot]
    int page_index = 0
    while page_index < state.page_counts[slot] {
        state.page_ids[session_kv_page_offset(state, slot, page_index)] = 0
        page_index = page_index + 1
    }
    state.active[slot] = 0
    state.ownership[slot] = kv_owner_none()
    state.page_counts[slot] = 0
    state.binding_count = state.binding_count - 1
    state
}
