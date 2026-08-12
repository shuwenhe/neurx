package neurx.posttrain.dpo.dpo_state
struct dpo_state {
    float beta
    float label_smoothing
    float last_margin
    float last_loss
    bool ready
}
func clamp_float(float value, float low, float high) float {
    if value < low {
        return low
    }
    if value > high {
        return high
    }
    value
}
func new_dpo_state(float beta, float label_smoothing) dpo_state {
    dpo_state {
        beta: beta,
        label_smoothing: clamp_float(label_smoothing, 0.0, 0.5),
        last_margin: 0.0,
        last_loss: 0.0,
        ready: false,
    }
}
func new_default_dpo_state() dpo_state {
    new_dpo_state(0.1, 0.0)
}
func dpo_state_dict(dpo_state state) dpo_state {
    state
}
func dpo_load_state_dict(dpo_state state, dpo_state other) dpo_state {
    other
}
