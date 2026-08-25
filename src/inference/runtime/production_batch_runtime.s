package neurx.inference.runtime.production_batch_runtime
use neurx.inference.runtime.transformer_executor.{transformer_execution_plan, transformer_execution_result, transformer_plan_execute}

func production_request_free() int { 0 }

func production_request_waiting() int { 1 }

func production_request_prefill() int { 2 }

func production_request_decode() int { 3 }

func production_request_finished() int { 4 }

func production_request_cancelled() int { 5 }

struct production_batch_config {
    int request_capacity
    int page_capacity
    int page_size
    int maximum_pages_per_request
    int maximum_batch_sequences
    int maximum_batch_tokens
}

struct production_batch_runtime {
    production_batch_config config
    []int session_id
    []int request_id
    []int status
    []int prompt_tokens
    []int maximum_new_tokens
    []int generated_tokens
    []int page_count
    []int page_id
    []int page_owner
    int active_requests
    int queued_requests
    int allocated_pages
    int scheduling_round
    int completed_requests
    int rejected_requests
}

struct production_batch_selection {
    production_batch_runtime runtime
    []int prefill_slot
    []int decode_slot
    int prefill_count
    int decode_count
    int prefill_tokens
    int decode_tokens
    bool selected
}

struct production_admission_result {
    production_batch_runtime runtime
    int slot
    bool accepted
    string error_message
}

func production_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int index = 0
    for index < capacity { values[index] = 0; index = index + 1 }
    values
}

func new_production_batch_runtime(production_batch_config config) production_batch_runtime {
    if config.request_capacity <= 0 { config.request_capacity = 1 }
    if config.page_capacity <= 0 { config.page_capacity = 1 }
    if config.page_size <= 0 { config.page_size = 16 }
    if config.maximum_pages_per_request <= 0 { config.maximum_pages_per_request = 1 }
    if config.maximum_batch_sequences <= 0 { config.maximum_batch_sequences = 1 }
    if config.maximum_batch_tokens <= 0 { config.maximum_batch_tokens = 1 }
    production_batch_runtime {config: config, session_id: production_int_array(config.request_capacity), request_id: production_int_array(config.request_capacity), status: production_int_array(config.request_capacity), prompt_tokens: production_int_array(config.request_capacity), maximum_new_tokens: production_int_array(config.request_capacity), generated_tokens: production_int_array(config.request_capacity), page_count: production_int_array(config.request_capacity), page_id: production_int_array(config.request_capacity * config.maximum_pages_per_request), page_owner: production_int_array(config.page_capacity), active_requests: 0, queued_requests: 0, allocated_pages: 0, scheduling_round: 0, completed_requests: 0, rejected_requests: 0}
}

func production_page_offset(production_batch_runtime runtime, int slot, int page_index) int {
    slot * runtime.config.maximum_pages_per_request + page_index
}

func production_find_free_slot(production_batch_runtime runtime) int {
    int slot = 0
    for slot < runtime.config.request_capacity {
        if runtime.status[slot] == production_request_free() || runtime.status[slot] == production_request_finished() || runtime.status[slot] == production_request_cancelled() { return slot }
        slot = slot + 1
    }
    -1
}

func production_free_page_count(production_batch_runtime runtime) int {
    runtime.config.page_capacity - runtime.allocated_pages
}

func production_release_slot_pages(production_batch_runtime runtime, int slot) production_batch_runtime {
    int page_index = 0
    for page_index < runtime.page_count[slot] {
        int offset = production_page_offset(runtime, slot, page_index)
        int page = runtime.page_id[offset]
        if page >= 0 && page < runtime.config.page_capacity && runtime.page_owner[page] == slot + 1 {
            runtime.page_owner[page] = 0
            runtime.allocated_pages = runtime.allocated_pages - 1
        }
        runtime.page_id[offset] = 0
        page_index = page_index + 1
    }
    runtime.page_count[slot] = 0
    runtime
}

