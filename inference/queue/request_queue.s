package neurx.inference.queue.request_queue

struct vllm_request_queue_state {
    []string request_ids
    []int prefill_tokens
    []int remaining_tokens
}

struct vllm_queue_pop_result {
    vllm_request_queue_state state
    string request_id
    int prefill_tokens
    int remaining_tokens
    bool ok
}

func new_vllm_request_queue_state() vllm_request_queue_state {
    vllm_request_queue_state {
        request_ids: [],
        prefill_tokens: [],
        remaining_tokens: [],
    }
}

func vllm_queue_size(vllm_request_queue_state state) int {
    len(state.request_ids)
}

func vllm_queue_empty(vllm_request_queue_state state) bool {
    len(state.request_ids) == 0
}

func vllm_queue_enqueue(vllm_request_queue_state state, string request_id, int prefill_tokens, int remaining_tokens) vllm_request_queue_state {
    []string ids = []string{cap: len(state.request_ids) + 1}
    []int prefill = []int{cap: len(state.prefill_tokens) + 1}
    []int remain = []int{cap: len(state.remaining_tokens) + 1}
    int i = 0
    while i < len(state.request_ids) {
        ids[i] = state.request_ids[i]
        prefill[i] = state.prefill_tokens[i]
        remain[i] = state.remaining_tokens[i]
        i = i + 1
    }
    int next_prefill = prefill_tokens
    if next_prefill < 0 {
        next_prefill = 0
    }
    int next_remaining = remaining_tokens
    if next_remaining < 0 {
        next_remaining = 0
    }
    int idx = len(state.request_ids)
    ids[idx] = request_id
    prefill[idx] = next_prefill
    remain[idx] = next_remaining
    vllm_request_queue_state {
        request_ids: ids,
        prefill_tokens: prefill,
        remaining_tokens: remain,
    }
}

func vllm_queue_remove_at(vllm_request_queue_state state, int index) vllm_queue_pop_result {
    if index < 0 || index >= len(state.request_ids) {
        return vllm_queue_pop_result {
            state: state,
            request_id: "",
            prefill_tokens: 0,
            remaining_tokens: 0,
            ok: false,
        }
    }
    string removed_id = state.request_ids[index]
    int removed_prefill = state.prefill_tokens[index]
    int removed_remaining = state.remaining_tokens[index]
    int next_len = len(state.request_ids) - 1
    []string ids = []string{cap: next_len}
    []int prefill = []int{cap: next_len}
    []int remain = []int{cap: next_len}
    int i = 0
    int j = 0
    while i < len(state.request_ids) {
        if i != index {
            ids[j] = state.request_ids[i]
            prefill[j] = state.prefill_tokens[i]
            remain[j] = state.remaining_tokens[i]
            j = j + 1
        }
        i = i + 1
    }
    vllm_queue_pop_result {
        state: vllm_request_queue_state {
            request_ids: ids,
            prefill_tokens: prefill,
            remaining_tokens: remain,
        },
        request_id: removed_id,
        prefill_tokens: removed_prefill,
        remaining_tokens: removed_remaining,
        ok: true,
    }
}

func vllm_queue_pop_front(vllm_request_queue_state state) vllm_queue_pop_result {
    vllm_queue_remove_at(state, 0)
}

func vllm_queue_shortest_index(vllm_request_queue_state state) int {
    if len(state.remaining_tokens) == 0 {
        return -1
    }
    int best_idx = 0
    int best_value = state.remaining_tokens[0]
    int i = 1
    while i < len(state.remaining_tokens) {
        if state.remaining_tokens[i] < best_value {
            best_value = state.remaining_tokens[i]
            best_idx = i
        }
        i = i + 1
    }
    best_idx
}

func vllm_queue_pop_shortest(vllm_request_queue_state state) vllm_queue_pop_result {
    int idx = vllm_queue_shortest_index(state)
    vllm_queue_remove_at(state, idx)
}

func vllm_request_queue_state_dict(vllm_request_queue_state state) vllm_request_queue_state {
    state
}

func vllm_request_queue_load_state_dict(vllm_request_queue_state state, vllm_request_queue_state other) vllm_request_queue_state {
    other
}
