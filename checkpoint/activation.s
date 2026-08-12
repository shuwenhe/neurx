package neurx.checkpoint.activation
use neurx.tensor.tensor
use neurx.autograd
func save_checkpoint(
    checkpoint_manager mgr,
    int layer_id,
    tensor input,
    []tensor cheap_intermediates
) (checkpoint_manager, bool) {
    if !mgr.config.enabled {
        return (mgr, false)
    }
    bool should_checkpoint = should_save_layer(mgr, layer_id)
    if !should_checkpoint {
        return (mgr, false)
    }
    layer_checkpoint ckpt {
        layer_id: layer_id,
        input_activation: input,
        intermediates: cheap_intermediates,
        memory_size_bytes: estimate_tensor_memory(input),
        is_on_cpu: false,
        recompute_cost: estimate_recompute_cost(layer_id),
    }
    if mgr.config.cpu_offload {
        ckpt = offload_to_cpu(ckpt)
        ckpt.is_on_cpu = true
    }
    int idx = len(mgr.checkpoints)
    mgr.checkpoints.push(ckpt)
    mgr.layer_to_ckpt_idx[layer_id] = idx
    mgr.total_saved_activations = mgr.total_saved_activations + estimate_full_layer_memory(layer_id)
    mgr.estimated_memory_saved = mgr.estimated_memory_saved +
                                  (estimate_full_layer_memory(layer_id) - estimate_tensor_memory(input))
    (mgr, true)
}


func should_save_layer(checkpoint_manager mgr, int layer_id) bool {
    if len(mgr.config.checkpoint_layers) > 0 {
        for l in mgr.config.checkpoint_layers {
            if l == layer_id { return true }
        }
        return false
    }
    if mgr.config.checkpoint_every <= 0 {
        return true
    }
    (layer_id % mgr.config.checkpoint_every) == 0
}


func estimate_tensor_memory(tensor t) int {
    len(t.data) * 4 * size_of_dimensions(t.shape)
}


func estimate_full_layer_memory(int layer_id) int {
    base_size = 1024 * 1024 * 4
    base_size * 5
}


func size_of_dimensions([]int shape) int {
    if len(shape) == 0 { return 1 }
    int size = 1
    for s in shape { size = size * s }
    size
}


func estimate_recompute_cost(int layer_id) int {
    1000000
}


func restore_activation(
    checkpoint_manager mgr,
    int layer_id,
    layer_forward_fn forward_fn,
) tensor {
    if !(layer_id in mgr.layer_to_ckpt_idx) {
        return tensor { data: [], shape: [] }
    }
    int ckpt_idx = mgr.layer_to_ckpt_idx[layer_id]
    layer_checkpoint ckpt = mgr.checkpoints[ckpt_idx]
    if ckpt.is_on_cpu && mgr.config.cpu_offload {
        ckpt = load_from_cpu(ckpt)
        mgr.checkpoints[ckpt_idx] = ckpt
    }
    ckpt.input_activation
}


func recompute_layer(
    layer_checkpoint ckpt,
    layer_forward_fn forward_fn
) []tensor {
    tensor input = ckpt.input_activation
    []tensor recomputed = forward_fn(input)
    recomputed
}

