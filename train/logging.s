package neurx.train.logging

struct training_logger_state {
    bool enabled
    int message_count
    int last_step
    int last_epoch
    int last_flush_step
    int last_flush_epoch
}

func new_training_logger(bool enabled) training_logger_state {
    training_logger_state {
        enabled: enabled,
        message_count: 0,
        last_step: -1,
        last_epoch: -1,
        last_flush_step: -1,
        last_flush_epoch: -1,
    }
}

func training_logger_enable(training_logger_state state) training_logger_state {
    training_logger_state {
        enabled: true,
        message_count: state.message_count,
        last_step: state.last_step,
        last_epoch: state.last_epoch,
        last_flush_step: state.last_flush_step,
        last_flush_epoch: state.last_flush_epoch,
    }
}

func training_logger_disable(training_logger_state state) training_logger_state {
    training_logger_state {
        enabled: false,
        message_count: state.message_count,
        last_step: state.last_step,
        last_epoch: state.last_epoch,
        last_flush_step: state.last_flush_step,
        last_flush_epoch: state.last_flush_epoch,
    }
}

func training_logger_log(training_logger_state state, int step, int epoch) training_logger_state {
    int message_count = state.message_count
    int last_step = state.last_step
    int last_epoch = state.last_epoch
    if state.enabled {
        message_count = message_count + 1
        last_step = step
        last_epoch = epoch
    }
    training_logger_state {
        enabled: state.enabled,
        message_count: message_count,
        last_step: last_step,
        last_epoch: last_epoch,
        last_flush_step: state.last_flush_step,
        last_flush_epoch: state.last_flush_epoch,
    }
}

func training_logger_flush(training_logger_state state, int step, int epoch) training_logger_state {
    training_logger_state {
        enabled: state.enabled,
        message_count: state.message_count,
        last_step: state.last_step,
        last_epoch: state.last_epoch,
        last_flush_step: step,
        last_flush_epoch: epoch,
    }
}

func training_logger_state_dict(training_logger_state state) training_logger_state {
    state
}

func training_logger_load_state_dict(training_logger_state state, training_logger_state other) training_logger_state {
    other
}
