package neurx.workflows.robotics.policy

struct robotics_policy_state {
    string policy_name
    int obs_dim
    int act_dim
    bool trained
}

func new_robotics_policy_state(string policy_name, int obs_dim, int act_dim) robotics_policy_state {
    robotics_policy_state {
        policy_name: policy_name,
        obs_dim: obs_dim,
        act_dim: act_dim,
        trained: false,
    }
}

func robotics_policy_state_dict(robotics_policy_state state) robotics_policy_state {
    state
}

func robotics_policy_load_state_dict(robotics_policy_state state, robotics_policy_state other) robotics_policy_state {
    other
}

func robotics_policy_mark_trained(robotics_policy_state state) robotics_policy_state {
    robotics_policy_state {
        policy_name: state.policy_name,
        obs_dim: state.obs_dim,
        act_dim: state.act_dim,
        trained: true,
    }
}

