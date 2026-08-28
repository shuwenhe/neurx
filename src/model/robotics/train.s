package neurx.model.robotics.train
use neurx.model.robotics.train_robotics.{robotics_training_config, robotics_training_loop_state, robotics_training_metrics, robotics_training_state, new_robotics_training_config, new_robotics_training_metrics, new_robotics_training_state, robotics_training_state_dict, robotics_training_load_state_dict, robotics_training_step, robotics_training_run, robotics_training_complete}
use neurx.model.robotics.trajectory_train.{robotics_trajectory_train_config, robotics_trajectory_train_state, robotics_trajectory_train_metrics, new_robotics_trajectory_train_config, new_robotics_trajectory_train_state, robotics_trajectory_train_state_dict, robotics_trajectory_train_load_state_dict, robotics_trajectory_train_step, robotics_trajectory_train_run, robotics_trajectory_train_complete}
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
func robotics_robot_train_config(int obs_dim, int latent_dim, int act_dim, int max_steps, int sample_count, float learning_rate, string task_name) robotics_trajectory_train_config {
    new_robotics_trajectory_train_config(obs_dim, latent_dim, act_dim, max_steps, sample_count, learning_rate, task_name)
}
func robotics_robot_train_state(robotics_trajectory_train_config config) robotics_trajectory_train_state {
    new_robotics_trajectory_train_state(config)
}
func robotics_robot_train_state_dict(robotics_trajectory_train_state state) robotics_trajectory_train_state {
    robotics_trajectory_train_state_dict(state)
}
func robotics_robot_train_load_state_dict(robotics_trajectory_train_state state, robotics_trajectory_train_state other) robotics_trajectory_train_state {
    robotics_trajectory_train_load_state_dict(state, other)
}
func robotics_robot_train_step(robotics_trajectory_train_state state) robotics_trajectory_train_state {
    robotics_trajectory_train_step(state)
}
func robotics_robot_train_run(robotics_trajectory_train_state state, int steps) robotics_trajectory_train_state {
    robotics_trajectory_train_run(state, steps)
}
func robotics_robot_train_complete(robotics_trajectory_train_state state) bool {
    robotics_trajectory_train_complete(state)
}
