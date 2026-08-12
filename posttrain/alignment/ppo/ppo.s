package neurx.posttrain.rlhf.ppo
use neurx.posttrain.config
struct ppo_state {
    float clip_range
    float kl_coef
    float value_coef
    float entropy_coef
    float last_ratio
    float last_advantage
    float last_kl
    bool ready
}


struct ppo_step_result {
    ppo_state state
    float objective
    float policy_loss
    float value_loss
    float clipped_ratio
    float advantage
}


func abs_float(float x) float {
    if x < 0.0 {
        return 0.0 - x
    }
    x
}


func exp_approx(float x) float {
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    1.0 + x + (x2 / 2.0) + (x3 / 6.0) + (x4 / 24.0) + (x5 / 120.0)
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


func new_ppo_state(posttrain_config cfg) ppo_state {
    ppo_state {
        clip_range: cfg.clip_range,
        kl_coef: cfg.kl_coef,
        value_coef: 0.5,
        entropy_coef: 0.0,
        last_ratio: 1.0,
        last_advantage: 0.0,
        last_kl: 0.0,
        ready: false,
    }
}


func ppo_advantage(float reward_value, float value_estimate) float {
    reward_value - value_estimate
}


func ppo_ratio(float new_logp, float old_logp) float {
    exp_approx(new_logp - old_logp)
}


func ppo_policy_loss(float ratio, float advantage, float clip_range) float {
    float unclipped = ratio * advantage
    float clipped_ratio = clamp_float(ratio, 1.0 - clip_range, 1.0 + clip_range)
    float clipped = clipped_ratio * advantage
    if advantage >= 0.0 {
        if unclipped < clipped {
            return 0.0 - unclipped
        }
        return 0.0 - clipped
    }
    if unclipped > clipped {
        return 0.0 - unclipped
    }
    0.0 - clipped
}


func ppo_value_loss(float value_pred, float value_target) float {
    float diff = value_pred - value_target
    0.5 * diff * diff
}


func ppo_objective(float policy_loss, float value_loss, float kl_value, ppo_state state) float {
    policy_loss + (state.value_coef * value_loss) + (state.kl_coef * kl_value)
}


func ppo_step(ppo_state state, float old_logp, float new_logp, float reward_value, float value_pred, float value_target, float kl_value) ppo_step_result {
    float advantage = ppo_advantage(reward_value, value_pred)
    float ratio = ppo_ratio(new_logp, old_logp)
    float clipped_ratio = clamp_float(ratio, 1.0 - state.clip_range, 1.0 + state.clip_range)
    float policy_loss = ppo_policy_loss(ratio, advantage, state.clip_range)
    float value_loss = ppo_value_loss(value_pred, value_target)
    float objective = ppo_objective(policy_loss, value_loss, kl_value, state)
    ppo_step_result {
        state: ppo_state {
            clip_range: state.clip_range,
            kl_coef: state.kl_coef,
            value_coef: state.value_coef,
            entropy_coef: state.entropy_coef,
            last_ratio: ratio,
            last_advantage: advantage,
            last_kl: kl_value,
            ready: true,
        },
        objective: objective,
        policy_loss: policy_loss,
        value_loss: value_loss,
        clipped_ratio: clipped_ratio,
        advantage: advantage,
    }
}


func ppo_state_dict(ppo_state state) ppo_state {
    state
}


func ppo_load_state_dict(ppo_state state, ppo_state other) ppo_state {
    other
}


func ppo_step_result_state_dict(ppo_step_result result) ppo_step_result {
    result
}


func ppo_step_result_load_state_dict(ppo_step_result result, ppo_step_result other) ppo_step_result {
    other
}

