package neurx.pretrain.loop
use neurx.pretrain.config
use neurx.pretrain.data
struct pretrain_loop_state {
    pretrain_config cfg
    pretrain_data_state data
    int global_step
    int micro_step
    int tokens_seen
    float loss
    float grad_norm
    bool should_log
    bool should_eval
    bool should_save
    bool finished
}

func new_pretrain_loop_state(pretrain_config cfg, pretrain_data_state data) pretrain_loop_state {
    pretrain_loop_state {
        cfg: cfg,
        data: data,
        global_step: 0,
        micro_step: 0,
        tokens_seen: 0,
        loss: 0.0,
        grad_norm: 0.0,
        should_log: false,
        should_eval: false,
        should_save: false,
        finished: false,
    }
}

func pretrain_step(pretrain_loop_state state, float loss, float grad_norm, int new_tokens) pretrain_loop_state {
    int next_global_step = state.global_step + 1
    bool should_log = (next_global_step / state.cfg.log_interval) * state.cfg.log_interval == next_global_step
    bool should_eval = (next_global_step / state.cfg.eval_interval) * state.cfg.eval_interval == next_global_step
    bool should_save = (next_global_step / state.cfg.save_interval) * state.cfg.save_interval == next_global_step
    bool finished = next_global_step >= state.cfg.max_steps
    pretrain_loop_state {
        cfg: state.cfg,
        data: advance_tokens(state.data, new_tokens),
        global_step: next_global_step,
        micro_step: state.micro_step + 1,
        tokens_seen: state.tokens_seen + new_tokens,
        loss: loss,
        grad_norm: grad_norm,
        should_log: should_log,
        should_eval: should_eval,
        should_save: should_save,
        finished: finished,
    }
}

func pretrain_reset_micro_step(pretrain_loop_state state) pretrain_loop_state {
    pretrain_loop_state {
        cfg: state.cfg,
        data: state.data,
        global_step: state.global_step,
        micro_step: 0,
        tokens_seen: state.tokens_seen,
        loss: state.loss,
        grad_norm: state.grad_norm,
        should_log: state.should_log,
        should_eval: state.should_eval,
        should_save: state.should_save,
        finished: state.finished,
    }
}

func pretrain_loop_state_dict(pretrain_loop_state state) pretrain_loop_state {
    state
}

func pretrain_loop_load_state_dict(pretrain_loop_state state, pretrain_loop_state other) pretrain_loop_state {
    other
}
