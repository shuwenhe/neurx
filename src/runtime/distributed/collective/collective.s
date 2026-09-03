package neurx.distributed.collective
int OP_SUM     = 0
int OP_PROD    = 1
int OP_MAX     = 2
int OP_MIN     = 3
int OP_AVG     = 4
int OP_BOR     = 5
int OP_BAND    = 6
int OP_BXOR    = 7
int BACKEND_NCCL    = 0
int BACKEND_GLOO    = 1
int BACKEND_MPI     = 2
int BACKEND_CUSTOM  = 3
int DTYPE_FLOAT32  = 0
int DTYPE_FLOAT16  = 1
int DTYPE_BFLOAT16 = 2
int DTYPE_INT64    = 3
int DTYPE_INT32    = 4
int DTYPE_BOOL     = 5
struct process_group {
    int pg_id
    []int ranks
    int world_size
    int my_rank
    int backend
    bool is_initialized
    string name
}

struct comm_tensor {
    []float data
    []int shape
    int dtype
    int numel
    int device
}

struct comm_request {
    int request_id
    bool is_completed
    float start_time_ms
    float elapsed_ms
    int bytes_transferred
    int error_code
    string error_msg
}

struct p2p_irecv_result {
    comm_request request
    comm_tensor tensor
}

struct allreduce_async_result {
    comm_tensor tensor
    comm_request request
}

struct comm_metrics {
    float total_comm_time_ms
    float total_bytes_sent
    float total_bytes_received
    int num_allreduces
    int num_allgathers
    int num_reducescatters
    float bandwidth_efficiency
}

func new_process_group(int pg_id, []int ranks, int my_rank, int backend) process_group {
    process_group pg
    pg.pg_id = pg_id
    pg.ranks = ranks
    pg.world_size = len(ranks)
    pg.my_rank = my_rank
    pg.backend = backend
    pg.is_initialized = true
    pg.name = "pg_" + str(pg_id)
    return pg
}

func create_default_world_group(int world_size, int my_rank) process_group {
    []int all_ranks = make([]int, world_size)
    int i = 0
    for i < world_size {
        all_ranks[i] = i
        i = i + 1
    }
    return new_process_group(0, all_ranks, my_rank, BACKEND_NCCL)
}

func split_process_group(process_group parent_pg, int color, int key) process_group {
    []int subgroup_ranks = make([]int, parent_pg.world_size)
    int count = 0
    int i = 0
    for i < len(parent_pg.ranks) {
        if c_mod_nonneg(parent_pg.ranks[i], color + 1) == c_mod_nonneg(parent_pg.my_rank, color + 1) {
            subgroup_ranks[count] = parent_pg.ranks[i]
            count = count + 1
        }
        i = i + 1
    }
    []int final_ranks = make([]int, count)
    int j = 0
    for j < count {
        final_ranks[j] = subgroup_ranks[j]
        j = j + 1
    }
    return new_process_group(parent_pg.pg_id * 100 + color, final_ranks,
                             parent_pg.my_rank, parent_pg.backend)
}

func destroy_process_group(process_group pg) {
    pg.is_initialized = false
}

func c_mod_nonneg(int value, int divisor) int {
    if divisor <= 0 { return 0 }
    int current = value
    for current >= divisor { current = current - divisor }
    for current < 0 { current = current + divisor }
    return current
}

func dtype_bytes(int dtype) int {
    if dtype == DTYPE_FLOAT32 { return 4 }
    if dtype == DTYPE_FLOAT16 { return 2 }
    if dtype == DTYPE_BFLOAT16 { return 2 }
    if dtype == DTYPE_INT64 { return 8 }
    if dtype == DTYPE_INT32 { return 4 }
    if dtype == DTYPE_BOOL { return 1 }
    return 4
}

func make_comm_tensor([]float data, []int shape, int dtype) comm_tensor {
    comm_tensor t
    t.data = data
    t.shape = shape
    t.dtype = dtype
    int n = 1
    int i = 0
    for i < len(shape) {
        n = n * shape[i]
        i = i + 1
    }
    t.numel = n
    t.device = -1
    return t
}

func new_comm_metrics() comm_metrics {
    comm_metrics m
    m.total_comm_time_ms = 0.0
    m.total_bytes_sent = 0.0
    m.total_bytes_received = 0.0
    m.num_allreduces = 0
    m.num_allgathers = 0
    m.num_reducescatters = 0
    m.bandwidth_efficiency = 1.0
    return m
}

