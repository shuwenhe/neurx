package neurx.logging

// ============================================================================
// Logger API - High-level functions for logging during training
// ============================================================================

// Create new logger with given configuration
func new_logger(logger_config cfg) logger {
    logger {
        config: cfg,
        current_step: 0,
        metric_buffer: [],
        message_buffer: [],
    }
}

// ========================================================================
# LOG SCALAR METRIC
# Most common operation: log a single value (loss, accuracy, lr, etc.)
# ========================================================================

func log_scalar(
    logger *lg,
    string name,
    float value,
    int step,              // Global step (-1 = auto-increment)
    map[string]string tags
) {
    if step < 0 { 
        step = lg.current_step + lg.config.global_step_offset 
    }
    
    // Add to buffer
    metric_entry entry {
        step: step,
        name: name,
        type: metric_type.SCALAR,
        scalar_value: value,
        tags: tags,
        wall_time: current_time_seconds(),
    }
    
    lg.metric_buffer.push(entry)
    
    // Console output (if enabled and frequency matches)
    if lg.config.log_to_console && should_log(lg) {
        print_scalar_to_console(lg.config, name, value, step, tags)
    }
    
    // Immediate write to backends (or buffer for batch writes)
    flush_if_needed(lg)
}

// ========================================================================
# LOG HISTOGRAM
# For distributions like gradient norms per layer, activation values, etc.
# ========================================================================

func log_histogram(
    logger *lg,
    string name,
    []float values,
    int step,
    map[string]string tags
) {
    if step < 0 {
        step = lg.current_step + lg.config.global_step_offset
    }
    
    metric_entry entry {
        step: step,
        name: name,
        type: metric_type.HISTOGRAM,
        histogram_values: values,
        tags: tags,
        wall_time: current_time_seconds(),
    }
    
    lg.metric_buffer.push(entry)
}

// ========================================================================
# LOG TEXT / SAMPLES
# For generated text samples, error messages, etc.
# ========================================================================

func log_text(
    logger *lg,
    string name,
    string text,
    int step,
    map[string]string tags
) {
    if step < 0 {
        step = lg.current_step + lg.config.global_step_offset
    }
    
    metric_entry entry {
        step: step,
        name: name,
        type: metric_type.TEXT,
        tags: tags,
        wall_time: current_time_seconds(),
    }
    
    // Store text in metadata (as we don't have a dedicated field)
    entry.metadata["text"] = text
    
    lg.metric_buffer.push(entry)
}

// ========================================================================
# LOG MESSAGE (for console/file logging of status messages)
# ========================================================================

func log_message(
    logger *lg,
    log_level level,
    string message
) {
    log_entry entry {
        timestamp: current_time_seconds(),
        level: level,
        message: message,
        metadata: {},
    }
    
    lg.message_buffer.push(entry)
    
    // Console output
    if lg.config.log_to_console && level >= lg.config.console_level {
        print_message_to_console(lg.config, entry)
    }
}
