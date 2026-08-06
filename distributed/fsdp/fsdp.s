package neurx.distributed.fsdp
import "neurx.distributed.nccl_backend"
enum fsdp_sharding_strategy {
    FULL_SHARD = 0
    SHARD_GRAD_OP = 1
    NO_SHARD = 2
}
struct fsdp_config {
    fsdp_sharding_strategy sharding_strategy
    bool mixed_precision
    bool use_orig_params
    bool sync_module_states
    int auto_wrap_policy
    int min_num_params
    bool cpu_offload
    bool pin_memory
    bool use_sharded_state_dict
    bool limit_all_gathers
    float gradient_predivide_factor
    float gradient_accumulation_steps
}

struct fsdp_state {
    int rank
    int world_size
    int local_rank
    int num_shards
    []int param_shards
    []int grad_shards
    []int optimizer_shards
    bool is_root
    nccl_backend.nccl_comm comm
    fsdp_config config
}

struct fsdp_param {
    []float local_data
    []float shard_data
    []float grad
    int global_offset
    int local_size
    int shard_size
    bool is_sharded
}

struct fsdp_module {
    fsdp_state state
    []fsdp_param params
    []float flattened_params
    []float flattened_grads
    int total_params
    int local_params
}

func new_fsdp_config() fsdp_config {
    fsdp_config {
        sharding_strategy: fsdp_sharding_strategy.FULL_SHARD,
        mixed_precision: true,
        use_orig_params: true,
        sync_module_states: true,
        auto_wrap_policy: 0,
        min_num_params: 1000000,
        cpu_offload: false,
        pin_memory: true,
        use_sharded_state_dict: true,
        limit_all_gathers: true,
        gradient_predivide_factor: 1.0,
        gradient_accumulation_steps: 1.0,
    }
}

func new_fsdp_state(int rank, int world_size, nccl_backend.nccl_comm comm) fsdp_state {
    fsdp_state {
        rank: rank,
        world_size: world_size,
        local_rank: rank % 8,
        num_shards: world_size,
        param_shards: []int{},
        grad_shards: []int{},
        optimizer_shards: []int{},
        is_root: rank == 0,
        comm: comm,
        config: new_fsdp_config(),
    }
}

func allocate_vector(int size, float init_val) []float {
    []float v = []float{cap: size}
    int i = 0
    while i < size {
        v[i] = init_val
        i = i + 1
    }
    v
}

func fsdp_init(pointer model, fsdp_state state) fsdp_module {
    []float all_params = model.parameters()
    int total_params = len(all_params)
    int shard_size = total_params / state.world_size
    int remainder = total_params % state.world_size
    int local_size = shard_size
    if state.rank < remainder {
        local_size = local_size + 1
    }
    int global_offset = shard_size * state.rank + min(state.rank, remainder)
    fsdp_module module {
        state: state,
        params: []fsdp_param{cap: 100},
        flattened_params: allocate_vector(local_size, 0.0),
        flattened_grads: allocate_vector(local_size, 0.0),
        total_params: total_params,
        local_params: local_size,
    }
    int i = 0
    while i < local_size && global_offset + i < total_params {
        module.flattened_params[i] = all_params[global_offset + i]
        i = i + 1
    }
    module
}

func fsdp_all_gather_params(fsdp_module module) fsdp_module {
    if module.state.config.sharding_strategy == fsdp_sharding_strategy.NO_SHARD {
        return module
    }
    []float full_params = allocate_vector(module.total_params, 0.0)
    nccl_backend.nccl_all_gather(
        module.flattened_params,
        full_params,
        module.local_params,
        module.state.comm,
    )
    int i = 0
    while i < len(module.params) {
        fsdp_param param = module.params[i]
        int j = 0
        while j < param.local_size {
            param.local_data[j] = full_params[param.global_offset + j]
            j = j + 1
        }
        module.params[i] = param
        i = i + 1
    }
    module
}

func fsdp_scatter_params(fsdp_module module) fsdp_module {
    if module.state.config.sharding_strategy == fsdp_sharding_strategy.NO_SHARD {
        return module
    }
    []float full_params = allocate_vector(module.total_params, 0.0)
    int i = 0
    while i < len(module.params) {
        fsdp_param param = module.params[i]
        int j = 0
        while j < param.local_size {
            full_params[param.global_offset + j] = param.local_data[j]
            j = j + 1
        }
        module.params[i] = param
        i = i + 1
    }
    nccl_backend.nccl_scatter(
        full_params,
        module.flattened_params,
        module.local_params,
        module.state.comm,
    )
    module
}

func fsdp_reduce_scatter_grads(fsdp_module module) fsdp_module {
    if module.state.config.sharding_strategy == fsdp_sharding_strategy.NO_SHARD {
        return module
    }
    []float full_grads = allocate_vector(module.total_params, 0.0)
    int i = 0
    while i < len(module.params) {
        fsdp_param param = module.params[i]
        int j = 0
        while j < param.local_size {
            full_grads[param.global_offset + j] = param.grad[j]
            j = j + 1
        }
        module.params[i] = param
        i = i + 1
    }
    nccl_backend.nccl_reduce_scatter(
        full_grads,
        module.flattened_grads,
        module.local_params,
        nccl_backend.nccl_reduction_op.NCCL_SUM,
        module.state.comm,
    )
    float scale = module.state.config.gradient_predivide_factor / module.state.world_size
    i = 0
    while i < module.local_params {
        module.flattened_grads[i] = module.flattened_grads[i] * scale
        i = i + 1
    }
    module
}

