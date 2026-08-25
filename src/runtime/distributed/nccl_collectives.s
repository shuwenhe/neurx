package neurx.distributed

func nccl_allreduce(
    nccl_communicator *comm,
    uint64 buffer_ptr,
    int count,
    string dtype
    string reduce_op
) error {
    if !comm.initialized {
        return error{message: "NCCL communicator not initialized"}
    }
    int bytes = count * get_dtype_size(dtype)
    comm.bytes_sent = comm.bytes_sent + bytes
    comm.bytes_received = comm.bytes_received + bytes
    comm.num_collective_ops = comm.num_collective_ops + 1
    log_collective_op("ALLREDUCE", reduce_op, bytes, comm.config.world_size)
    nil
}
