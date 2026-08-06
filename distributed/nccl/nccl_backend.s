package neurx.distributed

struct nccl_config {
    int world_size
    int rank
    string backend
    bool use_nvlinks
    int nccl_threads
    string blocking_mode
    float timeout_secs
}

struct nccl_communicator {
    bool initialized
    uint64 comm_handle
    nccl_config config
    int bytes_sent
    int bytes_received
    int num_collective_ops
}

