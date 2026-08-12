package neurx.workflows.robotics.train
use neurx.model.robotics.train.{robotics_training_state, robotics_training_config}
use neurx.model.robotics.train.{robotics_trajectory_train_config, robotics_trajectory_train_state}

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


func robotics_robot_train_config(int obs_dim, int latent_dim, int act_dim, int max_steps, int sample_count, float learning_rate, string task_name) robotics_trajectory_train_config {
    neurx.model.robotics.train.robotics_robot_train_config(obs_dim, latent_dim, act_dim, max_steps, sample_count, learning_rate, task_name)
}


func robotics_robot_train_state(robotics_trajectory_train_config config) robotics_trajectory_train_state {
    neurx.model.robotics.train.robotics_robot_train_state(config)
}


func robotics_robot_train_state_dict(robotics_trajectory_train_state state) robotics_trajectory_train_state {
    neurx.model.robotics.train.robotics_robot_train_state_dict(state)
}


func robotics_robot_train_load_state_dict(robotics_trajectory_train_state state, robotics_trajectory_train_state other) robotics_trajectory_train_state {
    neurx.model.robotics.train.robotics_robot_train_load_state_dict(state, other)
}


func robotics_robot_train_step(robotics_trajectory_train_state state) robotics_trajectory_train_state {
    neurx.model.robotics.train.robotics_robot_train_step(state)
}


func robotics_robot_train_run(robotics_trajectory_train_state state, int steps) robotics_trajectory_train_state {
    neurx.model.robotics.train.robotics_robot_train_run(state, steps)
}


func robotics_robot_train_complete(robotics_trajectory_train_state state) bool {
    neurx.model.robotics.train.robotics_robot_train_complete(state)
}

