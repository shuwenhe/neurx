package neurx.workflows.robotics.train

struct robotics_train_state {
    string strategy
    int steps
    bool running
}

func new_robotics_train_state(string strategy, int steps) robotics_train_state {
    robotics_train_state {
        strategy: strategy,
        steps: steps,
        running: false,
    }
}

func robotics_train_state_dict(robotics_train_state state) robotics_train_state {
    state
}

func robotics_train_load_state_dict(robotics_train_state state, robotics_train_state other) robotics_train_state {
    other
}

func robotics_train_start(robotics_train_state state) robotics_train_state {
    robotics_train_state {
        strategy: state.strategy,
        steps: state.steps,
        running: true,
    }
}

func robotics_train_stop(robotics_train_state state) robotics_train_state {
    robotics_train_state {
        strategy: state.strategy,
        steps: state.steps,
        running: false,
    }
}

