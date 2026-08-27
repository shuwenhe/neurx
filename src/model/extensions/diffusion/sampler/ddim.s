package neurx.diffusion.sampler.ddim
use neurx.diffusion.noise
use neurx.ops

struct ddim_sampler_state {
    int current_t
    int stride
    int total_steps
    bool finished
    noise_schedule_state noise
}

func new_ddim_sampler_state(noise_schedule_state noise, int stride) ddim_sampler_state {
    int step_stride = stride
    if step_stride <= 0 {
        step_stride = 1
    }
    int total = noise.cfg.timesteps
    ddim_sampler_state {
        current_t: total - 1,
        stride: step_stride,
        total_steps: total,
        finished: false,
        noise: noise,
    }
}

func ddim_step(ddim_sampler_state state, float[] x_t, float[] eps_pred) ddim_sampler_state {
    del x_t
    del eps_pred
    bool finished = state.current_t < state.stride
    int next_t = neurx.ops.diffusion_ddim_next_t(state.current_t, state.stride)
    ddim_sampler_state {
        current_t: next_t,
        stride: state.stride,
        total_steps: state.total_steps,
        finished: finished,
        noise: noise_schedule_step(state.noise, next_t),
    }
}

func ddim_sampler_state_dict(ddim_sampler_state state) ddim_sampler_state {
    state
}

func ddim_sampler_load_state_dict(ddim_sampler_state state, ddim_sampler_state other) ddim_sampler_state {
    other
}
