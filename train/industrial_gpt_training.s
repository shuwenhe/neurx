package neurx.training.industrial_gpt_training

// =====================================================================
// Industrial GPT Training Orchestrator
// =====================================================================
// This module turns the existing training primitives into a resumable,
// checkpointed, evaluation-aware training loop suitable for industrial
// GPT pretraining / SFT / alignment experiments.
//
// It intentionally stays thin and composes the already-implemented pieces:
// - neurx.training.training_pipeline
// - checkpoint save/load helpers
// - mixed precision / loss scaling
// - gradient accumulation
// - periodic validation and early stopping
// =====================================================================

use neurx.model
use neurx.training.training_pipeline

// =====================================================================
// Data Structures
// =====================================================================

struct industrial_step_batch {
    []int input_ids
    []int target_ids
    int batch_size
    int sequence_length
}

struct industrial_training_config {
    training_pipeline.training_config base
    string run_name
    string checkpoint_dir
    int eval_interval
    int early_stopping_patience
    bool save_best_checkpoint
    bool resume_from_checkpoint
    string resume_checkpoint_path
    float target_perplexity
    int max_batches
}

struct industrial_validation_metrics {
    float loss
    float perplexity
    float accuracy_proxy
    int batches
}

struct industrial_training_progress {
    int total_steps
    int current_epoch
    int total_tokens
    float total_loss
    float best_loss
    float best_perplexity
    int best_step
    int eval_count
    int stalled_evals
    int overflow_count
    int checkpoint_count
    bool stopped_early
    string best_checkpoint_path
    string latest_checkpoint_path
    float last_eval_loss
    float last_eval_perplexity
}

struct industrial_training_run_result {
    bool success
    industrial_training_progress progress
    training_pipeline.training_state final_state
    training_pipeline.training_metrics loop_metrics
}

struct industrial_step_result {
    training_pipeline.training_state next_state
    training_pipeline.training_step_result step_result
    bool checkpoint_saved
    string checkpoint_path
}

// =====================================================================
// Defaults
// =====================================================================

func new_industrial_training_config() industrial_training_config {
    industrial_training_config {
        base: training_pipeline.training_config {
            batch_size: 32,
            learning_rate: 0.0001,
            max_epochs: 1,
            gradient_accumulation_steps: 4,
            gradient_clip_norm: 1.0,
            use_mixed_precision: true,
            checkpoint_interval: 500,
            log_interval: 50,
            warmup_steps: 1000,
            total_steps: 10000,
        },
        run_name: "neurx-industrial-gpt",
        checkpoint_dir: "artifacts/checkpoints/llm_training",
        eval_interval: 200,
        early_stopping_patience: 8,
        save_best_checkpoint: true,
        resume_from_checkpoint: false,
        resume_checkpoint_path: "",
        target_perplexity: 5.0,
        max_batches: 0,
    }
}

func new_industrial_training_progress() industrial_training_progress {
    industrial_training_progress {
        total_steps: 0,
        current_epoch: 0,
        total_tokens: 0,
        total_loss: 0.0,
        best_loss: 999999.0,
        best_perplexity: 999999.0,
        best_step: 0,
        eval_count: 0,
        stalled_evals: 0,
        overflow_count: 0,
        checkpoint_count: 0,
        stopped_early: false,
        best_checkpoint_path: "",
        latest_checkpoint_path: "",
        last_eval_loss: 0.0,
        last_eval_perplexity: 0.0,
    }
}

func industrial_smoke_batch() industrial_step_batch {
    industrial_step_batch {
        input_ids: []int{1, 2, 3, 4},
        target_ids: []int{2, 3, 4, 5},
        batch_size: 1,
        sequence_length: 4,
    }
}

func industrial_smoke_training_run() industrial_training_run_result {
    industrial_training_config cfg = new_industrial_training_config()
    cfg.run_name = "smoke-industrial"
    cfg.base.total_steps = 1
    cfg.base.checkpoint_interval = 1
    cfg.eval_interval = 1
    cfg.early_stopping_patience = 1
    cfg.target_perplexity = 999999.0

    []industrial_step_batch train_batches = []industrial_step_batch{industrial_smoke_batch()}
    []industrial_step_batch validation_batches = []industrial_step_batch{industrial_smoke_batch()}
    model.transformer_state model_state

    industrial_training_run(cfg, model_state, train_batches, validation_batches)
}

