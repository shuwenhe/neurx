package neurx.inference.llm.streaming_session

func session_ok() int { 0 }

func session_not_found() int { 1 }

func session_duplicate() int { 2 }

func session_busy() int { 3 }

func session_streaming_rewrite_forbidden() int { 4 }

func session_invalid_parent() int { 5 }

struct streaming_session_config {
    int capacity
    int default_timeout_ms
}

struct streaming_session_state {
    streaming_session_config config
    []int session_ids
    []int streaming
    []int timeout_ms
    []int last_active_ms
    []int inflight
    []int close_on_finish
    []int last_request_ids
    []int pending_request_ids
    []int committed_origin_tokens
    []int committed_output_tokens
    []int pending_origin_tokens
    []int kv_committed_tokens
    []int kv_pages
    []int active
    int session_count
    int opened
    int closed
    int timed_out
    int rejected
}

struct session_update_result {
    streaming_session_state state
    int session_slot
    int context_tokens
    int status
    bool accepted
    bool released_kv
}

func session_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    for i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_streaming_session_state(streaming_session_config config) streaming_session_state {
    if config.capacity <= 0 { config.capacity = 1 }
    if config.capacity > 1024 { config.capacity = 1024 }
    if config.default_timeout_ms < 0 { config.default_timeout_ms = 0 }
    streaming_session_state {
        config: config,
        session_ids: session_int_array(config.capacity), streaming: session_int_array(config.capacity), timeout_ms: session_int_array(config.capacity), last_active_ms: session_int_array(config.capacity), inflight: session_int_array(config.capacity), close_on_finish: session_int_array(config.capacity), last_request_ids: session_int_array(config.capacity), pending_request_ids: session_int_array(config.capacity), committed_origin_tokens: session_int_array(config.capacity), committed_output_tokens: session_int_array(config.capacity), pending_origin_tokens: session_int_array(config.capacity), kv_committed_tokens: session_int_array(config.capacity), kv_pages: session_int_array(config.capacity), active: session_int_array(config.capacity),
        session_count: 0, opened: 0, closed: 0, timed_out: 0, rejected: 0,
    }
}

func session_find(streaming_session_state state, int session_id) int {
    int i = 0
    for i < state.config.capacity {
        if state.active[i] == 1 && state.session_ids[i] == session_id { return i }
        i = i + 1
    }
    0 - 1
}

func session_result(streaming_session_state state, int slot, int context_tokens, int status, bool accepted, bool released_kv) session_update_result {
    session_update_result {state: state, session_slot: slot, context_tokens: context_tokens, status: status, accepted: accepted, released_kv: released_kv}
}

func session_open(streaming_session_state state, int session_id, bool streaming, int timeout_ms, int now_ms) session_update_result {
    if session_id <= 0 || session_find(state, session_id) >= 0 { state.rejected = state.rejected + 1; return session_result(state, 0 - 1, 0, session_duplicate(), false, false) }
    int slot = 0 - 1
    int i = 0
    for i < state.config.capacity {
        if slot < 0 && state.active[i] == 0 { slot = i }
        i = i + 1
    }
    if slot < 0 { state.rejected = state.rejected + 1; return session_result(state, slot, 0, session_busy(), false, false) }
    int timeout = timeout_ms
    if timeout < 0 { timeout = state.config.default_timeout_ms }
    state.session_ids[slot] = session_id
    if streaming { state.streaming[slot] = 1 } else { state.streaming[slot] = 0 }
    state.timeout_ms[slot] = timeout
    state.last_active_ms[slot] = now_ms
    state.active[slot] = 1
    state.session_count = state.session_count + 1
    state.opened = state.opened + 1
    session_result(state, slot, 0, session_ok(), true, false)
}

