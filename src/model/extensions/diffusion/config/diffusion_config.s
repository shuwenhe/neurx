package neurx.diffusion.config
struct diffusion_config {
    int timesteps
    float beta_start
    float beta_end
    string schedule
    string prediction_type
    bool v_prediction
}

func new_diffusion_config() diffusion_config {
    diffusion_config {
        timesteps: 1000,
        beta_start: 0.0001,
        beta_end: 0.02,
        schedule: "linear",
        prediction_type: "epsilon",
        v_prediction: false,
    }
}

func with_timesteps(diffusion_config cfg, int timesteps) diffusion_config {
    diffusion_config {
        timesteps: timesteps,
        beta_start: cfg.beta_start,
        beta_end: cfg.beta_end,
        schedule: cfg.schedule,
        prediction_type: cfg.prediction_type,
        v_prediction: cfg.v_prediction,
    }
}

func with_schedule(diffusion_config cfg, string schedule) diffusion_config {
    diffusion_config {
        timesteps: cfg.timesteps,
        beta_start: cfg.beta_start,
        beta_end: cfg.beta_end,
        schedule: schedule,
        prediction_type: cfg.prediction_type,
        v_prediction: cfg.v_prediction,
    }
}

func diffusion_config_state_dict(diffusion_config cfg) diffusion_config {
    cfg
}

func diffusion_config_load_state_dict(diffusion_config cfg, diffusion_config other) diffusion_config {
    other
}
