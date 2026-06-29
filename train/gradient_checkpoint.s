package neurx.train

// ============================================================================
// Gradient Checkpointing (Activation Recomputation)
// Trade memory for compute: don't save activations, recompute on backward
// Critical for training large models with limited GPU memory
// Based on: "Training Deep Nets with Sublinear Memory Cost" (Chen et al., 2016)
// ============================================================================

// ---- Checkpoint Configuration ----
struct checkpoint_config {
    bool enabled              // Enable gradient checkpointing
    int checkpoint_every      // Save activations every N layers (default: 1 = every layer)
    bool use_rematerialization // Use rematerialization (recompute from inputs)
    []int checkpoint_layers   // Specific layer indices to checkpoint (-1 = auto)
    
    // Memory optimization
    bool cpu_offload          // Offload saved checkpoints to CPU memory
    bool sequential_offload   // Offload one at a time to minimize CPU RAM
    float memory_budget_gb    // Target memory budget (0 = auto-detect)
}

// Default configuration
func default_checkpoint_config() checkpoint_config {
    checkpoint_config {
        enabled: true,
        checkpoint_every: 1,
        use_rematerialization: true,
        checkpoint_layers: [],
        cpu_offload: false,
        sequential_offload: false,
        memory_budget_gb: 0.0,
    }
}

// ---- Checkpoint State for a Layer ----
struct layer_checkpoint {
    int layer_id
    tensor input_activation   // Saved input (for recomputing)
    []tensor intermediates   // Optional: some cheap-to-save intermediate values
    
    // Metadata
    int memory_size_bytes     // Approximate memory footprint
    bool is_on_cpu            // Currently offloaded to CPU?
    int recompute_cost        // Estimated FLOPs to recompute this layer
}

// ---- Checkpoint Manager (per model) ----
struct checkpoint_manager {
    checkpoint_config config
    []layer_checkpoint checkpoints  // All layer checkpoints
    map<int>int layer_to_ckpt_idx   // Map layer_id -> index in checkpoints array
    
    // Statistics
    int total_saved_activations     // Total size of saved activations (bytes)
    int estimated_memory_saved      // Estimated memory savings (bytes)
}

func new_checkpoint_manager(checkpoint_config cfg) checkpoint_manager {
    checkpoint_manager {
        config: cfg,
        checkpoints: [],
        layer_to_ckpt_idx: {},
        total_saved_activations: 0,
        estimated_memory_saved: 0,
    }
}
