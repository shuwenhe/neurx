package neurx.amp.gradient_checkpoint
struct checkpoint_context {
    [][]float saved_activations
    []bool is_checkpoint_required
}

func new_checkpoint_context() checkpoint_context {
    checkpoint_context {
        saved_activations: make([][]float, 0),
        is_checkpoint_required: make([]bool, 0),
    }
}

func checkpoint_save_activation(
    checkpoint_context ctx,
    []float activation
) checkpoint_context {
    ctx.saved_activations = append(ctx.saved_activations, clone_activation(activation))
    ctx.is_checkpoint_required = append(ctx.is_checkpoint_required, true)
    return ctx
}

func checkpoint_get_activation(checkpoint_context ctx, int layer_id) []float {
    if layer_id < 0 {
        return []float{}
    }
    if layer_id >= len(ctx.saved_activations) {
        return []float{}
    }
    return clone_activation(ctx.saved_activations[layer_id])
}

func checkpoint_clear_activation(checkpoint_context ctx, int layer_id) checkpoint_context {
    if layer_id >= 0 {
        if layer_id < len(ctx.saved_activations) {
            ctx.is_checkpoint_required[layer_id] = false
        }
    }
    return ctx
}

func checkpoint_get_memory_saved(checkpoint_context ctx) int {
    int total = 0
    int i = 0
    while i < len(ctx.saved_activations) {
        if !ctx.is_checkpoint_required[i] {
            total = total + len(ctx.saved_activations[i])
        }
        i = i + 1
    }
    return total
}

func clone_activation([]float act) []float {
    []float cloned = []float{cap: len(act)}
    int i = 0
    while i < len(act) {
        cloned[i] = act[i]
        i = i + 1
    }
    return cloned
}
