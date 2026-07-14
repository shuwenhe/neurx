package neurx.distributed

// ============================================================================
// NCCL Backend - NVIDIA Collective Communication Library
// Provides high-performance multi-GPU communication primitives:
// - AllReduce: Sum/Average/Max across all GPUs (for gradient synchronization)
// - AllGather: Gather data from all GPUs to all GPUs (for tensor parallelism)
// - ReduceScatter: Scatter reduced results to each GPU
// - Broadcast: Send data from one GPU to all others
// - Send/Recv: Point-to-point communication (for pipeline parallelism)
//
// Critical for distributed training performance!
// ============================================================================

// ---- NCCL Configuration ----
struct nccl_config {
    int world_size              // Total number of GPUs/workers
    int rank                   // This worker's rank (0 to world_size-1)
    
    // Communication backend
    string backend             // "nccl" (default), "gloo" (CPU), "mpi"
    
    // Performance tuning
    bool use_nvlinks           // Use NVLink if available (much faster than PCIe)
    int nccl_threads           // Internal NCCL threads (usually 1 is fine)
    string blocking_mode       // "blocking" or "non-blocking"
    
    // Timeout and error handling
    float timeout_secs         // NCCL operation timeout
}

// ---- NCCL Communicator (connection handle) ----
struct nccl_communicator {
    bool initialized
    uint64 comm_handle          // ncclComm_t (opaque handle from NCCL library)
    nccl_config config
    
    // Statistics
    int bytes_sent              // Total data sent
    int bytes_received          // Total data received
    int num_collective_ops      // Number of collective operations performed
}
