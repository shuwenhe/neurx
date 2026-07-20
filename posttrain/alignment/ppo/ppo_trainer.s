package neurx.posttrain.rlhf.ppo_trainer

// ════════════════════════════════════════════════════════════════════════════════
// PPO Trainer - Proximal Policy Optimization (English textoptimize)
//
// English textoptimize, useEnglish text:
//   1. English text (trajectory Collection)
//   2. English text (Advantage Estimation)
//   3. PPO losscompute (PPO Loss Computation)
//   4. English text (Policy Update)
//   5. English text (Value Network Update)
//
// English text:
//   - RLHF alignmenttraining
//   - rewardoptimize
//   - English text
// ════════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════════
// 1. dataEnglish text
// ════════════════════════════════════════════════════════════════════════════════

// English textstep
struct ppo_step {
    int step_id
    []float tokens              // English textinput
    []float logits              // modeloutput logits
    float log_prob_old          // English text log English text
    float log_prob_new          // English text log English text
    float value_estimate        // English text
    float reward                // English textreward (English text reward model)
    float advantage             // English text A_t = r_t + γV(s_{t+1}) - V(s_t)
    float return_value          // English text G_t
    bool is_terminal            // English text
}

// English text (English textcompleteEnglish text)
struct ppo_trajectory {
    []ppo_step steps
    int trajectory_id
    int total_reward            // English textreward
    int episode_length          // English text
    float policy_loss           // English textloss
    float value_loss            // English textloss
    float entropy               // English text
}

// PPO configuration
struct ppo_config {
    // modelparameter
    int vocab_size
    int hidden_size
    int seq_len
    int num_layers

    // trainingparameter
    float learning_rate
    float learning_rate_policy
    float learning_rate_value

    // PPO English textparameter
    float clip_epsilon          // PPO English text (0.2 English text)
    float entropy_coef          // English text (0.01)
    float value_coef            // English textlossEnglish text (0.5)
    float gamma                 // English text (0.99)
    float gae_lambda            // GAE λ parameter (0.95)

    // KL English text
    float target_kl             // English text KL English text (0.015)
    float kl_coef               // KL English text

    // trainingpipeline
    int horizon                 // English textstepEnglish text (2048)
    int mini_batch_size         // English text (256)
    int num_epochs              // PPO English text (4)
    int num_mini_batches        // English textcount

    // English texttraining
    int global_rank
    int world_size
    int dp_degree               // dataEnglish text
    bool use_mixed_precision    // English texttraining

    // checkpointEnglish textevaluation
    int checkpoint_interval
    int eval_interval
}

// PPO state (English texttrainingstate)
struct ppo_state {
    ppo_config config

    // parameterEnglish text
    []float policy_params
    []float policy_grads
    []float value_params
    []float value_grads

    // trainingstate
    int current_step
    int current_epoch
    int total_steps
    int total_trajectories

    // English text
    float avg_policy_loss
    float avg_value_loss
    float avg_entropy
    float avg_kl_divergence
    float avg_reward
    float avg_advantage_magnitude
    float clip_fraction

    // English textstep
    int global_rank
    int world_size
    []float global_avg_loss
}

// PPO trainingstepEnglish textresult
struct ppo_training_result {
    float policy_loss
    float value_loss
    float entropy_loss
    float total_loss
    float kl_divergence
    float clip_fraction
    float explained_variance
    float ratio_mean
    float advantage_mean
}

// ════════════════════════════════════════════════════════════════════════════════
// 2. English text
// ════════════════════════════════════════════════════════════════════════════════

