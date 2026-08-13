package neurx.inference.sglang.pd_bootstrap_room
func pd_room_empty() int { 0 }

func pd_room_bootstrapping() int { 1 }

func pd_room_waiting_for_input() int { 2 }

func pd_room_transferring() int { 3 }

func pd_room_success() int { 4 }

func pd_room_failed() int { 5 }

struct pd_bootstrap_config {
    int capacity
    int bootstrap_timeout_ms
    int waiting_timeout_ms
}
struct pd_bootstrap_state {
    pd_bootstrap_config config
    []int room_ids
    []int request_ids
    []int statuses
    []int expected_peers
    []int ready_peers
    []int reserved_pages
    []int created_ms
    []int status_changed_ms
    []int failure_codes
    int active_rooms
    int completed_rooms
    int failed_rooms
}
struct pd_room_result {
    pd_bootstrap_state state
    int room_slot
    int status
    bool accepted
}
func pd_room_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}
func new_pd_bootstrap_state(pd_bootstrap_config config) pd_bootstrap_state {
    if config.capacity <= 0 { config.capacity = 1 }
    if config.capacity > 1024 { config.capacity = 1024 }
    if config.bootstrap_timeout_ms <= 0 { config.bootstrap_timeout_ms = 1 }
    if config.waiting_timeout_ms <= 0 { config.waiting_timeout_ms = 1 }
    pd_bootstrap_state {config: config, room_ids: pd_room_int_array(config.capacity), request_ids: pd_room_int_array(config.capacity), statuses: pd_room_int_array(config.capacity), expected_peers: pd_room_int_array(config.capacity), ready_peers: pd_room_int_array(config.capacity), reserved_pages: pd_room_int_array(config.capacity), created_ms: pd_room_int_array(config.capacity), status_changed_ms: pd_room_int_array(config.capacity), failure_codes: pd_room_int_array(config.capacity), active_rooms: 0, completed_rooms: 0, failed_rooms: 0}
}
func pd_find_room(pd_bootstrap_state state, int room_id) int {
    int i = 0
    while i < state.config.capacity {
        if state.statuses[i] != pd_room_empty() && state.room_ids[i] == room_id { return i }
        i = i + 1
    }
    0 - 1
}
func pd_room_result_of(pd_bootstrap_state state, int slot, bool accepted) pd_room_result {
    int status = pd_room_empty()
    if slot >= 0 { status = state.statuses[slot] }
    pd_room_result {state: state, room_slot: slot, status: status, accepted: accepted}
}
func pd_create_room(pd_bootstrap_state state, int room_id, int request_id, int expected_peers, int reserved_pages, int now_ms) pd_room_result {
    if room_id <= 0 || request_id <= 0 || expected_peers <= 0 || reserved_pages < 0 || pd_find_room(state, room_id) >= 0 { return pd_room_result_of(state, -1, false) }
    int slot = 0 - 1
    int i = 0
    while i < state.config.capacity {
        if slot < 0 && state.statuses[i] == pd_room_empty() { slot = i }
        i = i + 1
    }
    if slot < 0 { return pd_room_result_of(state, slot, false) }
    state.room_ids[slot] = room_id
    state.request_ids[slot] = request_id
    state.statuses[slot] = pd_room_bootstrapping()
    state.expected_peers[slot] = expected_peers
    state.ready_peers[slot] = 0
    state.reserved_pages[slot] = reserved_pages
    state.created_ms[slot] = now_ms
    state.status_changed_ms[slot] = now_ms
    state.failure_codes[slot] = 0
    state.active_rooms = state.active_rooms + 1
    pd_room_result_of(state, slot, true)
}
func pd_room_peer_ready(pd_bootstrap_state state, int room_id, int now_ms) pd_room_result {
    int slot = pd_find_room(state, room_id)
    if slot < 0 || state.statuses[slot] != pd_room_bootstrapping() { return pd_room_result_of(state, slot, false) }
    if state.ready_peers[slot] < state.expected_peers[slot] { state.ready_peers[slot] = state.ready_peers[slot] + 1 }
    if state.ready_peers[slot] >= state.expected_peers[slot] {
        state.statuses[slot] = pd_room_waiting_for_input()
        state.status_changed_ms[slot] = now_ms
    }
    pd_room_result_of(state, slot, true)
}
func pd_room_start_transfer(pd_bootstrap_state state, int room_id, int now_ms) pd_room_result {
    int slot = pd_find_room(state, room_id)
    if slot < 0 || state.statuses[slot] != pd_room_waiting_for_input() { return pd_room_result_of(state, slot, false) }
    state.statuses[slot] = pd_room_transferring()
    state.status_changed_ms[slot] = now_ms
    pd_room_result_of(state, slot, true)
}
func pd_room_complete(pd_bootstrap_state state, int room_id, bool success, int failure_code, int now_ms) pd_room_result {
    int slot = pd_find_room(state, room_id)
    if slot < 0 || state.statuses[slot] != pd_room_transferring() { return pd_room_result_of(state, slot, false) }
    if success {
        state.statuses[slot] = pd_room_success()
        state.completed_rooms = state.completed_rooms + 1
    } else {
        state.statuses[slot] = pd_room_failed()
        state.failure_codes[slot] = failure_code
        state.failed_rooms = state.failed_rooms + 1
    }
    state.status_changed_ms[slot] = now_ms
    state.active_rooms = state.active_rooms - 1
    pd_room_result_of(state, slot, true)
}
func pd_room_poll(pd_bootstrap_state state, int room_id, int now_ms) pd_room_result {
    int slot = pd_find_room(state, room_id)
    if slot < 0 { return pd_room_result_of(state, slot, false) }
    bool timeout = false
    if state.statuses[slot] == pd_room_bootstrapping() && now_ms - state.created_ms[slot] > state.config.bootstrap_timeout_ms { timeout = true }
    bool waiting = state.statuses[slot] == pd_room_waiting_for_input() || state.statuses[slot] == pd_room_transferring()
    if waiting && now_ms - state.status_changed_ms[slot] > state.config.waiting_timeout_ms { timeout = true }
    if timeout {
        state.statuses[slot] = pd_room_failed()
        state.failure_codes[slot] = 408
        state.failed_rooms = state.failed_rooms + 1
        state.active_rooms = state.active_rooms - 1
    }
    pd_room_result_of(state, slot, true)
}
func pd_room_release(pd_bootstrap_state state, int room_id) pd_bootstrap_state {
    int slot = pd_find_room(state, room_id)
    if slot < 0 { return state }
    if state.statuses[slot] == pd_room_bootstrapping() || state.statuses[slot] == pd_room_waiting_for_input() || state.statuses[slot] == pd_room_transferring() { state.active_rooms = state.active_rooms - 1 }
    state.statuses[slot] = pd_room_empty()
    state.room_ids[slot] = 0
    state.request_ids[slot] = 0
    state.reserved_pages[slot] = 0
    state
}