func p2p_send(
    process_group pg,
    comm_tensor tensor,
    int dest_rank,
    int tag) comm_request {
    comm_request req
    req.request_id = dest_rank * 10000 + tag
    req.is_completed = true
    req.start_time_ms = 0.0
    req.elapsed_ms = 0.001
    req.bytes_transferred = tensor.numel * dtype_bytes(tensor.dtype)
    req.error_code = 0
    return req
}

func p2p_recv(
    process_group pg,
    int expected_numel,
    int expected_dtype,
    int src_rank,
    int tag) comm_tensor {
    comm_tensor result
    result.shape = []int{expected_numel}
    result.numel = expected_numel
    result.dtype = expected_dtype
    result.device = -1
    result.data = make([]float, expected_numel)
    return result
}

func p2p_isend(
    process_group pg,
    comm_tensor tensor,
    int dest_rank,
    int tag) comm_request {
    comm_request req = p2p_send(pg, tensor, dest_rank, tag)
    req.is_completed = false
    return req
}

func p2p_irecv(
    process_group pg,
    int expected_numel,
    int expected_dtype,
    int src_rank,
    int tag) p2p_irecv_result {
    comm_request req
    req.request_id = src_rank * 10000 + tag + 5000
    req.is_completed = false
    req.error_code = 0
    comm_tensor placeholder
    placeholder.shape = []int{expected_numel}
    placeholder.numel = expected_numel
    placeholder.dtype = expected_dtype
    placeholder.data = make([]float, expected_numel)
    p2p_irecv_result result
    result.request = req
    result.tensor = placeholder
    return result
}

func wait_request(comm_request req) comm_request {
    req.is_completed = true
    req.elapsed_ms = 0.002
    return req
}

func wait_all_requests([]comm_request requests) []comm_request {
    int i = 0
    for i < len(requests) {
        requests[i].is_completed = true
        requests[i].elapsed_ms = 0.002
        i = i + 1
    }
    return requests
}

func test_request(comm_request req) bool {
    return req.is_completed
}

func broadcast(
    process_group pg,
    comm_tensor tensor,
    int root_rank,
    ref comm_metrics metrics) comm_tensor {
    float start_time = 0.0
    if pg.my_rank == root_rank {
    } else {
        tensor.data = make([]float, tensor.numel)
    }
    float elapsed = 0.0005
    metrics.total_comm_time_ms = metrics.total_comm_time_ms + elapsed
    metrics.total_bytes_received = metrics.total_bytes_received + tensor.numel * dtype_bytes(tensor.dtype)
    return tensor
}

func allreduce(
    process_group pg,
    comm_tensor tensor,
    int reduce_op,
    ref comm_metrics metrics) comm_tensor {
    float start_time = 0.0
    int world_size = pg.world_size
    int numel = tensor.numel
    int tensor_bytes = numel * dtype_bytes(tensor.dtype)
    comm_tensor result = local_identical_allreduce(pg, tensor, reduce_op)
    float elapsed = estimate_comm_time(numel, dtype_bytes(result.dtype), world_size, "allreduce")
    metrics.total_comm_time_ms = metrics.total_comm_time_ms + elapsed
    metrics.num_allreduces = metrics.num_allreduces + 1
    metrics.total_bytes_sent = metrics.total_bytes_sent + tensor_bytes * 2 * (world_size - 1)
    metrics.total_bytes_received = metrics.total_bytes_received + tensor_bytes * 2 * (world_size - 1)
    return result
}

func local_identical_allreduce(process_group pg, comm_tensor tensor, int reduce_op) comm_tensor {
    int world_size = pg.world_size
    if world_size <= 1 {
        return tensor
    }
    []float out = make([]float, tensor.numel)
    int i = 0
    for i < tensor.numel {
        float v = tensor.data[i]
        if reduce_op == OP_SUM {
            out[i] = v * world_size
        } else if reduce_op == OP_AVG {
            out[i] = v
        } else if reduce_op == OP_PROD {
            float prod = 1.0
            int r = 0
            for r < world_size {
                prod = prod * v
                r = r + 1
            }
            out[i] = prod
        } else {
            out[i] = v
        }
        i = i + 1
    }
    tensor.data = out
    return tensor
}

