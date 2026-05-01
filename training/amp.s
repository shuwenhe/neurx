package neurx.training.amp

struct autocast_state {
    bool enabled
    int dtype_code
}

struct grad_scaler_state {
    float scale
    float growth_factor
    float backoff_factor
    int growth_interval
    int growth_tracker
    bool enabled
}

func new_autocast_state(bool enabled, int dtype_code) autocast_state {
    autocast_state {
        enabled: enabled,
        dtype_code: dtype_code,
    }
}

func is_autocast_enabled(autocast_state state) bool {
    state.enabled
}

func get_autocast_dtype(autocast_state state) int {
    state.dtype_code
}

func set_autocast_enabled(autocast_state state, bool enabled) autocast_state {
    autocast_state {
        enabled: enabled,
        dtype_code: state.dtype_code,
    }
}

func set_autocast_dtype(autocast_state state, int dtype_code) autocast_state {
    autocast_state {
        enabled: state.enabled,
        dtype_code: dtype_code,
    }
}

func new_grad_scaler(float init_scale, float growth_factor, float backoff_factor, int growth_interval, bool enabled) grad_scaler_state {
    grad_scaler_state {
        scale: init_scale,
        growth_factor: growth_factor,
        backoff_factor: backoff_factor,
        growth_interval: growth_interval,
        growth_tracker: 0,
        enabled: enabled,
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
    if found_inf {
        grad_scaler_state {
            scale: if state.scale * state.backoff_factor > 1.0 { state.scale * state.backoff_factor } else { 1.0 },
            growth_factor: state.growth_factor,
            backoff_factor: state.backoff_factor,
            growth_interval: state.growth_interval,
            growth_tracker: 0,
            enabled: state.enabled,
        }
    }
    int next_tracker = state.growth_tracker + 1
    if next_tracker >= state.growth_interval {
        grad_scaler_state {
            scale: state.scale * state.growth_factor,
            growth_factor: state.growth_factor,
            backoff_factor: state.backoff_factor,
            growth_interval: state.growth_interval,
            growth_tracker: 0,
            enabled: state.enabled,
        }
    }
    grad_scaler_state {
        scale: state.scale,
        growth_factor: state.growth_factor,
        backoff_factor: state.backoff_factor,
        growth_interval: state.growth_interval,
        growth_tracker: next_tracker,
        enabled: state.enabled,
    }
}

func grad_scaler_step(grad_scaler_state scaler, float loss) grad_scaler_state {
    del loss
    scaler
}

func grad_scaler_state_dict(grad_scaler_state state) grad_scaler_state {
    state
}

func grad_scaler_load_state_dict(grad_scaler_state state, grad_scaler_state other) grad_scaler_state {
    other
}
