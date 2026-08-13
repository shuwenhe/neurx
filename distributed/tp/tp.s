package neurx.distributed.tp

struct tp_state {
    int world_size
    int rank
    int shard_dim
    bool enabled
}

struct tp_shard_spec {
    int start
    int end
    int shard_size
    int padded_size
}

func normalize_world_size(int world_size) int {
    if world_size > 0 {
        return world_size
    }
    1
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

func new_tp_state(int world_size, int rank, int shard_dim) tp_state {
    int normalized_world = normalize_world_size(world_size)
    int normalized_rank = clamp_rank(rank, normalized_world)
    tp_state {
        world_size: normalized_world,
        rank: normalized_rank,
        shard_dim: shard_dim,
        enabled: normalized_world > 1,
    }
}

func tp_compute_shard(tp_state state, int total_size) tp_shard_spec {
    int normalized_total = total_size
    if normalized_total < 0 {
        normalized_total = 0
    }
    int per_rank = (normalized_total + state.world_size - 1) / state.world_size
    int start = state.rank * per_rank
    int end = start + per_rank
    if end > normalized_total {
        end = normalized_total
    }
    int shard_size = end - start
    if shard_size < 0 {
        shard_size = 0
    }
    tp_shard_spec {
        start: start,
        end: end,
        shard_size: shard_size,
        padded_size: per_rank,
    }
}

func tp_enabled(tp_state state) bool {
    state.enabled
}

func tp_state_dict(tp_state state) tp_state {
    state
}

func tp_load_state_dict(tp_state state, tp_state other) tp_state {
    other
}

func tp_shard_spec_state_dict(tp_shard_spec spec) tp_shard_spec {
    spec
}

func tp_shard_spec_load_state_dict(tp_shard_spec spec, tp_shard_spec other) tp_shard_spec {
    other
}
