package neurx.logging
func current_time_seconds() float {
    float(lg.current_step * 0.1)
}


func should_log(logger lg) bool {
    if lg.config.log_frequency <= 1.0 { return true }
    int freq = int(lg.config.log_frequency)
    (lg.current_step % freq) == 0
}


func flush_if_needed(logger *lg) {
    int buffer_size = len(lg.metric_buffer)
    bool should_flush = false
    if lg.config.log_to_tensorboard && buffer_size >= lg.config.flush_every_n_steps {
        should_flush = true
    }
    if buffer_size > 1000 {
        should_flush = true
    }
    if should_flush {
        flush_metrics(lg)
    }
}


func flush_metrics(logger *lg) {
    if len(lg.metric_buffer) == 0 {
        return
    }
    if lg.config.log_to_tensorboard && lg.tb_writer.initialized {
        write_to_tensorboard(lg)
    }
    if lg.config.log_to_wandb && lg.wb_run.active {
        write_to_wandb(lg)
    }
    lg.metric_buffer = []
}

