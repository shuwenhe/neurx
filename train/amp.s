package neurx.train.amp

struct autocast_state {
    bool enabled
    int dtype_code
    int nesting
}

struct grad_scaler_state {
    float scale
    float growth_factor
    float backoff_factor
    int growth_interval
    int growth_tracker
    bool enabled
    bool found_inf
}

func new_autocast_state(bool enabled, int dtype_code) autocast_state {
    autocast_state {
        enabled: enabled,
        dtype_code: dtype_code,
        nesting: 0,
    }
}

func is_autocast_enabled(autocast_state state) bool {
    state.enabled && state.nesting > -1
}

func get_autocast_dtype(autocast_state state) int {
    state.dtype_code
}

func set_autocast_enabled(autocast_state state, bool enabled) autocast_state {
    autocast_state {
        enabled: enabled,
        dtype_code: state.dtype_code,
        nesting: state.nesting,
    }
}

func set_autocast_dtype(autocast_state state, int dtype_code) autocast_state {
    autocast_state {
        enabled: state.enabled,
        dtype_code: dtype_code,
        nesting: state.nesting,
    }
}

func autocast_enter(autocast_state state) autocast_state {
    autocast_state {
        enabled: state.enabled,
        dtype_code: state.dtype_code,
        nesting: state.nesting + 1,
    }
}

func autocast_exit(autocast_state state) autocast_state {
    int nesting = state.nesting - 1
    if nesting < 0 {
        nesting = 0
    }
    autocast_state {
        enabled: state.enabled,
        dtype_code: state.dtype_code,
        nesting: nesting,
    }
}

func autocast_state_dict(autocast_state state) autocast_state {
    state
}

func autocast_load_state_dict(autocast_state state, autocast_state other) autocast_state {
    other
}

func new_grad_scaler(float init_scale, float growth_factor, float backoff_factor, int growth_interval, bool enabled) grad_scaler_state {
    grad_scaler_state {
        scale: init_scale,
        growth_factor: growth_factor,
        backoff_factor: backoff_factor,
        growth_interval: growth_interval,
        growth_tracker: 0,
        enabled: enabled,
        found_inf: false,
    }
}

func scale_loss(grad_scaler_state state, float loss) float {
    if !state.enabled {
        return loss
    }
    loss * state.scale
}

func update_scale(grad_scaler_state state, bool found_inf) grad_scaler_state {
    if !state.enabled {
        return state
    }
    float next_scale = state.scale
    int next_tracker = state.growth_tracker + 1
    bool next_found_inf = false
    if found_inf {
        next_scale = state.scale * state.backoff_factor
        if next_scale < 1.0 {
            next_scale = 1.0
        }
        next_tracker = 0
        next_found_inf = true
    } else {
        if next_tracker >= state.growth_interval {
            next_scale = state.scale * state.growth_factor
            next_tracker = 0
        }
    }
    grad_scaler_state {
        scale: next_scale,
        growth_factor: state.growth_factor,
        backoff_factor: state.backoff_factor,
        growth_interval: state.growth_interval,
        growth_tracker: next_tracker,
        enabled: state.enabled,
        found_inf: next_found_inf,
    }
}

func grad_scaler_step(grad_scaler_state scaler, float loss) grad_scaler_state {
    bool found_inf = false
    if loss != loss {
        found_inf = true
    }
    if loss > 1.0e30 {
        found_inf = true
    }
    return update_scale(scaler, found_inf)
}

func grad_scaler_state_dict(grad_scaler_state state) grad_scaler_state {
    state
}

func grad_scaler_load_state_dict(grad_scaler_state state, grad_scaler_state other) grad_scaler_state {
    other
}
