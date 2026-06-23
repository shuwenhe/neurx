package neurx.train

// ============================================================================
// Checkpoint Restore & Recomputation
// During backward pass, retrieve or recompute activations as needed
// ============================================================================

use neurx.tensor.tensor

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