// English textgenerateEnglish text
func collect_trajectory(
    string prompt,
    ppo_config config
) ppo_trajectory {

    ppo_trajectory traj
    traj.steps = []ppo_step{}
    traj.trajectory_id = 0
    traj.total_reward = 0
    traj.episode_length = 0

    // generateEnglish textstepEnglish text
    int prompt_len = len(prompt)
    int t = 0
    while t < config.horizon {
        ppo_step step
        step.step_id = t

        // English text token English text, English texttruthful tokenizer output
        step.tokens = []float{cap: 4}
        step.tokens[0] = float(prompt_len)
        step.tokens[1] = float(t)
        step.tokens[2] = float(config.seq_len)
        step.tokens[3] = float(config.hidden_size)

        // English text logits, English texttruthfulEnglish textoutput
        step.logits = []float{cap: 4}
        step.logits[0] = 0.10 + float(t) * 0.01
        step.logits[1] = 0.20 + float(prompt_len) * 0.001
        step.logits[2] = 0.30 + float(config.num_layers) * 0.001
        step.logits[3] = 0.40 + float(mod_int(config.vocab_size, 10)) * 0.01

        // compute log prob
        step.log_prob_old = compute_log_prob(step.logits)

        // English text (English text)
        step.value_estimate = compute_value_estimate(step.tokens, config)

        // English textreward (English text reward model English text)
        step.reward = float(mod_int(prompt_len + t, 5) + 1)

        // English textstepEnglish text
        traj.steps = append_ppo_step(traj.steps, step)
        traj.total_reward = traj.total_reward + int(step.reward)

        t = t + 1
    }

    traj.episode_length = t

    // computeEnglish text (GAE)
    traj = compute_gae_advantages(traj, config)

    traj
}

// computeEnglish text (Generalized Advantage Estimation)
func compute_gae_advantages(ppo_trajectory traj, ppo_config config) ppo_trajectory {

    int T = len(traj.steps)
    if T == 0 {
        return traj
    }

    // initializeEnglish text
    []float advantages = make_float_array(T, 0.0)
    []float returns = make_float_array(T, 0.0)

    float gae = 0.0  // GAE English text

    // English textcompute
    int t = T - 1
    while t >= 0 {
        float next_value = 0.0
        if t < T - 1 {
            next_value = traj.steps[t + 1].value_estimate
        }

        float reward = traj.steps[t].reward
        float value = traj.steps[t].value_estimate

        // TD English text
        float delta = reward + config.gamma * next_value - value

        // GAE English text
        gae = delta + config.gamma * config.gae_lambda * gae

        advantages[t] = gae
        returns[t] = gae + value

        // English text step English text
        traj.steps[t].advantage = gae
        traj.steps[t].return_value = returns[t]

        t = t - 1
    }

    // English text (English text)
    float mean_advantage = 0.0
    int i = 0
    while i < len(advantages) {
        mean_advantage = mean_advantage + advantages[i]
        i = i + 1
    }
    mean_advantage = mean_advantage / float(T)

    float std_advantage = 0.0
    i = 0
    while i < len(advantages) {
        float diff = advantages[i] - mean_advantage
        std_advantage = std_advantage + diff * diff
        i = i + 1
    }
    std_advantage = sqrt_approx(std_advantage / float(T))

    if std_advantage > 0.0001 {
        i = 0
        while i < len(advantages) {
            traj.steps[i].advantage = (traj.steps[i].advantage - mean_advantage) / std_advantage
            i = i + 1
        }
    }

    traj
}

// ════════════════════════════════════════════════════════════════════════════════
// 3. PPO losscompute
// ════════════════════════════════════════════════════════════════════════════════

// computeEnglish textloss (PPO English textfunction)
func compute_ppo_policy_loss(
    float log_prob_old,
    float log_prob_new,
    float advantage,
    float clip_epsilon
) float {

    // English text
    float ratio = exp_approx(log_prob_new - log_prob_old)

    // English text
    float clipped_ratio = clamp_float(ratio, 1.0 - clip_epsilon, 1.0 + clip_epsilon)

    // PPO loss = -min(ratio * A, clip(ratio, 1±ε) * A)
    float surr1 = ratio * advantage
    float surr2 = clipped_ratio * advantage

    float policy_loss = 0.0
    if surr1 < surr2 {
        policy_loss = surr1
    } else {
        policy_loss = surr2
    }

    // English text (English text)
    0.0 - policy_loss
}

// computeEnglish textloss
func compute_ppo_value_loss(
    float value_pred,
    float return_value
) float {

    float diff = value_pred - return_value
    0.5 * diff * diff
}

// computeEnglish text (English text)
func compute_entropy([]float logits) float {

    if len(logits) == 0 {
        return 0.0
    }

    []float probs = softmax_approx(logits)
    float entropy = 0.0

    int i = 0
    while i < len(probs) {
        if probs[i] > 0.00001 {
            entropy = entropy - probs[i] * log_approx(probs[i])
        }
        i = i + 1
    }

    entropy
}

