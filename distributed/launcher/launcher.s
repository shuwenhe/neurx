package neurx.distributed.launcher
struct distributed_config {
    int world_size
    int rank
    int local_rank
    string master_addr
    int master_port
    string backend
}

func clamp_positive(int value, int fallback) int {
    if value > 0 {
        return value
    }
    fallback
}

func clamp_rank(int rank, int world_size) int {
    if rank < 0 {
        return 0
    }
    if rank >= world_size {
        return world_size - 1
    }
    rank
}

func new_distributed_config(int world_size, int rank, int local_rank, string master_addr, int master_port, string backend) distributed_config {
    int normalized_world_size = clamp_positive(world_size, 1)
    int normalized_rank = clamp_rank(rank, normalized_world_size)
    int normalized_local_rank = local_rank
    if normalized_local_rank < 0 {
        normalized_local_rank = 0
    }
    int normalized_master_port = master_port
    if normalized_master_port < 1 || normalized_master_port > 65535 {
        normalized_master_port = 29500
    }
    string normalized_master_addr = master_addr
    if master_addr == "" {
        normalized_master_addr = "127.0.0.1"
    }
    string normalized_backend = backend
    if normalized_backend == "" {
        normalized_backend = "nccl"
    }
    distributed_config {
        world_size: normalized_world_size,
        rank: normalized_rank,
        local_rank: normalized_local_rank,
        master_addr: normalized_master_addr,
        master_port: normalized_master_port,
        backend: normalized_backend,
    }
}

func distributed_config_state_dict(distributed_config cfg) distributed_config {
    distributed_config {
        world_size: cfg.world_size,
        rank: cfg.rank,
        local_rank: cfg.local_rank,
        master_addr: cfg.master_addr,
        master_port: cfg.master_port,
        backend: cfg.backend,
    }
}

func distributed_config_load_state_dict(distributed_config cfg, distributed_config other) distributed_config {
    distributed_config {
        world_size: other.world_size,
        rank: other.rank,
        local_rank: other.local_rank,
        master_addr: other.master_addr,
        master_port: other.master_port,
        backend: other.backend,
    }
}

func detect_distributed_config() distributed_config {
    string backend = env_get("TENSOR_DIST_BACKEND", "nccl")
    string master_addr = env_get("MASTER_ADDR", "127.0.0.1")
    new_distributed_config(1, 0, 0, master_addr, 29500, backend)
}

func validate_distributed_config(distributed_config cfg) bool {
    if cfg.world_size < 1 {
        return false
    }
    if cfg.rank < 0 || cfg.rank >= cfg.world_size {
        return false
    }
    if cfg.local_rank < 0 {
        return false
    }
    if cfg.master_port < 1 || cfg.master_port > 65535 {
        return false
    }
    if cfg.backend != "gloo" && cfg.backend != "nccl" && cfg.backend != "hccl" {
        return false
    }
    true
}

func is_distributed(distributed_config cfg) bool {
    cfg.world_size > 1
}

