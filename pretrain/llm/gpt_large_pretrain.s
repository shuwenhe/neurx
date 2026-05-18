package neurx.pretrain.llm.gpt_large_pretrain

use neurx.model.llm.gpt_large_train.{gpt_large_training_config, gpt_large_training_state, new_gpt_large_training_config, new_gpt_large_training_state, gpt_large_training_step}
use neurx.pretrain.checkpoint.{pretrain_checkpoint_state, new_pretrain_checkpoint_state, mark_saved, mark_best, pretrain_checkpoint_state_dict, pretrain_checkpoint_load_state_dict}
use neurx.pretrain.config.{pretrain_config, new_pretrain_config, with_max_steps, with_lr, pretrain_config_state_dict, pretrain_config_load_state_dict}
use neurx.pretrain.data.{pretrain_data_state, new_pretrain_data_state, advance_tokens, next_epoch, pretrain_data_state_dict, pretrain_data_load_state_dict}
use neurx.pretrain.eval.{pretrain_eval_state, new_pretrain_eval_state, update_pretrain_eval, pretrain_eval_state_dict, pretrain_eval_load_state_dict}
use neurx.pretrain.loop.{pretrain_loop_state, new_pretrain_loop_state, pretrain_step, pretrain_reset_micro_step, pretrain_loop_state_dict, pretrain_loop_load_state_dict}

struct gpt_large_pretrain_state {
    pretrain_config cfg
    pretrain_data_state data
    pretrain_loop_state loop
    pretrain_checkpoint_state checkpoint
    pretrain_eval_state eval
    gpt_large_training_state training
}

