package neurx.inference.sampling.thinking_budget_state
struct thinking_budget_config {
    int capacity
    int start_token_id
    int end_token_id
    int speculative_width
    bool enabled
}

struct thinking_budget_state {
    thinking_budget_config config
    []int request_ids
    []int budgets
    []int used_tokens
    []int in_thinking
    []int force_end
    int tracked_requests
    int forced_end_count
    bool initialized
}

struct thinking_budget_update {
    thinking_budget_state state
    bool accepted
    bool force_end_token
    int forced_token_id
}

func thinking_zero_array(int capacity) []int {
    []int values = make([]int, capacity)
    int i = 0
    for i < capacity { values[i] = 0; i = i + 1 }
    values
}

func init_thinking_budget(thinking_budget_config config) thinking_budget_state {
    bool initialized = !config.enabled || (config.capacity > 0 && config.start_token_id >= 0 && config.end_token_id >= 0 && config.speculative_width >= 0)
    thinking_budget_state {config: config, request_ids: thinking_zero_array(config.capacity), budgets: thinking_zero_array(config.capacity), used_tokens: thinking_zero_array(config.capacity), in_thinking: thinking_zero_array(config.capacity), force_end: thinking_zero_array(config.capacity), tracked_requests: 0, forced_end_count: 0, initialized: initialized}
}

func thinking_find_request(thinking_budget_state state, int request_id) int {
    int i = 0
    for i < state.config.capacity {
        if state.request_ids[i] == request_id { return i }
        i = i + 1
    }
    0 - 1
}

func add_thinking_request(thinking_budget_state state, int request_id, int budget, bool prompt_in_thinking, int prompt_thinking_tokens) thinking_budget_update {
    if !state.initialized || !state.config.enabled || request_id <= 0 || budget < 0 || thinking_find_request(state, request_id) >= 0 { return thinking_budget_update {state: state, accepted: false, force_end_token: false, forced_token_id: 0} }
    int slot = 0
    for slot < state.config.capacity && state.request_ids[slot] != 0 { slot = slot + 1 }
    if slot >= state.config.capacity { return thinking_budget_update {state: state, accepted: false, force_end_token: false, forced_token_id: 0} }
    state.request_ids[slot] = request_id
    state.budgets[slot] = budget
    state.used_tokens[slot] = prompt_thinking_tokens
    if prompt_in_thinking { state.in_thinking[slot] = 1 }
    if prompt_in_thinking && prompt_thinking_tokens >= budget { state.force_end[slot] = 1 }
    state.tracked_requests = state.tracked_requests + 1
    thinking_budget_update {state: state, accepted: true, force_end_token: state.force_end[slot] == 1, forced_token_id: state.config.end_token_id}
}

func update_thinking_token(thinking_budget_state state, int request_id, int token_id) thinking_budget_update {
    int slot = thinking_find_request(state, request_id)
    if slot < 0 { return thinking_budget_update {state: state, accepted: false, force_end_token: false, forced_token_id: 0} }
    if token_id == state.config.start_token_id { state.in_thinking[slot] = 1; state.used_tokens[slot] = 0; state.force_end[slot] = 0 }
    else if token_id == state.config.end_token_id { state.in_thinking[slot] = 0; state.force_end[slot] = 0 }
    else if state.in_thinking[slot] == 1 {
        state.used_tokens[slot] = state.used_tokens[slot] + 1
        if state.used_tokens[slot] >= state.budgets[slot] && state.force_end[slot] == 0 {
            state.force_end[slot] = 1
            state.forced_end_count = state.forced_end_count + 1
        }
    }
    thinking_budget_update {state: state, accepted: true, force_end_token: state.force_end[slot] == 1, forced_token_id: state.config.end_token_id}
}

func remove_thinking_request(thinking_budget_state state, int request_id) thinking_budget_state {
    int slot = thinking_find_request(state, request_id)
    if slot < 0 { return state }
    state.request_ids[slot] = 0
    state.budgets[slot] = 0
    state.used_tokens[slot] = 0
    state.in_thinking[slot] = 0
    state.force_end[slot] = 0
    if state.tracked_requests > 0 { state.tracked_requests = state.tracked_requests - 1 }
    state
}
