package neurx.posttrain.reward

struct reward_state {
    string reward_model
    float last_reward
    float last_kl
    float margin
    bool has_result
}

func new_reward_state(string reward_model) reward_state {
    reward_state {
        reward_model: reward_model,
        last_reward: 0.0,
        last_kl: 0.0,
        margin: 0.0,
        has_result: false,
    }
}

func update_reward_state(reward_state state, float reward, float kl, float margin) reward_state {
    reward_state {
        reward_model: state.reward_model,
        last_reward: reward,
        last_kl: kl,
        margin: margin,
        has_result: true,
    }
}

func reward_state_dict(reward_state state) reward_state {
    state
}

func reward_load_state_dict(reward_state state, reward_state other) reward_state {
    other
}
