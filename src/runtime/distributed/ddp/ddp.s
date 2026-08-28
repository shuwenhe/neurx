package neurx.distributed.ddp
use neurx.strings
use neurx.distributed.comm
struct ddp_state {
    string name
    string backend
    int rank
    int world_size
    bool initialized
    int bucket_cap
    bool find_unused
    int step
    string[] params
    int[] param_sizes
    string[] ready_params
    int reduced_bucket_count
    bool gradient_synchronized
    float last_sync_scale
}
func copy_ints(int[] values) int[] {
    int[] out = int[]{cap: len(values)}
    int i = 0
    for i < len(values) {
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
func has_string(string[] values, string value) bool {
    int i = 0
    for i < len(values) {
        if values[i] == value {
            return true
        }
        i = i + 1
    }
    false
}
func new_ddp_state(string name, int bucket_cap, bool find_unused) ddp_state {
    ddp_state {
        name: name,
        backend: "gloo",
        rank: 0,
        world_size: 1,
        initialized: false,
        bucket_cap: clamp_positive(bucket_cap, 1),
        find_unused: find_unused,
        step: 0,
        params: [],
        param_sizes: [],
        ready_params: [],
        reduced_bucket_count: 0,
        gradient_synchronized: false,
        last_sync_scale: 1.0,
    }
}
func ddp_state_dict(ddp_state state) ddp_state {
    ddp_state {
        name: state.name,
        backend: state.backend,
        rank: state.rank,
        world_size: state.world_size,
        initialized: state.initialized,
        bucket_cap: state.bucket_cap,
        find_unused: state.find_unused,
        step: state.step,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: copy_strings(state.ready_params),
        reduced_bucket_count: state.reduced_bucket_count,
        gradient_synchronized: state.gradient_synchronized,
        last_sync_scale: state.last_sync_scale,
    }
}
func ddp_load_state_dict(ddp_state state, ddp_state other) ddp_state {
    ddp_state {
        name: other.name,
        backend: other.backend,
        rank: other.rank,
        world_size: other.world_size,
        initialized: other.initialized,
        bucket_cap: other.bucket_cap,
        find_unused: other.find_unused,
        step: other.step,
        params: copy_strings(other.params),
        param_sizes: copy_ints(other.param_sizes),
        ready_params: copy_strings(other.ready_params),
        reduced_bucket_count: other.reduced_bucket_count,
        gradient_synchronized: other.gradient_synchronized,
        last_sync_scale: other.last_sync_scale,
    }
}
func ddp_name(ddp_state state) string {
    state.name
}
func ddp_process_group_backend(ddp_state state) string {
    state.backend
}
func ddp_process_group_rank(ddp_state state) int {
    state.rank
}
func ddp_process_group_world_size(ddp_state state) int {
    state.world_size
}
func ddp_process_group_initialized(ddp_state state) bool {
    state.initialized
}
func ddp_step(ddp_state state) int {
    state.step
}
func ddp_bucket_cap(ddp_state state) int {
    state.bucket_cap
}
func ddp_param_count(ddp_state state) int {
    len(state.params)
}
func ddp_ready_param_count(ddp_state state) int {
    len(state.ready_params)
}
func ddp_reduced_bucket_count(ddp_state state) int {
    state.reduced_bucket_count
}
func ddp_gradient_synchronized(ddp_state state) bool {
    state.gradient_synchronized
}
func ddp_is_distributed(ddp_state state) bool {
    state.initialized && state.world_size > 1
}
func ddp_sync_scale(ddp_state state) float {
    if state.world_size <= 1 {
        return 1.0
    }
    1.0 / state.world_size
}
func ddp_is_param_registered(ddp_state state, string param_name) bool {
    has_string(state.params, param_name)
}
func ddp_is_param_ready(ddp_state state, string param_name) bool {
    has_string(state.ready_params, param_name)
}
func ddp_add_param(ddp_state state, string param_name, int size) ddp_state {
    if has_string(state.params, param_name) {
        return ddp_state_dict(state)
    }
    string[] params = copy_strings(state.params)
    int[] param_sizes = copy_ints(state.param_sizes)
    params = append(params, param_name)
    param_sizes = append(param_sizes, clamp_positive(size, 1))
    ddp_state {
        name: state.name,
        backend: state.backend,
        rank: state.rank,
        world_size: state.world_size,
        initialized: state.initialized,
        bucket_cap: state.bucket_cap,
        find_unused: state.find_unused,
        step: state.step,
        params: params,
        param_sizes: param_sizes,
        ready_params: copy_strings(state.ready_params),
        reduced_bucket_count: state.reduced_bucket_count,
        gradient_synchronized: state.gradient_synchronized,
        last_sync_scale: state.last_sync_scale,
    }
}
func ddp_mark_grad_ready(ddp_state state, string param_name) ddp_state {
    if !has_string(state.params, param_name) {
        return ddp_state_dict(state)
    }
    if has_string(state.ready_params, param_name) {
        return ddp_state_dict(state)
    }
    string[] ready = copy_strings(state.ready_params)
    ready = append(ready, param_name)
    ddp_state {
        name: state.name,
        backend: state.backend,
        rank: state.rank,
        world_size: state.world_size,
        initialized: state.initialized,
        bucket_cap: state.bucket_cap,
        find_unused: state.find_unused,
        step: state.step,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: ready,
        reduced_bucket_count: state.reduced_bucket_count,
        gradient_synchronized: state.gradient_synchronized,
        last_sync_scale: state.last_sync_scale,
    }
}
func ddp_reduce_ready_buckets(ddp_state state, int world_size) ddp_state {
    int normalized_world = clamp_positive(world_size, 1)
    bool sync = len(state.ready_params) >= len(state.params) && len(state.params) > 0
    int reduced_bucket_count = state.reduced_bucket_count
    if sync {
        reduced_bucket_count = reduced_bucket_count + 1
    }
    ddp_state {
        name: state.name,
        backend: state.backend,
        rank: state.rank,
        world_size: state.world_size,
        initialized: state.initialized,
        bucket_cap: state.bucket_cap,
        find_unused: state.find_unused,
        step: state.step,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: copy_strings(state.ready_params),
        reduced_bucket_count: reduced_bucket_count,
        gradient_synchronized: sync,
        last_sync_scale: 1.0 / normalized_world,
    }
}
func ddp_finalize_step(ddp_state state) ddp_state {
    ddp_state {
        name: state.name,
        backend: state.backend,
        rank: state.rank,
        world_size: state.world_size,
        initialized: state.initialized,
        bucket_cap: state.bucket_cap,
        find_unused: state.find_unused,
        step: state.step + 1,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: [],
        reduced_bucket_count: state.reduced_bucket_count,
        gradient_synchronized: false,
        last_sync_scale: state.last_sync_scale,
    }
}
func ddp_attach_process_group(ddp_state state, process_group_state pg) ddp_state {
    ddp_state {
        name: state.name,
        backend: process_group_backend(pg),
        rank: process_group_rank(pg),
        world_size: process_group_world_size(pg),
        initialized: process_group_initialized(pg),
        bucket_cap: state.bucket_cap,
        find_unused: state.find_unused,
        step: state.step,
        params: copy_strings(state.params),
        param_sizes: copy_ints(state.param_sizes),
        ready_params: copy_strings(state.ready_params),
        reduced_bucket_count: state.reduced_bucket_count,
        gradient_synchronized: state.gradient_synchronized,
        last_sync_scale: state.last_sync_scale,
    }
}
func ddp_all_reduce_grad(ddp_state state, process_group_state pg, float[] grads) float[] {
    if !ddp_is_distributed(ddp_state_dict(state)) {
        return copy_float(grads)
    }
    all_reduce_sum(pg, grads)
}
func ddp_broadcast_params(ddp_state state, process_group_state pg, float[] params) float[] {
    if !ddp_is_distributed(ddp_state_dict(state)) {
        return copy_float(params)
    }
    broadcast(pg, 0, params)
}
