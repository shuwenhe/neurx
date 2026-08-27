package neurx.model.robotics.perception

struct robotics_perception_state {
    string perception_name
    int obs_dim
    int latent_dim
    float[] weight
    float[] bias
    bool normalized
    bool trained
}

func robotics_perception_copy_float(float[] values) float[] {
    int n = len(values)
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func robotics_perception_copy_int(int[] values) int[] {
    int n = len(values)
    int[] out = int[]{cap: n}
    int i = 0
    for i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}

func robotics_perception_ramp_values(int n, float scale) float[] {
    float[] out = float[]{cap: n}
    int i = 0
    for i < n {
        out[i] = scale * ((i + 1) as float) / ((n + 1) as float)
        i = i + 1
    }
    out
}

func new_robotics_perception_state(string perception_name, int obs_dim, int latent_dim) robotics_perception_state {
    int weight_count = obs_dim * latent_dim
    robotics_perception_state {
        perception_name: perception_name,
        obs_dim: obs_dim,
        latent_dim: latent_dim,
        weight: robotics_perception_ramp_values(weight_count, 0.01),
        bias: float[]{cap: latent_dim},
        normalized: false,
        trained: false,
    }
}

func robotics_perception_state_dict(robotics_perception_state state) robotics_perception_state {
    robotics_perception_state {
        perception_name: state.perception_name,
        obs_dim: state.obs_dim,
        latent_dim: state.latent_dim,
        weight: robotics_perception_copy_float(state.weight),
        bias: robotics_perception_copy_float(state.bias),
        normalized: state.normalized,
        trained: state.trained,
    }
}

func robotics_perception_load_state_dict(robotics_perception_state state, robotics_perception_state other) robotics_perception_state {
    robotics_perception_state {
        perception_name: other.perception_name,
        obs_dim: other.obs_dim,
        latent_dim: other.latent_dim,
        weight: robotics_perception_copy_float(other.weight),
        bias: robotics_perception_copy_float(other.bias),
        normalized: other.normalized,
        trained: other.trained,
    }
}

func robotics_perception_encode(robotics_perception_state state, float[] observation) float[] {
    float[] latent = float[]{cap: state.latent_dim}
    int j = 0
    for j < state.latent_dim {
        float acc = state.bias[j]
        int i = 0
        for i < state.obs_dim {
            int weight_idx = j * state.obs_dim + i
            float value = 0.0
            if i < len(observation) {
                value = observation[i]
            }
            acc = acc + state.weight[weight_idx] * value
            i = i + 1
        }
        latent[j] = acc
        j = j + 1
    }
    latent
}

func robotics_perception_mark_normalized(robotics_perception_state state) robotics_perception_state {
    robotics_perception_state {
        perception_name: state.perception_name,
        obs_dim: state.obs_dim,
        latent_dim: state.latent_dim,
        weight: robotics_perception_copy_float(state.weight),
        bias: robotics_perception_copy_float(state.bias),
        normalized: true,
        trained: state.trained,
    }
}
