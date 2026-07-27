package neurx.posttrain.loop
use neurx.posttrain.config
use neurx.posttrain.data
use neurx.posttrain.reward
use neurx.posttrain.checkpoint
use neurx.posttrain.eval
use neurx.optimizer.optimizer
use neurx.scheduler.training_scheduler
struct posttrain_loop_state {
    posttrain_config cfg
    posttrain_data_state data
    reward_state reward
    int global_step
    float objective
    float policy_loss
    float value_loss
    bool should_log
    bool should_eval
    bool should_save
    bool finished
}

struct posttrain_metrics_state {
    int step
    float objective
    float reward
    float policy_loss
    float value_loss
}

struct posttrain_pipeline_state {
    posttrain_loop_state loop
    posttrain_checkpoint_state checkpoint
    posttrain_eval_state eval
    optimizer opt
    lr_scheduler sched
    posttrain_metrics_state metrics
}

func new_posttrain_loop_state(posttrain_config cfg, posttrain_data_state data, reward_state reward) posttrain_loop_state {
    posttrain_loop_state {
        cfg: cfg,
        data: data,
        reward: reward,
        global_step: 0,
        objective: 0.0,
        policy_loss: 0.0,
        value_loss: 0.0,
        should_log: false,
        should_eval: false,
        should_save: false,
        finished: false,
    }
}

func new_posttrain_metrics_state() posttrain_metrics_state {
    posttrain_metrics_state {
        step: 0,
        objective: 0.0,
        reward: 0.0,
        policy_loss: 0.0,
        value_loss: 0.0,
    }
}

func new_posttrain_pipeline_state(posttrain_config cfg, posttrain_data_state data, reward_state reward, string run_name, string root) posttrain_pipeline_state {
    posttrain_pipeline_state {
        loop: new_posttrain_loop_state(cfg, data, reward),
        checkpoint: new_posttrain_checkpoint_state(run_name, root),
        eval: new_posttrain_eval_state(),
        opt:        new_optimizer(),
        sched:      new_named_lr_scheduler(cfg.lr, cfg.lr * 0.1, 0, cfg.max_steps, cfg.scheduler),
        metrics: new_posttrain_metrics_state(),
    }
}

func posttrain_step(posttrain_loop_state state, float objective, float policy_loss, float value_loss, int samples) posttrain_loop_state {
    int next_step = state.global_step + 1
    bool should_log = (next_step / state.cfg.log_interval) * state.cfg.log_interval == next_step
    bool should_eval = (next_step / state.cfg.eval_interval) * state.cfg.eval_interval == next_step
    bool should_save = (next_step / state.cfg.save_interval) * state.cfg.save_interval == next_step
    bool finished = next_step >= state.cfg.max_steps
    posttrain_data_state next_data = state.data
    if state.data.sample_mode == "preference" {
        next_data = advance_pairs(state.data, samples)
    } else {
        next_data = advance_samples(state.data, samples)
    }
    posttrain_loop_state {
        cfg: state.cfg,
        data: next_data,
        reward: state.reward,
        global_step: next_step,
        objective: objective,
        policy_loss: policy_loss,
        value_loss: value_loss,
        should_log: should_log,
        should_eval: should_eval,
        should_save: should_save,
        finished: finished,
    }
}

func posttrain_make_metrics(int step, float objective, float reward, float policy_loss, float value_loss) posttrain_metrics_state {
    posttrain_metrics_state {
        step: step,
        objective: objective,
        reward: reward,
        policy_loss: policy_loss,
        value_loss: value_loss,
    }
}

func posttrain_pipeline_step(posttrain_pipeline_state state, float reward_value, float kl_value, float margin, float policy_loss, float value_loss, int samples) posttrain_pipeline_state {
    reward_state next_reward = update_reward_state(state.loop.reward, reward_value, kl_value, margin)
    float objective = policy_loss + value_loss - reward_value
    posttrain_loop_state next_loop = posttrain_step(
        posttrain_loop_state {
            cfg: state.loop.cfg,
            data: state.loop.data,
            reward: next_reward,
            global_step: state.loop.global_step,
            objective: state.loop.objective,
            policy_loss: state.loop.policy_loss,
            value_loss: state.loop.value_loss,
            should_log: state.loop.should_log,
            should_eval: state.loop.should_eval,
            should_save: state.loop.should_save,
            finished: state.loop.finished,
        },
        objective,
        policy_loss,
        value_loss,
        samples,
    )
    optimizer next_opt = optimizer_set_scheduler(state.opt, state.sched)
    next_opt = optimizer_step_all_groups_with_scheduler(next_opt, next_loop.global_step)
    next_opt = optimizer_zero_grad(next_opt)
    lr_scheduler next_sched = next_opt.scheduler
    posttrain_checkpoint_state next_checkpoint = state.checkpoint
    if next_loop.should_save {
        next_checkpoint = mark_posttrain_saved(next_checkpoint, next_loop.global_step)
    }
    next_checkpoint = mark_posttrain_best(next_checkpoint, next_loop.global_step, reward_value)
    posttrain_eval_state next_eval = state.eval
    if next_loop.should_eval {
        float alignment = reward_value - (next_loop.cfg.kl_coef * kl_value)
        float safety = 1.0 - margin
        next_eval = update_posttrain_eval(next_eval, next_loop.global_step, reward_value, alignment, safety)
    }
    posttrain_pipeline_state {
        loop: next_loop,
        checkpoint: next_checkpoint,
        eval: next_eval,
        opt: next_opt,
        sched: next_sched,
        metrics: posttrain_make_metrics(next_loop.global_step, objective, reward_value, policy_loss, value_loss),
    }
}

func posttrain_pipeline_state_dict(posttrain_pipeline_state state) posttrain_pipeline_state {
    state
}

func posttrain_pipeline_load_state_dict(posttrain_pipeline_state state, posttrain_pipeline_state other) posttrain_pipeline_state {
    other
}

func posttrain_metrics_state_dict(posttrain_metrics_state state) posttrain_metrics_state {
    state
}

func posttrain_metrics_load_state_dict(posttrain_metrics_state state, posttrain_metrics_state other) posttrain_metrics_state {
    other
}

func posttrain_loop_state_dict(posttrain_loop_state state) posttrain_loop_state {
    state
}

func posttrain_loop_load_state_dict(posttrain_loop_state state, posttrain_loop_state other) posttrain_loop_state {
    other
}
