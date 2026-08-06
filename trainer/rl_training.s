package neurx.trainer.rl_training
import "neurx.util.math"
enum rl_algorithm {
    PPO = 0
    VAPO = 1
    DAPO = 2
    RLAIF = 3
}
enum rl_stage {
    COLLECTING = 0
    TRAINING = 1
    EVALUATING = 2
}

struct rl_config {
    rl_algorithm algorithm
    int batch_size
    int seq_len
    int horizon
    int rollout_steps
    int num_epochs
    int num_mini_batches
    float learning_rate
    float gamma
    float gae_lambda
    float clip_epsilon
    float value_coef
    float policy_coef
    float entropy_coef
    float target_kl
    float vapo_alpha
    float vapo_beta
    bool use_advantage_scaling
    bool use_clipped_value_loss
    bool normalize_advantages
    int max_grad_norm
}

struct rollout_data {
    []float observations
    []float actions
    []float log_probs
    []float values
    []float rewards
    []float advantages
    []float returns
    []bool masks
}

struct rl_state {
    rl_config config
    rl_stage stage
    rollout_data buffer
    []float policy_params
    []float value_params
    float current_step
    float current_epoch
    float total_steps
    float total_epochs
    float avg_reward
    float avg_advantage
    float policy_loss
    float value_loss
    float entropy_loss
    float kl_divergence
}

struct rl_metrics {
    float reward_mean
    float reward_std
    float advantage_mean
    float advantage_std
    float policy_loss
    float value_loss
    float entropy_loss
    float kl_divergence
    float clip_fraction
}

func new_rl_config() rl_config {
    rl_config {
        algorithm: PPO,
        batch_size: 32,
        seq_len: 512,
        horizon: 2048,
        rollout_steps: 128,
        num_epochs: 3,
        num_mini_batches: 8,
        learning_rate: 3e-5,
        gamma: 0.99,
        gae_lambda: 0.95,
        clip_epsilon: 0.2,
        value_coef: 0.5,
        policy_coef: 1.0,
        entropy_coef: 0.01,
        target_kl: 0.01,
        vapo_alpha: 0.1,
        vapo_beta: 0.9,
        use_advantage_scaling: true,
        use_clipped_value_loss: true,
        normalize_advantages: true,
        max_grad_norm: 1.0,
    }
}

func new_rollout_data(int horizon, int obs_dim, int action_dim) rollout_data {
    rollout_data {
        observations: math.allocate_float(horizon * obs_dim, 0.0),
        actions: math.allocate_float(horizon * action_dim, 0.0),
        log_probs: math.allocate_float(horizon, 0.0),
        values: math.allocate_float(horizon, 0.0),
        rewards: math.allocate_float(horizon, 0.0),
        advantages: math.allocate_float(horizon, 0.0),
        returns: math.allocate_float(horizon, 0.0),
        masks: math.allocate_bool(horizon, true),
    }
}

func new_rl_state(rl_config config) rl_state {
    rl_state {
        config: config,
        stage: COLLECTING,
        buffer: new_rollout_data(config.horizon, config.seq_len, config.seq_len),
        policy_params: math.allocate_float(0, 0.0),
        value_params: math.allocate_float(0, 0.0),
        current_step: 0.0,
        current_epoch: 0.0,
        total_steps: 0.0,
        total_epochs: 0.0,
        avg_reward: 0.0,
        avg_advantage: 0.0,
        policy_loss: 0.0,
        value_loss: 0.0,
        entropy_loss: 0.0,
        kl_divergence: 0.0,
    }
}

