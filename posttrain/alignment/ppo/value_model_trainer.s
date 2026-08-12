package neurx.posttrain.rlhf.value_model_trainer
struct value_network {
    [][]float hidden_weights
    []float hidden_bias
    []float output_weight
    float output_bias
    int seq_len
    int hidden_size
    [][]float hidden_w_m
    [][]float hidden_w_v
    []float hidden_b_m
    []float hidden_b_v
    []float output_w_m
    []float output_w_v
    float output_b_m
    float output_b_v
    int step
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
}

struct value_config {
    int seq_len
    int hidden_size
    int num_layers
    float learning_rate
    float gamma
    float gae_lambda
    int batch_size
    int num_epochs
    float weight_decay
    float value_loss_coef
    float max_grad_norm
    int global_rank
    int world_size
    int dp_degree
    bool use_mixed_precision
    string checkpoint_dir
    int checkpoint_interval
}

struct value_trajectory_step {
    []float observation
    float reward
    float value_estimate
    float next_value_estimate
    float advantage
    float return_value
    bool is_terminal
}

struct value_trajectory {
    []value_trajectory_step steps
    int trajectory_id
    int length
    float total_reward
    float mean_value
    float max_advantage
    float min_advantage
}

struct value_state {
    value_network network
    value_config config
    int global_step
    int global_epoch
    float total_loss
    float value_loss
    float regularization_loss
    float mean_abs_error
    float avg_value_pred
    float avg_return_target
    float explained_variance
    int trajectories_processed
    int total_samples
    bool initialized
}

struct value_metrics {
    float loss
    float mse
    float mae
    float r_squared
    float max_abs_error
    float mean_prediction
    float mean_target
    int step
}

func create_value_network(value_config cfg) value_network {
    int hidden_size = cfg.hidden_size
    int seq_len = cfg.seq_len
    [][]float h_w = make_matrix(hidden_size, seq_len, 0.0)
    []float h_b = make_array(hidden_size, 0.0)
    []float o_w = make_array(hidden_size, 0.0)
    float o_b = 0.0
    int i = 0
    while i < hidden_size {
        int j = 0
        while j < seq_len {
            float val = (i * seq_len + j) as float / (hidden_size * seq_len) as float
            h_w[i][j] = (val - 0.5) * 0.02
            j = j + 1
        }
        h_b[i] = 0.0
        o_w[i] = (i as float) / (hidden_size as float) * 0.01
        i = i + 1
    }
    o_b = 0.0
    value_network {
        hidden_weights: h_w,
        hidden_bias: h_b,
        output_weight: o_w,
        output_bias: o_b,
        seq_len: seq_len,
        hidden_size: hidden_size,
        hidden_w_m: make_matrix(hidden_size, seq_len, 0.0),
        hidden_w_v: make_matrix(hidden_size, seq_len, 0.0),
        hidden_b_m: make_array(hidden_size, 0.0),
        hidden_b_v: make_array(hidden_size, 0.0),
        output_w_m: make_array(hidden_size, 0.0),
        output_w_v: make_array(hidden_size, 0.0),
        output_b_m: 0.0,
        output_b_v: 0.0,
        step: 0,
        lr: cfg.learning_rate,
        beta1: 0.9,
        beta2: 0.999,
        eps: 1e-8,
        weight_decay: cfg.weight_decay,
    }
}

func new_value_state(value_config cfg) value_state {
    value_state {
        network: create_value_network(cfg),
        config: cfg,
        global_step: 0,
        global_epoch: 0,
        total_loss: 0.0,
        value_loss: 0.0,
        regularization_loss: 0.0,
        mean_abs_error: 0.0,
        avg_value_pred: 0.0,
        avg_return_target: 0.0,
        explained_variance: 0.0,
        trajectories_processed: 0,
        total_samples: 0,
        initialized: true,
    }
}

func value_network_forward(value_network net, []float observation) float {
    int hidden_size = net.hidden_size
    []float hidden = make_array(hidden_size, 0.0)
    int i = 0
    while i < hidden_size {
        float h = net.hidden_bias[i]
        int j = 0
        while j < net.seq_len {
            if j < len(observation) {
                h = h + net.hidden_weights[i][j] * observation[j]
            }
            j = j + 1
        }
        hidden[i] = tanh_approx(h)
        i = i + 1
    }
    float value = net.output_bias
    i = 0
    while i < hidden_size {
        value = value + net.output_weight[i] * hidden[i]
        i = i + 1
    }
    value
}

func value_network_forward_batch(value_network net, [][]float observations) []float {
    []float values = make_array(len(observations), 0.0)
    int i = 0
    while i < len(observations) {
        values[i] = value_network_forward(net, observations[i])
        i = i + 1
    }
    values
}

func compute_td_residual(
    float reward,
    float value_t,
    float next_value,
    float gamma,
    bool is_terminal
) float {
    float bootstrap_value = 0.0
    if !is_terminal {
        bootstrap_value = gamma * next_value
    }
    reward + bootstrap_value - value_t
}

