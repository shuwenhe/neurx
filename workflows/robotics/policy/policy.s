package neurx.workflows.robotics.policy

use neurx.model.robotics.policy.{robotics_policy_state}

func new_robotics_policy_state(string policy_name, int obs_dim, int act_dim) robotics_policy_state {
    neurx.model.robotics.policy.new_robotics_policy_state(policy_name, obs_dim, act_dim)
}

func robotics_policy_state_dict(robotics_policy_state state) robotics_policy_state {
    neurx.model.robotics.policy.robotics_policy_state_dict(state)
}

func robotics_policy_load_state_dict(robotics_policy_state state, robotics_policy_state other) robotics_policy_state {
    neurx.model.robotics.policy.robotics_policy_load_state_dict(state, other)
}

func robotics_policy_mark_trained(robotics_policy_state state) robotics_policy_state {
    neurx.model.robotics.policy.robotics_policy_mark_trained(state)
}

