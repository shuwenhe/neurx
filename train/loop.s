package neurx.train.loop

use neurx.dl.dataloader.{dataloader_state, dataloader_step_output, new_state, has_next, next_batch, reset_state}

struct training_loop_state {
    int epoch
    int step
    bool should_stop
    int last_valid_tokens
}

struct training_loop_run_state {
    training_loop_state loop
    dataloader_state loader
}

func new_training_loop_state() training_loop_state {
    training_loop_state {
        epoch: 0,
        step: 0,
        should_stop: false,
        last_valid_tokens: 0,
    }
}

func new_training_run_state([]int token_ids, int batch_size, int seq_len) training_loop_run_state {
    training_loop_run_state {
        loop: new_training_loop_state(),
        loader: new_state(token_ids, batch_size, seq_len),
    }
}

func _advance_loop_state(training_loop_state state, int epoch_delta, int step_delta, int valid_tokens) training_loop_state {
    if state.should_stop {
        return state
    }
    training_loop_state {
        epoch: state.epoch + epoch_delta,
        step: state.step + step_delta,
        should_stop: state.should_stop,
        last_valid_tokens: valid_tokens,
    }
}

func stop_training_loop(training_loop_state state) training_loop_state {
    training_loop_state {
        epoch: state.epoch,
        step: state.step,
        should_stop: true,
        last_valid_tokens: state.last_valid_tokens,
    }
}

func resume_training_loop(training_loop_state state) training_loop_state {
    training_loop_state {
        epoch: state.epoch,
        step: state.step,
        should_stop: false,
        last_valid_tokens: state.last_valid_tokens,
    }
}

func run_training_loop(training_loop_state state, int epochs) training_loop_state {
    int loops = epochs
    if loops < 0 {
        loops = 0
    }
    training_loop_state current = state
    int i = 0
    while i < loops {
        current = _advance_loop_state(current, 1, 1, current.last_valid_tokens)
        i = i + 1
    }
    current
}

func train_epoch(training_loop_run_state state) training_loop_run_state {
    if !has_next(state.loader) {
        training_loop_run_state {
            loop: state.loop,
            loader: reset_state(state.loader),
        }
    }
    dataloader_step_output batch_output = next_batch(state.loader)
    training_loop_state loop = _advance_loop_state(state.loop, 1, 1, batch_output.batch.valid_tokens)
    training_loop_run_state {
        loop: loop,
        loader: batch_output.state,
    }
}

func train_epochs(training_loop_run_state state, int epochs) training_loop_run_state {
    int loops = epochs
    if loops < 0 {
        loops = 0
    }
    training_loop_run_state current = state
    int i = 0
    while i < loops {
        current = train_epoch(current)
        i = i + 1
        if current.loop.should_stop {
            return current
        }
    }
    current
}

func stop_training_run(training_loop_run_state state) training_loop_run_state {
    training_loop_run_state {
        loop: stop_training_loop(state.loop),
        loader: state.loader,
    }
}

func resume_training_run(training_loop_run_state state) training_loop_run_state {
    training_loop_run_state {
        loop: resume_training_loop(state.loop),
        loader: state.loader,
    }
}
