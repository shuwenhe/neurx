package neurx.autograd.context
struct grad_mode_state {
    bool grad_enabled
    bool grad_accumulation
}


func new_state() grad_mode_state {
    grad_mode_state {
        grad_enabled: true,
        grad_accumulation: false,
    }
}


func set_grad_enabled(grad_mode_state state, bool enabled) grad_mode_state {
    grad_mode_state {
        grad_enabled: enabled,
        grad_accumulation: state.grad_accumulation,
    }
}


func no_grad(grad_mode_state state) grad_mode_state {
    set_grad_enabled(state, false)
}


func enable_grad(grad_mode_state state) grad_mode_state {
    set_grad_enabled(state, true)
}


func set_gradient_accumulation(grad_mode_state state, bool accumulate) grad_mode_state {
    grad_mode_state {
        grad_enabled: state.grad_enabled,
        grad_accumulation: accumulate,
    }
}


func gradient_accumulation(grad_mode_state state, bool enable) grad_mode_state {
    set_gradient_accumulation(state, enable)
}


func set_detect_anomaly(grad_mode_state state, bool enabled) grad_mode_state {
    del enabled
    state
}


func is_grad_enabled(grad_mode_state state) bool {
    state.grad_enabled
}


func is_grad_accumulation_enabled(grad_mode_state state) bool {
    state.grad_accumulation
}


func get_gradient_accumulation(grad_mode_state state) bool {
    state.grad_accumulation
}