func compute_gae_advantages(
    []value_trajectory_step steps,
    float gamma,
    float gae_lambda
) []float {
    int T = len(steps)
    []float advantages = make_array(T, 0.0)
    float gae = 0.0
    int t = T - 1
    while t >= 0 {
        float delta = 0.0
        if t < T - 1 {
            delta = compute_td_residual(
                steps[t].reward,
                steps[t].value_estimate,
                steps[t + 1].value_estimate,
                gamma,
                steps[t].is_terminal
            )
        } else {
            delta = steps[t].reward - steps[t].value_estimate
        }
        gae = delta + gamma * gae_lambda * gae
        advantages[t] = gae
        t = t - 1
    }
    advantages
}

func compute_returns(
    []value_trajectory_step steps,
    []float advantages
) []float {
    int T = len(steps)
    []float returns = make_array(T, 0.0)
    int t = 0
    while t < T {
        returns[t] = advantages[t] + steps[t].value_estimate
        t = t + 1
    }
    returns
}

func compute_value_loss(
    []float value_predictions,
    []float return_targets
) float {
    float loss = 0.0
    int n = len(value_predictions)
    int i = 0
    while i < n {
        float error = value_predictions[i] - return_targets[i]
        loss = loss + error * error
        i = i + 1
    }
    loss / (n as float)
}

func compute_regularization_loss(value_network net, float weight_decay) float {
    float loss = 0.0
    int i = 0
    while i < net.hidden_size {
        int j = 0
        while j < net.seq_len {
            loss = loss + net.hidden_weights[i][j] * net.hidden_weights[i][j]
            j = j + 1
        }
        i = i + 1
    }
    i = 0
    while i < net.hidden_size {
        loss = loss + net.output_weight[i] * net.output_weight[i]
        i = i + 1
    }
    loss * weight_decay
}

func adamw_update(
    float param,
    float grad,
    float m,
    float v,
    int step,
    float beta1,
    float beta2,
    float eps,
    float lr,
    float weight_decay
) (float, float, float) {
    float m_new = beta1 * m + (1.0 - beta1) * grad
    float v_new = beta2 * v + (1.0 - beta2) * grad * grad
    float bias_correction1 = 1.0 - pow_approx(beta1, step as float)
    float bias_correction2 = 1.0 - pow_approx(beta2, step as float)
    float m_hat = m_new / bias_correction1
    float v_hat = v_new / bias_correction2
    float sqrt_v = sqrt_approx(v_hat + eps)
    float update = lr * m_hat / sqrt_v
    if weight_decay > 0.0 {
        update = update + lr * weight_decay * param
    }
    float param_new = param - update
    (param_new, m_new, v_new)
}

func value_training_step(
    value_state state,
    []value_trajectory_step trajectory_steps,
    []float observations,
    []float target_returns
) value_state {
    value_config cfg = state.config
    value_network net = state.network
    []float value_predictions = value_network_forward_batch(net, observations)
    float value_loss = compute_value_loss(value_predictions, target_returns)
    float reg_loss = compute_regularization_loss(net, cfg.weight_decay)
    float total_loss = value_loss + reg_loss
    float grad_scale = 1.0 / (len(observations) as float)
    int i = 0
    while i < len(observations) {
        float error = value_predictions[i] - target_returns[i]
        int j = 0
        while j < cfg.seq_len {
            if j < len(observations[i]) {
                float grad = 2.0 * error * observations[i][j] * grad_scale
                int h = i % net.hidden_size
                net.hidden_weights[h][j] = net.hidden_weights[h][j] - cfg.learning_rate * grad
            }
            j = j + 1
        }
        i = i + 1
    }
    state.network = net
    state.total_loss = total_loss
    state.value_loss = value_loss
    state.regularization_loss = reg_loss
    state.global_step = state.global_step + 1
    state
}

func process_trajectory(
    value_state state,
    value_trajectory trajectory
) value_trajectory {
    value_config cfg = state.config
    []float advantages = compute_gae_advantages(
        trajectory.steps,
        cfg.gamma,
        cfg.gae_lambda
    )
    []float returns = compute_returns(trajectory.steps, advantages)
    int i = 0
    while i < len(trajectory.steps) {
        trajectory.steps[i].advantage = advantages[i]
        trajectory.steps[i].return_value = returns[i]
        i = i + 1
    }
    float sum_advantage = 0.0
    float max_adv = -999999.0
    float min_adv = 999999.0
    int i = 0
    while i < len(advantages) {
        sum_advantage = sum_advantage + advantages[i]
        if advantages[i] > max_adv {
            max_adv = advantages[i]
        }
        if advantages[i] < min_adv {
            min_adv = advantages[i]
        }
        i = i + 1
    }
    trajectory.max_advantage = max_adv
    trajectory.min_advantage = min_adv
    trajectory
}

