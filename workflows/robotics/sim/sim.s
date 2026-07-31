package neurx.workflows.robotics.sim
struct robotics_sim_state {
    string env_name
    int episodes
    bool domain_randomization
}
func new_robotics_sim_state(string env_name, int episodes, bool domain_randomization) robotics_sim_state {
    robotics_sim_state {
        env_name: env_name,
        episodes: episodes,
        domain_randomization: domain_randomization,
    }
}

func robotics_sim_state_dict(robotics_sim_state state) robotics_sim_state {
    state
}

func robotics_sim_load_state_dict(robotics_sim_state state, robotics_sim_state other) robotics_sim_state {
    other
}

func robotics_sim_enable_domain_randomization(robotics_sim_state state) robotics_sim_state {
    robotics_sim_state {
        env_name: state.env_name,
        episodes: state.episodes,
        domain_randomization: true,
    }
}
