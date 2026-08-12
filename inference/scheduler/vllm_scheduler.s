package neurx.inference.scheduler.neurx_scheduler
use neurx.inference.cache.block_manager
func scheduler_waiting_status() int { 1 }

func scheduler_running_status() int { 2 }

func scheduler_preempted_status() int { 3 }

func scheduler_finished_status() int { 4 }

func scheduler_cancelled_status() int { 5 }

func scheduler_failed_status() int { 6 }

func scheduler_paused_status() int { 7 }


struct neurx_scheduler_config {
    int max_running_requests
    int max_scheduled_tokens
    int long_prefill_threshold
    int max_model_length
    int lookahead_tokens
    int priority_aging_interval
    string policy
    bool chunked_prefill
    bool prioritize_decode
    bool enable_preemption
}


struct scheduler_request {
    string request_id
    int prompt_tokens
    int computed_tokens
    int generated_tokens
    int max_new_tokens
    int priority
    int arrival_tick
    int last_scheduled_tick
    int status
    int preemptions
    []string prefix_hashes
    string adapter_id
    string error_message
}


struct scheduled_request {
    string request_id
    int token_count
    int computed_tokens
    bool prefill
    bool new_request
    bool resumed
    []int block_ids
}


struct scheduler_step_output {
    []scheduled_request requests
    []string preempted_request_ids
    []string finished_request_ids
    int scheduled_tokens
    int token_budget_remaining
    int waiting_count
    int running_count
}


struct neurx_scheduler_state {
    neurx_scheduler_config config
    block_manager_state block_manager
    []scheduler_request waiting
    []scheduler_request running
    []string finished_request_ids
    int tick
    int total_submitted
    int total_completed
    int total_cancelled
    int total_preemptions
    int empty_steps
    bool paused
}


struct scheduler_step_result {
    neurx_scheduler_state state
    scheduler_step_output output
}


struct scheduler_update_result {
    neurx_scheduler_state state
    scheduler_request request
    bool success
    string error_message
}


func default_neurx_scheduler_config() neurx_scheduler_config {
    neurx_scheduler_config config
    config.max_running_requests = 64
    config.max_scheduled_tokens = 4096
    config.long_prefill_threshold = 512
    config.max_model_length = 32768
    config.lookahead_tokens = 0
    config.priority_aging_interval = 100
    config.policy = "fcfs"
    config.chunked_prefill = true
    config.prioritize_decode = true
    config.enable_preemption = true
    config
}


func normalize_neurx_scheduler_config(neurx_scheduler_config config) neurx_scheduler_config {
    if config.max_running_requests <= 0 { config.max_running_requests = 1 }
    if config.max_scheduled_tokens <= 0 { config.max_scheduled_tokens = 1 }
    if config.long_prefill_threshold <= 0 { config.long_prefill_threshold = config.max_scheduled_tokens }
    if config.max_model_length <= 0 { config.max_model_length = 1 }
    if config.lookahead_tokens < 0 { config.lookahead_tokens = 0 }
    if config.priority_aging_interval <= 0 { config.priority_aging_interval = 100 }
    if config.policy != "priority" { config.policy = "fcfs" }
    config
}


func new_neurx_scheduler(neurx_scheduler_config config, int total_blocks, int block_size, int watermark_blocks) neurx_scheduler_state {
    neurx_scheduler_state state
    state.config = normalize_neurx_scheduler_config(config)
    state.block_manager = new_block_manager(total_blocks, block_size, watermark_blocks)
    state.waiting = []
    state.running = []
    state.finished_request_ids = []
    state.tick = 0
    state.total_submitted = 0
    state.total_completed = 0
    state.total_cancelled = 0
    state.total_preemptions = 0
    state.empty_steps = 0
    state.paused = false
    state
}


func empty_scheduler_request() scheduler_request {
    scheduler_request request
    request.request_id = ""
    request.prompt_tokens = 0
    request.computed_tokens = 0
    request.generated_tokens = 0
    request.max_new_tokens = 0
    request.priority = 0
    request.arrival_tick = 0
    request.last_scheduled_tick = 0
    request.status = scheduler_failed_status()
    request.preemptions = 0
    request.prefix_hashes = []
    request.adapter_id = ""
    request.error_message = ""
    request
}