func ring_allreduce_impl(
    process_group pg,
    comm_tensor tensor,
    int reduce_op,
    ref comm_metrics metrics) comm_tensor {
    int world_size = pg.world_size
    int rank = pg.my_rank
    int numel = tensor.numel
    if world_size <= 1 {
        return tensor
    }
    int base_chunk_size = numel / world_size
    int remainder = c_mod_nonneg(numel, world_size)
    []int chunk_sizes = make([]int, world_size)
    int offset = 0
    int i = 0
    for i < world_size {
        int sz = base_chunk_size
        if i < remainder { sz = sz + 1 }
        chunk_sizes[i] = sz
        offset = offset + sz
        i = i + 1
    }
    []float output_data = make([]float, numel)
    int k = 0
    for k < numel {
        output_data[k] = tensor.data[k]
        k = k + 1
    }
    int send_dst = c_mod_nonneg((rank + 1), world_size)
    int recv_src = c_mod_nonneg((rank - 1 + world_size), world_size)
    int round = 0
    for round < world_size - 1 {
        int send_chunk_idx = c_mod_nonneg((rank - round + world_size), world_size)
        int recv_chunk_idx = c_mod_nonneg((rank - round - 1 + world_size), world_size)
        int send_offset = compute_chunk_offset(chunk_sizes, send_chunk_idx)
        int recv_offset = compute_chunk_offset(chunk_sizes, recv_chunk_idx)
        int j = 0
        for j < chunk_sizes[recv_chunk_idx] {
            int idx = recv_offset + j
            float neighbor_val = output_data[idx]
            output_data[idx] = apply_reduce_op(output_data[idx], neighbor_val, reduce_op)
            j = j + 1
        }
        round = round + 1
    }
    round = 0
    for round < world_size - 1 {
        int send_chunk_idx = c_mod_nonneg((rank - round + 1 + world_size), world_size)
        int recv_chunk_idx = c_mod_nonneg((rank - round + world_size), world_size)
        int send_offset = compute_chunk_offset(chunk_sizes, send_chunk_idx)
        int recv_offset = compute_chunk_offset(chunk_sizes, recv_chunk_idx)
        int j = 0
        for j < chunk_sizes[recv_chunk_idx] {
            output_data[recv_offset + j] = output_data[recv_offset + j]
            j = j + 1
        }
        round = round + 1
    }
    tensor.data = output_data
    return tensor
}

func tree_allreduce_impl(
    process_group pg,
    comm_tensor tensor,
    int reduce_op,
    ref comm_metrics metrics) comm_tensor {
    int world_size = pg.world_size
    int rank = pg.my_rank
    int numel = tensor.numel
    if world_size <= 1 { return tensor }
    []float output_data = make([]float, numel)
    int k = 0
    for k < numel {
        output_data[k] = tensor.data[k]
        k = k + 1
    }
    int step = 1
    for step < world_size {
        int partner = rank + step
        if partner < world_size && c_mod_nonneg(rank, step) == 0 {
            if rank < partner {
                int j = 0
                for j < numel {
                    float partner_val = output_data[j]
                    output_data[j] = apply_reduce_op(output_data[j], partner_val, reduce_op)
                    j = j + 1
                }
            }
        }
        step = step * 2
    }
    step = step / 2
    for step > 0 {
        int partner = rank + step
        if partner < world_size && c_mod_nonneg(rank, step) == 0 {
            if rank < partner {
            } else {
            }
        }
        step = step / 2
    }
    tensor.data = output_data
    return tensor
}

func allgather(
    process_group pg,
    comm_tensor tensor,
    ref comm_metrics metrics) comm_tensor {
    int world_size = pg.world_size
    int rank = pg.my_rank
    int numel = tensor.numel
    int dtype_sz = dtype_bytes(tensor.dtype)
    int total_numel = numel * world_size
    []float gathered_data = make([]float, total_numel)
    int local_start = rank * numel
    int i = 0
    for i < numel {
        gathered_data[local_start + i] = tensor.data[i]
        i = i + 1
    }
    int r = 0
    for r < world_size {
        if r != rank {
            int remote_start = r * numel
            int j = 0
            for j < numel {
                gathered_data[remote_start + j] = tensor.data[j]
                j = j + 1
            }
        }
        r = r + 1
    }
    comm_tensor result
    result.data = gathered_data
    result.shape = []int{world_size}
    if len(tensor.shape) > 0 {
        result.shape[0] = tensor.shape[0] * world_size
        int s = 1
        for s < len(tensor.shape) {
            result.shape = append(result.shape, tensor.shape[s])
            s = s + 1
        }
    }
    result.numel = total_numel
    result.dtype = tensor.dtype
    result.device = tensor.device
    float elapsed = estimate_comm_time(total_numel, dtype_sz, world_size, "allgather")
    metrics.total_comm_time_ms = metrics.total_comm_time_ms + elapsed
    metrics.num_allgathers = metrics.num_allgathers + 1
    metrics.total_bytes_sent = metrics.total_bytes_sent + numel * dtype_sz * (world_size - 1)
    metrics.total_bytes_received = metrics.total_bytes_received + numel * dtype_sz * (world_size - 1)
    return result
}