func collect_rollout(rl_state state, []float model_output, []float rewards, int steps) rl_state {
    int obs_dim = state.config.seq_len
    int action_dim = state.config.seq_len
    int start_idx = int(state.current_step)
    int i = 0
    while i < steps {
        int idx = start_idx + i
        if idx < state.config.horizon {
            int j = 0
            while j < obs_dim {
                state.buffer.observations[idx * obs_dim + j] = model_output[i * obs_dim + j]
                state.buffer.actions[idx * action_dim + j] = model_output[i * obs_dim + j]
                j = j + 1
            }
            state.buffer.rewards[idx] = rewards[i]
            state.buffer.masks[idx] = true
            state.buffer.log_probs[idx] = compute_log_prob(model_output[i * obs_dim..(i+1) * obs_dim], action_dim)
            state.buffer.values[idx] = compute_value_estimate(model_output[i * obs_dim..(i+1) * obs_dim])
        }
        i = i + 1
    }
    state.current_step = float(start_idx + steps)
    if state.current_step >= float(state.config.horizon) {
        state.stage = TRAINING
        state.buffer = compute_advantages(state.buffer, state.config)
    }
    state
}

func compute_log_prob([]float logits, int dim) float {
    []float probs = math.softmax_1d(logits)
    float log_prob = 0.0
    int i = 0
    while i < dim {
        if probs[i] > 0.0 {
            log_prob = log_prob + probs[i] * math.log_approx(probs[i])
        }
        i = i + 1
    }
    -log_prob
}

func compute_value_estimate([]float hidden_states) float {
    float value = 0.0
    int n = len(hidden_states)
    int i = 0
    while i < n {
        value = value + hidden_states[i]
        i = i + 1
    }
    value / float(n)
}

func compute_advantages(rollout_data buffer, rl_config config) rollout_data {
    int horizon = config.horizon
    float gamma = config.gamma
    float lambda = config.gae_lambda
    float running_advantage = 0.0
    float running_return = 0.0
    int i = horizon - 1
    while i >= 0 {
        float mask = 1.0
        if !buffer.masks[i] {
            mask = 0.0
        }
        float delta = buffer.rewards[i] + gamma * running_return * mask - buffer.values[i]
        running_advantage = delta + gamma * lambda * running_advantage * mask
        running_return = buffer.values[i] + running_advantage
        buffer.advantages[i] = running_advantage
        buffer.returns[i] = running_return
        i = i - 1
    }
    if config.normalize_advantages {
        float mean = math.mean_float(buffer.advantages)
        float var = math.compute_variance(buffer.advantages, horizon)
        float std = math.sqrt_approx(var)
        if std > 1e-8 {
            i = 0
            while i < horizon {
                buffer.advantages[i] = (buffer.advantages[i] - mean) / std
                i = i + 1
            }
        }
    }
    buffer
}

