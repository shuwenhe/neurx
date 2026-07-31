package neurx.posttrain.backend.fsdp

use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}
use neurx.distributed.{distributed_context}

// FSDP: Fully Sharded Data Parallel
// Implementation of PyTorch FSDP for distributed training

struct fsdp_config {
    int world_size
    int rank
    bool use_mixed_precision
    string sharding_strategy  // "full_shard", "shard_grad_op", "no_shard"
    bool cpu_offload
    int backward_prefetch
    int forward_prefetch
    bool use_orig_params
    []string ignored_modules
}

struct fsdp_state {
    []tensor sharded_params
    []tensor gathered_params
    []tensor param_grads
    int shard_size
    int global_size
    bool is_gathered
}

struct fsdp_module {
    module base_module
    fsdp_config config
    fsdp_state state
    distributed_context ctx
}

func new_fsdp_config() fsdp_config {
    fsdp_config {
        world_size: 1,
        rank: 0,
        use_mixed_precision: true,
        sharding_strategy: "full_shard",
        cpu_offload: false,
        backward_prefetch: 1,
        forward_prefetch: 1,
        use_orig_params: false,
        ignored_modules: []string{},
    }
}

func fsdp_shard_parameters(
    []tensor params,
    int world_size,
    int rank
) []tensor {
    // Shard parameters across processes
    []tensor sharded = []tensor{cap: params.len}
    
    int i = 0
    while i < params.len {
        tensor param = params[i]
        int total_size = param.shape[0]
        int shard_size = (total_size + world_size - 1) / world_size
        
        int start = rank * shard_size
        int end = start + shard_size
        if end > total_size {
            end = total_size
        }
        
        // Slice parameter for this rank
        tensor shard = tensor_ops.slice(param, 0, start, end)
        sharded[i] = shard
        
        i = i + 1
    }
    
    sharded
}

func fsdp_gather_parameters(
    []tensor sharded_params,
    distributed_context ctx
) []tensor {
    // All-gather parameters from all processes
    []tensor gathered = []tensor{cap: sharded_params.len}
    
    int i = 0
    while i < sharded_params.len {
        tensor shard = sharded_params[i]
        
        // All-gather across processes
        tensor full_param = ctx.all_gather(shard)
        gathered[i] = full_param
        
        i = i + 1
    }
    
    gathered
}

func fsdp_reduce_scatter_gradients(
    []tensor param_grads,
    distributed_context ctx
) []tensor {
    // Reduce-scatter gradients across processes
    []tensor reduced = []tensor{cap: param_grads.len}
    
    int i = 0
    while i < param_grads.len {
        tensor grad = param_grads[i]
        
        // Reduce-scatter operation
        tensor reduced_grad = ctx.reduce_scatter(grad)
        reduced[i] = reduced_grad
        
        i = i + 1
    }
    
    reduced
}

func new_fsdp_module(
    module base_module,
    fsdp_config config,
    distributed_context ctx
) fsdp_module {
    // Get module parameters
    []tensor params = base_module.parameters()
    
    // Shard parameters
    []tensor sharded = fsdp_shard_parameters(
        params,
        config.world_size,
        config.rank
    )
    
    fsdp_state state = fsdp_state {
        sharded_params: sharded,
        gathered_params: []tensor{},
        param_grads: []tensor{cap: params.len},
        shard_size: 0,
        global_size: 0,
        is_gathered: false,
    }
    
    fsdp_module {
        base_module: base_module,
        config: config,
        state: state,
        ctx: ctx,
    }
}

func fsdp_forward(fsdp_module fsdp_mod, tensor input) tensor {
    // Gather parameters before forward pass
    if !fsdp_mod.state.is_gathered {
        fsdp_mod.state.gathered_params = fsdp_gather_parameters(
            fsdp_mod.state.sharded_params,
            fsdp_mod.ctx
        )
        fsdp_mod.state.is_gathered = true
        
        // Update module with gathered parameters
        fsdp_mod.base_module.load_parameters(fsdp_mod.state.gathered_params)
    }
    
    // Forward pass
    tensor output = fsdp_mod.base_module.forward(input)
    
    // Free gathered parameters to save memory (if using full_shard strategy)
    if fsdp_mod.config.sharding_strategy == "full_shard" {
        fsdp_mod.state.is_gathered = false
        fsdp_mod.state.gathered_params = []tensor{}
    }
    
    output
}

func fsdp_backward(fsdp_module fsdp_mod, tensor grad_output) {
    // Gather parameters if needed
    if !fsdp_mod.state.is_gathered {
        fsdp_mod.state.gathered_params = fsdp_gather_parameters(
            fsdp_mod.state.sharded_params,
            fsdp_mod.ctx
        )
        fsdp_mod.state.is_gathered = true
    }
    
    // Backward pass
    grad_output.backward()
    
    // Get gradients
    []tensor grads = fsdp_mod.base_module.get_gradients()
    
    // Reduce-scatter gradients
    fsdp_mod.state.param_grads = fsdp_reduce_scatter_gradients(
        grads,
        fsdp_mod.ctx
    )
    
    // Update sharded parameters with reduced gradients
    fsdp_mod.state.sharded_params = fsdp_mod.state.param_grads
    
    // Free gathered parameters
    if fsdp_mod.config.sharding_strategy == "full_shard" {
        fsdp_mod.state.is_gathered = false
        fsdp_mod.state.gathered_params = []tensor{}
    }
}