func reducescatter(
    process_group pg,
    comm_tensor tensor,
    int reduce_op,
    ref comm_metrics metrics) comm_tensor {
    int world_size = pg.world_size
    int rank = pg.my_rank
    int total_numel = tensor.numel
    int dtype_sz = dtype_bytes(tensor.dtype)
    int chunk_size = (total_numel + world_size - 1) / world_size
    int my_start = rank * chunk_size
    int my_end = my_start + chunk_size
    if my_end > total_numel { my_end = total_numel }
    int my_count = my_end - my_start
    []float scattered_data = make([]float, my_count)
    comm_tensor reduced = local_identical_allreduce(pg, tensor, reduce_op)
    int i = 0
    for i < my_count {
        if my_start + i < total_numel {
            scattered_data[i] = reduced.data[my_start + i]
        }
        i = i + 1
    }
    comm_tensor result
    result.data = scattered_data
    result.shape = []int{my_count}
    result.numel = my_count
    result.dtype = tensor.dtype
    result.device = tensor.device
    float elapsed = estimate_comm_time(my_count, dtype_sz, world_size, "reducescatter")
    metrics.total_comm_time_ms = metrics.total_comm_time_ms + elapsed
    metrics.num_reducescatters = metrics.num_reducescatters + 1
    return result
}

func scatter(
    process_group pg,
    comm_tensor tensor,
    int root_rank,
    ref comm_metrics metrics) comm_tensor {
    int world_size = pg.world_size
    int rank = pg.my_rank
    int total_numel = tensor.numel
    int chunk_size = (total_numel + world_size - 1) / world_size
    int my_start = rank * chunk_size
    int my_end = my_start + chunk_size
    if my_end > total_numel { my_end = total_numel }
    int my_count = my_end - my_start
    []float my_data = make([]float, my_count)
    int i = 0
    for i < my_count {
        my_data[i] = tensor.data[my_start + i]
        i = i + 1
    }
    comm_tensor result
    result.data = my_data
    result.shape = []int{my_count}
    result.numel = my_count
    result.dtype = tensor.dtype
    return result
}

func gather(
    process_group pg,
    comm_tensor tensor,
    int root_rank,
    ref comm_metrics metrics) comm_tensor {
    int world_size = pg.world_size
    int rank = pg.my_rank
    int numel = tensor.numel
    int dtype_sz = dtype_bytes(tensor.dtype)
    if rank == root_rank {
        int total_numel = numel * world_size
        []float gathered = make([]float, total_numel)
        int r = 0
        for r < world_size {
            int offset = r * numel
            int i = 0
            for i < numel {
                if r == rank {
                    gathered[offset + i] = tensor.data[i]
                } else {
                    gathered[offset + i] = tensor.data[i]
                }
                i = i + 1
            }
            r = r + 1
        }
        comm_tensor result
        result.data = gathered
        []int gathered_shape = make([]int, 1)
        gathered_shape[0] = world_size * numel
        result.shape = gathered_shape
        result.numel = total_numel
        result.dtype = tensor.dtype
        return result
    } else {
        return tensor
    }
}

func alltoall(
    process_group pg,
    comm_tensor tensor,
    ref comm_metrics metrics) comm_tensor {
    int world_size = pg.world_size
    int rank = pg.my_rank
    int total_numel = tensor.numel
    int chunk_size = total_numel / world_size
    int dtype_sz = dtype_bytes(tensor.dtype)
    []float out_data = make([]float, total_numel)
    int j = 0
    for j < world_size {
        int src_start = j * chunk_size
        int dst_start = rank * chunk_size
        int k = 0
        for k < chunk_size {
            if src_start + k < total_numel && dst_start + k < total_numel {
                out_data[dst_start + k] = tensor.data[src_start + k]
            }
            k = k + 1
        }
        j = j + 1
    }
    comm_tensor result
    result.data = out_data
    result.shape = tensor.shape
    result.numel = total_numel
    result.dtype = tensor.dtype
    float elapsed = estimate_comm_time(chunk_size, dtype_sz, world_size, "alltoall")
    metrics.total_comm_time_ms = metrics.total_comm_time_ms + elapsed
    metrics.total_bytes_sent = metrics.total_bytes_sent + chunk_size * dtype_sz * world_size
    metrics.total_bytes_received = metrics.total_bytes_received + chunk_size * dtype_sz * world_size
    return result
}

