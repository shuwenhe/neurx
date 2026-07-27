package neurx.workflows.robotics.eval
use neurx.model.robotics.eval.{robotics_eval_state}
func new_robotics_eval_state(string metric_name) robotics_eval_state {
    neurx.model.robotics.eval.new_robotics_eval_state(metric_name)
}
func robotics_eval_state_dict(robotics_eval_state state) robotics_eval_state {
    neurx.model.robotics.eval.robotics_eval_state_dict(state)
}
func robotics_eval_load_state_dict(robotics_eval_state state, robotics_eval_state other) robotics_eval_state {
    neurx.model.robotics.eval.robotics_eval_load_state_dict(state, other)
}
func robotics_eval_update(robotics_eval_state state, float score, int episodes) robotics_eval_state {
    neurx.model.robotics.eval.robotics_eval_update(state, score, episodes)
}
