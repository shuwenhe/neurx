package neurx.distributed.nccl_binding

struct nccl_config {
    int rank
    int world_size
    int local_rank
    string master_addr
    int master_port
    bool enable_trace
}

struct nccl_communicator {
    int rank
    int world_size
    int64 handle
    bool initialized
}

struct nccl_operation {
    string op_type
    int64 send_buffer
    int64 recv_buffer
    int count
    string data_type
    string reduction_op
}

struct nccl_performance_stats {
    int total_ops
    float avg_latency_us
    float avg_bandwidth_gbps
    int64 total_bytes_transferred
}
extern func neurx_nccl_get_unique_id(int64 unique_id_ptr) int
extern func neurx_nccl_init_rank(int rank, int world_size, int64 unique_id) int64
extern func neurx_nccl_destroy_communicator(int64 comm) int
extern func neurx_nccl_all_reduce(int64 comm, int64 buffer, int count, string dtype, string op) int
extern func neurx_nccl_reduce(int64 comm, int64 send_buff, int64 recv_buff, int count, string dtype, string op, int root) int
extern func neurx_nccl_broadcast(int64 comm, int64 buffer, int count, string dtype, int root) int
extern func neurx_nccl_all_gather(int64 comm, int64 send_buff, int64 recv_buff, int count, string dtype) int
extern func neurx_nccl_reduce_scatter(int64 comm, int64 send_buff, int64 recv_buff, int count, string dtype, string op) int
extern func neurx_nccl_send(int64 comm, int64 buffer, int count, string dtype, int peer, int tag) int
extern func neurx_nccl_recv(int64 comm, int64 buffer, int count, string dtype, int peer, int tag) int

func new_nccl_config(int rank, int world_size) nccl_config {
    nccl_config{
        rank: rank,
        world_size: world_size,
        local_rank: rank % 8,
        master_addr: "localhost",
        master_port: 29500,
        enable_trace: false,
    }
}

func init_nccl_communicator(nccl_config config) nccl_communicator {
    nccl_communicator{
        rank: config.rank,
        world_size: config.world_size,
        handle: 0,
        initialized: false,
    }
}

func nccl_all_reduce(
    nccl_communicator comm,
    int64 buffer_ptr,
    int count,
    string dtype,
    string op,
) int {
    result := neurx_nccl_all_reduce(comm.handle, buffer_ptr, count, dtype, op)
    result
}

func nccl_reduce(
    nccl_communicator comm,
    int64 send_buffer,
    int64 recv_buffer,
    int count,
    string dtype,
    string op,
    int root,
) int {
    result := neurx_nccl_reduce(comm.handle, send_buffer, recv_buffer, count, dtype, op, root)
    result
}

func nccl_broadcast(
    nccl_communicator comm,
    int64 buffer,
    int count,
    string dtype,
    int root,
) int {
    result := neurx_nccl_broadcast(comm.handle, buffer, count, dtype, root)
    result
}

func nccl_all_gather(
    nccl_communicator comm,
    int64 send_buffer,
    int64 recv_buffer,
    int count,
    string dtype,
) int {
    result := neurx_nccl_all_gather(comm.handle, send_buffer, recv_buffer, count, dtype)
    result
}

func nccl_reduce_scatter(
    nccl_communicator comm,
    int64 send_buffer,
    int64 recv_buffer,
    int count,
    string dtype,
    string op,
) int {
    result := neurx_nccl_reduce_scatter(comm.handle, send_buffer, recv_buffer, count, dtype, op)
    result
}

func nccl_send(
    nccl_communicator comm,
    int64 buffer,
    int count,
    string dtype,
    int peer,
) int {
    result := neurx_nccl_send(comm.handle, buffer, count, dtype, peer, 0)
    result
}

func nccl_recv(
    nccl_communicator comm,
    int64 buffer,
    int count,
    string dtype,
    int peer,
) int {
    result := neurx_nccl_recv(comm.handle, buffer, count, dtype, peer, 0)
    result
}

func compute_allreduce_latency(int world_size, int count, string dtype) int {
    data_size := count
    if dtype == "float32" || dtype == "int32" {
        data_size = count * 4
    }
    if dtype == "float64" || dtype == "int64" {
        data_size = count * 8
    }
    network_bandwidth_gbps := 100
    latency_per_elem := data_size / network_bandwidth_gbps
    setup_latency := 10
    total_latency := setup_latency + latency_per_elem * log2(world_size)
    total_latency
}

func compute_broadcast_latency(int count, string dtype) int {
    data_size := count
    if dtype == "float32" || dtype == "int32" {
        data_size = count * 4
    }
    if dtype == "float64" || dtype == "int64" {
        data_size = count * 8
    }
    network_bandwidth_gbps := 100
    latency := data_size / network_bandwidth_gbps
    latency
}

func get_nccl_topology(int world_size) string {
    if world_size == 1 {
        return "single_gpu"
    }
    if world_size == 2 {
        return "nvlink_pair"
    }
    if world_size == 4 {
        return "nvlink_quad"
    }
    if world_size == 8 {
        return "full_nvswitch"
    }
    return "general"
}

func estimate_collective_bandwidth(
    string op_type,
    int count,
    int world_size,
) float {
    base_bandwidth := 100.0
    if op_type == "allreduce" {
        return base_bandwidth / float(world_size)
    }
    if op_type == "allgather" {
        return base_bandwidth / float(world_size)
    }
    if op_type == "reducescatter" {
        return base_bandwidth / float(world_size)
    }
    if op_type == "broadcast" {
        return base_bandwidth
    }
    base_bandwidth
}

func log2(int n) int {
    result := 0
    val := 1
    while val < n {
        val = val * 2
        result = result + 1
    }
    result
}
