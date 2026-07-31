package neurx.diffusion.eval
struct diffusion_eval_state {
    int samples
    float fid_like
    float is_like
    bool has_result
}
func new_diffusion_eval_state() diffusion_eval_state {
    diffusion_eval_state {
        samples: 0,
        fid_like: 0.0,
        is_like: 0.0,
        has_result: false,
    }
}

func update_diffusion_eval(diffusion_eval_state state, int samples, float fid_like, float is_like) diffusion_eval_state {
    diffusion_eval_state {
        samples: samples,
        fid_like: fid_like,
        is_like: is_like,
        has_result: true,
    }
}

func diffusion_eval_state_dict(diffusion_eval_state state) diffusion_eval_state {
    state
}

func diffusion_eval_load_state_dict(diffusion_eval_state state, diffusion_eval_state other) diffusion_eval_state {
    other
}
