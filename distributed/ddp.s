package neurx.distributed.ddp

struct ddp_state {
    string name
    int bucket_cap
    bool find_unused
    int step
    []string params
    []int param_sizes
    []string ready_params
    int reduced_bucket_count
    bool gradient_synchronized
    float last_sync_scale
}

func copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
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

func new_ddp_state(string name, int bucket_cap, bool find_unused) ddp_state {
    ddp_state {
        name: name,
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
    []string params = copy_strings(state.params)
    []int param_sizes = copy_ints(state.param_sizes)
    params.push(param_name)
    param_sizes.push(clamp_positive(size, 1))
    ddp_state {
        name: state.name,
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
    []string ready = copy_strings(state.ready_params)
    ready.push(param_name)
    ddp_state {
        name: state.name,
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