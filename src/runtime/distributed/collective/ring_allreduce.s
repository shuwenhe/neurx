package neurx.distributed.collective.ring_allreduce
struct ring_topology {
    int rank
    int world_size
    int left_neighbor
    int right_neighbor
    int num_chunks
}

struct allreduce_request {
    int request_id
    int64 start_time_ns
    int64 end_time_ns
    int num_bytes_transferred
    int num_iterations_completed
    bool is_complete
}

struct ring_allreduce_engine {
    ring_topology topology
    int[] chunk_ranks
    int pending_sends
    int pending_recvs
    allreduce_request current_request
}

func new_ring_topology(int rank, int world_size) ring_topology {
    topology := ring_topology {
        rank: rank,
        world_size: world_size,
        left_neighbor: (rank - 1 + world_size) % world_size,
        right_neighbor: (rank + 1) % world_size,
        num_chunks: world_size,
    }
    return topology
}

func new_ring_allreduce_engine(int rank, int world_size) ring_allreduce_engine {
    engine := ring_allreduce_engine {
        topology: new_ring_topology(rank, world_size),
        chunk_ranks: int[]{cap: world_size},
        pending_sends: 0,
        pending_recvs: 0,
        current_request: allreduce_request {
            request_id: 0,
            start_time_ns: 0,
            end_time_ns: 0,
            num_bytes_transferred: 0,
            num_iterations_completed: 0,
            is_complete: false,
        },
    }
    int i = 0
    for i < world_size {
        engine.chunk_ranks = append(engine.chunk_ranks, i)
        i = i + 1
    }
    return engine
}

func (ring_allreduce_engine* engine) allreduce_reduce_scatter(
    float[] data,
    int op_type
) (float[], bool) {
    if len(data) == 0 {
        return float[]{}, false
    }
    chunk_size := (len(data) + engine.topology.num_chunks - 1) / engine.topology.num_chunks
    float[] local_data = make(float[], len(data))
    int i = 0
    for i < len(data) {
        local_data[i] = data[i]
        i = i + 1
    }
    int iteration = 0
    for iteration < engine.topology.world_size - 1 {
        int send_chunk_idx = (engine.topology.rank - iteration + engine.topology.world_size) % engine.topology.world_size
        int recv_chunk_idx = (engine.topology.rank - iteration - 1 + engine.topology.world_size) % engine.topology.world_size
        int send_start = send_chunk_idx * chunk_size
        int send_end = send_start + chunk_size
        if send_end > len(local_data) {
            send_end = len(local_data)
        }
        float[] send_chunk = make(float[], send_end - send_start)
        i = 0
        for i < len(send_chunk) && send_start + i < len(local_data) {
            send_chunk[i] = local_data[send_start + i]
            i = i + 1
        }
        float[] recv_chunk = engine.irecv_from_left_neighbor(len(send_chunk))
        engine.isend_to_right_neighbor(send_chunk)
        int recv_start = recv_chunk_idx * chunk_size
        int recv_end = recv_start + chunk_size
        if recv_end > len(local_data) {
            recv_end = len(local_data)
        }
        i = 0
        for i < len(recv_chunk) && recv_start + i < len(local_data) {
            float reduced = engine.reduce_op(local_data[recv_start + i], recv_chunk[i], op_type)
            local_data[recv_start + i] = reduced
            i = i + 1
        }
        engine.wait_send()
        iteration = iteration + 1
    }
    return local_data, true
}

