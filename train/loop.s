package neurx.train.loop

struct training_loop_state {
    int epoch
    int step
}

func new_training_loop_state() training_loop_state {
    training_loop_state {
        epoch: 0,
        step: 0,
    }
}

func run_training_loop(training_loop_state state, int epochs) training_loop_state {
    training_loop_state {
        epoch: epochs,
        step: state.step,
    }
}
