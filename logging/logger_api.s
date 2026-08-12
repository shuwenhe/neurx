package neurx.logging
func new_logger(logger_config cfg) logger {
    logger {
        config: cfg,
        current_step: 0,
        metric_buffer: [],
        message_buffer: [],
    }
}
func log_scalar(
    logger *lg,
    string name,
    float value,
    int step,
    map[string]string tags
) {
    if step < 0 {
        step = lg.current_step + lg.config.global_step_offset
    }
    metric_entry entry {
        step: step,
        name: name,
        type: metric_type.SCALAR,
        scalar_value: value,
        tags: tags,
        wall_time: current_time_seconds(),
    }
    lg.metric_buffer.push(entry)
    if lg.config.log_to_console && should_log(lg) {
        print_scalar_to_console(lg.config, name, value, step, tags)
    }
    flush_if_needed(lg)
}
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
    entry.metadata["text"] = text
    lg.metric_buffer.push(entry)
}
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
    if lg.config.log_to_console && level >= lg.config.console_level {
        print_message_to_console(lg.config, entry)
    }
}
