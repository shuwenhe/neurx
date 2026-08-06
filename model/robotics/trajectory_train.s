package neurx.model.robotics.trajectory_train
use neurx.model.robotics.perception.{robotics_perception_state, new_robotics_perception_state, robotics_perception_state_dict, robotics_perception_load_state_dict, robotics_perception_encode, robotics_perception_mark_normalized}
use neurx.model.robotics.policy.{robotics_policy_state, new_robotics_policy_state, robotics_policy_state_dict, robotics_policy_load_state_dict, robotics_policy_forward}
struct robotics_trajectory_train_config {
    int obs_dim
    int latent_dim
    int act_dim
    int max_steps
    int sample_count
    float learning_rate
    string task_name
}

struct robotics_trajectory_train_metrics {
    int step
    int sample_index
    float loss
    float action_error
    bool trained
}

struct robotics_trajectory_train_state {
    robotics_perception_state perception
    robotics_policy_state policy
    robotics_trajectory_train_config config
    robotics_trajectory_train_metrics metrics
    int step
    float last_loss
    bool finished
}

func robotics_trajectory_copy_float([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func robotics_trajectory_copy_int([]int values) []int {
    int n = len(values)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func linear_target_weight(int act_index, int obs_index) float {
    float base = ((act_index + 1) as float) * 0.2
    float offset = ((obs_index + 1) as float) * 0.05
    base + offset
}

func new_robotics_trajectory_train_config(int obs_dim, int latent_dim, int act_dim, int max_steps, int sample_count, float learning_rate, string task_name) robotics_trajectory_train_config {
    robotics_trajectory_train_config {
        obs_dim: obs_dim,
        latent_dim: latent_dim,
        act_dim: act_dim,
        max_steps: max_steps,
        sample_count: sample_count,
        learning_rate: learning_rate,
        task_name: task_name,
    }
}

func new_robotics_trajectory_train_metrics() robotics_trajectory_train_metrics {
    robotics_trajectory_train_metrics {
        step: 0,
        sample_index: 0,
        loss: 0.0,
        action_error: 0.0,
        trained: false,
    }
}

func new_robotics_trajectory_train_state(robotics_trajectory_train_config config) robotics_trajectory_train_state {
    robotics_trajectory_train_state {
        perception: robotics_perception_mark_normalized(new_robotics_perception_state(config.task_name + "_perception", config.obs_dim, config.latent_dim)),
        policy: new_robotics_policy_state(config.task_name + "_policy", config.latent_dim, config.act_dim),
        config: config,
        metrics: new_robotics_trajectory_train_metrics(),
        step: 0,
        last_loss: 0.0,
        finished: false,
    }
}

func robotics_trajectory_train_state_dict(robotics_trajectory_train_state state) robotics_trajectory_train_state {
    robotics_trajectory_train_state {
        perception: robotics_perception_state_dict(state.perception),
        policy: robotics_policy_state_dict(state.policy),
        config: state.config,
        metrics: state.metrics,
        step: state.step,
        last_loss: state.last_loss,
        finished: state.finished,
    }
}

func robotics_trajectory_train_load_state_dict(robotics_trajectory_train_state state, robotics_trajectory_train_state other) robotics_trajectory_train_state {
    robotics_trajectory_train_state {
        perception: robotics_perception_load_state_dict(state.perception, other.perception),
        policy: robotics_policy_load_state_dict(state.policy, other.policy),
        config: other.config,
        metrics: other.metrics,
        step: other.step,
        last_loss: other.last_loss,
        finished: other.finished,
    }
}

func robotics_trajectory_observation(int sample_index, int obs_dim) []float {
    []float obs = []float{cap: obs_dim}
    int i = 0
    while i < obs_dim {
        int basis = sample_index + (i + 1)
        int mod = basis - (basis / 7) * 7
        obs[i] = ((mod as float) - 3.0) / 3.0
        i = i + 1
    }
    obs
}

func robotics_trajectory_target_action([]float observation, int act_dim) []float {
    []float target = []float{cap: act_dim}
    int a = 0
    while a < act_dim {
        float acc = 0.0
        int i = 0
        while i < len(observation) {
            acc = acc + observation[i] * linear_target_weight(a, i)
            i = i + 1
        }
        int parity = a - (a / 2) * 2
        if parity == 0 {
            acc = acc + 0.1
        } else {
            acc = acc - 0.1
        }
        target[a] = acc
        a = a + 1
    }
    target
}

func robotics_trajectory_mse([]float prediction, []float target) float {
    int n = len(prediction)
    if n <= 0 {
        return 0.0
    }
    float total = 0.0
    int i = 0
    while i < n {
        float diff = prediction[i]
        if i < len(target) {
            diff = diff - target[i]
        }
        total = total + diff * diff
        i = i + 1
    }
    total / (n as float)
}

func robotics_trajectory_train_complete(robotics_trajectory_train_state state) bool {
    state.finished
}

func robotics_trajectory_train_step(robotics_trajectory_train_state state) robotics_trajectory_train_state {
    if state.finished {
        return state
    }
    int sample_count = state.config.sample_count
    if sample_count <= 0 {
        sample_count = 1
    }
    int sample_index = state.step
    if sample_index >= sample_count {
        int remainder = sample_index - (sample_index / sample_count) * sample_count
        sample_index = remainder
    }
    []float observation = robotics_trajectory_observation(sample_index, state.config.obs_dim)
    []float target_action = robotics_trajectory_target_action(observation, state.config.act_dim)
    []float latent = robotics_perception_encode(state.perception, observation)
    []float prediction = robotics_policy_forward(state.policy, latent)
    float loss = robotics_trajectory_mse(prediction, target_action)
    float action_error = 0.0
    int act_dim = state.config.act_dim
    if act_dim <= 0 {
        act_dim = 1
    }
    []float grad_action = []float{cap: state.config.act_dim}
    int a = 0
    while a < state.config.act_dim {
        float diff = prediction[a] - target_action[a]
        action_error = action_error + diff * diff
        grad_action[a] = (2.0 * diff) / (act_dim as float)
        a = a + 1
    }
    float lr = state.config.learning_rate
    robotics_policy_state next_policy = state.policy
    []float next_policy_weight = robotics_trajectory_copy_float(next_policy.weight)
    []float next_policy_bias = robotics_trajectory_copy_float(next_policy.bias)
    []float grad_latent = []float{cap: state.config.latent_dim}
    a = 0
    while a < state.config.act_dim {
        int i = 0
        while i < state.config.latent_dim {
            int weight_idx = a * state.config.latent_dim + i
            grad_latent[i] = grad_latent[i] + next_policy_weight[weight_idx] * grad_action[a]
            next_policy_weight[weight_idx] = next_policy_weight[weight_idx] - lr * grad_action[a] * latent[i]
            i = i + 1
        }
        next_policy_bias[a] = next_policy_bias[a] - lr * grad_action[a]
        a = a + 1
    }
    robotics_perception_state next_perception = state.perception
    []float next_perception_weight = robotics_trajectory_copy_float(next_perception.weight)
    []float next_perception_bias = robotics_trajectory_copy_float(next_perception.bias)
    int latent_index = 0
    while latent_index < state.config.latent_dim {
        int obs_index = 0
        while obs_index < state.config.obs_dim {
            int weight_idx = latent_index * state.config.obs_dim + obs_index
            next_perception_weight[weight_idx] = next_perception_weight[weight_idx] - lr * grad_latent[latent_index] * observation[obs_index]
            obs_index = obs_index + 1
        }
        next_perception_bias[latent_index] = next_perception_bias[latent_index] - lr * grad_latent[latent_index]
        latent_index = latent_index + 1
    }
    int next_step = state.step + 1
    bool finished = next_step >= state.config.max_steps
    robotics_trajectory_train_state {
        perception: robotics_perception_state {
            perception_name: next_perception.perception_name,
            obs_dim: next_perception.obs_dim,
            latent_dim: next_perception.latent_dim,
            weight: next_perception_weight,
            bias: next_perception_bias,
            normalized: next_perception.normalized,
            trained: true,
        },
        policy: robotics_policy_state {
            policy_name: next_policy.policy_name,
            input_dim: next_policy.input_dim,
            act_dim: next_policy.act_dim,
            weight: next_policy_weight,
            bias: next_policy_bias,
            train_loss: loss,
            trained: true,
        },
        config: state.config,
        metrics: robotics_trajectory_train_metrics {
            step: next_step,
            sample_index: sample_index,
            loss: loss,
            action_error: action_error / (act_dim as float),
            trained: finished,
        },
        step: next_step,
        last_loss: loss,
        finished: finished,
    }
}

func robotics_trajectory_train_run(robotics_trajectory_train_state state, int steps) robotics_trajectory_train_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    robotics_trajectory_train_state current = state
    int i = 0
    while i < loops {
        current = robotics_trajectory_train_step(current)
        i = i + 1
        if current.finished {
            return current
        }
    }
    current
}
