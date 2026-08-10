package neurx.distributed

func nccl_allgather(
    nccl_communicator *comm,
    uint64 send_buffer,
    uint64 recv_buffer,
    int count,
    string dtype
) error {
    if !comm->initialized {
        return error{message: "NCCL communicator not initialized"}
    }
    int send_bytes = count * get_dtype_size(dtype)
    int total_bytes = send_bytes * comm->config.world_size
    comm->bytes_sent = comm->bytes_sent + send_bytes
    comm->bytes_received = comm->bytes_received + total_bytes
    comm->num_collective_ops = comm->num_collective_ops + 1
    log_collective_op("ALLGATHER", "concat", total_bytes, comm->config.world_size)
    nil
}

func nccl_reducescatter(
    nccl_communicator *comm,
    uint64 recv_buffer,
    uint64 send_buffer,
    int count,
    string dtype,
    string reduce_op
) error {
    if !comm->initialized {
        return error{message: "NCCL communicator not initialized"}
    }
    int send_bytes = count * get_dtype_size(dtype) * comm->config.world_size
    int recv_bytes = count * get_dtype_size(dtype)
    comm->bytes_sent = comm->bytes_sent + send_bytes
    comm->bytes_received = comm->bytes_received + recv_bytes
    comm->num_collective_ops = comm->num_collective_ops + 1
    log_collective_op("REDUCESCATTER", reduce_op, send_bytes, comm->config.world_size)
    nil
}