func fsdp_all_reduce_grads(fsdp_module module) fsdp_module {
    nccl_backend.nccl_all_reduce(
        module.flattened_grads,
        module.local_params,
        nccl_backend.nccl_reduction_op.NCCL_SUM,
        module.state.comm,
    )
    float scale = 1.0 / module.state.world_size
    int i = 0
    while i < module.local_params {
        module.flattened_grads[i] = module.flattened_grads[i] * scale
        i = i + 1
    }
    module
}

func fsdp_forward_pre_hook(fsdp_module module) fsdp_module {
    if module.state.config.sharding_strategy == fsdp_sharding_strategy.FULL_SHARD {
        module = fsdp_all_gather_params(module)
    }
    module
}

func fsdp_backward_post_hook(fsdp_module module) fsdp_module {
    if module.state.config.sharding_strategy == fsdp_sharding_strategy.FULL_SHARD {
        module = fsdp_reduce_scatter_grads(module)
    } else if module.state.config.sharding_strategy == fsdp_sharding_strategy.SHARD_GRAD_OP {
        module = fsdp_all_reduce_grads(module)
    }
    module
}

func fsdp_optimizer_step_pre_hook(fsdp_module module) fsdp_module {
    if module.state.config.sharding_strategy == fsdp_sharding_strategy.FULL_SHARD {
        module = fsdp_all_gather_params(module)
    }
    module
}

func fsdp_optimizer_step_post_hook(fsdp_module module) fsdp_module {
    if module.state.config.sharding_strategy == fsdp_sharding_strategy.FULL_SHARD {
        module = fsdp_scatter_params(module)
    }
    module
}

func fsdp_flatten_params(fsdp_module module) fsdp_module {
    int offset = 0
    int i = 0
    while i < len(module.params) {
        fsdp_param param = module.params[i]
        param.global_offset = offset
        param.local_size = len(param.local_data)
        param.shard_size = param.local_size / module.state.world_size
        int j = 0
        while j < param.local_size && offset + j < module.total_params {
            module.flattened_params[offset + j] = param.local_data[j]
            j = j + 1
        }
        offset = offset + param.local_size
        module.params[i] = param
        i = i + 1
    }
    module
}

func fsdp_unflatten_params(fsdp_module module) fsdp_module {
    int offset = 0
    int i = 0
    while i < len(module.params) {
        fsdp_param param = module.params[i]
        int j = 0
        while j < param.local_size && offset + j < module.total_params {
            param.local_data[j] = module.flattened_params[offset + j]
            j = j + 1
        }
        offset = offset + param.local_size
        module.params[i] = param
        i = i + 1
    }
    module
}

func fsdp_save_checkpoint(fsdp_module module, string path) bool {
    if module.state.is_root {
        module = fsdp_all_gather_params(module)
        int i = 0
        while i < module.total_params {
            write_float_to_file(path, module.flattened_params[i])
            i = i + 1
        }
    }
    nccl_backend.nccl_barrier(module.state.comm)
    true
}

func fsdp_load_checkpoint(fsdp_module module, string path) bool {
    if module.state.is_root {
        []float full_params = allocate_vector(module.total_params, 0.0)
        int i = 0
        while i < module.total_params {
            full_params[i] = read_float_from_file(path, i)
            i = i + 1
        }
        nccl_backend.nccl_broadcast(
            full_params,
            module.total_params,
            0,
            module.state.comm,
        )
    } else {
        nccl_backend.nccl_broadcast(
            module.flattened_params,
            module.total_params,
            0,
            module.state.comm,
        )
    }
    module = fsdp_scatter_params(module)
    true
}

func write_float_to_file(string path, float value) {
}

func read_float_from_file(string path, int idx) float {
    0.0
}

func fsdp_compute_memory_savings(fsdp_module module) float {
    float total_memory = module.total_params * 4.0 / (1024 * 1024 * 1024)
    float local_memory = module.local_params * 4.0 / (1024 * 1024 * 1024)
    (1.0 - local_memory / total_memory) * 100.0
}

func fsdp_module_parameters(fsdp_module module) []float {
    module.flattened_params
}

func fsdp_module_gradients(fsdp_module module) []float {
    module.flattened_grads
}

func fsdp_zero_grad(fsdp_module module) fsdp_module {
    int i = 0
    while i < module.local_params {
        module.flattened_grads[i] = 0.0
        i = i + 1
    }
    int j = 0
    while j < len(module.params) {
        fsdp_param param = module.params[j]
        int k = 0
        while k < len(param.grad) {
            param.grad[k] = 0.0
            k = k + 1
        }
        module.params[j] = param
        j = j + 1
    }
    module
}

func min(int a, int b) int {
    if a < b {
        return a
    }
    b
}

func fsdp_set_gradients(fsdp_module module, []float grads) fsdp_module {
    int i = 0
    while i < min(len(grads), module.local_params) {
        module.flattened_grads[i] = grads[i]
        i = i + 1
    }
    module
}

func fsdp_get_gradients(fsdp_module module) []float {
    copy_vector(module.flattened_grads)
}

func copy_vector([]float src) []float {
    int n = len(src)
    []float out = []float{cap: n}
    for i := 0; i < n; i += 1 {
        out[i] = src[i]
    }
    out
}
