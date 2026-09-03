package neurx.inference.sampling.dllm_runtime
func dllm_strategy_low_confidence() int { 1 }

func dllm_strategy_random() int { 2 }

func dllm_strategy_block() int { 3 }

struct dllm_config {
    int sequence_length
    int maximum_steps
    int tokens_per_step
    int remask_strategy
    int confidence_threshold_per_mille
    int block_size
}

struct dllm_state {
    dllm_config config
    []int token_ids
    []int masked
    []int confidences
    int masked_count
    int step
    int committed_tokens
    bool complete
}

struct dllm_step_result {
    dllm_state state
    []int selected_positions
    int selected_count
    bool complete
}

func dllm_int_array(int capacity) []int {
    []int values = make([]int, capacity)
    int i = 0
    for i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_dllm_state(dllm_config config, []int prompt_tokens) dllm_state {
    if config.sequence_length <= 0 { config.sequence_length = 1 }
    if config.maximum_steps <= 0 { config.maximum_steps = 1 }
    if config.tokens_per_step <= 0 { config.tokens_per_step = 1 }
    if config.block_size <= 0 { config.block_size = config.sequence_length }
    []int tokens = dllm_int_array(config.sequence_length)
    []int masks = dllm_int_array(config.sequence_length)
    []int confidence = dllm_int_array(config.sequence_length)
    int prompt = len(prompt_tokens)
    if prompt > config.sequence_length { prompt = config.sequence_length }
    int i = 0
    for i < config.sequence_length {
        if i < prompt { tokens[i] = prompt_tokens[i]; masks[i] = 0; confidence[i] = 1000 }
        else { masks[i] = 1; confidence[i] = 0 }
        i = i + 1
    }
    dllm_state {config: config, token_ids: tokens, masked: masks, confidences: confidence, masked_count: config.sequence_length - prompt, step: 0, committed_tokens: prompt, complete: prompt == config.sequence_length}
}

func dllm_set_prediction(dllm_state state, int position, int token_id, int confidence_per_mille) dllm_state {
    if position < 0 || position >= state.config.sequence_length || state.masked[position] == 0 { return state }
    state.token_ids[position] = token_id
    state.confidences[position] = confidence_per_mille
    state
}

func dllm_position_allowed(dllm_state state, int position) bool {
    if state.masked[position] == 0 { return false }
    if state.config.remask_strategy != dllm_strategy_block() { return true }
    int block_start = (state.step * state.config.block_size) % state.config.sequence_length
    position >= block_start && position < block_start + state.config.block_size
}

func dllm_selected_contains([]int selected, int selected_count, int position) bool {
    int i = 0
    for i < selected_count {
        if selected[i] == position { return true }
        i = i + 1
    }
    false
}

func dllm_decode_step(dllm_state state) dllm_step_result {
    []int selected = dllm_int_array(state.config.tokens_per_step)
    int selected_count = 0
    int i = 0
    if state.config.remask_strategy == dllm_strategy_random() {
        int offset = (state.step * 17 + 3) % state.config.sequence_length
        for i < state.config.sequence_length && selected_count < state.config.tokens_per_step {
            int position = (offset + i) % state.config.sequence_length
            if dllm_position_allowed(state, position) {
                selected[selected_count] = position
                selected_count = selected_count + 1
            }
            i = i + 1
        }
    } else {
        for selected_count < state.config.tokens_per_step {
            int best = 0 - 1
            i = 0
            for i < state.config.sequence_length {
                bool threshold_match = state.confidences[i] >= state.config.confidence_threshold_per_mille
                if dllm_position_allowed(state, i) && threshold_match && !dllm_selected_contains(selected, selected_count, i) && (best < 0 || state.confidences[i] > state.confidences[best]) { best = i }
                i = i + 1
            }
            if best < 0 { break }
            selected[selected_count] = best
            selected_count = selected_count + 1
        }
    }
    if selected_count == 0 {
        int best = 0 - 1
        i = 0
        for i < state.config.sequence_length {
            if dllm_position_allowed(state, i) && (best < 0 || state.confidences[i] > state.confidences[best]) { best = i }
            i = i + 1
        }
        if best >= 0 { selected[0] = best; selected_count = 1 }
    }
    i = 0
    for i < selected_count {
        int position = selected[i]
        state.masked[position] = 0
        state.masked_count = state.masked_count - 1
        state.committed_tokens = state.committed_tokens + 1
        i = i + 1
    }
    state.step = state.step + 1
    state.complete = state.masked_count == 0 || state.step >= state.config.maximum_steps
    dllm_step_result {state: state, selected_positions: selected, selected_count: selected_count, complete: state.complete}
}