func scheduler_request_at([]scheduler_request requests, int index) scheduler_request {
    requests[index]
}


func scheduled_request_at([]scheduled_request requests, int index) scheduled_request {
    requests[index]
}


func scheduler_remove_request_at([]scheduler_request requests, int remove_index) []scheduler_request {
    []scheduler_request filtered_requests = []scheduler_request{cap: len(requests)}
    int i = 0
    while i < len(requests) {
        if i != remove_index {
            filtered_requests = append(filtered_requests, scheduler_request_at(requests, i))
        }
        i = i + 1
    }
    filtered_requests
}


func scheduler_find_request([]scheduler_request requests, string request_id) int {
    int i = 0
    while i < len(requests) {
        scheduler_request request = scheduler_request_at(requests, i)
        if request.request_id == request_id {
            return i
        }
        i = i + 1
    }
    -1
}


func scheduler_has_request(neurx_scheduler_state state, string request_id) bool {
    scheduler_find_request(state.waiting, request_id) >= 0 || scheduler_find_request(state.running, request_id) >= 0
}


func scheduler_effective_priority(neurx_scheduler_state state, scheduler_request request) int {
    if state.config.policy != "priority" {
        return 0 - request.arrival_tick
    }
    int waited = state.tick - request.arrival_tick
    if waited < 0 { waited = 0 }
    request.priority + waited / state.config.priority_aging_interval
}


func scheduler_best_waiting_index(neurx_scheduler_state state) int {
    if len(state.waiting) == 0 { return -1 }
    int best_index = 0
    scheduler_request best_request = scheduler_request_at(state.waiting, 0)
    int best_score = scheduler_effective_priority(state, best_request)
    int i = 1
    while i < len(state.waiting) {
        scheduler_request candidate = scheduler_request_at(state.waiting, i)
        int score = scheduler_effective_priority(state, candidate)
        if score > best_score || (score == best_score && candidate.arrival_tick < best_request.arrival_tick) {
            best_index = i
            best_request = candidate
            best_score = score
        }
        i = i + 1
    }
    best_index
}


func scheduler_submit(neurx_scheduler_state state, string request_id, int prompt_tokens, int max_new_tokens, int priority, []string prefix_hashes, string adapter_id) scheduler_update_result {
    scheduler_update_result result
    result.state = state
    result.request = empty_scheduler_request()
    result.success = false
    result.error_message = ""
    if request_id == "" || max_new_tokens <= 0 || scheduler_has_request(state, request_id) {
        result.error_message = "invalid or duplicate request"
        return result
    }
    int normalized_prompt = prompt_tokens
    if normalized_prompt < 0 { normalized_prompt = 0 }
    if normalized_prompt + max_new_tokens > state.config.max_model_length {
        result.error_message = "request exceeds max model length"
        return result
    }
    scheduler_request request
    request.request_id = request_id
    request.prompt_tokens = normalized_prompt
    request.computed_tokens = 0
    request.generated_tokens = 0
    request.max_new_tokens = max_new_tokens
    request.priority = priority
    request.arrival_tick = state.tick
    request.last_scheduled_tick = state.tick
    request.status = scheduler_waiting_status()
    request.preemptions = 0
    request.prefix_hashes = prefix_hashes
    request.adapter_id = adapter_id
    request.error_message = ""
    state.waiting = append(state.waiting, request)
    state.total_submitted = state.total_submitted + 1
    result.state = state
    result.request = request
    result.success = true
    result
}


func scheduler_request_is_prefill(scheduler_request request) bool {
    request.computed_tokens < request.prompt_tokens
}


func scheduler_request_remaining(scheduler_request request) int {
    if scheduler_request_is_prefill(request) {
        return request.prompt_tokens - request.computed_tokens
    }
    int remaining = request.max_new_tokens - request.generated_tokens
    if remaining < 0 { return 0 }
    remaining
}


func scheduler_chunk_size(neurx_scheduler_state state, scheduler_request request, int token_budget) int {
    int remaining = scheduler_request_remaining(request)
    if remaining <= 0 || token_budget <= 0 { return 0 }
    int tokens = remaining
    if scheduler_request_is_prefill(request) {
        if state.config.chunked_prefill && tokens > state.config.long_prefill_threshold {
            tokens = state.config.long_prefill_threshold
        }
        if !state.config.chunked_prefill && tokens > token_budget {
            return 0
        }
    } else {
        tokens = 1
    }
    if tokens > token_budget { tokens = token_budget }
    tokens
}


