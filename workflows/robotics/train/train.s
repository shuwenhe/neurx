package neurx.workflows.robotics.train

use neurx.model.robotics.train.{robotics_training_config, robotics_training_state, robotics_train_config, robotics_train_state, robotics_train_state_dict, robotics_train_load_state_dict, robotics_train_start, robotics_train_stop, robotics_train_run, robotics_train_complete}

func new_robotics_train_state(string strategy, int steps) robotics_training_state {
    robotics_train_state(robotics_train_config(1, 1, steps, 0.0001, strategy))
}

func robotics_train_state_dict(robotics_training_state state) robotics_training_state {
    robotics_train_state_dict(state)
}

func robotics_train_load_state_dict(robotics_training_state state, robotics_training_state other) robotics_training_state {
    robotics_train_load_state_dict(state, other)
}

func robotics_train_start(robotics_training_state state) robotics_training_state {
    robotics_train_start(state)
}

func robotics_train_stop(robotics_training_state state) robotics_training_state {
    robotics_train_stop(state)
}

