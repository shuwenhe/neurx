package neurx.workflows.robotics.eval

struct robotics_eval_state {
    string metric_name
    float score
    int episodes
}

func new_robotics_eval_state(string metric_name) robotics_eval_state {
    robotics_eval_state {
        metric_name: metric_name,
        score: 0.0,
        episodes: 0,
    }
}

func robotics_eval_state_dict(robotics_eval_state state) robotics_eval_state {
    state
}

func robotics_eval_load_state_dict(robotics_eval_state state, robotics_eval_state other) robotics_eval_state {
    other
}

func robotics_eval_update(robotics_eval_state state, float score, int episodes) robotics_eval_state {
    robotics_eval_state {
        metric_name: state.metric_name,
        score: score,
        episodes: episodes,
    }
}