func session_begin_request(streaming_session_state state, int session_id, int request_id, int input_tokens, int parent_request_id, bool replace, bool drop_previous_output, int offset, int now_ms) session_update_result {
    int slot = session_find(state, session_id)
    if slot < 0 { state.rejected = state.rejected + 1; return session_result(state, slot, 0, session_not_found(), false, false) }
    if state.inflight[slot] == 1 { state.rejected = state.rejected + 1; return session_result(state, slot, 0, session_busy(), false, false) }
    if state.streaming[slot] == 1 && (replace || drop_previous_output || offset != 0) { state.rejected = state.rejected + 1; return session_result(state, slot, 0, session_streaming_rewrite_forbidden(), false, false) }
    if state.streaming[slot] == 0 && parent_request_id != 0 && parent_request_id != state.last_request_ids[slot] { state.rejected = state.rejected + 1; return session_result(state, slot, 0, session_invalid_parent(), false, false) }
    int input = input_tokens
    if input < 0 { input = 0 }
    int context = state.committed_origin_tokens[slot] + state.committed_output_tokens[slot]
    if drop_previous_output { context = state.committed_origin_tokens[slot] }
    if replace { context = 0 }
    if offset > 0 && offset < context { context = offset }
    context = context + input
    state.pending_request_ids[slot] = request_id
    state.pending_origin_tokens[slot] = context
    state.inflight[slot] = 1
    state.last_active_ms[slot] = now_ms
    session_result(state, slot, context, session_ok(), true, false)
}

func session_release_slot(streaming_session_state state, int slot) session_update_result {
    if slot < 0 || slot >= state.config.capacity || state.active[slot] == 0 { return session_result(state, slot, 0, session_not_found(), false, false) }
    bool released = state.kv_pages[slot] > 0 || state.kv_committed_tokens[slot] > 0
    state.active[slot] = 0
    state.inflight[slot] = 0
    state.close_on_finish[slot] = 0
    state.kv_pages[slot] = 0
    state.kv_committed_tokens[slot] = 0
    state.session_count = state.session_count - 1
    state.closed = state.closed + 1
    session_result(state, slot, 0, session_ok(), true, released)
}

func session_finish_request(streaming_session_state state, int session_id, int request_id, int output_tokens, int kv_committed_tokens, int kv_pages, int now_ms) session_update_result {
    int slot = session_find(state, session_id)
    if slot < 0 { return session_result(state, slot, 0, session_not_found(), false, false) }
    if state.inflight[slot] == 0 || state.pending_request_ids[slot] != request_id { return session_result(state, slot, 0, session_invalid_parent(), false, false) }
    state.inflight[slot] = 0
    state.last_request_ids[slot] = request_id
    state.committed_origin_tokens[slot] = state.pending_origin_tokens[slot]
    state.committed_output_tokens[slot] = output_tokens
    state.kv_committed_tokens[slot] = kv_committed_tokens
    state.kv_pages[slot] = kv_pages
    state.pending_request_ids[slot] = 0
    state.last_active_ms[slot] = now_ms
    if state.close_on_finish[slot] == 1 { return session_release_slot(state, slot) }
    session_result(state, slot, state.committed_origin_tokens[slot] + state.committed_output_tokens[slot], session_ok(), true, false)
}

func session_abort_request(streaming_session_state state, int session_id, int request_id, int now_ms) session_update_result {
    int slot = session_find(state, session_id)
    if slot < 0 { return session_result(state, slot, 0, session_not_found(), false, false) }
    if state.inflight[slot] == 0 || state.pending_request_ids[slot] != request_id { return session_result(state, slot, 0, session_invalid_parent(), false, false) }
    state.inflight[slot] = 0
    state.pending_request_ids[slot] = 0
    state.pending_origin_tokens[slot] = 0
    state.last_active_ms[slot] = now_ms
    if state.close_on_finish[slot] == 1 { return session_release_slot(state, slot) }
    session_result(state, slot, state.committed_origin_tokens[slot] + state.committed_output_tokens[slot], session_ok(), true, false)
}

func session_close(streaming_session_state state, int session_id) session_update_result {
    int slot = session_find(state, session_id)
    if slot < 0 { return session_result(state, slot, 0, session_not_found(), false, false) }
    if state.inflight[slot] == 1 { state.close_on_finish[slot] = 1; return session_result(state, slot, 0, session_busy(), true, false) }
    session_release_slot(state, slot)
}

func session_reap_timeouts(streaming_session_state state, int now_ms) streaming_session_state {
    streaming_session_state current = state
    int i = 0
    for i < current.config.capacity {
        if current.active[i] == 1 && current.timeout_ms[i] > 0 && now_ms - current.last_active_ms[i] > current.timeout_ms[i] {
            current.timed_out = current.timed_out + 1
            if current.inflight[i] == 1 { current.close_on_finish[i] = 1 }
            else { session_update_result closed = session_release_slot(current, i); current = closed.state }
        }
        i = i + 1
    }
    current
}