// compute KL English text
func compute_kl_divergence(
    float log_prob_old,
    float log_prob_new
) float {

    // KL(old || new) = E[log(old) - log(new)]
    log_prob_old - log_prob_new
}

// ════════════════════════════════════════════════════════════════════════════════
// 4. PPO trainingstepEnglish text
// ════════════════════════════════════════════════════════════════════════════════

// English text PPO trainingstepEnglish text
func ppo_training_step(
    ppo_trajectory trajectory,
    ppo_state state
) ppo_training_result {

    ppo_training_result result
    result.policy_loss = 0.0
    result.value_loss = 0.0
    result.entropy_loss = 0.0
    result.total_loss = 0.0
    result.kl_divergence = 0.0
    result.clip_fraction = 0.0
    result.ratio_mean = 1.0
    result.advantage_mean = 0.0

    int clipped_count = 0
    float total_ratio = 0.0
    float total_advantage = 0.0

    // English textstepEnglish text
    int i = 0
    while i < len(trajectory.steps) {
        ppo_step step = trajectory.steps[i]

        // English textcomputeEnglish text log prob (English text)
        float log_prob_new = compute_log_prob(step.logits)

        // English textcomputeEnglish text
        float value_pred = compute_value_estimate(step.tokens, state.config)

        // English textloss
        float policy_loss = compute_ppo_policy_loss(
            step.log_prob_old,
            log_prob_new,
            step.advantage,
            state.config.clip_epsilon
        )
        result.policy_loss = result.policy_loss + policy_loss

        // English textloss
        float value_loss = compute_ppo_value_loss(
            value_pred,
            step.return_value
        )
        result.value_loss = result.value_loss + value_loss

        // English text
        float entropy = compute_entropy(step.logits)
        result.entropy_loss = result.entropy_loss + entropy

        // KL English text
        float kl_div = compute_kl_divergence(
            step.log_prob_old,
            log_prob_new
        )
        result.kl_divergence = result.kl_divergence + kl_div

        // English text
        float ratio = exp_approx(log_prob_new - step.log_prob_old)
        total_ratio = total_ratio + ratio
        total_advantage = total_advantage + step.advantage

        if ratio > 1.0 + state.config.clip_epsilon || ratio < 1.0 - state.config.clip_epsilon {
            clipped_count = clipped_count + 1
        }

        i = i + 1
    }

    int num_steps = len(trajectory.steps)
    if num_steps == 0 {
        return result
    }

    // English textloss
    result.policy_loss = result.policy_loss / float(num_steps)
    result.value_loss = result.value_loss / float(num_steps)
    result.entropy_loss = 0.0 - result.entropy_loss / float(num_steps)
    result.kl_divergence = result.kl_divergence / float(num_steps)
    result.clip_fraction = float(clipped_count) / float(num_steps)
    result.ratio_mean = total_ratio / float(num_steps)
    result.advantage_mean = total_advantage / float(num_steps)

    // English textloss = English textloss + valueEnglish text*English textloss + KLEnglish text*KL
    result.total_loss = result.policy_loss +
                       state.config.value_coef * result.value_loss +
                       state.config.kl_coef * result.kl_divergence -
                       state.config.entropy_coef * result.entropy_loss

    // compute explained variance
    result.explained_variance = compute_explained_variance(trajectory)

    result
}

// computeEnglish text (explained variance)
func compute_explained_variance(ppo_trajectory traj) float {

    if len(traj.steps) == 0 {
        return 0.0
    }

    // computeEnglish text
    float mean_return = 0.0
    int i = 0
    while i < len(traj.steps) {
        mean_return = mean_return + traj.steps[i].return_value
        i = i + 1
    }
    mean_return = mean_return / float(len(traj.steps))

    float var_return = 0.0
    i = 0
    while i < len(traj.steps) {
        float diff = traj.steps[i].return_value - mean_return
        var_return = var_return + diff * diff
        i = i + 1
    }
    var_return = var_return / float(len(traj.steps))

    // computeEnglish text
    float mean_resid = 0.0
    i = 0
    while i < len(traj.steps) {
        float resid = traj.steps[i].return_value - traj.steps[i].value_estimate
        mean_resid = mean_resid + resid
        i = i + 1
    }
    mean_resid = mean_resid / float(len(traj.steps))

    float var_resid = 0.0
    i = 0
    while i < len(traj.steps) {
        float resid = traj.steps[i].return_value - traj.steps[i].value_estimate
        float diff = resid - mean_resid
        var_resid = var_resid + diff * diff
        i = i + 1
    }
    var_resid = var_resid / float(len(traj.steps))

    if var_return < 0.00001 {
        return 0.0
    }

    1.0 - (var_resid / var_return)
}