func scheduler_lowest_priority_running(neurx_scheduler_state state, string protected_request_id, []string scheduled_ids) int {
    int selected_index = -1
    int selected_score = 2147483647
    int i = 0
    while i < len(state.running) {
        scheduler_request candidate = scheduler_request_at(state.running, i)
        if candidate.request_id != protected_request_id {
            bool already_scheduled = false
            int j = 0
            while j < len(scheduled_ids) {
                if scheduled_ids[j] == candidate.request_id { already_scheduled = true }
                j = j + 1
            }
            int score = scheduler_effective_priority(state, candidate)
            if !already_scheduled && score < selected_score {
                selected_index = i
                selected_score = score
            }
        }
        i = i + 1
    }
    selected_index
}


func scheduler_preempt_at(neurx_scheduler_state state, int running_index) neurx_scheduler_state {
    if running_index < 0 || running_index >= len(state.running) { return state }
    scheduler_request victim = scheduler_request_at(state.running, running_index)
    state.block_manager = block_manager_preempt_request(state.block_manager, victim.request_id)
    victim.status = scheduler_preempted_status()
    victim.computed_tokens = 0
    victim.preemptions = victim.preemptions + 1
    victim.arrival_tick = state.tick
    state.running = scheduler_remove_request_at(state.running, running_index)
    state.waiting = append(state.waiting, victim)
    state.total_preemptions = state.total_preemptions + 1
    state
}


func scheduler_copy_block_ids(request_block_table table) []int {
    []int copied_ids = []int{cap: len(table.block_ids)}
    int i = 0
    while i < len(table.block_ids) {
        copied_ids = append(copied_ids, table.block_ids[i])
        i = i + 1
    }
    copied_ids
}


func scheduler_make_scheduled(scheduler_request request, int token_count, bool new_request, bool resumed, request_block_table table) scheduled_request {
    scheduled_request scheduled
    scheduled.request_id = request.request_id
    scheduled.token_count = token_count
    scheduled.computed_tokens = request.computed_tokens
    scheduled.prefill = scheduler_request_is_prefill(request)
    scheduled.new_request = new_request
    scheduled.resumed = resumed
    scheduled.block_ids = scheduler_copy_block_ids(table)
    scheduled
}


func scheduler_schedule_running(neurx_scheduler_state state, scheduler_step_output output, int token_budget) scheduler_step_result {
    []string scheduled_ids = []
    int phase = 0
    while phase < 2 && token_budget > 0 {
        int running_index = 0
        while running_index < len(state.running) && token_budget > 0 {
            scheduler_request request = scheduler_request_at(state.running, running_index)
            bool prefill = scheduler_request_is_prefill(request)
            bool phase_matches = (phase == 0 && state.config.prioritize_decode && !prefill) || (phase == 1) || (!state.config.prioritize_decode && phase == 0)
            if !phase_matches || (phase == 1 && state.config.prioritize_decode && !prefill) {
                running_index = running_index + 1
                continue
            }
            int tokens = scheduler_chunk_size(state, request, token_budget)
            if tokens <= 0 {
                running_index = running_index + 1
                continue
            }
            request_block_table table = block_manager_get_table(state.block_manager, request.request_id)
            int lookahead = 0
            if !prefill { lookahead = state.config.lookahead_tokens }
            bool allocated = false
            while !allocated {
                block_allocation_result allocation = block_manager_allocate(state.block_manager, request.request_id, tokens, lookahead, false)
                state.block_manager = allocation.state
                if allocation.success {
                    table = allocation.table
                    allocated = true
                } else if state.config.enable_preemption {
                    int victim_index = scheduler_lowest_priority_running(state, request.request_id, scheduled_ids)
                    if victim_index < 0 { break }
                    scheduler_request victim = scheduler_request_at(state.running, victim_index)
                    output.preempted_request_ids = append(output.preempted_request_ids, victim.request_id)
                    state = scheduler_preempt_at(state, victim_index)
                    if victim_index < running_index { running_index = running_index - 1 }
                } else {
                    break
                }
            }
            if !allocated {
                running_index = running_index + 1
                continue
            }
            request.last_scheduled_tick = state.tick
            state.running[running_index] = request
            scheduled_request scheduled = scheduler_make_scheduled(request, tokens, false, false, table)
            output.requests = append(output.requests, scheduled)
            scheduled_ids = append(scheduled_ids, request.request_id)
            output.scheduled_tokens = output.scheduled_tokens + tokens
            token_budget = token_budget - tokens
            running_index = running_index + 1
        }
        if !state.config.prioritize_decode { phase = 2 } else { phase = phase + 1 }
    }
    output.token_budget_remaining = token_budget
    scheduler_step_result result
    result.state = state
    result.output = output
    result
}