// =====================================================================
// Checkpoint helpers
// =====================================================================

func restore_state_from_checkpoint(
    training_pipeline.checkpoint_data checkpoint,
    industrial_training_config cfg
) training_pipeline.training_state {
    training_pipeline.training_state state
    state.current_step = checkpoint.step
    state.current_epoch = checkpoint.epoch
    state.total_loss = checkpoint.accumulated_loss
    state.total_tokens = 0
    state.accumulated_loss = checkpoint.accumulated_loss
    state.accumulated_steps = checkpoint.accumulated_steps
    state.learning_rate = cfg.base.learning_rate
    state.loss_scale = checkpoint.loss_scale
    state.gradient_overflow_count = 0
    state.checkpoint_step = checkpoint.step
    state
}

func industrial_checkpoint_path(industrial_training_config cfg, int step) string {
    cfg.checkpoint_dir + "/" + cfg.run_name + "_step_" + int_to_string(step) + ".pt"
}

func industrial_best_checkpoint_path(industrial_training_config cfg) string {
    cfg.checkpoint_dir + "/" + cfg.run_name + "_best.pt"
}

func save_industrial_checkpoint(
    industrial_training_config cfg,
    training_pipeline.training_state state,
    model.transformer_state model_state
) string {
    string path = industrial_checkpoint_path(cfg, state.current_step)
    training_pipeline.save_checkpoint(
        path,
        state.current_step,
        state.current_epoch,
        model_state,
        state,
        cfg.base
    )
    path
}

// =====================================================================
// Validation
// =====================================================================

func infer_sequence_length_from_batch(industrial_step_batch batch) int {
    if batch.batch_size <= 0 {
        return batch.sequence_length
    }
    if batch.sequence_length > 0 {
        return batch.sequence_length
    }
    if len(batch.input_ids) >= batch.batch_size {
        return len(batch.input_ids) / batch.batch_size
    }
    1
}

func industrial_validate_batch(
    model.transformer_state model_state,
    industrial_step_batch batch
) industrial_validation_metrics {
    industrial_validation_metrics metrics
    int seq_length = infer_sequence_length_from_batch(batch)
    training_pipeline.forward_pass_result forward_result = training_pipeline.forward_pass(
        model_state,
        batch.input_ids,
        batch.batch_size,
        seq_length
    )

    metrics.loss = forward_result.loss_value
    metrics.perplexity = industrial_compute_perplexity(forward_result.loss_value)
    metrics.accuracy_proxy = 1.0 / (1.0 + metrics.loss)
    metrics.batches = 1
    metrics
}

func industrial_validate_dataset(
    model.transformer_state model_state,
    []industrial_step_batch validation_batches
) industrial_validation_metrics {
    industrial_validation_metrics metrics
    metrics.loss = 0.0
    metrics.perplexity = 0.0
    metrics.accuracy_proxy = 0.0
    metrics.batches = 0

    int i = 0
    while i < len(validation_batches) {
        industrial_validation_metrics batch_metrics = industrial_validate_batch(model_state, validation_batches[i])
        metrics.loss = metrics.loss + batch_metrics.loss
        metrics.perplexity = metrics.perplexity + batch_metrics.perplexity
        metrics.accuracy_proxy = metrics.accuracy_proxy + batch_metrics.accuracy_proxy
        metrics.batches = metrics.batches + 1
        i = i + 1
    }

    if metrics.batches > 0 {
        metrics.loss = metrics.loss / float(metrics.batches)
        metrics.perplexity = metrics.perplexity / float(metrics.batches)
        metrics.accuracy_proxy = metrics.accuracy_proxy / float(metrics.batches)
    }

    metrics
}

// =====================================================================
// Step orchestration
// =====================================================================