func reduce(
    process_group pg,
    comm_tensor tensor,
    int reduce_op,
    int root_rank,
    ref comm_metrics metrics) comm_tensor {
    if pg.my_rank == root_rank {
        return allreduce(pg, tensor, reduce_op, metrics)
    } else {
        comm_tensor empty_result
        return empty_result
    }
}

func allreduce_copy(
    process_group pg,
    comm_tensor tensor,
    int reduce_op,
    ref comm_metrics metrics) comm_tensor {
    return allreduce(pg, tensor, reduce_op, metrics)
}

func allreduce_inplace(
    process_group pg,
    comm_tensor tensor,
    int reduce_op,
    ref comm_metrics metrics) comm_tensor {
    comm_tensor temp = allreduce(pg, tensor, reduce_op, metrics)
    return temp
}

func allreduce_async(
    process_group pg,
    comm_tensor tensor,
    int reduce_op,
    ref comm_metrics metrics) allreduce_async_result {
    comm_request req
    req.request_id = 99999
    req.is_completed = false
    req.error_code = 0
    comm_tensor result = allreduce(pg, tensor, reduce_op, metrics)
    req.is_completed = true
    allreduce_async_result out
    out.tensor = result
    out.request = req
    return out
}

func apply_reduce_op(float a, float b, int op) float {
    if op == OP_SUM { return a + b }
    if op == OP_PROD { return a * b }
    if op == OP_MAX {
        if a > b { return a } else { return b }
    }
    if op == OP_MIN {
        if a < b { return a } else { return b }
    }
    if op == OP_AVG { return (a + b) / 2.0 }
    return a + b
}

func compute_chunk_offset([]int chunk_sizes, int chunk_idx) int {
    int offset = 0
    int i = 0
    for i < chunk_idx {
        offset = offset + chunk_sizes[i]
        i = i + 1
    }
    return offset
}

func estimate_comm_time(int numel, int dtype_bytes, int world_size, string op_type) float {
    int total_bytes = numel * dtype_bytes
    float alpha = 5e-6
    float beta_inv = 1e9
    float bytes_per_gpu
    if op_type == "allreduce" || op_type == "ring" {
        bytes_per_gpu = total_bytes * 2.0 * (world_size - 1) / world_size
    } else if op_type == "allgather" {
        bytes_per_gpu = total_bytes * 2.0 * (world_size - 1) / world_size
    } else if op_type == "reducescatter" {
        bytes_per_gpu = total_bytes * (world_size - 1) / world_size
    } else if op_type == "alltoall" {
        int chunk_size = total_bytes / world_size
        bytes_per_gpu = chunk_size * 2.0 * (world_size - 1)
    } else {
        bytes_per_gpu = total_bytes
    }
    return alpha + bytes_per_gpu / beta_inv
}

func barrier(process_group pg, ref comm_metrics metrics) {
    float start_time = 0.0
    float elapsed = 0.01
    metrics.total_comm_time_ms = metrics.total_comm_time_ms + elapsed
}

struct nccl_unique_id {
    byte[NCCL_UNIQUE_ID_BYTES] id
}
int NCCL_UNIQUE_ID_BYTES = 128
func get_nccl_unique_id(process_group pg) nccl_unique_id {
    nccl_unique_id uid
    return uid
}

func nccl_comm_init_rank(nccl_unique_id uid, int rank, int world_size) int {
    return rank * 1000
}

func reset_metrics(ref comm_metrics m) {
    m.total_comm_time_ms = 0.0
    m.total_bytes_sent = 0.0
    m.total_bytes_received = 0.0
    m.num_allreduces = 0
    m.num_allgathers = 0
    m.num_reducescatters = 0
    m.bandwidth_efficiency = 1.0
}

func print_comm_summary(comm_metrics m, string prefix) {
    float sent_gb = m.total_bytes_sent / (1024.0 * 1024.0 * 1024.0)
    float recv_gb = m.total_bytes_received / (1024.0 * 1024.0 * 1024.0)
    float eff_pct = m.bandwidth_efficiency * 100.0
}

func estimate_collective_memory(int tensor_elements, int world_size, int dtype) float {
    int elem_bytes = dtype_bytes(dtype)
    float allgather_mem = tensor_elements * elem_bytes * world_size
    float allreduce_mem = tensor_elements * elem_bytes * 2
    return allgather_mem
}
