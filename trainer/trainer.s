package neurx.trainer
struct trainer_config {
    string name
    string mode
    int max_steps
    int log_interval
    int eval_interval
    int save_interval
}
struct trainer_state {
    trainer_config config
    int step
    float loss
    bool finished
}
func new_trainer_config(string name, string mode, int max_steps) trainer_config {
    trainer_config {
        name: name,
        mode: mode,
        max_steps: max_steps,
        log_interval: 10,
        eval_interval: 1000,
        save_interval: 1000,
    }
}
func new_trainer_state(trainer_config config) trainer_state {
    trainer_state {
        config: config,
        step: 0,
        loss: 0.0,
        finished: false,
    }
}
func trainer_step(trainer_state state, float loss) trainer_state {
    int next_step = state.step + 1
    trainer_state {
        config: state.config,
        step: next_step,
        loss: loss,
        finished: next_step >= state.config.max_steps,
    }
}
func trainer_should_log(trainer_state state) bool {
    state.step > 0 && (state.step / state.config.log_interval) * state.config.log_interval == state.step
}
func trainer_should_eval(trainer_state state) bool {
    state.step > 0 && (state.step / state.config.eval_interval) * state.config.eval_interval == state.step
}
func trainer_should_save(trainer_state state) bool {
    state.step > 0 && (state.step / state.config.save_interval) * state.config.save_interval == state.step
}
func trainer_state_dict(trainer_state state) trainer_state {
    state
}
func trainer_load_state_dict(trainer_state state, trainer_state other) trainer_state {
    other
}