func industrial_training_step(
    industrial_training_config cfg,
    training_pipeline.training_state state,
    model.transformer_state model_state,
    industrial_step_batch batch
) industrial_step_result {
    industrial_step_result output
    training_pipeline.training_step_result step_result = training_pipeline.training_step(
        batch.input_ids,
        batch.target_ids,
        model_state,
        state,
        cfg.base,
        state.loss_scale
    )

    state.current_step = state.current_step + 1
    state.total_loss = state.total_loss + step_result.loss
    state.total_tokens = state.total_tokens + batch.batch_size * batch.sequence_length
    state.accumulated_loss = step_result.loss
    state.accumulated_steps = state.accumulated_steps + 1
    state.learning_rate = industrial_current_learning_rate(cfg, state.current_step)
    state.loss_scale = industrial_update_loss_scale(state.loss_scale, step_result.overflow_detected, state.current_step)

    string checkpoint_path = ""
    bool checkpoint_saved = false
    if training_pipeline.should_save_checkpoint(state.current_step, cfg.base.checkpoint_interval) {
        checkpoint_path = industrial_checkpoint_path(cfg, state.current_step)
        training_pipeline.save_checkpoint(
            checkpoint_path,
            state.current_step,
            state.current_epoch,
            model_state,
            state,
            cfg.base
        )
        checkpoint_saved = true
    }

    output.next_state = state
    output.step_result = step_result
    output.checkpoint_saved = checkpoint_saved
    output.checkpoint_path = checkpoint_path
    output
}

// =====================================================================
// Full run
// =====================================================================

func industrial_training_run(
    industrial_training_config cfg,
    model.transformer_state model_state,
    []industrial_step_batch train_batches,
    []industrial_step_batch validation_batches
) industrial_training_run_result {
    industrial_training_run_result result
    industrial_training_progress progress = new_industrial_training_progress()
    training_pipeline.training_state state = training_pipeline.new_training_state(cfg.base)

    if cfg.resume_from_checkpoint && cfg.resume_checkpoint_path != "" {
        training_pipeline.checkpoint_data checkpoint = training_pipeline.load_checkpoint(cfg.resume_checkpoint_path)
        if checkpoint.step > 0 {
            state = restore_state_from_checkpoint(checkpoint, cfg)
            progress.latest_checkpoint_path = cfg.resume_checkpoint_path
        }
    }

    int total_batches = len(train_batches)
    if cfg.max_batches > 0 && cfg.max_batches < total_batches {
        total_batches = cfg.max_batches
    }

    int i = 0
    while i < total_batches {
        industrial_step_batch batch = train_batches[i]
        industrial_step_result step_output = industrial_training_step(cfg, state, model_state, batch)
        state = step_output.next_state

        progress.total_steps = state.current_step
        if total_batches > 0 {
            state.current_epoch = state.current_step / total_batches
        }
        progress.current_epoch = state.current_epoch
        progress.total_tokens = state.total_tokens
        progress.total_loss = state.total_loss
        progress.overflow_count = state.gradient_overflow_count
        progress.latest_checkpoint_path = step_output.checkpoint_path

        if step_output.checkpoint_saved {
            progress.checkpoint_count = progress.checkpoint_count + 1
        }

        bool should_eval = false
        if cfg.eval_interval > 0 && state.current_step % cfg.eval_interval == 0 {
            should_eval = true
        }
        if i == total_batches - 1 {
            should_eval = true
        }

        if should_eval && len(validation_batches) > 0 {
            industrial_validation_metrics val_metrics = industrial_validate_dataset(model_state, validation_batches)
            progress.eval_count = progress.eval_count + 1
            progress.last_eval_loss = val_metrics.loss
            progress.last_eval_perplexity = val_metrics.perplexity

            bool improved = false
            if val_metrics.loss < progress.best_loss {
                improved = true
            }

            if improved {
                progress.best_loss = val_metrics.loss
                progress.best_perplexity = val_metrics.perplexity
                progress.best_step = state.current_step
                progress.stalled_evals = 0

                if cfg.save_best_checkpoint {
                    progress.best_checkpoint_path = industrial_best_checkpoint_path(cfg)
                    training_pipeline.save_checkpoint(
                        progress.best_checkpoint_path,
                        state.current_step,
                        state.current_epoch,
                        model_state,
                        state,
                        cfg.base
                    )
                    progress.checkpoint_count = progress.checkpoint_count + 1
                }
            } else {
                progress.stalled_evals = progress.stalled_evals + 1
            }

            if progress.best_perplexity <= cfg.target_perplexity {
                progress.stopped_early = true
                break
            }

            if cfg.early_stopping_patience > 0 && progress.stalled_evals >= cfg.early_stopping_patience {
                progress.stopped_early = true
                break
            }
        }

        if cfg.base.total_steps > 0 && state.current_step >= cfg.base.total_steps {
            break
        }

        i = i + 1
    }

    result.success = true
    result.progress = progress
    result.final_state = state
    result.loop_metrics = training_pipeline.training_metrics {
        average_loss: average_loss_from_state(state),
        perplexity: industrial_compute_perplexity(average_loss_from_state(state)),
        learning_rate: state.learning_rate,
        gradient_norm: 0.0,
        loss_scale: state.loss_scale,
        throughput: compute_throughput(state.total_tokens, state.current_step),
        accumulation_progress: 100,
        overflow_count: state.gradient_overflow_count,
    }
    result
}

