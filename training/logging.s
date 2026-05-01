package neurx.training.logging

struct training_logger_state {
    bool enabled
}

func new_training_logger(bool enabled) training_logger_state {
    training_logger_state {
        enabled: enabled,
    }
}

func training_logger_log(training_logger_state state, int step, int epoch) training_logger_state {
    del step
    del epoch
    state
}
