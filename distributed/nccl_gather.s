package neurx.distributed

// ============================================================================
// ALLGATHER - Gather data from all GPUs to all GPUs
// Each GPU contributes a chunk, and every GPU receives ALL chunks concatenated.
//
// Primary use case: Tensor Parallelism (Megatron-style)
// When model weights are sharded across GPUs, we need to gather
// the full tensor before computing operations like softmax or layer norm.
//
// Example (2 GPUs, each has half of embedding matrix):
//   GPU 0: [emb_0]  -> AllGather -> [emb_0 | emb_1]
//   GPU 1: [emb_1]  -> AllGather -> [emb_0 | emb_1]
//
// ============================================================================

func nccl_allgather(
    nccl_communicator *comm,
    uint64 send_buffer,       // Local data to contribute [count elements]
    uint64 recv_buffer,       // Output buffer [count * world_size elements]
    int count,                // Elements per GPU
    string dtype              // Data type
) error {
    if !comm->initialized {
        return error{message: "NCCL communicator not initialized"}
    }
    
    // ncclAllgather(send_buffer, recv_buffer, count, dtype, comm, stream)
    
    int send_bytes = count * get_dtype_size(dtype)
    int total_bytes = send_bytes * comm->config.world_size
    
    comm->bytes_sent = comm->bytes_sent + send_bytes
    comm->bytes_received = comm->bytes_received + total_bytes
    comm->num_collective_ops = comm->num_collective_ops + 1
    
    log_collective_op("ALLGATHER", "concat", total_bytes, comm->config.world_size)
    
    nil
}

// ========================================================================
// REDUCESCATTER - Reduce then scatter results to each GPU
// Combination of Reduce + Scatter in one operation (more efficient)
//
// Primary use case: Gradient synchronization with partial results
// Or reverse of AllGather for tensor parallel backward pass
// ========================================================================

func nccl_reducescatter(
    nccl_communicator *comm,
    uint64 recv_buffer,       // Output buffer [count elements per GPU]
    uint64 send_buffer,       // Input buffer [count * world_size elements]
    int count,                // Output size per GPU
    string dtype,
    string reduce_op          // "sum" usually
) error {
    if !comm->initialized {
        return error{message: "NCCL communicator not initialized"}
    }
    
    // ncclReduceScatter(send_buffer, recv_buffer, count, dtype, op, comm, stream)
    
    int send_bytes = count * get_dtype_size(dtype) * comm->config.world_size
    int recv_bytes = count * get_dtype_size(dtype)
    
    comm->bytes_sent = comm->bytes_sent + send_bytes
    comm->bytes_received = comm->bytes_received + recv_bytes
    comm->num_collective_ops = comm->num_collective_ops + 1
    
    log_collective_op("REDUCESCATTER", reduce_op, send_bytes, comm->config.world_size)
    
    nil
}
