package neurx.logging

// ============================================================================
// Training Dashboard & Progress Display
// Console-based real-time training monitoring
// ============================================================================

// ---- Training Metrics (collected per step/epoch) ----
struct training_metrics {
    // Loss values
    float current_loss         // Most recent loss
    []float recent_losses      // Rolling window of losses (for smoothing)
    float avg_loss             // Running average loss
    
    // Timing & Throughput
    float samples_per_second   // Current throughput
    float tokens_per_second    // Token throughput (for LM training)
    float avg_step_time        // Average time per step (seconds)
    
    // Learning rate
    float current_lr           // Current learning rate value
    
    // GPU / System stats
    float gpu_memory_used_gb   // GPU memory in use
    float gpu_memory_total_gb  // Total GPU memory available
    float cpu_percent          // CPU utilization (%)
    float memory_used_gb       // System RAM used
    
    // Progress counters
    int global_step            // Total steps taken so far
    int steps_in_epoch         // Steps completed in current epoch
    int total_steps            // Total steps for this run
    int epoch                  // Current epoch number
    int total_epochs           // Total epochs to train
    
    // Quality metrics (computed periodically)
    float validation_loss      // Last computed validation loss
    float accuracy             // Last computed accuracy
    float perplexity           // Last computed perplexity
    
    // Best model tracking
    float best_validation_loss // Best val loss seen so far
    int best_step              // Step when best model was saved
}

// Initialize metrics with default values
func new_training_metrics() training_metrics {
    training_metrics {
        current_loss: 0.0,
        recent_losses: [],
        avg_loss: 0.0,
        
        samples_per_second: 0.0,
        tokens_per_second: 0.0,
        avg_step_time: 0.0,
        
        current_lr: 0.0,
        
        gpu_memory_used_gb: 0.0,
        gpu_memory_total_gb: 0.0,
        cpu_percent: 0.0,
        memory_used_gb: 0.0,
        
        global_step: 0,
        steps_in_epoch: 0,
        total_steps: 10000,
        epoch: 0,
        total_epochs: 10,
        
        validation_loss: 99999.9,
        accuracy: 0.0,
        perplexity: 99999.9,
        
        best_validation_loss: 99999.9,
        best_step: -1,
    }
}
