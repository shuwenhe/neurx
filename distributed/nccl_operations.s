package neurx.distributed

func nccl_init(nccl_config cfg) (nccl_communicator, error) {
    if cfg.world_size <= 0 || cfg.rank < 0 || cfg.rank >= cfg.world_size {
        return (nccl_communicator{},
                error{message: "Invalid world_size or rank"})
    }

    println("NCCL initialized: rank " + int_to_string(cfg.rank) +
            "/" + int_to_string(cfg.world_size) +
            " using " + cfg.backend)

    nccl_communicator comm {
        initialized: true,
        comm_handle: generate_nccl_handle(),
        config: cfg,
        bytes_sent: 0,
        bytes_received: 0,
        num_collective_ops: 0,
    }

    (comm, nil)
}