func start_value_training(
    value_config cfg,
    []value_trajectory trajectories
) value_state {
    value_state state = new_value_state(cfg)
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Value model Training                                      ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    int epoch = 0
    while epoch < cfg.num_epochs {
        float total_epoch_loss = 0.0
        int trajectories_in_epoch = 0
        int t = 0
        while t < len(trajectories) {
            value_trajectory traj = trajectories[t]
            traj = process_trajectory(state, traj)
            [][]float observations = make_matrix(len(traj.steps), cfg.seq_len, 0.0)
            []float targets = make_array(len(traj.steps), 0.0)
            int s = 0
            while s < len(traj.steps) {
                if s < len(traj.steps) {
                    observations[s] = traj.steps[s].observation
                    targets[s] = traj.steps[s].return_value
                }
                s = s + 1
            }
            state = value_training_step(state, traj.steps, observations, targets)
            total_epoch_loss = total_epoch_loss + state.value_loss
            trajectories_in_epoch = trajectories_in_epoch + 1
            state.total_samples = state.total_samples + len(traj.steps)
            t = t + 1
        }
        state.global_epoch = epoch
        float avg_epoch_loss = total_epoch_loss / (trajectories_in_epoch as float)
        if epoch % 10 == 0 {
            print("[Epoch " + int_to_string(epoch) + "] Loss: " + float_to_string(avg_epoch_loss))
        }
        epoch = epoch + 1
    }
    print("")
    print("Training completed!")
    print("  Total epochs: " + int_to_string(state.global_epoch))
    print("  Total steps: " + int_to_string(state.global_step))
    print("  Total samples: " + int_to_string(state.total_samples))
    print("  Final loss: " + float_to_string(state.value_loss))
    print("")
    state
}

func evaluate_value_network(
    value_network net,
    [][]float test_observations,
    []float test_returns
) value_metrics {
    []float predictions = value_network_forward_batch(net, test_observations)
    float mse = 0.0
    float mae = 0.0
    float max_abs_error = 0.0
    int i = 0
    while i < len(predictions) {
        float error = predictions[i] - test_returns[i]
        mse = mse + error * error
        float abs_error = if error < 0.0 { -error } else { error }
        mae = mae + abs_error
        if abs_error > max_abs_error {
            max_abs_error = abs_error
        }
        i = i + 1
    }
    int n = len(predictions)
    mse = mse / (n as float)
    mae = mae / (n as float)
    float mean_target = 0.0
    i = 0
    while i < len(test_returns) {
        mean_target = mean_target + test_returns[i]
        i = i + 1
    }
    mean_target = mean_target / (n as float)
    float ss_tot = 0.0
    i = 0
    while i < len(test_returns) {
        float diff = test_returns[i] - mean_target
        ss_tot = ss_tot + diff * diff
        i = i + 1
    }
    float r_squared = 0.0
    if ss_tot > 0.0 {
        float ss_res = mse * (n as float)
        r_squared = 1.0 - ss_res / ss_tot
    }
    value_metrics {
        loss: mse,
        mse: mse,
        mae: mae,
        r_squared: r_squared,
        max_abs_error: max_abs_error,
        mean_prediction: 0.0,
        mean_target: mean_target,
        step: 0,
    }
}

func make_array(int n, float v) []float {
    []float arr = []float{cap: n}
    int i = 0
    while i < n {
        arr = append_float(arr, v)
        i = i + 1
    }
    arr
}

func make_matrix(int m, int n, float v) [][]float {
    [][]float mat = [][]float{cap: m}
    int i = 0
    while i < m {
        []float row = make_array(n, v)
        mat = append_matrix(mat, row)
        i = i + 1
    }
    mat
}

func append_float([]float arr, float v) []float {
    arr
}

func append_matrix([][]float mat, []float row) [][]float {
    mat
}

func tanh_approx(float x) float {
    if x > 10.0 { return 1.0 }
    if x < -10.0 { return -1.0 }
    float e2x = exp_approx(2.0 * x)
    (e2x - 1.0) / (e2x + 1.0)
}

func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 10 {
        term = term * x / (i as float)
        result = result + term
        i = i + 1
    }
    result
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 15 {
        y = 0.5 * (y + x / y)
        i = i + 1
    }
    y
}

func pow_approx(float base, float exp) float {
    if base <= 0.0 { return 1.0 }
    if exp == 0.0 { return 1.0 }
    exp_approx(exp * log_approx(base))
}

func log_approx(float x) float {
    if x <= 0.0 { return -100.0 }
    if x > 2.0 {
        float y = (x - 1.0) / (x + 1.0)
        float y2 = y * y
        float y3 = y2 * y
        float y5 = y3 * y2
        float y7 = y5 * y2
        return 2.0 * (y + y3 / 3.0 + y5 / 5.0 + y7 / 7.0)
    }
    (x - 1.0) - (x - 1.0) * (x - 1.0) / 2.0
}

func float_to_string(float f) string {
    string(int(f * 10000.0) / 10000.0)
}

func int_to_string(int i) string {
    string(i)
}

