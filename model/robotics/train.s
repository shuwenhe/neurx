package neurx.model.robotics.train

use neurx.model.robotics.train_robotics.{robotics_training_config, robotics_training_loop_state, robotics_training_metrics, robotics_training_state, new_robotics_training_config, new_robotics_training_metrics, new_robotics_training_state, robotics_training_state_dict, robotics_training_load_state_dict, robotics_training_step, robotics_training_run, robotics_training_complete}

func robotics_train_config(int batch_size, int seq_len, int max_steps, float learning_rate, string task_name) robotics_training_config {
    new_robotics_training_config(batch_size, seq_len, max_steps, learning_rate, task_name)
}

func robotics_train_state(robotics_training_config config) robotics_training_state {
    new_robotics_training_state(config)
}

func robotics_train_state_dict(robotics_training_state state) robotics_training_state {
    robotics_training_state_dict(state)
}

func robotics_train_load_state_dict(robotics_training_state state, robotics_training_state other) robotics_training_state {
    robotics_training_load_state_dict(state, other)
}

func robotics_train_start(robotics_training_state state) robotics_training_state {
    robotics_training_step(state)
}

func robotics_train_stop(robotics_training_state state) robotics_training_state {
    robotics_training_state {
        cfg: state.cfg,
        loop: state.loop,
        loader: state.loader,
        task: state.task,
        metrics: state.metrics,
        last_loss: state.last_loss,
        finished: true,
    }
}

func robotics_train_run(robotics_training_state state, int steps) robotics_training_state {
    robotics_training_run(state, steps)
}

func robotics_train_complete(robotics_training_state state) bool {
    robotics_training_complete(state)
}

