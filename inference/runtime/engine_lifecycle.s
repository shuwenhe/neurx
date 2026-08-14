package neurx.inference.runtime.engine_lifecycle
func engine_awake_status() int { 1 }

func engine_sleeping_status() int { 2 }

func engine_asleep_status() int { 3 }

func engine_waking_status() int { 4 }

func segment_device_residency() int { 1 }

func segment_host_residency() int { 2 }

func segment_discarded_residency() int { 3 }

struct engine_memory_segment {
    string segment_id
    string tag
    int byte_count
    int residency
    int pending_residency
    bool reloadable
    bool mutable
    string snapshot_checksum
    int generation
}

struct engine_memory_transfer {
    string segment_id
    string tag
    string operation
    int byte_count
    int transition_id
    int generation
}

struct engine_lifecycle_state {
    bool enabled
    string backend_name
    int status
    int previous_status
    int sleep_level
    int pending_sleep_level
    int transition_id
    []engine_memory_segment segments
    []string sleeping_tags
    []string active_request_ids
    int device_bytes
    int host_bytes
    int reclaimed_bytes
    int total_sleeps
    int total_wakes
    int failed_transitions
    bool preserves_communicators
    bool preserves_compiled_artifacts
    string last_error
}

struct engine_lifecycle_result {
    engine_lifecycle_state state
    []engine_memory_transfer transfers
    []string aborted_request_ids
    bool accepted
    bool pending
    int transition_id
    string error_message
}

func new_engine_lifecycle_result(engine_lifecycle_state state, bool accepted, bool pending, string error_message) engine_lifecycle_result {
    engine_lifecycle_result result
    result.state = state
    result.transfers = []
    result.aborted_request_ids = []
    result.accepted = accepted
    result.pending = pending
    result.transition_id = state.transition_id
    result.error_message = error_message
    result
}

func new_engine_lifecycle(bool enabled, string backend_name, bool preserves_communicators, bool preserves_compiled_artifacts) engine_lifecycle_state {
    engine_lifecycle_state state
    state.enabled = enabled
    state.backend_name = backend_name
    state.status = engine_awake_status()
    state.previous_status = engine_awake_status()
    state.sleep_level = 0
    state.pending_sleep_level = 0
    state.transition_id = 0
    state.segments = []
    state.sleeping_tags = []
    state.active_request_ids = []
    state.device_bytes = 0
    state.host_bytes = 0
    state.reclaimed_bytes = 0
    state.total_sleeps = 0
    state.total_wakes = 0
    state.failed_transitions = 0
    state.preserves_communicators = preserves_communicators
    state.preserves_compiled_artifacts = preserves_compiled_artifacts
    state.last_error = ""
    state
}

func engine_string_contains([]string values, string expected) bool {
    int i = 0
    while i < len(values) {
        if values[i] == expected { return true }
        i = i + 1
    }
    false
}

func engine_string_append_unique([]string values, string value) []string {
    if value == "" || engine_string_contains(values, value) { return values }
    append(values, value)
}

func engine_string_remove([]string values, string expected) []string {
    []string result = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        if values[i] != expected { result = append(result, values[i]) }
        i = i + 1
    }
    result
}

func engine_segment_at(engine_lifecycle_state state, int index) engine_memory_segment {
    state.segments[index]
}

func engine_find_segment(engine_lifecycle_state state, string segment_id) int {
    int i = 0
    while i < len(state.segments) {
        if state.segments[i].segment_id == segment_id { return i }
        i = i + 1
    }
    -1
}

func engine_recount_memory(engine_lifecycle_state state) engine_lifecycle_state {
    state.device_bytes = 0
    state.host_bytes = 0
    int i = 0
    while i < len(state.segments) {
        engine_memory_segment segment = engine_segment_at(state, i)
        if segment.residency == segment_device_residency() {
            state.device_bytes = state.device_bytes + segment.byte_count
        } else if segment.residency == segment_host_residency() {
            state.host_bytes = state.host_bytes + segment.byte_count
        }
        i = i + 1
    }
    state
}

func engine_register_segment(engine_lifecycle_state state, string segment_id, string tag, int byte_count, bool reloadable, bool mutable, string snapshot_checksum) engine_lifecycle_result {
    if segment_id == "" || tag == "" || byte_count < 0 || engine_find_segment(state, segment_id) >= 0 {
        return new_engine_lifecycle_result(state, false, false, "invalid or duplicate memory segment")
    }
    if state.status != engine_awake_status() {
        return new_engine_lifecycle_result(state, false, false, "memory segments can only be registered while awake")
    }
    engine_memory_segment segment
    segment.segment_id = segment_id
    segment.tag = tag
    segment.byte_count = byte_count
    segment.residency = segment_device_residency()
    segment.pending_residency = 0
    segment.reloadable = reloadable
    segment.mutable = mutable
    segment.snapshot_checksum = snapshot_checksum
    segment.generation = 1
    state.segments = append(state.segments, segment)
    state = engine_recount_memory(state)
    new_engine_lifecycle_result(state, true, false, "")
}