func scheduler_schedule_waiting(neurx_scheduler_state state, scheduler_step_output output, int token_budget) scheduler_step_result {
    while len(state.waiting) > 0 && len(state.running) < state.config.max_running_requests && token_budget > 0 {
        int waiting_index = scheduler_best_waiting_index(state)
        if waiting_index < 0 { break }
        scheduler_request request = scheduler_request_at(state.waiting, waiting_index)
        bool resumed = request.status == scheduler_preempted_status()
        if request.computed_tokens == 0 && len(request.prefix_hashes) > 0 {
            prefix_match_result prefix = block_manager_match_prefix(state.block_manager, request.request_id, request.prefix_hashes)
            state.block_manager = prefix.state
            request.computed_tokens = prefix.matched_tokens
        }
        int tokens = scheduler_chunk_size(state, request, token_budget)
        if tokens <= 0 { break }
        bool prefill = scheduler_request_is_prefill(request)
        int lookahead = 0
        if !prefill { lookahead = state.config.lookahead_tokens }
        block_allocation_result allocation = block_manager_allocate(state.block_manager, request.request_id, tokens, lookahead, true)
        state.block_manager = allocation.state
        if !allocation.success {
            if state.config.enable_preemption && len(state.running) > 0 {
                int victim_index = scheduler_lowest_priority_running(state, "", [])
                if victim_index >= 0 {
                    scheduler_request victim = scheduler_request_at(state.running, victim_index)
                    int candidate_score = scheduler_effective_priority(state, request)
                    int victim_score = scheduler_effective_priority(state, victim)
                    if candidate_score > victim_score {
                        output.preempted_request_ids = append(output.preempted_request_ids, victim.request_id)
                        state = scheduler_preempt_at(state, victim_index)
                        continue
                    }
                }
            }
            state.block_manager = block_manager_free_request(state.block_manager, request.request_id, false)
            request.computed_tokens = 0
            state.waiting[waiting_index] = request
            break
        }
        state.waiting = scheduler_remove_request_at(state.waiting, waiting_index)
        request.status = scheduler_running_status()
        request.last_scheduled_tick = state.tick
        state.running = append(state.running, request)
        scheduled_request scheduled = scheduler_make_scheduled(request, tokens, !resumed, resumed, allocation.table)
        output.requests = append(output.requests, scheduled)
        output.scheduled_tokens = output.scheduled_tokens + tokens
        token_budget = token_budget - tokens
    }
    output.token_budget_remaining = token_budget
    scheduler_step_result result
    result.state = state
    result.output = output
    result
}


func scheduler_step(neurx_scheduler_state state) scheduler_step_result {
    scheduler_step_output output
    output.requests = []
    output.preempted_request_ids = []
    output.finished_request_ids = state.finished_request_ids
    output.scheduled_tokens = 0
    output.token_budget_remaining = state.config.max_scheduled_tokens
    output.waiting_count = len(state.waiting)
    output.running_count = len(state.running)
    state.finished_request_ids = []
    state.tick = state.tick + 1
    if state.paused {
        scheduler_step_result paused_result
        paused_result.state = state
        paused_result.output = output
        return paused_result
    }
    int budget = state.config.max_scheduled_tokens
    scheduler_step_result running_result = scheduler_schedule_running(state, output, budget)
    state = running_result.state
    output = running_result.output
    scheduler_step_result waiting_result = scheduler_schedule_waiting(state, output, output.token_budget_remaining)
    state = waiting_result.state
    output = waiting_result.output
    output.waiting_count = len(state.waiting)
    output.running_count = len(state.running)
    if output.scheduled_tokens == 0 { state.empty_steps = state.empty_steps + 1 }
    scheduler_step_result result
    result.state = state
    result.output = output
    result
}


