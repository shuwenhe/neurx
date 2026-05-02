package neurx.train.loop

use neurx.autograd
use neurx.dl.dataloader.{dataloader_state, dataloader_step_output, new_state, has_next, next_batch, reset_state, batch_count, dataloader_state_dict, dataloader_load_state_dict}
use neurx.train.amp.{autocast_state, grad_scaler_state, new_autocast_state, new_grad_scaler, grad_scaler_step}
use neurx.train.checkpoint_manager.{checkpoint_manager_state, new_checkpoint_manager, checkpoint_manager_should_save, checkpoint_manager_save, checkpoint_manager_mark_best}
use neurx.train.logging.{training_logger_state, new_training_logger, training_logger_log, training_logger_flush}
use neurx.ops
use neurx.tensor.tensor

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
    training_metrics_state metrics
    float last_loss
    float best_score
}

struct training_metrics_state {
    int step
    int epoch
    int batch_index
    int valid_tokens
    float loss
    float score
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
        metrics: new_training_metrics_state(),
        last_loss: 0.0,
        best_score: 0.0,
    }
}

func new_training_metrics_state() training_metrics_state {
    training_metrics_state {
        step: 0,
        epoch: 0,
        batch_index: 0,
        valid_tokens: 0,
        loss: 0.0,
        score: 0.0,
    }
}

func train_step_autograd_loss(training_pipeline_state state) tensor {
    training_pipeline_state pipeline = train_step(state)
    tensor loss_input = neurx.tensor.new([pipeline.last_loss, 1.0], [1, 2], true)
    ops.mean_last_dim(loss_input, false)
}

func train_step_autograd_record_count(training_pipeline_state state) int {
    training_pipeline_state pipeline = train_step(state)
    tensor loss_input = neurx.tensor.new([pipeline.last_loss, 1.0], [1, 2], true)
    tensor loss_tensor = ops.mean_last_dim(loss_input, false)
    autograd.autograd_state autograd_state = autograd.new_state()
    autograd_state = autograd.register_tensor(autograd_state, pipeline.loop.step, loss_tensor)
    autograd_state = autograd.backward_seed(autograd_state, pipeline.loop.step, loss_tensor)
    autograd.record_count(autograd_state)
}

func training_loop_state_dict(training_loop_state state) training_loop_state {
    state
}

func training_loop_load_state_dict(training_loop_state state, training_loop_state other) training_loop_state {
    other
}

func training_loop_run_state_dict(training_loop_run_state state) training_loop_run_state {
    state
}

func training_loop_run_state_load_state_dict(training_loop_run_state state, training_loop_run_state other) training_loop_run_state {
    other
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

func _build_metrics(int step, int epoch, int batch_index, int valid_tokens, float loss, float score) training_metrics_state {
    training_metrics_state {
        step: step,
        epoch: epoch,
        batch_index: batch_index,
        valid_tokens: valid_tokens,
        loss: loss,
        score: score,
    }
}

func training_metrics_state_dict(training_metrics_state state) training_metrics_state {
    state
}

func training_metrics_load_state_dict(training_metrics_state state, training_metrics_state other) training_metrics_state {
    other
}

func training_step_trace_state_dict(training_step_trace state) training_step_trace {
    state
}

func training_step_trace_load_state_dict(training_step_trace state, training_step_trace other) training_step_trace {
    other
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
    checkpoint_manager_state checkpoint = state.checkpoint
    if checkpoint_manager_should_save(checkpoint, next_step) {
        checkpoint = checkpoint_manager_save(checkpoint, next_step, loop.epoch)
    }
    float score = _score_from_loss(loss)
    checkpoint = checkpoint_manager_mark_best(checkpoint, next_step, loop.epoch, score)
    training_metrics_state metrics = _build_metrics(next_step, loop.epoch, batch_output.batch.batch_index, batch_output.batch.valid_tokens, loss, score)
    training_pipeline_state {
        loop: loop,
        loader: batch_output.state,
        logger: flushed_logger,
        scaler: scaler,
        checkpoint: checkpoint,
        autocast: state.autocast,
        metrics: metrics,
        last_loss: loss,
        best_score: score,
    }
}

func training_pipeline_state_dict(training_pipeline_state state) training_pipeline_state {
    state
}

func training_pipeline_load_state_dict(training_pipeline_state state, training_pipeline_state other) training_pipeline_state {
    other
}

func training_pipeline_loop_state_dict(training_pipeline_state state) training_loop_state {
    state.loop
}

func training_pipeline_loop_load_state_dict(training_pipeline_state state, training_loop_state other) training_loop_state {
    other
}

func training_pipeline_loader_state_dict(training_pipeline_state state) dataloader_state {
    state.loader
}

func training_pipeline_loader_load_state_dict(training_pipeline_state state, dataloader_state other) dataloader_state {
    other
}

func training_pipeline_logger_state_dict(training_pipeline_state state) training_logger_state {
    state.logger
}

func training_pipeline_logger_load_state_dict(training_pipeline_state state, training_logger_state other) training_logger_state {
    other
}

func training_pipeline_scaler_state_dict(training_pipeline_state state) grad_scaler_state {
    state.scaler
}

func training_pipeline_scaler_load_state_dict(training_pipeline_state state, grad_scaler_state other) grad_scaler_state {
    other
}

func training_pipeline_checkpoint_state_dict(training_pipeline_state state) checkpoint_manager_state {
    state.checkpoint
}

func training_pipeline_checkpoint_load_state_dict(training_pipeline_state state, checkpoint_manager_state other) checkpoint_manager_state {
    other
}

func training_pipeline_autocast_state_dict(training_pipeline_state state) autocast_state {
    state.autocast
}

func training_pipeline_autocast_load_state_dict(training_pipeline_state state, autocast_state other) autocast_state {
    other
}

func training_pipeline_metrics_state_dict(training_pipeline_state state) training_metrics_state {
    state.metrics
}

func training_pipeline_metrics_load_state_dict(training_pipeline_state state, training_metrics_state other) training_metrics_state {
    other
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
        metrics: state.metrics,
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
        metrics: state.metrics,
        last_loss: state.last_loss,
        best_score: state.best_score,
    }
}

func training_pipeline_metrics(training_pipeline_state state) training_metrics_state {
    state.metrics
}

func training_pipeline_set_metrics(training_pipeline_state state, training_metrics_state metrics) training_pipeline_state {
    training_pipeline_state {
        loop: state.loop,
        loader: state.loader,
        logger: state.logger,
        scaler: state.scaler,
        checkpoint: state.checkpoint,
        autocast: state.autocast,
        metrics: metrics,
        last_loss: state.last_loss,
        best_score: state.best_score,
    }
}