func ppo_update(rl_state state) rl_state {
    rl_config config = state.config
    rollout_data buffer = state.buffer
    int horizon = config.horizon
    int mini_batch_size = horizon / config.num_mini_batches
    float total_policy_loss = 0.0
    float total_value_loss = 0.0
    float total_entropy_loss = 0.0
    int clip_count = 0
    int epoch = 0
    while epoch < config.num_epochs {
        int mb_idx = 0
        while mb_idx < config.num_mini_batches {
            int start = mb_idx * mini_batch_size
            int end = start + mini_batch_size
            []float old_log_probs = buffer.log_probs[start..end]
            []float old_values = buffer.values[start..end]
            []float advantages = buffer.advantages[start..end]
            []float returns = buffer.returns[start..end]
            []float new_log_probs = math.allocate_float(end - start, 0.0)
            []float new_values = math.allocate_float(end - start, 0.0)
            int i = 0
            while i < end - start {
                int global_idx = start + i
                []float obs_slice = buffer.observations[global_idx * config.seq_len..(global_idx+1) * config.seq_len]
                new_log_probs[i] = compute_log_prob(obs_slice, config.seq_len)
                new_values[i] = compute_value_estimate(obs_slice)
                i = i + 1
            }
            float policy_loss = 0.0
            float value_loss = 0.0
            float entropy_loss = 0.0
            i = 0
            while i < end - start {
                float ratio = math.exp_approx(new_log_probs[i] - old_log_probs[i])
                float clipped_ratio = math.clamp_float(ratio, 1.0 - config.clip_epsilon, 1.0 + config.clip_epsilon)
                float surr1 = ratio * advantages[i]
                float surr2 = clipped_ratio * advantages[i]
                policy_loss = policy_loss - math.min_float(surr1, surr2)
                if config.use_clipped_value_loss {
                    float clipped_value = old_values[i] + math.clamp_float(new_values[i] - old_values[i], -config.clip_epsilon, config.clip_epsilon)
                    float v_loss1 = (new_values[i] - returns[i]) * (new_values[i] - returns[i])
                    float v_loss2 = (clipped_value - returns[i]) * (clipped_value - returns[i])
                    value_loss = value_loss + math.max_float(v_loss1, v_loss2)
                } else {
                    value_loss = value_loss + (new_values[i] - returns[i]) * (new_values[i] - returns[i])
                }
                if ratio < 1.0 - config.clip_epsilon || ratio > 1.0 + config.clip_epsilon {
                    clip_count = clip_count + 1
                }
                i = i + 1
            }
            policy_loss = policy_loss / float(end - start)
            value_loss = value_loss / float(end - start)
            []float log_probs = new_log_probs
            float ent = 0.0
            i = 0
            while i < end - start {
                float prob = math.exp_approx(log_probs[i])
                if prob > 0.0 {
                    ent = ent - prob * math.log_approx(prob)
                }
                i = i + 1
            }
            entropy_loss = ent / float(end - start)
            total_policy_loss = total_policy_loss + policy_loss
            total_value_loss = total_value_loss + value_loss
            total_entropy_loss = total_entropy_loss + entropy_loss
            mb_idx = mb_idx + 1
        }
        epoch = epoch + 1
    }
    int total_samples = config.num_epochs * config.num_mini_batches * mini_batch_size
    state.policy_loss = total_policy_loss / float(config.num_epochs * config.num_mini_batches)
    state.value_loss = total_value_loss / float(config.num_epochs * config.num_mini_batches) * config.value_coef
    state.entropy_loss = total_entropy_loss / float(config.num_epochs * config.num_mini_batches) * config.entropy_coef
    state.avg_reward = math.mean_float(buffer.rewards)
    state.avg_advantage = math.mean_float(buffer.advantages)
    state.current_step = 0.0
    state.current_epoch = state.current_epoch + 1.0
    state.total_epochs = state.total_epochs + 1.0
    state.stage = COLLECTING
    state
}

func vapo_update(rl_state state) rl_state {
    rl_config config = state.config
    rollout_data buffer = state.buffer
    int horizon = config.horizon
    float alpha = config.vapo_alpha
    float beta = config.vapo_beta
    float value_advantage = 0.0
    int i = 0
    while i < horizon {
        value_advantage = value_advantage + buffer.returns[i] - buffer.values[i]
        i = i + 1
    }
    value_advantage = value_advantage / float(horizon)
    float adjusted_advantage = beta * buffer.avg_advantage + alpha * value_advantage
    []float vapo_advantages = math.copy_float(buffer.advantages)
    i = 0
    while i < horizon {
        vapo_advantages[i] = buffer.advantages[i] + adjusted_advantage
        i = i + 1
    }
    buffer.advantages = vapo_advantages
    state.buffer = buffer
    ppo_update(state)
}

func dapo_update(rl_state state) rl_state {
    rl_config config = state.config
    rollout_data buffer = state.buffer
    int horizon = config.horizon
    []float distributed_advantages = math.allocate_float(horizon, 0.0)
    int num_workers = 4
    int chunk_size = horizon / num_workers
    int worker = 0
    while worker < num_workers {
        int start = worker * chunk_size
        int end = start + chunk_size
        float local_mean = math.mean_float(buffer.advantages[start..end])
        int i = start
        while i < end {
            distributed_advantages[i] = buffer.advantages[i] - local_mean
            i = i + 1
        }
        worker = worker + 1
    }
    float global_mean = math.mean_float(distributed_advantages)
    i = 0
    while i < horizon {
        distributed_advantages[i] = distributed_advantages[i] + global_mean
        i = i + 1
    }
    buffer.advantages = distributed_advantages
    state.buffer = buffer
    ppo_update(state)
}

