package neurx.distributed.zero
use neurx.strings
use neurx.distributed.comm
use neurx.strings

struct zero_state {
    string name
    string backend
    int world_size
    int rank
    int shard_dim
    int bucket_cap
    string stage
    bool initialized
    []string params
    []int param_sizes
    []string ready_params
    int reduced_bucket_count
    int gathered_bucket_count
    float last_sync_scale
}

func copy_ints([]int values) []int {
    []int out = []int{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
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

func has_string([]string values, string value) bool {
    int i = 0
    while i < len(values) {
        if values[i] == value {
            return true
        }
        i = i + 1
    }
    false
}

func normalize_stage(string stage) string {
    if stage == "zero-1" || stage == "zero-2" || stage == "zero-3" {
        return stage
    }
    "zero-2"
}

func new_zero_state(string name, string backend, int world_size, int rank, int shard_dim, int bucket_cap, string stage) zero_state {
    int normalized_world = clamp_positive(world_size, 1)
    zero_state {
        name: name,
        backend: backend,
        world_size: normalized_world,
        rank: clamp_rank(rank, normalized_world),
        shard_dim: clamp_positive(shard_dim, 1),
        bucket_cap: clamp_positive(bucket_cap, 1),
        stage: normalize_stage(stage),
        initialized: true,
        params: [],
        param_sizes: [],
        ready_params: [],
        reduced_bucket_count: 0,
        gathered_bucket_count: 0,
        last_sync_scale: 1.0,
    }
}

func zero_state_dict(zero_state state) zero_state {
    zero_state {
        name: state.name,
        backend: state.backend,
        world_size: state.world_size,
        rank: state.rank,
        shard_dim: state.shard_dim,
        bucket_cap: state.bucket_cap,
        stage: state.stage,
        initialized: state.initialized,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: copy_strings(state.ready_params),
        reduced_bucket_count: state.reduced_bucket_count,
        gathered_bucket_count: state.gathered_bucket_count,
        last_sync_scale: state.last_sync_scale,
    }
}

func zero_load_state_dict(zero_state state, zero_state other) zero_state {
    zero_state {
        name: other.name,
        backend: other.backend,
        world_size: other.world_size,
        rank: other.rank,
        shard_dim: other.shard_dim,
        bucket_cap: other.bucket_cap,
        stage: other.stage,
        initialized: other.initialized,
        params: copy_strings(other.params),
        param_sizes: copy_ints(other.param_sizes),
        ready_params: copy_strings(other.ready_params),
        reduced_bucket_count: other.reduced_bucket_count,
        gathered_bucket_count: other.gathered_bucket_count,
        last_sync_scale: other.last_sync_scale,
    }
}

func zero_name(zero_state state) string {
    state.name
}

func zero_stage(zero_state state) string {
    state.stage
}

func zero_enabled(zero_state state) bool {
    state.initialized && state.world_size > 1
}

func zero_optimizer_sharded(zero_state state) bool {
    zero_enabled(state) && state.stage != "zero-1"
}

func zero_param_count(zero_state state) int {
    len(state.params)
}

func zero_ready_param_count(zero_state state) int {
    len(state.ready_params)
}

func zero_reduced_bucket_count(zero_state state) int {
    state.reduced_bucket_count
}

func zero_gathered_bucket_count(zero_state state) int {
    state.gathered_bucket_count
}

func zero_add_param(zero_state state, string param_name, int size) zero_state {
    if has_string(state.params, param_name) {
        return zero_state_dict(state)
    }
    []string params = copy_strings(state.params)
    []int param_sizes = copy_ints(state.param_sizes)
    params.push(param_name)
    param_sizes.push(clamp_positive(size, 1))
    zero_state {
        name: state.name,
        backend: state.backend,
        world_size: state.world_size,
        rank: state.rank,
        shard_dim: state.shard_dim,
        bucket_cap: state.bucket_cap,
        stage: state.stage,
        initialized: state.initialized,
        params: params,
        param_sizes: param_sizes,
        ready_params: copy_strings(state.ready_params),
        reduced_bucket_count: state.reduced_bucket_count,
        gathered_bucket_count: state.gathered_bucket_count,
        last_sync_scale: state.last_sync_scale,
    }
}

func zero_mark_grad_ready(zero_state state, string param_name) zero_state {
    if !has_string(state.params, param_name) {
        return zero_state_dict(state)
    }
    if has_string(state.ready_params, param_name) {
        return zero_state_dict(state)
    }
    []string ready = copy_strings(state.ready_params)
    ready.push(param_name)
    zero_state {
        name: state.name,
        backend: state.backend,
        world_size: state.world_size,
        rank: state.rank,
        shard_dim: state.shard_dim,
        bucket_cap: state.bucket_cap,
        stage: state.stage,
        initialized: state.initialized,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: ready,
        reduced_bucket_count: state.reduced_bucket_count,
        gathered_bucket_count: state.gathered_bucket_count,
        last_sync_scale: state.last_sync_scale,
    }
}

func zero_reduce_scatter_grads(zero_state state, []float grads) []float {
    if !zero_optimizer_sharded(state) {
        return copy_float(grads)
    }
    reduce_scatter_sum(new_process_group(state.backend, state.rank, state.world_size), grads)
}

func zero_all_gather_params(zero_state state, []float shard_values) []float {
    if !zero_optimizer_sharded(state) {
        return copy_float(shard_values)
    }
    all_gather(new_process_group(state.backend, state.rank, state.world_size), shard_values)
}

func zero_mark_reduced(zero_state state) zero_state {
    zero_state {
        name: state.name,
        backend: state.backend,
        world_size: state.world_size,
        rank: state.rank,
        shard_dim: state.shard_dim,
        bucket_cap: state.bucket_cap,
        stage: state.stage,
        initialized: state.initialized,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: copy_strings(state.ready_params),
        reduced_bucket_count: state.reduced_bucket_count + 1,
        gathered_bucket_count: state.gathered_bucket_count,
        last_sync_scale: 1.0 / clamp_positive(state.world_size, 1),
    }
}

func zero_mark_gathered(zero_state state) zero_state {
    zero_state {
        name: state.name,
        backend: state.backend,
        world_size: state.world_size,
        rank: state.rank,
        shard_dim: state.shard_dim,
        bucket_cap: state.bucket_cap,
        stage: state.stage,
        initialized: state.initialized,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: copy_strings(state.ready_params),
        reduced_bucket_count: state.reduced_bucket_count,
        gathered_bucket_count: state.gathered_bucket_count + 1,
        last_sync_scale: state.last_sync_scale,
    }
}

func zero_finalize_step(zero_state state) zero_state {
    zero_state {
        name: state.name,
        backend: state.backend,
        world_size: state.world_size,
        rank: state.rank,
        shard_dim: state.shard_dim,
        bucket_cap: state.bucket_cap,
        stage: state.stage,
        initialized: state.initialized,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: [],
        reduced_bucket_count: state.reduced_bucket_count,
        gathered_bucket_count: state.gathered_bucket_count,
        last_sync_scale: state.last_sync_scale,
    }
}