func production_admit(production_batch_runtime runtime, int session_id, int request_id, int prompt_tokens, int maximum_new_tokens) production_admission_result {
    production_batch_runtime next = runtime
    if session_id <= 0 || request_id <= 0 || prompt_tokens <= 0 || maximum_new_tokens <= 0 {
        next.rejected_requests = next.rejected_requests + 1
        return production_admission_result {runtime: next, slot: -1, accepted: false, error_message: "invalid_request"}
    }
    int slot = production_find_free_slot(next)
    int required_pages = (prompt_tokens + maximum_new_tokens + next.config.page_size - 1) / next.config.page_size
    if slot < 0 || required_pages > next.config.maximum_pages_per_request || required_pages > production_free_page_count(next) {
        next.rejected_requests = next.rejected_requests + 1
        return production_admission_result {runtime: next, slot: -1, accepted: false, error_message: "kv_capacity_exhausted"}
    }
    next = production_release_slot_pages(next, slot)
    int allocated = 0
    int page = 0
    for page < next.config.page_capacity && allocated < required_pages {
        if next.page_owner[page] == 0 {
            next.page_owner[page] = slot + 1
            next.page_id[production_page_offset(next, slot, allocated)] = page
            next.allocated_pages = next.allocated_pages + 1
            allocated = allocated + 1
        }
        page = page + 1
    }
    next.session_id[slot] = session_id
    next.request_id[slot] = request_id
    next.status[slot] = production_request_waiting()
    next.prompt_tokens[slot] = prompt_tokens
    next.maximum_new_tokens[slot] = maximum_new_tokens
    next.generated_tokens[slot] = 0
    next.page_count[slot] = allocated
    next.queued_requests = next.queued_requests + 1
    production_admission_result {runtime: next, slot: slot, accepted: true, error_message: ""}
}

func production_schedule(production_batch_runtime runtime) production_batch_selection {
    []int prefill = production_int_array(runtime.config.maximum_batch_sequences)
    []int decode = production_int_array(runtime.config.maximum_batch_sequences)
    int prefill_count = 0
    int decode_count = 0
    int token_budget = runtime.config.maximum_batch_tokens
    int slot = 0
    for slot < runtime.config.request_capacity && prefill_count < runtime.config.maximum_batch_sequences {
        if runtime.status[slot] == production_request_waiting() && runtime.prompt_tokens[slot] <= token_budget {
            prefill[prefill_count] = slot
            prefill_count = prefill_count + 1
            token_budget = token_budget - runtime.prompt_tokens[slot]
            runtime.status[slot] = production_request_prefill()
            runtime.queued_requests = runtime.queued_requests - 1
            runtime.active_requests = runtime.active_requests + 1
        }
        slot = slot + 1
    }
    slot = 0
    for slot < runtime.config.request_capacity && decode_count + prefill_count < runtime.config.maximum_batch_sequences && token_budget > 0 {
        if runtime.status[slot] == production_request_decode() {
            decode[decode_count] = slot
            decode_count = decode_count + 1
            token_budget = token_budget - 1
        }
        slot = slot + 1
    }
    int prefill_token_count = 0
    int index = 0
    for index < prefill_count { prefill_token_count = prefill_token_count + runtime.prompt_tokens[prefill[index]]; index = index + 1 }
    runtime.scheduling_round = runtime.scheduling_round + 1
    production_batch_selection {runtime: runtime, prefill_slot: prefill, decode_slot: decode, prefill_count: prefill_count, decode_count: decode_count, prefill_tokens: prefill_token_count, decode_tokens: decode_count, selected: prefill_count + decode_count > 0}
}

func production_mark_prefill_complete(production_batch_runtime runtime, []int slots, int count) production_batch_runtime {
    int index = 0
    for index < count {
        int slot = slots[index]
        if slot >= 0 && slot < runtime.config.request_capacity && runtime.status[slot] == production_request_prefill() { runtime.status[slot] = production_request_decode() }
        index = index + 1
    }
    runtime
}

func production_record_decode(production_batch_runtime runtime, int slot, int token_count, bool stopped) production_batch_runtime {
    production_batch_runtime next = runtime
    if slot < 0 || slot >= next.config.request_capacity || next.status[slot] != production_request_decode() { return next }
    if token_count > 0 { next.generated_tokens[slot] = next.generated_tokens[slot] + token_count }
    if stopped || next.generated_tokens[slot] >= next.maximum_new_tokens[slot] {
        next = production_release_slot_pages(next, slot)
        next.status[slot] = production_request_finished()
        next.active_requests = next.active_requests - 1
        next.completed_requests = next.completed_requests + 1
    }
    next
}

func production_cancel(production_batch_runtime runtime, int session_id) production_batch_runtime {
    production_batch_runtime next = runtime
    int slot = 0
    for slot < next.config.request_capacity {
        if next.session_id[slot] == session_id && next.status[slot] != production_request_free() && next.status[slot] != production_request_finished() {
            if next.status[slot] == production_request_waiting() { next.queued_requests = next.queued_requests - 1 }
            else { next.active_requests = next.active_requests - 1 }
            next = production_release_slot_pages(next, slot)
            next.status[slot] = production_request_cancelled()
            return next
        }
        slot = slot + 1
    }
    next
}

func production_execute_selected(transformer_execution_plan plan, production_batch_selection selected, []string binding, bool synchronize) transformer_execution_result {
    if !selected.selected { return transformer_execution_result {success: false, completed_operations: 0, failed_operation: -1, error_message: "empty_batch"} }
    transformer_plan_execute(plan, binding, synchronize)
}