func (ring_allreduce_engine* engine) allreduce_broadcast(
    float[] reduced_data
) (float[], bool) {
    if len(reduced_data) == 0 {
        return float[]{}, false
    }
    chunk_size := (len(reduced_data) + engine.topology.num_chunks - 1) / engine.topology.num_chunks
    float[] broadcast_data = make(float[], len(reduced_data))
    int i = 0
    for i < len(reduced_data) {
        broadcast_data[i] = reduced_data[i]
        i = i + 1
    }
    int iteration = 0
    for iteration < engine.topology.world_size - 1 {
        int send_chunk_idx = (engine.topology.rank - iteration + engine.topology.world_size) % engine.topology.world_size
        int recv_chunk_idx = (engine.topology.rank - iteration - 1 + engine.topology.world_size) % engine.topology.world_size
        int send_start = send_chunk_idx * chunk_size
        int send_end = send_start + chunk_size
        if send_end > len(broadcast_data) {
            send_end = len(broadcast_data)
        }
        float[] send_chunk = make(float[], send_end - send_start)
        i = 0
        for i < len(send_chunk) && send_start + i < len(broadcast_data) {
            send_chunk[i] = broadcast_data[send_start + i]
            i = i + 1
        }
        float[] recv_chunk = engine.irecv_from_left_neighbor(len(send_chunk))
        engine.isend_to_right_neighbor(send_chunk)
        int recv_start = recv_chunk_idx * chunk_size
        int recv_end = recv_start + chunk_size
        if recv_end > len(broadcast_data) {
            recv_end = len(broadcast_data)
        }
        i = 0
        for i < len(recv_chunk) && recv_start + i < len(broadcast_data) {
            broadcast_data[recv_start + i] = recv_chunk[i]
            i = i + 1
        }
        engine.wait_send()
        iteration = iteration + 1
    }
    return broadcast_data, true
}

func (ring_allreduce_engine* engine) ring_allreduce(
    float[] data,
    int op_type
) (float[], bool) {
    if len(data) == 0 {
        return float[]{}, false
    }
    reduced_data, success := engine.allreduce_reduce_scatter(data, op_type)
    if !success {
        return float[]{}, false
    }
    final_data, broadcast_success := engine.allreduce_broadcast(reduced_data)
    return final_data, broadcast_success
}

func (ring_allreduce_engine* engine) isend_to_right_neighbor(float[] data) {
    engine.pending_sends = engine.pending_sends + 1
}

func (ring_allreduce_engine* engine) irecv_from_left_neighbor(int size) float[] {
    recv_data := make(float[], size)
    int i = 0
    for i < size {
        recv_data[i] = 0.0
        i = i + 1
    }
    engine.pending_recvs = engine.pending_recvs + 1
    return recv_data
}

func (ring_allreduce_engine* engine) wait_send() {
    engine.pending_sends = 0
}

func (ring_allreduce_engine* engine) wait_recv() {
    engine.pending_recvs = 0
}

func (ring_allreduce_engine* engine) reduce_op(
    float a,
    float b,
    int op_type
) float {
    if op_type == 0 {
        return a + b
    } else if op_type == 1 {
        return a * b
    } else if op_type == 2 {
        return max_f(a, b)
    } else if op_type == 3 {
        return min_f(a, b)
    } else if op_type == 4 {
        return (a + b) / 2.0
    }
    return a + b
}

func max_f(float a, float b) float {
    if a > b {
        return a
    }
    return b
}

func min_f(float a, float b) float {
    if a < b {
        return a
    }
    return b
}

func (ring_allreduce_engine* engine) get_left_neighbor() int {
    return engine.topology.left_neighbor
}

func (ring_allreduce_engine* engine) get_right_neighbor() int {
    return engine.topology.right_neighbor
}

func (ring_allreduce_engine* engine) get_topology() ring_topology {
    return engine.topology
}

func (ring_allreduce_engine* engine) get_current_request() allreduce_request {
    return engine.current_request
}

func (ring_allreduce_engine* engine) is_complete() bool {
    return engine.current_request.is_complete
}

func (ring_allreduce_engine* engine) get_num_chunks() int {
    return engine.topology.num_chunks
}

func (ring_allreduce_engine* engine) set_num_chunks(int chunks) {
    engine.topology.num_chunks = chunks
    if chunks <= 0 {
        engine.topology.num_chunks = engine.topology.world_size
    }
}

func (ring_allreduce_engine* engine) get_metrics() (int, int, int) {
    return engine.current_request.num_bytes_transferred, engine.current_request.num_iterations_completed, engine.pending_sends
}

func (ring_allreduce_engine* engine) reset_request() {
    engine.current_request.request_id = 0
    engine.current_request.num_bytes_transferred = 0
    engine.current_request.num_iterations_completed = 0
    engine.current_request.is_complete = false
}

func (ring_allreduce_engine* engine) finalize_request() {
    engine.current_request.is_complete = true
    engine.current_request.num_iterations_completed = engine.topology.world_size * 2 - 2
}
