package neurx.os.boot

struct boot_state {
    bool early_memory_ready
    bool scheduler_ready
    bool vfs_ready
    bool network_ready
    bool accelerator_ready
    bool model_runtime_ready
    bool userspace_ready
    int completed_stages
    int failed_stage
    string error
}

func boot_state_create() boot_state {
    boot_state {
        early_memory_ready: false,
        scheduler_ready: false,
        vfs_ready: false,
        network_ready: false,
        accelerator_ready: false,
        model_runtime_ready: false,
        userspace_ready: false,
        completed_stages: 0,
        failed_stage: 0,
        error: ""
    }
}

func boot_fail(boot_state state, int stage, string message) boot_state {
    if state.failed_stage == 0 {
        state.failed_stage = stage
        state.error = message
    }
    return state
}

func init_early_memory(boot_state state) boot_state {
    if state.failed_stage != 0 { return state }
    state.early_memory_ready = true
    state.completed_stages = state.completed_stages + 1
    return state
}

func init_scheduler(boot_state state) boot_state {
    if !state.early_memory_ready {
        return boot_fail(state, 2, "scheduler requires early memory")
    }
    state.scheduler_ready = true
    state.completed_stages = state.completed_stages + 1
    return state
}

func init_vfs(boot_state state) boot_state {
    if !state.scheduler_ready {
        return boot_fail(state, 3, "VFS requires scheduler")
    }
    state.vfs_ready = true
    state.completed_stages = state.completed_stages + 1
    return state
}

func init_network(boot_state state) boot_state {
    if !state.vfs_ready {
        return boot_fail(state, 4, "network requires VFS")
    }
    state.network_ready = true
    state.completed_stages = state.completed_stages + 1
    return state
}

func init_accelerator(boot_state state) boot_state {
    if !state.scheduler_ready || !state.early_memory_ready {
        return boot_fail(state, 5, "accelerator requires memory and scheduler")
    }
    state.accelerator_ready = true
    state.completed_stages = state.completed_stages + 1
    return state
}

func init_model_runtime(boot_state state) boot_state {
    if !state.accelerator_ready || !state.vfs_ready {
        return boot_fail(state, 6, "model runtime requires accelerator and VFS")
    }
    state.model_runtime_ready = true
    state.completed_stages = state.completed_stages + 1
    return state
}

func start_userspace(boot_state state) boot_state {
    if !state.model_runtime_ready || !state.network_ready {
        return boot_fail(state, 7, "userspace requires model runtime and network")
    }
    state.userspace_ready = true
    state.completed_stages = state.completed_stages + 1
    return state
}

func boot_is_ready(boot_state state) bool {
    return state.failed_stage == 0 && state.completed_stages == 7 &&
        state.early_memory_ready && state.scheduler_ready && state.vfs_ready &&
        state.network_ready && state.accelerator_ready &&
        state.model_runtime_ready && state.userspace_ready
}

func run_boot_sequence(boot_state state) boot_state {
    boot_state current = state
    current = init_early_memory(current)
    current = init_scheduler(current)
    current = init_vfs(current)
    current = init_network(current)
    current = init_accelerator(current)
    current = init_model_runtime(current)
    current = start_userspace(current)
    return current
}
