package neurx.inference.scheduler.queue.request_queue

struct neurx_request_queue_state {
    string[] request_ids
    int[] prefill_tokens
    int[] remaining_tokens
}

struct neurx_queue_pop_result {
    neurx_request_queue_state state
    string request_id
    int prefill_tokens
    int remaining_tokens
    bool ok
}

func new_neurx_request_queue_state() neurx_request_queue_state {
    neurx_request_queue_state {
        request_ids: [],
        prefill_tokens: [],
        remaining_tokens: [],
    }
}

func neurx_queue_size(neurx_request_queue_state state) int {
    len(state.request_ids)
}

func neurx_queue_empty(neurx_request_queue_state state) bool {
    len(state.request_ids) == 0
}

func neurx_queue_enqueue(neurx_request_queue_state state, string request_id, int prefill_tokens, int remaining_tokens) neurx_request_queue_state {
    string[] ids = string[]{cap: len(state.request_ids) + 1}
    int[] prefill = int[]{cap: len(state.prefill_tokens) + 1}
    int[] remain = int[]{cap: len(state.remaining_tokens) + 1}
    int i = 0
    for i < len(state.request_ids) {
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
    neurx_request_queue_state {
        request_ids: ids,
        prefill_tokens: prefill,
        remaining_tokens: remain,
    }
}

func neurx_queue_remove_at(neurx_request_queue_state state, int index) neurx_queue_pop_result {
    if index < 0 || index >= len(state.request_ids) {
        return neurx_queue_pop_result {
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
    string[] ids = string[]{cap: next_len}
    int[] prefill = int[]{cap: next_len}
    int[] remain = int[]{cap: next_len}
    int i = 0
    int j = 0
    for i < len(state.request_ids) {
        if i != index {
            ids[j] = state.request_ids[i]
            prefill[j] = state.prefill_tokens[i]
            remain[j] = state.remaining_tokens[i]
            j = j + 1
        }
        i = i + 1
    }
    neurx_queue_pop_result {
        state: neurx_request_queue_state {
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

func neurx_queue_pop_front(neurx_request_queue_state state) neurx_queue_pop_result {
    neurx_queue_remove_at(state, 0)
}

func neurx_queue_shortest_index(neurx_request_queue_state state) int {
    if len(state.remaining_tokens) == 0 {
        return -1
    }
    int best_idx = 0
    int best_value = state.remaining_tokens[0]
    int i = 1
    for i < len(state.remaining_tokens) {
        if state.remaining_tokens[i] < best_value {
            best_value = state.remaining_tokens[i]
            best_idx = i
        }
        i = i + 1
    }
    best_idx
}

func neurx_queue_pop_shortest(neurx_request_queue_state state) neurx_queue_pop_result {
    int idx = neurx_queue_shortest_index(state)
    neurx_queue_remove_at(state, idx)
}

func neurx_request_queue_state_dict(neurx_request_queue_state state) neurx_request_queue_state {
    state
}

func neurx_request_queue_load_state_dict(neurx_request_queue_state state, neurx_request_queue_state other) neurx_request_queue_state {
    other
}
