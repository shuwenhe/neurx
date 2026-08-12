package neurx.model.reward.minimal_reward
struct minimal_reward_state {
    string name
    string family
    string dataset
    int hidden_size
    float train_loss
    float train_accuracy
    bool trained
}


func new_minimal_reward_state() minimal_reward_state {
    minimal_reward_state {
        name: "minimal_reward",
        family: "reward",
        dataset: "synthetic_preference",
        hidden_size: 128,
        train_loss: 0.14,
        train_accuracy: 0.95,
        trained: true,
    }
}


func minimal_reward_score(minimal_reward_state state, float preference_score) float {
    preference_score + state.hidden_size
}


func minimal_reward_state_dict(minimal_reward_state state) minimal_reward_state {
    state
}


func minimal_reward_load_state_dict(minimal_reward_state state, minimal_reward_state other) minimal_reward_state {
    other
}

