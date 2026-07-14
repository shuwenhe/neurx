package neurx.distributed

// ============================================================================
// ALLREDUCE - The most important collective for distributed training!
// Combines data from all GPUs and distributes the result to everyone.
//
// Primary use case: Gradient synchronization in Data Parallel (DDP/FSDP)
// After each GPU computes its own gradients, we average them:
//   allreduce(gradient, op=SUM) / world_size
//
// NCCL implementations:
// 1. Ring algorithm: O(N) steps, O(alpha * N + beta * size * N) time
//    - Data circulates around a logical ring of GPUs
//    - Each step: send chunk to neighbor, receive from other neighbor
//    - Memory efficient: only needs one buffer
//    - Best for large payloads (>1MB)
//
// 2. Tree algorithm: O(log N) steps for small messages
//    - Uses reduction tree topology
//    - Faster for small messages but more memory overhead
//
// ============================================================================

func nccl_allreduce(
    nccl_communicator *comm,
    uint64 buffer_ptr,         // [in/out] Buffer containing local data,
                               //          will be replaced with reduced result
    int count,                 // Number of elements in buffer
    string dtype               // "fp32", "fp16", "bf16", "int32"
    string reduce_op           // "sum", "prod", "max", "min", "avg"
) error {
    if !comm->initialized {
        return error{message: "NCCL communicator not initialized"}
    }
    
    // In real implementation:
    // ncclAllReduce(
    //     buffer_ptr,        // send buffer
    //     buffer_ptr,        // recv buffer (can be same for in-place)
    //     count,
    //     get_nccl_dtype(dtype),
    //     get_nccl_op(reduce_op),  // ncclSum, ncclProd, ncclMax, etc.
    //     comm->comm_handle,
    //     stream              // CUDA stream
    // );
    
    int bytes = count * get_dtype_size(dtype)
    
    comm->bytes_sent = comm->bytes_sent + bytes
    comm->bytes_received = comm->bytes_received + bytes
    comm->num_collective_ops = comm->num_collective_ops + 1
    
    log_collective_op("ALLREDUCE", reduce_op, bytes, comm->config.world_size)
    
    nil
}