func copy_strings([]string values) []string {
    []string out = []string{cap: len(values)}
    int i = 0
    while i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func gpt_large_pretrain_documents() []string {
    []string docs = []string{cap: 3}
    docs[0] = "neurx is a transformer first deep learning framework."
    docs[1] = "pretraining trains decoder only language models on token streams."
    docs[2] = "the pretrain layer coordinates loop, checkpoint, and evaluation states."
    docs
}

func new_gpt_large_pretrain_config() pretrain_config {
    pretrain_config cfg = new_pretrain_config()
    cfg = with_max_steps(cfg, 64)
    cfg = with_lr(cfg, 0.00015)
    pretrain_config {
        global_batch_size: cfg.global_batch_size,
        micro_batch_size: 8,
        seq_len: 16,
        max_steps: cfg.max_steps,
        warmup_steps: cfg.warmup_steps,
        lr: cfg.lr,
        min_lr: cfg.min_lr,
        weight_decay: cfg.weight_decay,
        log_interval: 8,
        eval_interval: 16,
        save_interval: 32,
        bf16: cfg.bf16,
        grad_checkpoint: cfg.grad_checkpoint,
        optimizer: "adamw",
        scheduler: "cosine",
        backend: cfg.backend,
    }
}

func new_gpt_large_pretrain_state() gpt_large_pretrain_state {
    pretrain_config cfg = new_gpt_large_pretrain_config()
    gpt_large_training_config training_cfg = new_gpt_large_training_config(cfg.micro_batch_size, cfg.seq_len, cfg.max_steps, cfg.lr)
    gpt_large_training_state training = new_gpt_large_training_state(gpt_large_pretrain_documents(), training_cfg)
    pretrain_data_state data = new_pretrain_data_state(training.model.dataset, 0, 1)
    pretrain_loop_state loop = new_pretrain_loop_state(cfg, data)
    gpt_large_pretrain_state {
        cfg: cfg,
        data: data,
        loop: loop,
        checkpoint: new_pretrain_checkpoint_state("gpt_large_pretrain", "artifacts/checkpoints/gpt_large_pretrain"),
        eval: new_pretrain_eval_state(),
        training: training,
    }
}

func new_gpt_large_pretrain_state_with_params(int micro_batch_size, int seq_len, int max_steps, float lr, int log_interval, int eval_interval, int save_interval) gpt_large_pretrain_state {
    pretrain_config base_cfg = new_gpt_large_pretrain_config()
    pretrain_config cfg = pretrain_config {
        global_batch_size: base_cfg.global_batch_size,
        micro_batch_size: micro_batch_size,
        seq_len: seq_len,
        max_steps: max_steps,
        warmup_steps: base_cfg.warmup_steps,
        lr: lr,
        min_lr: base_cfg.min_lr,
        weight_decay: base_cfg.weight_decay,
        log_interval: log_interval,
        eval_interval: eval_interval,
        save_interval: save_interval,
        bf16: base_cfg.bf16,
        grad_checkpoint: base_cfg.grad_checkpoint,
        optimizer: base_cfg.optimizer,
        scheduler: base_cfg.scheduler,
        backend: base_cfg.backend,
    }

    gpt_large_training_config training_cfg = new_gpt_large_training_config(cfg.micro_batch_size, cfg.seq_len, cfg.max_steps, cfg.lr)
    gpt_large_training_state training = new_gpt_large_training_state(gpt_large_pretrain_documents(), training_cfg)
    pretrain_data_state data = new_pretrain_data_state(training.model.dataset, 0, 1)
    pretrain_loop_state loop = new_pretrain_loop_state(cfg, data)
    gpt_large_pretrain_state {
        cfg: cfg,
        data: data,
        loop: loop,
        checkpoint: new_pretrain_checkpoint_state("gpt_large_pretrain", "artifacts/checkpoints/gpt_large_pretrain"),
        eval: new_pretrain_eval_state(),
        training: training,
    }
}

func gpt_large_pretrain_state_dict(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    gpt_large_pretrain_state {
        cfg: pretrain_config_state_dict(state.cfg),
        data: pretrain_data_state_dict(state.data),
        loop: pretrain_loop_state_dict(state.loop),
        checkpoint: pretrain_checkpoint_state_dict(state.checkpoint),
        eval: pretrain_eval_state_dict(state.eval),
        training: state.training,
    }
}

func gpt_large_pretrain_load_state_dict(gpt_large_pretrain_state state, gpt_large_pretrain_state other) gpt_large_pretrain_state {
    gpt_large_pretrain_state {
        cfg: pretrain_config_load_state_dict(state.cfg, other.cfg),
        data: pretrain_data_load_state_dict(state.data, other.data),
        loop: pretrain_loop_load_state_dict(state.loop, other.loop),
        checkpoint: pretrain_checkpoint_load_state_dict(state.checkpoint, other.checkpoint),
        eval: pretrain_eval_load_state_dict(state.eval, other.eval),
        training: other.training,
    }
}

func gpt_large_pretrain_step(gpt_large_pretrain_state state) gpt_large_pretrain_state {
    if state.loop.finished {
        return state
    }

    gpt_large_training_state next_training = gpt_large_training_step(state.training)
    int new_tokens = next_training.config.batch_size * next_training.config.seq_len
    if new_tokens <= 0 {
        new_tokens = state.cfg.micro_batch_size * state.cfg.seq_len
    }

    pretrain_loop_state next_loop = pretrain_step(state.loop, next_training.last_loss, 0.0, new_tokens)
    pretrain_data_state next_data = advance_tokens(state.data, new_tokens)
    if next_training.epoch > state.training.epoch {
        next_data = next_epoch(next_data)
    }

    pretrain_checkpoint_state next_checkpoint = state.checkpoint
    if next_loop.should_save {
        next_checkpoint = mark_saved(next_checkpoint, next_loop.global_step)
    }
    next_checkpoint = mark_best(next_checkpoint, next_loop.global_step, next_training.last_loss)

    pretrain_eval_state next_eval = state.eval
    if next_loop.should_eval {
        next_eval = update_pretrain_eval(next_eval, next_loop.global_step, next_training.model.validation_loss, next_training.model.validation_perplexity)
    }

    gpt_large_pretrain_state {
        cfg: state.cfg,
        data: next_data,
        loop: next_loop,
        checkpoint: next_checkpoint,
        eval: next_eval,
        training: next_training,
    }
}

func gpt_large_pretrain_run(gpt_large_pretrain_state state, int steps) gpt_large_pretrain_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    gpt_large_pretrain_state current = state
    int i = 0
    while i < loops {
        current = gpt_large_pretrain_step(current)
        i = i + 1
        if current.loop.finished {
            return current
        }
    }
    current
}

func gpt_large_pretrain_complete(gpt_large_pretrain_state state) bool {
    state.loop.finished
}
