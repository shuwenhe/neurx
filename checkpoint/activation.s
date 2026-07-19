package neurx.checkpoint.activation

// ============================================================================
// Gradient Checkpointing Operations
// Save, restore, and recompute activations during forward/backward
// ============================================================================

use neurx.tensor.tensor
use neurx.autograd

// ========================================================================
# SAVE CHECKPOINT for a layer's input activation
# Called during forward pass before computing the layer
# Returns: (updated manager, whether to actually save or discard)
# ========================================================================

func save_checkpoint(
    checkpoint_manager mgr,
    int layer_id,
    tensor input,
    []tensor cheap_intermediates  // Values that are small to save (e.g., norms)
) (checkpoint_manager, bool) {
    if !mgr.config.enabled {
        return (mgr, false)  // Checkpointing disabled, save everything normally
    }

    // Determine if this layer should be checkpointed
    bool should_checkpoint = should_save_layer(mgr, layer_id)

    if !should_checkpoint {
        return (mgr, false)  // This layer saves all activations (no checkpoint)
    }

    // Create checkpoint entry
    layer_checkpoint ckpt {
        layer_id: layer_id,
        input_activation: input,  // Only save the input (not intermediate activations)
        intermediates: cheap_intermediates,
        memory_size_bytes: estimate_tensor_memory(input),
        is_on_cpu: false,
        recompute_cost: estimate_recompute_cost(layer_id),
    }

    // Optionally offload to CPU
    if mgr.config.cpu_offload {
        ckpt = offload_to_cpu(ckpt)
        ckpt.is_on_cpu = true
    }

    // Store in manager
    int idx = len(mgr.checkpoints)
    mgr.checkpoints.push(ckpt)
    mgr.layer_to_ckpt_idx[layer_id] = idx

    // Update statistics
    mgr.total_saved_activations = mgr.total_saved_activations + estimate_full_layer_memory(layer_id)
    mgr.estimated_memory_saved = mgr.estimated_memory_saved +
                                  (estimate_full_layer_memory(layer_id) - estimate_tensor_memory(input))

    (mgr, true)
}

func should_save_layer(checkpoint_manager mgr, int layer_id) bool {
    // If specific layers are specified, check against that list
    if len(mgr.config.checkpoint_layers) > 0 {
        for l in mgr.config.checkpoint_layers {
            if l == layer_id { return true }
        }
        return false
    }

    // Otherwise, use checkpoint_every strategy
    if mgr.config.checkpoint_every <= 0 {
        return true  // Checkpoint every layer
    }

    // Checkpoint every Nth layer
    (layer_id % mgr.config.checkpoint_every) == 0
}

// Estimate memory in bytes for a tensor (float32 = 4 bytes per element)
func estimate_tensor_memory(tensor t) int {
    len(t.data) * 4 * size_of_dimensions(t.shape)
}

// Rough estimate of full memory for a layer (input + all intermediates)
func estimate_full_layer_memory(int layer_id) int {
    // Heuristic: assume a Transformer layer has ~5x input memory for activations
    base_size = 1024 * 1024 * 4  // Default 1MB base
    base_size * 5
}

func size_of_dimensions([]int shape) int {
    if len(shape) == 0 { return 1 }
    int size = 1
    for s in shape { size = size * s }
    size
}

// Estimate FLOPs needed to recompute this layer
func estimate_recompute_cost(int layer_id) int {
    // Heuristic based on typical Transformer layer FLOPs
    // Assume ~2x forward compute cost for recomputation
    1000000  // Placeholder: actual cost depends on model architecture
}

// ============================================================================
// Checkpoint Restore & Recomputation
// During backward pass, retrieve or recompute activations as needed
// ============================================================================

// ========================================================================
# RESTORE ACTIVATION for a layer
# Called during backward pass when we need this layer's activations
# Returns the input activation (either from saved state or recomputed)
# ========================================================================

func restore_activation(
    checkpoint_manager mgr,
    int layer_id,
    layer_forward_fn forward_fn,  // Function to recompute layer forward pass if needed
) tensor {
    // Check if this layer has a checkpoint
    if !(layer_id in mgr.layer_to_ckpt_idx) {
        // Layer wasn't checkpointed - should have full activations saved normally
        return tensor { data: [], shape: [] }  // Error: shouldn't happen
    }

    int ckpt_idx = mgr.layer_to_ckpt_idx[layer_id]
    layer_checkpoint ckpt = mgr.checkpoints[ckpt_idx]

    // Case 1: Checkpoint is on CPU - bring back to device (GPU)
    if ckpt.is_on_cpu && mgr.config.cpu_offload {
        ckpt = load_from_cpu(ckpt)
        mgr.checkpoints[ckpt_idx] = ckpt  // Update manager state
    }

    // Return the saved input activation
    ckpt.input_activation
}

// ========================================================================
# RECOMPUTE LAYER OUTPUT from saved input
# When backward needs intermediate values that weren't saved,
# recompute them by running forward again with the checkpointed input
# ========================================================================

func recompute_layer(
    layer_checkpoint ckpt,
    layer_forward_fn forward_fn
) []tensor {
    // Run forward function with saved input
    // This returns all intermediate activations needed for backward
    tensor input = ckpt.input_activation

    // Call the actual layer forward function
    []tensor recomputed = forward_fn(input)

    // Optionally discard after use to free memory immediately
    // (depends on memory pressure and whether other layers need this)

    recomputed
}
