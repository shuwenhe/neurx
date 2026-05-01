package neurx.train.loop

use neurx.dl.dataloader.{dataloader_state, dataloader_step_output, new_state, has_next, next_batch, reset_state}
use neurx.train.amp.{autocast_state, grad_scaler_state, new_autocast_state, new_grad_scaler, grad_scaler_step}
use neurx.train.checkpoint_manager.{checkpoint_manager_state, new_checkpoint_manager, checkpoint_manager_save, checkpoint_manager_mark_best}
use neurx.train.logging.{training_logger_state, new_training_logger, training_logger_log, training_logger_flush}

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

struct training_pipeline_state {
    training_loop_state loop
    dataloader_state loader
    training_logger_state logger
    grad_scaler_state scaler
    checkpoint_manager_state checkpoint
    autocast_state autocast
    float last_loss
    float best_score
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

func new_training_pipeline_state([]int token_ids, int batch_size, int seq_len) training_pipeline_state {
    training_pipeline_state {
        loop: new_training_loop_state(),
        loader: new_state(token_ids, batch_size, seq_len),
        logger: new_training_logger(true),
        scaler: new_grad_scaler(1.0, 2.0, 0.5, 2000, true),
        checkpoint: new_checkpoint_manager(5, 100, false),
        autocast: new_autocast_state(false, 0),
        last_loss: 0.0,
        best_score: 0.0,
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
    dataloader_state loader = state.loader
    int epoch_delta = 0
    if !has_next(loader) {
        loader = reset_state(loader)
        epoch_delta = 1
    }
    dataloader_step_output batch_output = next_batch(loader)
    training_loop_state loop = _advance_loop_state(state.loop, epoch_delta, 1, batch_output.batch.valid_tokens)
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

func _loss_from_valid_tokens(int valid_tokens) float {
    float loss = 0.0
    if valid_tokens > 0 {
        loss = valid_tokens
    }
    loss
}

func _score_from_loss(float loss) float {
    if loss < 0.0 {
        return 0.0 - loss
    }
    loss
}

func train_step(training_pipeline_state state) training_pipeline_state {
    dataloader_state loader = state.loader
    int epoch_delta = 0
    if !has_next(loader) {
        loader = reset_state(loader)
        epoch_delta = 1
    }
    dataloader_step_output batch_output = next_batch(loader)
    int next_step = state.loop.step + 1
    training_loop_state loop = _advance_loop_state(state.loop, epoch_delta, 1, batch_output.batch.valid_tokens)
    float loss = _loss_from_valid_tokens(batch_output.batch.valid_tokens)
    float scaled_loss = loss
    if state.scaler.enabled {
        scaled_loss = loss * state.scaler.scale
    }
    grad_scaler_state scaler = grad_scaler_step(state.scaler, scaled_loss)
    training_logger_state logger = training_logger_log(state.logger, next_step, loop.epoch)
    training_logger_state flushed_logger = logger
    int flush_bucket = next_step / 10
    if flush_bucket * 10 == next_step {
        flushed_logger = training_logger_flush(logger, next_step, loop.epoch)
    }
    checkpoint_manager_state checkpoint = checkpoint_manager_save(state.checkpoint, next_step, loop.epoch)
    float score = _score_from_loss(loss)
    checkpoint = checkpoint_manager_mark_best(checkpoint, next_step, loop.epoch, score)
    training_pipeline_state {
        loop: loop,
        loader: batch_output.state,
        logger: flushed_logger,
        scaler: scaler,
        checkpoint: checkpoint,
        autocast: state.autocast,
        last_loss: loss,
        best_score: score,
    }
}

func train_steps(training_pipeline_state state, int steps) training_pipeline_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    training_pipeline_state current = state
    int i = 0
    while i < loops {
        current = train_step(current)
        i = i + 1
        if current.loop.should_stop {
            return current
        }
    }
    current
}

func stop_training_pipeline(training_pipeline_state state) training_pipeline_state {
    training_pipeline_state {
        loop: stop_training_loop(state.loop),
        loader: state.loader,
        logger: state.logger,
        scaler: state.scaler,
        checkpoint: state.checkpoint,
        autocast: state.autocast,
        last_loss: state.last_loss,
        best_score: state.best_score,
    }
}

func resume_training_pipeline(training_pipeline_state state) training_pipeline_state {
    training_pipeline_state {
        loop: resume_training_loop(state.loop),
        loader: state.loader,
        logger: state.logger,
        scaler: state.scaler,
        checkpoint: state.checkpoint,
        autocast: state.autocast,
        last_loss: state.last_loss,
        best_score: state.best_score,
    }
}