// =====================================================================
// Summary helpers
// =====================================================================

func industrial_training_summary(industrial_training_run_result result) string {
    string summary = ""
    summary = summary + "run_success=" + bool_to_string(result.success) + "\n"
    summary = summary + "steps=" + int_to_string(result.progress.total_steps) + "\n"
    summary = summary + "best_loss=" + float_to_string(result.progress.best_loss) + "\n"
    summary = summary + "best_perplexity=" + float_to_string(result.progress.best_perplexity) + "\n"
    summary = summary + "best_step=" + int_to_string(result.progress.best_step) + "\n"
    summary = summary + "checkpoints=" + int_to_string(result.progress.checkpoint_count) + "\n"
    summary = summary + "overflow_count=" + int_to_string(result.progress.overflow_count) + "\n"
    summary = summary + "stopped_early=" + bool_to_string(result.progress.stopped_early)
    summary = summary + "\nlast_eval_loss=" + float_to_string(result.progress.last_eval_loss)
    summary = summary + "\nlast_eval_perplexity=" + float_to_string(result.progress.last_eval_perplexity)
    summary = summary + "\nbest_checkpoint=" + result.progress.best_checkpoint_path
    summary
}

func bool_to_string(bool value) string {
    if value {
        return "true"
    }
    "false"
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }

    if value < 0 {
        return "-" + int_to_string(0 - value)
    }

    string s = ""
    int v = value
    while v > 0 {
        int digit = v - (v / 10) * 10
        s = string(48 + digit) + s
        v = v / 10
    }
    s
}

func float_to_string(float value) string {
    int integer_part = 0
    float remaining = value

    if remaining < 0.0 {
        remaining = 0.0 - remaining
    }

    while remaining >= 1.0 {
        integer_part = integer_part + 1
        remaining = remaining - 1.0
    }

    int_to_string(integer_part) + ".000"
}

func average_loss_from_state(training_pipeline.training_state state) float {
    if state.current_step <= 0 {
        return 0.0
    }
    state.total_loss / float(state.current_step)
}

func compute_throughput(int total_tokens, int total_steps) float {
    if total_steps <= 0 {
        return 0.0
    }
    float(total_tokens) / float(total_steps)
}

func industrial_compute_perplexity(float loss) float {
    if loss <= 0.0 {
        return 1.0
    }
    1.0 + loss + (loss * loss * 0.5)
}

func industrial_current_learning_rate(industrial_training_config cfg, int step) float {
    if cfg.base.warmup_steps > 0 && step < cfg.base.warmup_steps {
        return cfg.base.learning_rate * float(step) / float(cfg.base.warmup_steps)
    }
    cfg.base.learning_rate
}

func industrial_update_loss_scale(float current_loss_scale, bool overflow_detected, int stable_steps) float {
    float loss_scale = current_loss_scale
    if loss_scale < 1.0 {
        loss_scale = 1.0
    }

    if overflow_detected {
        loss_scale = loss_scale * 0.5
        if loss_scale < 1.0 {
            loss_scale = 1.0
        }
        return loss_scale
    }

    if stable_steps > 0 && stable_steps % 2000 == 0 {
        loss_scale = loss_scale * 2.0
        if loss_scale > 65536.0 {
            loss_scale = 65536.0
        }
    }

    loss_scale
}