func rlaif_collect_feedback(rl_state state, []float responses, []float reference_responses) ([]float, []float) {
    int num_responses = len(responses) / state.config.seq_len
    []float rewards = math.allocate_float(num_responses, 0.0)
    []float preferences = math.allocate_float(num_responses, 0.0)
    int i = 0
    while i < num_responses {
        []float response = responses[i * state.config.seq_len..(i+1) * state.config.seq_len]
        []float reference = reference_responses[i * state.config.seq_len..(i+1) * state.config.seq_len]
        float similarity = compute_cosine_similarity(response, reference, state.config.seq_len)
        float quality = compute_response_quality(response, state.config.seq_len)
        rewards[i] = 0.7 * similarity + 0.3 * quality
        if rewards[i] > 0.5 {
            preferences[i] = 1.0
        } else {
            preferences[i] = 0.0
        }
        i = i + 1
    }
    (rewards, preferences)
}

func compute_cosine_similarity([]float a, []float b, int dim) float {
    float dot = 0.0
    float norm_a = 0.0
    float norm_b = 0.0
    int i = 0
    while i < dim {
        dot = dot + a[i] * b[i]
        norm_a = norm_a + a[i] * a[i]
        norm_b = norm_b + b[i] * b[i]
        i = i + 1
    }
    norm_a = math.sqrt_approx(norm_a)
    norm_b = math.sqrt_approx(norm_b)
    if norm_a == 0.0 || norm_b == 0.0 {
        return 0.0
    }
    dot / (norm_a * norm_b)
}

func compute_response_quality([]float response, int dim) float {
    float quality = 0.0
    int count = 0
    int i = 0
    while i < dim {
        if response[i] > 0.1 {
            quality = quality + response[i]
            count = count + 1
        }
        i = i + 1
    }
    if count == 0 {
        return 0.0
    }
    quality / float(count)
}

func rl_train_step(rl_state state, []float model_output, []float rewards) rl_state {
    if state.stage == COLLECTING {
        state = collect_rollout(state, model_output, rewards, state.config.rollout_steps)
    }
    if state.stage == TRAINING {
        switch state.config.algorithm {
            case PPO:
                state = ppo_update(state)
            case VAPO:
                state = vapo_update(state)
            case DAPO:
                state = dapo_update(state)
            case RLAIF:
                []float feedback_rewards = rewards
                []float preferences = math.allocate_float(0, 0.0)
                (feedback_rewards, preferences) = rlaif_collect_feedback(state, model_output, model_output)
                state.buffer.rewards = feedback_rewards
                state = ppo_update(state)
        }
    }
    state.total_steps = state.total_steps + float(state.config.rollout_steps)
    state
}

func rl_get_metrics(rl_state state) rl_metrics {
    rl_metrics {
        reward_mean: state.avg_reward,
        reward_std: math.sqrt_approx(math.compute_variance(state.buffer.rewards, len(state.buffer.rewards))),
        advantage_mean: state.avg_advantage,
        advantage_std: math.sqrt_approx(math.compute_variance(state.buffer.advantages, len(state.buffer.advantages))),
        policy_loss: state.policy_loss,
        value_loss: state.value_loss,
        entropy_loss: state.entropy_loss,
        kl_divergence: state.kl_divergence,
        clip_fraction: 0.0,
    }
}

func rl_reset(rl_state state) rl_state {
    state.current_step = 0.0
    state.current_epoch = 0.0
    state.total_steps = 0.0
    state.total_epochs = 0.0
    state.avg_reward = 0.0
    state.avg_advantage = 0.0
    state.policy_loss = 0.0
    state.value_loss = 0.0
    state.entropy_loss = 0.0
    state.kl_divergence = 0.0
    state.stage = COLLECTING
    state.buffer = new_rollout_data(state.config.horizon, state.config.seq_len, state.config.seq_len)
    state
}