func engine_begin_request(engine_lifecycle_state state, string request_id) engine_lifecycle_result {
    if request_id == "" || engine_string_contains(state.active_request_ids, request_id) {
        return new_engine_lifecycle_result(state, false, false, "invalid or duplicate request")
    }
    if state.status != engine_awake_status() {
        return new_engine_lifecycle_result(state, false, false, "engine is not awake")
    }
    state.active_request_ids = append(state.active_request_ids, request_id)
    new_engine_lifecycle_result(state, true, false, "")
}

func engine_end_request(engine_lifecycle_state state, string request_id) engine_lifecycle_result {
    if !engine_string_contains(state.active_request_ids, request_id) {
        return new_engine_lifecycle_result(state, false, false, "active request not found")
    }
    state.active_request_ids = engine_string_remove(state.active_request_ids, request_id)
    new_engine_lifecycle_result(state, true, false, "")
}

func engine_sleep_target(engine_memory_segment segment, int level) int {
    if level == 1 && segment.tag == "weights" { return segment_host_residency() }
    if level == 2 && segment.mutable && !segment.reloadable { return segment_host_residency() }
    segment_discarded_residency()
}

func engine_transfer_for(engine_memory_segment segment, int target, int transition_id) engine_memory_transfer {
    engine_memory_transfer transfer
    transfer.segment_id = segment.segment_id
    transfer.tag = segment.tag
    if target == segment_host_residency() {
        transfer.operation = "device_to_host"
    } else if target == segment_device_residency() && segment.residency == segment_host_residency() {
        transfer.operation = "host_to_device"
    } else if target == segment_device_residency() {
        transfer.operation = "reload_to_device"
    } else {
        transfer.operation = "discard_device"
    }
    transfer.byte_count = segment.byte_count
    transfer.transition_id = transition_id
    transfer.generation = segment.generation
    transfer
}

func engine_begin_sleep(engine_lifecycle_state state, int level, string mode) engine_lifecycle_result {
    engine_lifecycle_result result = new_engine_lifecycle_result(state, false, false, "")
    if !state.enabled { return new_engine_lifecycle_result(state, false, false, "sleep mode is disabled") }
    if state.status == engine_asleep_status() { return new_engine_lifecycle_result(state, true, false, "") }
    if state.status != engine_awake_status() { return new_engine_lifecycle_result(state, false, false, "engine lifecycle transition is active") }
    if level != 1 && level != 2 { return new_engine_lifecycle_result(state, false, false, "sleep level must be 1 or 2") }
    if mode != "abort" && mode != "wait" { return new_engine_lifecycle_result(state, false, false, "sleep mode must be abort or wait") }
    if mode == "wait" && len(state.active_request_ids) > 0 {
        engine_lifecycle_result waiting = new_engine_lifecycle_result(state, true, true, "")
        return waiting
    }
    if mode == "abort" { result.aborted_request_ids = state.active_request_ids }
    state.active_request_ids = []
    state.previous_status = state.status
    state.status = engine_sleeping_status()
    state.pending_sleep_level = level
    state.transition_id = state.transition_id + 1
    state.last_error = ""
    int i = 0
    while i < len(state.segments) {
        engine_memory_segment segment = engine_segment_at(state, i)
        if segment.residency == segment_device_residency() {
            int target = engine_sleep_target(segment, level)
            segment.pending_residency = target
            state.segments[i] = segment
            result.transfers = append(result.transfers, engine_transfer_for(segment, target, state.transition_id))
        }
        i = i + 1
    }
    result.state = state
    result.accepted = true
    result.transition_id = state.transition_id
    result
}

func engine_tag_selected([]string tags, string tag) bool {
    len(tags) == 0 || engine_string_contains(tags, tag)
}

