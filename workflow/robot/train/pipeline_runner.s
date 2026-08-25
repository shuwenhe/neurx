package neurx.workflows.robotics.train.pipeline_runner
use neurx.model.robotics.train.{
    robotics_trajectory_train_config,
    robotics_trajectory_train_state,
    robotics_robot_train_config,
    robotics_robot_train_state,
    robotics_robot_train_run,
    robotics_robot_train_step,
}

func run_robotics_training_with_params(int obs_dim, int latent_dim, int act_dim, int max_steps, int sample_count, float learning_rate, int eval_every, int save_every, string task_name) int {
    robotics_trajectory_train_config cfg = robotics_robot_train_config(obs_dim, latent_dim, act_dim, max_steps, sample_count, learning_rate, task_name)
    robotics_trajectory_train_state state = robotics_robot_train_state(cfg)
    state = robotics_robot_train_run(state, max_steps)
    if !state.finished {
        panic("robotics workflow training did not finish")
    }
    if state.metrics.step != max_steps {
        panic("robotics workflow training step mismatch")
    }
    if eval_every < 0 {
        panic("robotics workflow eval interval must be non-negative")
    }
    if save_every < 0 {
        panic("robotics workflow save interval must be non-negative")
    }
    0
}

struct robotics_workflow_tick_state {
    robotics_trajectory_train_state training
    int eval_every
    int save_every
    int eval_count
    int save_count
    int last_eval_step
    int last_save_step
}

func robotics_workflow_tick_state_dict(robotics_workflow_tick_state state) robotics_workflow_tick_state {
    robotics_workflow_tick_state {
        training: state.training,
        eval_every: state.eval_every,
        save_every: state.save_every,
        eval_count: state.eval_count,
        save_count: state.save_count,
        last_eval_step: state.last_eval_step,
        last_save_step: state.last_save_step,
    }
}

func robotics_workflow_tick_load_state_dict(robotics_workflow_tick_state state, robotics_workflow_tick_state other) robotics_workflow_tick_state {
    robotics_workflow_tick_state {
        training: other.training,
        eval_every: other.eval_every,
        save_every: other.save_every,
        eval_count: other.eval_count,
        save_count: other.save_count,
        last_eval_step: other.last_eval_step,
        last_save_step: other.last_save_step,
    }
}

func robotics_workflow_training_state(robotics_workflow_tick_state state) robotics_trajectory_train_state {
    state.training
}

func robotics_workflow_eval_count(robotics_workflow_tick_state state) int {
    state.eval_count
}

func robotics_workflow_save_count(robotics_workflow_tick_state state) int {
    state.save_count
}

func robotics_workflow_last_eval_step(robotics_workflow_tick_state state) int {
    state.last_eval_step
}

func robotics_workflow_last_save_step(robotics_workflow_tick_state state) int {
    state.last_save_step
}

func robotics_workflow_eval_interval(robotics_workflow_tick_state state) int {
    state.eval_every
}

func robotics_workflow_save_interval(robotics_workflow_tick_state state) int {
    state.save_every
}

func robotics_tick_due(int step, int interval, bool finished) bool {
    if interval <= 0 {
        return false
    }
    int remainder = step - (step / interval) * interval
    if remainder == 0 {
        return true
    }
    finished
}

func run_robotics_training_schedule_state(int obs_dim, int latent_dim, int act_dim, int max_steps, int sample_count, int eval_every, int save_every, float learning_rate, string task_name) robotics_workflow_tick_state {
    robotics_trajectory_train_config cfg = robotics_robot_train_config(obs_dim, latent_dim, act_dim, max_steps, sample_count, learning_rate, task_name)
    robotics_workflow_tick_state workflow = robotics_workflow_tick_state {
        training: robotics_robot_train_state(cfg),
        eval_every: eval_every,
        save_every: save_every,
        eval_count: 0,
        save_count: 0,
        last_eval_step: 0,
        last_save_step: 0,
    }
    while !workflow.training.finished {
        robotics_trajectory_train_state next_training = robotics_robot_train_step(workflow.training)
        int step = next_training.metrics.step
        int eval_count = workflow.eval_count
        int save_count = workflow.save_count
        int last_eval_step = workflow.last_eval_step
        int last_save_step = workflow.last_save_step
        if robotics_tick_due(step, workflow.eval_every, next_training.finished) && step != last_eval_step {
            eval_count = eval_count + 1
            last_eval_step = step
        }
        if robotics_tick_due(step, workflow.save_every, next_training.finished) && step != last_save_step {
            save_count = save_count + 1
            last_save_step = step
        }
        workflow = robotics_workflow_tick_state {
            training: next_training,
            eval_every: workflow.eval_every,
            save_every: workflow.save_every,
            eval_count: eval_count,
            save_count: save_count,
            last_eval_step: last_eval_step,
            last_save_step: last_save_step,
        }
    }
    workflow
}

func run_robotics_training_with_schedule(int obs_dim, int latent_dim, int act_dim, int max_steps, int sample_count, int eval_every, int save_every, float learning_rate, string task_name) int {
    robotics_workflow_tick_state workflow = run_robotics_training_schedule_state(obs_dim, latent_dim, act_dim, max_steps, sample_count, eval_every, save_every, learning_rate, task_name)
    if !workflow.training.finished {
        panic("robotics workflow training did not finish")
    }
    if workflow.training.metrics.step != max_steps {
        panic("robotics workflow training step mismatch")
    }
    if workflow.eval_every > 0 && workflow.eval_count <= 0 {
        panic("robotics workflow eval tick did not fire")
    }
    if workflow.save_every > 0 && workflow.save_count <= 0 {
        panic("robotics workflow save tick did not fire")
    }
    0
}
