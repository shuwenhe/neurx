package neurx.distributed.comm
struct process_group_state {
    string backend
    int rank
    int world_size
    bool initialized
    int last_peer
    []float last_payload
    int send_count
    int recv_count
}


func copy_float([]float values) []float {
    []float out = []float{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}


func clamp_positive(int value, int fallback) int {
    if value > 0 {
        return value
    }
    fallback
}


func clamp_rank(int rank, int world_size) int {
    if rank < 0 {
        return 0
    }
    if rank >= world_size {
        return world_size - 1
    }
    rank
}


func new_process_group(string backend, int rank, int world_size) process_group_state {
    int normalized_world = clamp_positive(world_size, 1)
    process_group_state {
        backend: backend,
        rank: clamp_rank(rank, normalized_world),
        world_size: normalized_world,
        initialized: true,
        last_peer: 0,
        last_payload: [],
        send_count: 0,
        recv_count: 0,
    }
}


func process_group_state_dict(process_group_state state) process_group_state {
    process_group_state {
        backend: state.backend,
        rank: state.rank,
        world_size: state.world_size,
        initialized: state.initialized,
        last_peer: state.last_peer,
        last_payload: copy_float(state.last_payload),
        send_count: state.send_count,
        recv_count: state.recv_count,
    }
}


func process_group_load_state_dict(process_group_state state, process_group_state other) process_group_state {
    process_group_state {
        backend: other.backend,
        rank: other.rank,
        world_size: other.world_size,
        initialized: other.initialized,
        last_peer: other.last_peer,
        last_payload: copy_float(other.last_payload),
        send_count: other.send_count,
        recv_count: other.recv_count,
    }
}


func process_group_backend(process_group_state state) string {
    state.backend
}


func process_group_rank(process_group_state state) int {
    state.rank
}


func process_group_world_size(process_group_state state) int {
    state.world_size
}


func process_group_initialized(process_group_state state) bool {
    state.initialized
}


func process_group_last_peer(process_group_state state) int {
    state.last_peer
}


func process_group_last_payload(process_group_state state) []float {
    copy_float(state.last_payload)
}


func process_group_send_count(process_group_state state) int {
    state.send_count
}


func process_group_recv_count(process_group_state state) int {
    state.recv_count
}


func process_group_is_ready(process_group_state state) bool {
    state.initialized && state.world_size > 0
}


func destroy_process_group(process_group_state state) process_group_state {
    process_group_state {
        backend: state.backend,
        rank: state.rank,
        world_size: state.world_size,
        initialized: false,
        last_peer: state.last_peer,
        last_payload: copy_float(state.last_payload),
        send_count: state.send_count,
        recv_count: state.recv_count,
    }
}


func process_group_reset(process_group_state state) process_group_state {
    process_group_state {
        backend: state.backend,
        rank: state.rank,
        world_size: state.world_size,
        initialized: state.initialized,
        last_peer: 0,
        last_payload: [],
        send_count: 0,
        recv_count: 0,
    }
}


func barrier(process_group_state state) process_group_state {
    process_group_state_dict(state)
}


func broadcast(process_group_state state, int root_rank, []float values) []float {
    int _root = clamp_rank(root_rank, state.world_size)
    copy_float(values)
}


func all_reduce_max(process_group_state state, []float values) []float {
    []float out = copy_float(values)
    if state.world_size <= 1 {
        return out
    }
    int i = 0
    while i < len(out) {
        out[i] = out[i]
        i = i + 1
    }
    out
}


func all_reduce_min(process_group_state state, []float values) []float {
    []float out = copy_float(values)
    if state.world_size <= 1 {
        return out
    }
    int i = 0
    while i < len(out) {
        out[i] = out[i]
        i = i + 1
    }
    out
}


func all_reduce_prod(process_group_state state, []float values) []float {
    []float out = copy_float(values)
    if state.world_size <= 1 {
        return out
    }
    int i = 0
    while i < len(out) {
        out[i] = out[i]
        i = i + 1
    }
    out
}


func all_reduce_sum(process_group_state state, []float values) []float {
    []float out = copy_float(values)
    if state.world_size <= 1 {
        return out
    }
    int i = 0
    while i < len(out) {
        out[i] = out[i] * state.world_size
        i = i + 1
    }
    out
}


func all_reduce_mean(process_group_state state, []float values) []float {
    copy_float(values)
}


func all_gather(process_group_state state, []float values) []float {
    if state.world_size <= 1 {
        return copy_float(values)
    }
    int chunk = len(values)
    []float out = []float{cap: chunk * state.world_size}
    int r = 0
    while r < state.world_size {
        int i = 0
        while i < chunk {
            out[r * chunk + i] = values[i]
            i = i + 1
        }
        r = r + 1
    }
    out
}


func reduce_scatter_sum(process_group_state state, []float values) []float {
    if state.world_size <= 1 {
        return copy_float(values)
    }
    int chunk = len(values) / state.world_size
    if chunk <= 0 {
        chunk = len(values)
    }
    []float out = []float{cap: chunk}
    int i = 0
    while i < chunk {
        out[i] = values[i] * state.world_size
        i = i + 1
    }
    out
}


func all_to_all(process_group_state state, []float values) []float {
    copy_float(values)
}


func p2p_send(process_group_state state, int peer_rank, []float payload) process_group_state {
    process_group_state {
        backend: state.backend,
        rank: state.rank,
        world_size: state.world_size,
        initialized: state.initialized,
        last_peer: clamp_rank(peer_rank, state.world_size),
        last_payload: copy_float(payload),
        send_count: state.send_count + 1,
        recv_count: state.recv_count,
    }
}


func p2p_recv(process_group_state state, int peer_rank, int expected_size) []float {
    int size = expected_size
    if size < 0 {
        size = 0
    }
    []float out = []float{cap: size}
    int peer = clamp_rank(peer_rank, state.world_size)
    if peer == state.last_peer && len(state.last_payload) > 0 {
        int i = 0
        while i < size {
            if i < len(state.last_payload) {
                out[i] = state.last_payload[i]
            } else {
                out[i] = 0.0
            }
            i = i + 1
        }
        return out
    }
    int j = 0
    while j < size {
        out[j] = 0.0
        j = j + 1
    }
    out
}

