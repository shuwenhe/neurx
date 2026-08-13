package neurx.diffusion
use neurx.diffusion.config
use neurx.diffusion.noise
use neurx.diffusion.model
use neurx.diffusion.sampler.ddpm
use neurx.diffusion.sampler.ddim
use neurx.diffusion.train
use neurx.diffusion.eval

struct diffusion_pipeline_state {
    diffusion_config cfg
    noise_schedule_state noise
    denoiser_state model
    ddpm_sampler_state ddpm
    ddim_sampler_state ddim
    diffusion_train_state train
    diffusion_eval_state eval
}

func new_diffusion_pipeline_state() diffusion_pipeline_state {
    diffusion_config cfg = new_diffusion_config()
    noise_schedule_state noise = new_noise_schedule_state(cfg)
    denoiser_state model = new_denoiser_state("unet_stub", 4, 128, true)
    diffusion_pipeline_state {
        cfg: cfg,
        noise: noise,
        model: model,
        ddpm: new_ddpm_sampler_state(noise),
        ddim: new_ddim_sampler_state(noise, 20),
        train: new_diffusion_train_state(cfg),
        eval: new_diffusion_eval_state(),
    }
}

func diffusion_pipeline_train_step(diffusion_pipeline_state state, float loss) diffusion_pipeline_state {
    diffusion_pipeline_state {
        cfg: state.cfg,
        noise: state.noise,
        model: state.model,
        ddpm: state.ddpm,
        ddim: state.ddim,
        train: diffusion_train_step(state.train, loss),
        eval: state.eval,
    }
}

func diffusion_pipeline_ddpm_step(diffusion_pipeline_state state, []float x_t) diffusion_pipeline_state {
    []float eps = denoiser_forward_stub(state.model, x_t, state.ddpm.current_t)
    diffusion_pipeline_state {
        cfg: state.cfg,
        noise: state.noise,
        model: state.model,
        ddpm: ddpm_step(state.ddpm, x_t, eps),
        ddim: state.ddim,
        train: state.train,
        eval: state.eval,
    }
}

func diffusion_pipeline_ddim_step(diffusion_pipeline_state state, []float x_t) diffusion_pipeline_state {
    []float eps = denoiser_forward_stub(state.model, x_t, state.ddim.current_t)
    diffusion_pipeline_state {
        cfg: state.cfg,
        noise: state.noise,
        model: state.model,
        ddpm: state.ddpm,
        ddim: ddim_step(state.ddim, x_t, eps),
        train: state.train,
        eval: state.eval,
    }
}

func diffusion_pipeline_state_dict(diffusion_pipeline_state state) diffusion_pipeline_state {
    state
}

func diffusion_pipeline_load_state_dict(diffusion_pipeline_state state, diffusion_pipeline_state other) diffusion_pipeline_state {
    other
}
