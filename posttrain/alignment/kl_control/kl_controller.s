package neurx.posttrain.alignment.kl_control
use neurx.tensor
struct kl_controller_config {
    string controller_type
    float init_kl_coef
    float target_kl
    int horizon
}

struct kl_controller_state {
    string controller_type
    float value
    float target
    int horizon
}

func default_adaptive_kl_config() kl_controller_config {
    kl_controller_config {
        controller_type: "adaptive",
        init_kl_coef: 0.2,
        target_kl: 0.01,
        horizon: 10000,
    }
}

func default_fixed_kl_config() kl_controller_config {
    kl_controller_config {
        controller_type: "fixed",
        init_kl_coef: 0.2,
        target_kl: 0.0,
        horizon: 0,
    }
}

func init_kl_controller(kl_controller_config config) kl_controller_state {
    kl_controller_state {
        controller_type: config.controller_type,
        value: config.init_kl_coef,
        target: config.target_kl,
        horizon: config.horizon,
    }
}

func update_kl_controller(
    kl_controller_state state,
    float current_kl,
    int n_steps
) kl_controller_state {
    if state.controller_type == "fixed" {
        return state
    }
    float proportional_error = clamp_float(current_kl / state.target - 1.0, -0.2, 0.2)
    float mult = 1.0 + proportional_error * float(n_steps) / float(state.horizon)
    state.value = state.value * mult
    return state
}

func get_kl_coef(kl_controller_state state) float {
    return state.value
}

func clamp_float(float x, float min_val, float max_val) float {
    if x < min_val {
        return min_val
    }
    if x > max_val {
        return max_val
    }
    return x
}

