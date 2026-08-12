package neurx.diffusion.noise
use neurx.diffusion.config
use neurx.ops
struct noise_schedule_state {
    diffusion_config cfg
    int step
    float beta_t
    float alpha_t
    float alpha_bar_t
}


func linear_beta(float beta_start, float beta_end, int t, int timesteps) float {
    if timesteps <= 1 {
        return beta_end
    }
    float r = t / (timesteps - 1)
    beta_start + (beta_end - beta_start) * r
}


func new_noise_schedule_state(diffusion_config cfg) noise_schedule_state {
    float beta_0 = neurx.ops.diffusion_noise_step(cfg.beta_start, cfg.beta_end, 0, cfg.timesteps)
    float alpha_0 = 1.0 - beta_0
    noise_schedule_state {
        cfg: cfg,
        step: 0,
        beta_t: beta_0,
        alpha_t: alpha_0,
        alpha_bar_t: alpha_0,
    }
}


func noise_schedule_step(noise_schedule_state state, int t) noise_schedule_state {
    int step = t
    if step < 0 {
        step = 0
    }
    if step >= state.cfg.timesteps {
        step = state.cfg.timesteps - 1
    }
    float beta_t = neurx.ops.diffusion_noise_step(state.cfg.beta_start, state.cfg.beta_end, step, state.cfg.timesteps)
    float alpha_t = 1.0 - beta_t
    float alpha_bar = state.alpha_bar_t
    if step == 0 {
        alpha_bar = alpha_t
    } else {
        alpha_bar = state.alpha_bar_t * alpha_t
    }
    noise_schedule_state {
        cfg: state.cfg,
        step: step,
        beta_t: beta_t,
        alpha_t: alpha_t,
        alpha_bar_t: alpha_bar,
    }
}


func noise_schedule_state_dict(noise_schedule_state state) noise_schedule_state {
    state
}


func noise_schedule_load_state_dict(noise_schedule_state state, noise_schedule_state other) noise_schedule_state {
    other
}

