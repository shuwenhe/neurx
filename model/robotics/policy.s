package neurx.model.robotics.policy
struct robotics_policy_state {
    string policy_name
    int input_dim
    int act_dim
    []float weight
    []float bias
    float train_loss
    bool trained
}
func robotics_policy_copy_float([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func robotics_policy_ramp_values(int n, float scale) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = scale * ((i + 1) as float) / ((n + 1) as float)
        i = i + 1
    }
    out
}

func new_robotics_policy_state(string policy_name, int obs_dim, int act_dim) robotics_policy_state {
    int weight_count = obs_dim * act_dim
    robotics_policy_state {
        policy_name: policy_name,
        input_dim: obs_dim,
        act_dim: act_dim,
        weight: robotics_policy_ramp_values(weight_count, 0.02),
        bias: []float{cap: act_dim},
        train_loss: 0.0,
        trained: false,
    }
}

func robotics_policy_state_dict(robotics_policy_state state) robotics_policy_state {
    robotics_policy_state {
        policy_name: state.policy_name,
        input_dim: state.input_dim,
        act_dim: state.act_dim,
        weight: robotics_policy_copy_float(state.weight),
        bias: robotics_policy_copy_float(state.bias),
        train_loss: state.train_loss,
        trained: state.trained,
    }
}

func robotics_policy_load_state_dict(robotics_policy_state state, robotics_policy_state other) robotics_policy_state {
    robotics_policy_state {
        policy_name: other.policy_name,
        input_dim: other.input_dim,
        act_dim: other.act_dim,
        weight: robotics_policy_copy_float(other.weight),
        bias: robotics_policy_copy_float(other.bias),
        train_loss: other.train_loss,
        trained: other.trained,
    }
}

func robotics_policy_mark_trained(robotics_policy_state state) robotics_policy_state {
    robotics_policy_state {
        policy_name: state.policy_name,
        input_dim: state.input_dim,
        act_dim: state.act_dim,
        weight: robotics_policy_copy_float(state.weight),
        bias: robotics_policy_copy_float(state.bias),
        train_loss: state.train_loss,
        trained: true,
    }
}

func robotics_policy_forward(robotics_policy_state state, []float input) []float {
    []float action = []float{cap: state.act_dim}
    int a = 0
    while a < state.act_dim {
        float acc = state.bias[a]
        int i = 0
        while i < state.input_dim {
            int weight_idx = a * state.input_dim + i
            float value = 0.0
            if i < len(input) {
                value = input[i]
            }
            acc = acc + state.weight[weight_idx] * value
            i = i + 1
        }
        action[a] = acc
        a = a + 1
    }
    action
}
