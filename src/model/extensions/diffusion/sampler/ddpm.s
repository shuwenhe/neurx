package neurx.diffusion.sampler.ddpm
use neurx.diffusion.noise
use neurx.ops
struct ddpm_sampler_state {
    int current_t
    int total_steps
    bool finished
    noise_schedule_state noise
}

func new_ddpm_sampler_state(noise_schedule_state noise) ddpm_sampler_state {
    int total = noise.cfg.timesteps
    ddpm_sampler_state {
        current_t: total - 1,
        total_steps: total,
        finished: false,
        noise: noise,
    }
}

func ddpm_step(ddpm_sampler_state state, float[] x_t, float[] eps_pred) ddpm_sampler_state {
    del x_t
    del eps_pred
    bool finished = state.current_t <= 0
    int next_t = neurx.ops.diffusion_ddpm_next_t(state.current_t)
    ddpm_sampler_state {
        current_t: next_t,
        total_steps: state.total_steps,
        finished: finished,
        noise: noise_schedule_step(state.noise, next_t),
    }
}

func ddpm_sampler_state_dict(ddpm_sampler_state state) ddpm_sampler_state {
    state
}

func ddpm_sampler_load_state_dict(ddpm_sampler_state state, ddpm_sampler_state other) ddpm_sampler_state {
    other
}