func scheduler_finish_running(neurx_scheduler_state state, int running_index, int terminal_status, string error_message) scheduler_update_result {
    scheduler_request request = scheduler_request_at(state.running, running_index)
    request.status = terminal_status
    request.error_message = error_message
    state.block_manager = block_manager_free_request(state.block_manager, request.request_id, false)
    state.running = scheduler_remove_request_at(state.running, running_index)
    state.finished_request_ids = append(state.finished_request_ids, request.request_id)
    if terminal_status == scheduler_finished_status() { state.total_completed = state.total_completed + 1 }
    if terminal_status == scheduler_cancelled_status() { state.total_cancelled = state.total_cancelled + 1 }
    scheduler_update_result result
    result.state = state
    result.request = request
    result.success = true
    result.error_message = ""
    result
}


func scheduler_apply_output(neurx_scheduler_state state, string request_id, int computed_tokens, int generated_tokens, bool eos, string error_message) scheduler_update_result {
    int running_index = scheduler_find_request(state.running, request_id)
    if running_index < 0 {
        scheduler_update_result missing
        missing.state = state
        missing.request = empty_scheduler_request()
        missing.success = false
        missing.error_message = "running request not found"
        return missing
    }
    scheduler_request request = scheduler_request_at(state.running, running_index)
    if error_message != "" {
        return scheduler_finish_running(state, running_index, scheduler_failed_status(), error_message)
    }
    int add_computed = computed_tokens
    if add_computed < 0 { add_computed = 0 }
    int add_generated = generated_tokens
    if add_generated < 0 { add_generated = 0 }
    request.generated_tokens = request.generated_tokens + add_generated
    if request.generated_tokens > request.max_new_tokens { request.generated_tokens = request.max_new_tokens }
    request.computed_tokens = request.computed_tokens + add_computed
    if request.computed_tokens > request.prompt_tokens + request.generated_tokens {
        request.computed_tokens = request.prompt_tokens + request.generated_tokens
    }
    state.block_manager = block_manager_mark_computed(state.block_manager, request_id, add_computed)
    if len(request.prefix_hashes) > 0 {
        state.block_manager = block_manager_cache_full_blocks(state.block_manager, request_id, request.prefix_hashes)
    }
    state.running[running_index] = request
    if eos || request.generated_tokens >= request.max_new_tokens {
        return scheduler_finish_running(state, running_index, scheduler_finished_status(), "")
    }
    scheduler_update_result result
    result.state = state
    result.request = request
    result.success = true
    result.error_message = ""
    result
}


func scheduler_cancel(neurx_scheduler_state state, string request_id) scheduler_update_result {
    int waiting_index = scheduler_find_request(state.waiting, request_id)
    if waiting_index >= 0 {
        scheduler_request request = scheduler_request_at(state.waiting, waiting_index)
        request.status = scheduler_cancelled_status()
        state.block_manager = block_manager_free_request(state.block_manager, request_id, false)
        state.waiting = scheduler_remove_request_at(state.waiting, waiting_index)
        state.finished_request_ids = append(state.finished_request_ids, request_id)
        state.total_cancelled = state.total_cancelled + 1
        scheduler_update_result waiting_result
        waiting_result.state = state
        waiting_result.request = request
        waiting_result.success = true
        waiting_result.error_message = ""
        return waiting_result
    }
    int running_index = scheduler_find_request(state.running, request_id)
    if running_index >= 0 {
        return scheduler_finish_running(state, running_index, scheduler_cancelled_status(), "")
    }
    scheduler_update_result missing
    missing.state = state
    missing.request = empty_scheduler_request()
    missing.success = false
    missing.error_message = "request not found"
    missing
}


func scheduler_set_paused(neurx_scheduler_state state, bool paused) neurx_scheduler_state {
    state.paused = paused
    state
}


func scheduler_unfinished_count(neurx_scheduler_state state) int {
    len(state.waiting) + len(state.running)
}

