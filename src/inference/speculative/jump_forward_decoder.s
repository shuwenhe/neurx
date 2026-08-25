package neurx.inference.speculative.jump_forward_decoder

struct jump_forward_fsm {
    []int from_states
    []int to_states
    []int byte_values
    []int final_states
    int edge_count
    int final_count
    int max_jump_steps
}

struct jump_forward_result {
    []int bytes
    int next_state
    int step_count
    bool jumped
}

func jump_forward_int_array(int capacity) []int {
    []int values = []int{cap: capacity}
    int i = 0
    for i < capacity { values[i] = 0; i = i + 1 }
    values
}

func new_jump_forward_fsm(int max_jump_steps) jump_forward_fsm {
    int steps = max_jump_steps
    if steps <= 0 { steps = 256 }
    jump_forward_fsm {from_states: jump_forward_int_array(512), to_states: jump_forward_int_array(512), byte_values: jump_forward_int_array(512), final_states: jump_forward_int_array(128), edge_count: 0, final_count: 0, max_jump_steps: steps}
}

func jump_forward_add_edge(jump_forward_fsm fsm, int from_state, int to_state, int byte_value) jump_forward_fsm {
    if from_state < 0 || to_state < 0 || byte_value < 0 || byte_value > 255 || fsm.edge_count >= 512 { return fsm }
    int index = fsm.edge_count
    fsm.from_states[index] = from_state
    fsm.to_states[index] = to_state
    fsm.byte_values[index] = byte_value
    fsm.edge_count = fsm.edge_count + 1
    fsm
}

func jump_forward_add_final(jump_forward_fsm fsm, int state) jump_forward_fsm {
    int i = 0
    for i < fsm.final_count {
        if fsm.final_states[i] == state { return fsm }
        i = i + 1
    }
    if fsm.final_count >= 128 { return fsm }
    fsm.final_states[fsm.final_count] = state
    fsm.final_count = fsm.final_count + 1
    fsm
}

func jump_forward_is_final(jump_forward_fsm fsm, int state) bool {
    int i = 0
    for i < fsm.final_count {
        if fsm.final_states[i] == state { return true }
        i = i + 1
    }
    false
}

func jump_forward_unique_edge(jump_forward_fsm fsm, int state) int {
    int found = 0 - 1
    int count = 0
    int i = 0
    for i < fsm.edge_count {
        if fsm.from_states[i] == state { found = i; count = count + 1 }
        i = i + 1
    }
    if count == 1 { return found }
    0 - 1
}

func jump_forward_contains_state([]int states, int count, int state) bool {
    int i = 0
    for i < count {
        if states[i] == state { return true }
        i = i + 1
    }
    false
}

func jump_forward_try(jump_forward_fsm fsm, int initial_state) jump_forward_result {
    []int bytes = jump_forward_int_array(fsm.max_jump_steps)
    []int visited = jump_forward_int_array(fsm.max_jump_steps + 1)
    int visited_count = 0
    int current = initial_state
    int steps = 0
    for steps < fsm.max_jump_steps && !jump_forward_is_final(fsm, current) && !jump_forward_contains_state(visited, visited_count, current) {
        visited[visited_count] = current
        visited_count = visited_count + 1
        int edge_index = jump_forward_unique_edge(fsm, current)
        if edge_index < 0 { break }
        bytes[steps] = fsm.byte_values[edge_index]
        current = fsm.to_states[edge_index]
        steps = steps + 1
    }
    []int result_bytes = jump_forward_int_array(steps)
    int i = 0
    for i < steps { result_bytes[i] = bytes[i]; i = i + 1 }
    jump_forward_result {bytes: result_bytes, next_state: current, step_count: steps, jumped: steps > 1}
}