// ════════════════════════════════════════════════════════════════════════════════
// 5. complete PPO trainingEnglish text
// ════════════════════════════════════════════════════════════════════════════════

// initialize PPO state
func init_ppo_state(ppo_config config) ppo_state {

    ppo_state state
    state.config = config
    state.policy_params = []float{}
    state.policy_grads = []float{}
    state.value_params = []float{}
    state.value_grads = []float{}

    state.current_step = 0
    state.current_epoch = 0
    state.total_steps = 0
    state.total_trajectories = 0

    state.avg_policy_loss = 0.0
    state.avg_value_loss = 0.0
    state.avg_entropy = 0.0
    state.avg_kl_divergence = 0.0
    state.avg_reward = 0.0
    state.avg_advantage_magnitude = 0.0
    state.clip_fraction = 0.0

    state.global_rank = config.global_rank
    state.world_size = config.world_size
    state.global_avg_loss = []float{}

    state
}

// start PPO training
func start_ppo_training(
    ppo_config config,
    int num_training_steps
) ppo_state {

    ppo_state state = init_ppo_state(config)

    // English texttrainingEnglish text
    if config.world_size > 1 {
        int expected_dp = config.world_size
        if config.dp_degree != expected_dp && config.dp_degree != 1 {
            // English textconfigurationEnglish text
        }
    }

    // maintrainingEnglish text
    int step = 0
    while step < num_training_steps {

        // 1. English text
        ppo_trajectory trajectory = collect_trajectory(
            "sample prompt",
            config
        )
        state.total_trajectories = state.total_trajectories + 1

        // 2. English text PPO English text
        int epoch = 0
        while epoch < config.num_epochs {

            ppo_training_result result = ppo_training_step(trajectory, state)

            // English text
            state.avg_policy_loss = 0.9 * state.avg_policy_loss + 0.1 * result.policy_loss
            state.avg_value_loss = 0.9 * state.avg_value_loss + 0.1 * result.value_loss
            state.avg_entropy = 0.9 * state.avg_entropy + 0.1 * result.entropy_loss
            state.avg_kl_divergence = 0.9 * state.avg_kl_divergence + 0.1 * result.kl_divergence
            state.avg_reward = 0.9 * state.avg_reward + 0.1 * float(trajectory.total_reward)
            state.avg_advantage_magnitude = 0.9 * state.avg_advantage_magnitude +
                                           0.1 * abs_float(result.advantage_mean)
            state.clip_fraction = 0.9 * state.clip_fraction + 0.1 * result.clip_fraction
            state.current_epoch = epoch

            // English text KL English text (English text)
            if result.kl_divergence > config.target_kl {
                break
            }

            epoch = epoch + 1
        }

        // 3. evaluationEnglish textcheckpoint
        if step > 0 && step % config.checkpoint_interval == 0 {
            // savecheckpoint
            print_ppo_checkpoint(state, step)
        }

        if step > 0 && step % config.eval_interval == 0 {
            // evaluationEnglish text
            print_ppo_evaluation(state, step)
        }

        state.current_step = step
        state.total_steps = state.total_steps + 1

        step = step + 1
    }

    state
}

// ════════════════════════════════════════════════════════════════════════════════
// 6. English text
// ════════════════════════════════════════════════════════════════════════════════

