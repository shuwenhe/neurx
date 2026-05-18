package neurx.workflows.robotics.train

use neurx.model.robotics.train.{robotics_training_state, robotics_training_config}

struct robotics_train_state {
    robotics_training_state state
}

func new_robotics_train_state(string strategy, int steps) robotics_train_state {
    robotics_train_state {
        state: neurx.model.robotics.train.robotics_train_state(
            neurx.model.robotics.train.robotics_train_config(1, 1, steps, 0.0001, strategy)
        ),
    }
}

func robotics_train_state_dict(robotics_train_state state) robotics_train_state {
    robotics_train_state {
        state: neurx.model.robotics.train.robotics_train_state_dict(state.state),
    }
}

func robotics_train_load_state_dict(robotics_train_state state, robotics_train_state other) robotics_train_state {
    robotics_train_state {
        state: neurx.model.robotics.train.robotics_train_load_state_dict(state.state, other.state),
    }
}

func robotics_train_start(robotics_train_state state) robotics_train_state {
    robotics_train_state {
        state: neurx.model.robotics.train.robotics_train_start(state.state),
    }
}

func robotics_train_stop(robotics_train_state state) robotics_train_state {
    robotics_train_state {
        state: neurx.model.robotics.train.robotics_train_stop(state.state),
    }
}

