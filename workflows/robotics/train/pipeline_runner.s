package neurx.workflows.robotics.train.pipeline_runner

use neurx.model.robotics.train_robotics.{
    robotics_training_config,
    robotics_training_state,
    new_robotics_training_config,
    new_robotics_training_state,
    robotics_training_run,
}

func run_robotics_training_with_params(int batch_size, int seq_len, int max_steps, float learning_rate, string task_name) int {
    robotics_training_config cfg = new_robotics_training_config(batch_size, seq_len, max_steps, learning_rate, task_name)
    robotics_training_state state = new_robotics_training_state(cfg)
    state = robotics_training_run(state, max_steps)

    if !state.finished {
        panic("robotics workflow training did not finish")
    }
    if state.metrics.step != max_steps {
        panic("robotics workflow training step mismatch")
    }
    0
}
