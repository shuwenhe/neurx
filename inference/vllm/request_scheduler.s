package neurx.inference.vllm.request_scheduler
func scheduler_policy_fcfs() int { 1 }

func scheduler_policy_priority() int { 2 }

func scheduler_request_queued() int { 1 }

func scheduler_request_running() int { 2 }

func scheduler_request_preempted() int { 3 }

func scheduler_request_finished() int { 4 }

func scheduler_request_cancelled() int { 5 }

struct vllm_scheduler_config {
    int capacity
    int policy
    int maximum_running_requests
    int maximum_batch_tokens
    int aging_interval_steps
}

struct vllm_scheduler_state {
    vllm_scheduler_config config
    []int request_ids
    []int priorities
    []int arrival_steps
    []int prompt_tokens
    []int remaining_tokens
    []int statuses
    []int active
    int request_count
    int running_count
    int completed_count
    int cancelled_count
    int preemption_count
    int logical_step
}

struct vllm_schedule_result {
    vllm_scheduler_state state
    int request_id
    int scheduled_tokens
    bool scheduled
}

func scheduler_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    while i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_vllm_scheduler(vllm_scheduler_config config) vllm_scheduler_state {
    if config.capacity <= 0 { config.capacity = 1 }
    if config.capacity > 8192 { config.capacity = 8192 }
    if config.policy != scheduler_policy_priority() { config.policy = scheduler_policy_fcfs() }
    if config.maximum_running_requests <= 0 { config.maximum_running_requests = 1 }
    if config.maximum_batch_tokens <= 0 { config.maximum_batch_tokens = 1 }
    if config.aging_interval_steps <= 0 { config.aging_interval_steps = 1 }
    vllm_scheduler_state {config: config, request_ids: scheduler_int_array(config.capacity), priorities: scheduler_int_array(config.capacity), arrival_steps: scheduler_int_array(config.capacity), prompt_tokens: scheduler_int_array(config.capacity), remaining_tokens: scheduler_int_array(config.capacity), statuses: scheduler_int_array(config.capacity), active: scheduler_int_array(config.capacity), request_count: 0, running_count: 0, completed_count: 0, cancelled_count: 0, preemption_count: 0, logical_step: 0}
}

func scheduler_find(vllm_scheduler_state state, int request_id) int {
    int i = 0
    while i < state.config.capacity {
        if state.active[i] == 1 && state.request_ids[i] == request_id { return i }
        i = i + 1
    }
    0 - 1
}

func scheduler_enqueue(vllm_scheduler_state state, int request_id, int priority, int prompt_tokens, int maximum_output_tokens) vllm_scheduler_state {
    if request_id <= 0 || prompt_tokens < 0 || maximum_output_tokens <= 0 || scheduler_find(state, request_id) >= 0 || state.request_count >= state.config.capacity { return state }
    int slot = 0 - 1
    int i = 0
    while i < state.config.capacity {
        if slot < 0 && state.active[i] == 0 { slot = i }
        i = i + 1
    }
    if slot < 0 { return state }
    state.active[slot] = 1
    state.request_ids[slot] = request_id
    state.priorities[slot] = priority
    state.arrival_steps[slot] = state.logical_step
    state.prompt_tokens[slot] = prompt_tokens
    state.remaining_tokens[slot] = prompt_tokens + maximum_output_tokens
    state.statuses[slot] = scheduler_request_queued()
    state.request_count = state.request_count + 1
    state
}

func scheduler_effective_priority(vllm_scheduler_state state, int slot) int {
    if state.config.policy == scheduler_policy_fcfs() { return state.arrival_steps[slot] }
    int age = state.logical_step - state.arrival_steps[slot]
    state.priorities[slot] - age / state.config.aging_interval_steps
}

func scheduler_next_slot(vllm_scheduler_state state) int {
    int selected = 0 - 1
    int i = 0
    while i < state.config.capacity {
        bool ready = state.active[i] == 1 && (state.statuses[i] == scheduler_request_queued() || state.statuses[i] == scheduler_request_preempted())
        if ready {
            if selected < 0 || scheduler_effective_priority(state, i) < scheduler_effective_priority(state, selected) || (scheduler_effective_priority(state, i) == scheduler_effective_priority(state, selected) && state.arrival_steps[i] < state.arrival_steps[selected]) { selected = i }
        }
        i = i + 1
    }
    selected
}

func scheduler_schedule_next(vllm_scheduler_state state, int token_budget) vllm_schedule_result {
    state.logical_step = state.logical_step + 1
    int budget = token_budget
    if budget > state.config.maximum_batch_tokens { budget = state.config.maximum_batch_tokens }
    if budget <= 0 || state.running_count >= state.config.maximum_running_requests { return vllm_schedule_result {state: state, request_id: 0, scheduled_tokens: 0, scheduled: false} }
    int slot = scheduler_next_slot(state)
    if slot < 0 { return vllm_schedule_result {state: state, request_id: 0, scheduled_tokens: 0, scheduled: false} }
    int scheduled_tokens = state.remaining_tokens[slot]
    if scheduled_tokens > budget { scheduled_tokens = budget }
    state.statuses[slot] = scheduler_request_running()
    state.running_count = state.running_count + 1
    vllm_schedule_result {state: state, request_id: state.request_ids[slot], scheduled_tokens: scheduled_tokens, scheduled: true}
}

func scheduler_complete_step(vllm_scheduler_state state, int request_id, int processed_tokens, bool finished) vllm_scheduler_state {
    int slot = scheduler_find(state, request_id)
    if slot < 0 || state.statuses[slot] != scheduler_request_running() { return state }
    int used = processed_tokens
    if used < 0 { used = 0 }
    if used > state.remaining_tokens[slot] { used = state.remaining_tokens[slot] }
    state.remaining_tokens[slot] = state.remaining_tokens[slot] - used
    if state.running_count > 0 { state.running_count = state.running_count - 1 }
    if finished || state.remaining_tokens[slot] == 0 {
        state.statuses[slot] = scheduler_request_finished()
        state.completed_count = state.completed_count + 1
    } else {
        state.statuses[slot] = scheduler_request_queued()
    }
    state
}

func scheduler_preempt_lowest(vllm_scheduler_state state) vllm_scheduler_state {
    int selected = 0 - 1
    int i = 0
    while i < state.config.capacity {
        if state.active[i] == 1 && state.statuses[i] == scheduler_request_running() {
            if selected < 0 || scheduler_effective_priority(state, i) > scheduler_effective_priority(state, selected) { selected = i }
        }
        i = i + 1
    }
    if selected >= 0 {
        state.statuses[selected] = scheduler_request_preempted()
        state.running_count = state.running_count - 1
        state.preemption_count = state.preemption_count + 1
    }
    state
}

func scheduler_cancel(vllm_scheduler_state state, int request_id) vllm_scheduler_state {
    int slot = scheduler_find(state, request_id)
    if slot < 0 || state.statuses[slot] == scheduler_request_finished() || state.statuses[slot] == scheduler_request_cancelled() { return state }
    if state.statuses[slot] == scheduler_request_running() && state.running_count > 0 { state.running_count = state.running_count - 1 }
    state.statuses[slot] = scheduler_request_cancelled()
    state.cancelled_count = state.cancelled_count + 1
    state
}