func engine_begin_wake(engine_lifecycle_state state, []string tags) engine_lifecycle_result {
    engine_lifecycle_result result = new_engine_lifecycle_result(state, false, false, "")
    if state.status == engine_awake_status() { return new_engine_lifecycle_result(state, true, false, "") }
    if state.status != engine_asleep_status() { return new_engine_lifecycle_result(state, false, false, "engine lifecycle transition is active") }
    int i = 0
    while i < len(tags) {
        if !engine_string_contains(state.sleeping_tags, tags[i]) {
            return new_engine_lifecycle_result(state, false, false, "wake tag is not sleeping")
        }
        i = i + 1
    }
    i = 0
    while i < len(state.segments) {
        engine_memory_segment candidate = engine_segment_at(state, i)
        if engine_tag_selected(tags, candidate.tag) && candidate.residency == segment_discarded_residency() && !candidate.reloadable {
            return new_engine_lifecycle_result(state, false, false, "discarded segment is not reloadable")
        }
        i = i + 1
    }
    state.previous_status = state.status
    state.status = engine_waking_status()
    state.transition_id = state.transition_id + 1
    state.last_error = ""
    i = 0
    while i < len(state.segments) {
        engine_memory_segment segment = engine_segment_at(state, i)
        if engine_tag_selected(tags, segment.tag) && segment.residency != segment_device_residency() {
            segment.pending_residency = segment_device_residency()
            state.segments[i] = segment
            result.transfers = append(result.transfers, engine_transfer_for(segment, segment_device_residency(), state.transition_id))
        }
        i = i + 1
    }
    result.state = state
    result.accepted = true
    result.transition_id = state.transition_id
    result
}

func engine_clear_pending(engine_lifecycle_state state) engine_lifecycle_state {
    int i = 0
    while i < len(state.segments) {
        engine_memory_segment segment = engine_segment_at(state, i)
        segment.pending_residency = 0
        state.segments[i] = segment
        i = i + 1
    }
    state.pending_sleep_level = 0
    state
}

func engine_rebuild_sleeping_tags(engine_lifecycle_state state) engine_lifecycle_state {
    state.sleeping_tags = []
    int i = 0
    while i < len(state.segments) {
        engine_memory_segment segment = engine_segment_at(state, i)
        if segment.residency != segment_device_residency() {
            state.sleeping_tags = engine_string_append_unique(state.sleeping_tags, segment.tag)
        }
        i = i + 1
    }
    state
}

func engine_commit_transition(engine_lifecycle_state state, int transition_id, bool success, string error_message) engine_lifecycle_result {
    if state.status != engine_sleeping_status() && state.status != engine_waking_status() {
        return new_engine_lifecycle_result(state, false, false, "no lifecycle transition is active")
    }
    if transition_id != state.transition_id {
        return new_engine_lifecycle_result(state, false, false, "stale lifecycle transition")
    }
    int transition_status = state.status
    if !success {
        state.status = state.previous_status
        state.failed_transitions = state.failed_transitions + 1
        state.last_error = error_message
        state = engine_clear_pending(state)
        return new_engine_lifecycle_result(state, false, false, error_message)
    }
    int device_bytes_before = state.device_bytes
    int i = 0
    while i < len(state.segments) {
        engine_memory_segment segment = engine_segment_at(state, i)
        if segment.pending_residency != 0 {
            segment.residency = segment.pending_residency
            segment.pending_residency = 0
            segment.generation = segment.generation + 1
            state.segments[i] = segment
        }
        i = i + 1
    }
    if transition_status == engine_sleeping_status() {
        state.sleep_level = state.pending_sleep_level
        state.status = engine_asleep_status()
        state.total_sleeps = state.total_sleeps + 1
    } else {
        state.status = engine_asleep_status()
        state.total_wakes = state.total_wakes + 1
    }
    state = engine_clear_pending(state)
    state = engine_recount_memory(state)
    state = engine_rebuild_sleeping_tags(state)
    if len(state.sleeping_tags) == 0 {
        state.status = engine_awake_status()
        state.sleep_level = 0
    }
    if device_bytes_before > state.device_bytes {
        state.reclaimed_bytes = state.reclaimed_bytes + device_bytes_before - state.device_bytes
    }
    state.last_error = ""
    new_engine_lifecycle_result(state, true, false, "")
}

func engine_is_available(engine_lifecycle_state state) bool {
    state.status == engine_awake_status()
}

func engine_is_sleeping(engine_lifecycle_state state) bool {
    state.status == engine_sleeping_status() || state.status == engine_asleep_status()
}

func engine_status_name(engine_lifecycle_state state) string {
    if state.status == engine_awake_status() { return "awake" }
    if state.status == engine_sleeping_status() { return "sleeping" }
    if state.status == engine_asleep_status() { return "asleep" }
    if state.status == engine_waking_status() { return "waking" }
    "unknown"
}