// English textcheckpointinformation
func print_ppo_checkpoint(ppo_state state, int step) {
    print("═══════════════════════════════════════════════════════════")
    print("PPO checkpoint - Step " + int_to_string_ppo(step))
    print("═══════════════════════════════════════════════════════════")
    print("Total Trajectories: " + int_to_string_ppo(state.total_trajectories))
    print("Policy Loss:        " + float_to_string_ppo(state.avg_policy_loss))
    print("Value Loss:         " + float_to_string_ppo(state.avg_value_loss))
    print("Entropy:            " + float_to_string_ppo(state.avg_entropy))
    print("KL Divergence:      " + float_to_string_ppo(state.avg_kl_divergence))
    print("Clip Fraction:      " + float_to_string_ppo(state.clip_fraction))
}

// English textevaluationinformation
func print_ppo_evaluation(ppo_state state, int step) {
    print("")
    print("─────────────────────────────────────────────────────────")
    print("PPO Evaluation - Step " + int_to_string_ppo(step))
    print("─────────────────────────────────────────────────────────")
    print("Rank:               " + int_to_string_ppo(state.global_rank) + "/" +
                                   int_to_string_ppo(state.world_size))
    print("Advantage Mag:      " + float_to_string_ppo(state.avg_advantage_magnitude))
}

// ════════════════════════════════════════════════════════════════════════════════
// 7. toolfunction
// ════════════════════════════════════════════════════════════════════════════════

func make_float_array(int size, float init_value) []float {
    []float arr = []float{cap: size}
    int i = 0
    while i < size {
        arr[i] = init_value
        i = i + 1
    }
    arr
}

func append_ppo_step([]ppo_step arr, ppo_step s) []ppo_step {
    arr = append(arr, s)
    arr
}

func compute_log_prob([]float logits) float {
    if len(logits) == 0 {
        return 0.0
    }

    float log_prob = 0.0
    int i = 0
    while i < len(logits) {
        log_prob = log_prob + logits[i]
        i = i + 1
    }
    log_prob / float(len(logits))
}

func compute_value_estimate([]float tokens, ppo_config config) float {
    if len(tokens) == 0 {
        return 0.0
    }

    float value = 0.0
    int i = 0
    while i < len(tokens) {
        value = value + tokens[i]
        i = i + 1
    }
    value / float(len(tokens))
}

func exp_approx(float x) float {
    // English text: e^x ≈ 1 + x + x^2/2 + x^3/6 + ...
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    1.0 + x + (x2 / 2.0) + (x3 / 6.0) + (x4 / 24.0)
}

func log_approx(float x) float {
    // English text log English text
    if x <= 0.0 { return 0.0 }
    if x > 2.0 { return 1.0 + log_approx(x / 2.0) }

    // log(1+u) ≈ u - u^2/2 + u^3/3 where u = x - 1
    float u = x - 1.0
    u - (u * u / 2.0) + (u * u * u / 3.0)
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }

    float guess = x / 2.0
    int i = 0
    while i < 5 {
        guess = (guess + x / guess) / 2.0
        i = i + 1
    }
    guess
}

func clamp_float(float value, float low, float high) float {
    if value < low { return low }
    if value > high { return high }
    value
}

func abs_float(float x) float {
    if x < 0.0 { return 0.0 - x }
    x
}

func softmax_approx([]float logits) []float {
    int n = len(logits)
    []float probs = []float{cap: n}
    if n == 0 {
        return probs
    }

    float max_logit = logits[0]
    int i = 0
    while i < n {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }

    float total = 0.0
    i = 0
    while i < n {
        probs[i] = exp_approx(logits[i] - max_logit)
        total = total + probs[i]
        i = i + 1
    }

    if total <= 0.0 {
        float inv_n = 1.0 / float(n)
        i = 0
        while i < n {
            probs[i] = inv_n
            i = i + 1
        }
        return probs
    }

    i = 0
    while i < n {
        probs[i] = probs[i] / total
        i = i + 1
    }

    probs
}

func float_to_string_ppo(float f) string {
    int i_part = int(f)
    int f_part = int((f - float(i_part)) * 10000.0)
    string(i_part) + "." + string(f_part)
}

func int_to_string_ppo(int i) string {
    string(i)
}

func mod_int(int a, int b) int {
    if b <= 0 {
        return 0
    }
    int value = a
    while value < 0 {
        value = value + b
    }
    while value >= b {
        value = value - b
    }
    value
}
