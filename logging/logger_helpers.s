package neurx.logging

// ============================================================================
// Logger Helper Functions
// ============================================================================

func current_time_seconds() float {
    // Placeholder: in real implementation would use system time
    float(lg.current_step * 0.1)  // Simulated time (100ms per step)
}

// Should we log at this step? (frequency-based filtering)
func should_log(logger lg) bool {
    if lg.config.log_frequency <= 1.0 { return true }  // Log every step
    
    int freq = int(lg.config.log_frequency)
    
    // Check if current step is a multiple of frequency
    (lg.current_step % freq) == 0
}

// Flush buffer to backends when it's full enough or on explicit call
func flush_if_needed(logger *lg) {
    int buffer_size = len(lg.metric_buffer)
    
    // Auto-flush based on step count
    bool should_flush = false
    
    if lg.config.log_to_tensorboard && buffer_size >= lg.config.flush_every_n_steps {
        should_flush = true
    }
    
    // Also flush if buffer is getting large (memory concern)
    if buffer_size > 1000 {
        should_flush = true
    }
    
    if should_flush {
        flush_metrics(lg)
    }
}

// Explicitly flush all buffered metrics
func flush_metrics(logger *lg) {
    if len(lg.metric_buffer) == 0 { 
        return 
    }
    
    // Write to TensorBoard
    if lg.config.log_to_tensorboard && lg.tb_writer.initialized {
        write_to_tensorboard(lg)
    }
    
    // Write to WandB
    if lg.config.log_to_wandb && lg.wb_run.active {
        write_to_wandb(lg)
    }
    
    // Clear buffer after successful writes
    lg.metric_buffer = []
}
