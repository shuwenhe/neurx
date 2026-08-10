package neurx.amp.grad_scaler

struct grad_scaler_state {
    float scale
    float growth_factor
    float backoff_factor
    int growth_interval
    int _growth_tracker
}

func new_grad_scaler(float init_scale, float growth_factor, float backoff_factor, int growth_interval) grad_scaler_state {
    grad_scaler_state {
        scale: init_scale,
        growth_factor: growth_factor,
        backoff_factor: backoff_factor,
        growth_interval: growth_interval,
        _growth_tracker: 0,
    }
}

func grad_scaler_scale(grad_scaler_state scaler, []float grads) []float {
    []float scaled = []float{cap: len(grads)}
    int i = 0
    while i < len(grads) {
        scaled[i] = grads[i] * scaler.scale
        i = i + 1
    }
    return scaled
}

func grad_scaler_unscale(grad_scaler_state scaler, []float grads) []float {
    []float unscaled = []float{cap: len(grads)}
    int i = 0
    while i < len(grads) {
        unscaled[i] = grads[i] / (scaler.scale + 1e-10)
        i = i + 1
    }
    return unscaled
}

func grad_scaler_has_overflow([]float grads) bool {
    int i = 0
    while i < len(grads) {
        if grads[i] != grads[i] {
            return true
        }
        float abs_val = grads[i]
        if abs_val < 0.0 {
            abs_val = 0.0 - abs_val
        }
        if abs_val > 1000000000000000.0 {
            return true
        }
        i = i + 1
    }
    return false
}

func grad_scaler_step(grad_scaler_state scaler, bool overflow_occurred) grad_scaler_state {
    if overflow_occurred {
        scaler.scale = scaler.scale * scaler.backoff_factor
        scaler._growth_tracker = 0
    } else {
        scaler._growth_tracker = scaler._growth_tracker + 1
        if scaler._growth_tracker >= scaler.growth_interval {
            scaler.scale = scaler.scale * scaler.growth_factor
            scaler._growth_tracker = 0
        }
    }
    return scaler
}

func grad_scaler_get_scale(grad_scaler_state scaler) float {
    return scaler.scale
}
