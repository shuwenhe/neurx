package neurx.diffusion.train
use neurx.diffusion.config
struct diffusion_train_state {
    diffusion_config cfg
    int step
    float loss
    bool finished
}

func new_diffusion_train_state(diffusion_config cfg) diffusion_train_state {
    diffusion_train_state {
        cfg: cfg,
        step: 0,
        loss: 0.0,
        finished: false,
    }
}

func diffusion_train_step(diffusion_train_state state, float loss) diffusion_train_state {
    int next_step = state.step + 1
    bool finished = next_step >= state.cfg.timesteps
    diffusion_train_state {
        cfg: state.cfg,
        step: next_step,
        loss: loss,
        finished: finished,
    }
}

func diffusion_train_state_dict(diffusion_train_state state) diffusion_train_state {
    state
}

func diffusion_train_load_state_dict(diffusion_train_state state, diffusion_train_state other) diffusion_train_state {
    other
}
