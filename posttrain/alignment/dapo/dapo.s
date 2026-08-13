package neurx.posttrain.alignment.dapo
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}
use neurx.posttrain.rl.{rollout, reward_manager}

struct dapo_config {
    float learning_rate
    int batch_size
    int num_epochs
    int num_rollouts
    float kl_coef
    float clip_range
    float entropy_coef
    float value_loss_coef
    int max_grad_norm
    float gamma
    float gae_lambda
    bool use_advantage_normalization
    bool use_value_clipping
    float temperature
    int top_k_trajectories
    bool use_self_improvement
    int num_iterations
}

struct dapo_state {
    tensor policy_logits
    tensor value_estimates
    tensor advantages
    tensor returns
    tensor old_log_probs
    tensor action_mask
    float kl_divergence
    float policy_loss
    float value_loss
    float entropy
    float total_loss
    int iteration
}

struct dapo_rollout_result {
    []tensor states
    []tensor actions
    []tensor rewards
    []tensor log_probs
    []tensor values
    []bool dones
    float avg_reward
    float max_reward
    int num_correct
}

func new_dapo_config() dapo_config {
    dapo_config {
        learning_rate: 1e-5,
        batch_size: 8,
        num_epochs: 4,
        num_rollouts: 256,
        kl_coef: 0.1,
        clip_range: 0.2,
        entropy_coef: 0.01,
        value_loss_coef: 0.5,
        max_grad_norm: 1,
        gamma: 1.0,
        gae_lambda: 0.95,
        use_advantage_normalization: true,
        use_value_clipping: true,
        temperature: 1.0,
        top_k_trajectories: 64,
        use_self_improvement: true,
        num_iterations: 100,
    }
}

func dapo_compute_advantages(
    []tensor rewards,
    []tensor values,
    []bool dones,
    float gamma,
    float gae_lambda
) ([]tensor, []tensor) {
    int T = rewards.len
    []tensor advantages = []tensor{cap: T}
    []tensor returns = []tensor{cap: T}
    tensor gae = tensor_ops.zeros_like(values[T - 1])
    int t = T - 1
    while t >= 0 {
        tensor reward = rewards[t]
        tensor value = values[t]
        bool done = dones[t]
        tensor next_value = tensor_ops.zeros_like(value)
        if t < T - 1 {
            next_value = values[t + 1]
        }
        if done {
            next_value = tensor_ops.zeros_like(value)
        }
        tensor delta = tensor_ops.add(
            reward,
            tensor_ops.sub(
                tensor_ops.mul_scalar(next_value, gamma),
                value
            )
        )
        gae = tensor_ops.add(
            delta,
            tensor_ops.mul_scalar(gae, gamma * gae_lambda)
        )
        if done {
            gae = tensor_ops.zeros_like(gae)
        }
        advantages[t] = gae
        returns[t] = tensor_ops.add(gae, value)
        t = t - 1
    }
    (advantages, returns)
}

func dapo_select_top_k_trajectories(
    dapo_rollout_result rollouts,
    int k
) dapo_rollout_result {
    int n = rollouts.states.len
    if k >= n {
        return rollouts
    }
    []int indices = []int{cap: n}
    int i = 0
    while i < n {
        indices[i] = i
        i = i + 1
    }
    i = 0
    while i < k {
        int max_idx = i
        int j = i + 1
        while j < n {
            float reward_i = tensor_ops.sum(rollouts.rewards[indices[max_idx]])
            float reward_j = tensor_ops.sum(rollouts.rewards[indices[j]])
            if reward_j > reward_i {
                max_idx = j
            }
            j = j + 1
        }
        int temp = indices[i]
        indices[i] = indices[max_idx]
        indices[max_idx] = temp
        i = i + 1
    }
    []tensor top_states = []tensor{cap: k}
    []tensor top_actions = []tensor{cap: k}
    []tensor top_rewards = []tensor{cap: k}
    []tensor top_log_probs = []tensor{cap: k}
    []tensor top_values = []tensor{cap: k}
    []bool top_dones = []bool{cap: k}
    i = 0
    while i < k {
        int idx = indices[i]
        top_states[i] = rollouts.states[idx]
        top_actions[i] = rollouts.actions[idx]
        top_rewards[i] = rollouts.rewards[idx]
        top_log_probs[i] = rollouts.log_probs[idx]
        top_values[i] = rollouts.values[idx]
        top_dones[i] = rollouts.dones[idx]
        i = i + 1
    }
    dapo_rollout_result {
        states: top_states,
        actions: top_actions,
        rewards: top_rewards,
        log_probs: top_log_probs,
        values: top_values,
        dones: top_dones,
        avg_reward: rollouts.avg_reward,
        max_reward: rollouts.max_reward,
        num_correct: rollouts.num_correct,
    }
}

func dapo_compute_policy_loss(
    tensor log_probs,
    tensor old_log_probs,
    tensor advantages,
    float clip_range
) (tensor, float) {
    tensor ratio = tensor_ops.exp(
        tensor_ops.sub(log_probs, old_log_probs)
    )
    tensor clipped_ratio = tensor_ops.clip(
        ratio,
        1.0 - clip_range,
        1.0 + clip_range
    )
    tensor adv_exp = tensor_ops.unsqueeze(advantages, -1)
    tensor surrogate1 = tensor_ops.mul(ratio, adv_exp)
    tensor surrogate2 = tensor_ops.mul(clipped_ratio, adv_exp)
    tensor policy_loss = tensor_ops.neg(
        tensor_ops.mean(
            tensor_ops.min(surrogate1, surrogate2)
        )
    )
    float kl_div = tensor_ops.sum_scalar(
        tensor_ops.mul(
            old_log_probs,
            tensor_ops.sub(old_log_probs, log_probs)
        )
    ) / old_log_probs.shape[0]
    (policy_loss, kl_div)
}

func dapo_compute_value_loss(
    tensor values,
    tensor returns,
    tensor old_values,
    bool use_clipping,
    float clip_range
) tensor {
    if use_clipping {
        tensor values_clipped = tensor_ops.clip(
            values,
            tensor_ops.sub_scalar(old_values, clip_range),
            tensor_ops.add_scalar(old_values, clip_range)
        )
        tensor loss1 = tensor_ops.pow(
            tensor_ops.sub(values, returns),
            2.0
        )
        tensor loss2 = tensor_ops.pow(
            tensor_ops.sub(values_clipped, returns),
            2.0
        )
        return tensor_ops.mean(tensor_ops.max(loss1, loss2))
    }
    return tensor_ops.mean(
        tensor_ops.pow(tensor_ops.sub(values, returns), 2.0)
    )
}

func dapo_step(
    module policy,
    module value_model,
    dapo_rollout_result rollouts,
    dapo_config cfg
) dapo_state {
    ([]tensor advantages, []tensor returns) = dapo_compute_advantages(
        rollouts.rewards,
        rollouts.values,
        rollouts.dones,
        cfg.gamma,
        cfg.gae_lambda
    )
    if cfg.use_advantage_normalization {
        tensor all_adv = tensor_ops.concat(advantages, 0)
        float mean_adv = tensor_ops.mean_scalar(all_adv)
        float std_adv = tensor_ops.std_scalar(all_adv)
        int i = 0
        while i < advantages.len {
            advantages[i] = tensor_ops.div_scalar(
                tensor_ops.sub_scalar(advantages[i], mean_adv),
                std_adv + 1e-8
            )
            i = i + 1
        }
    }
    tensor states = tensor_ops.concat(rollouts.states, 0)
    tensor actions = tensor_ops.concat(rollouts.actions, 0)
    tensor old_log_probs = tensor_ops.concat(rollouts.log_probs, 0)
    tensor old_values = tensor_ops.concat(rollouts.values, 0)
    tensor adv_tensor = tensor_ops.concat(advantages, 0)
    tensor ret_tensor = tensor_ops.concat(returns, 0)
    tensor policy_logits = policy.forward(states)
    tensor new_log_probs = tensor_ops.log_softmax(policy_logits, -1)
    new_log_probs = tensor_ops.gather(new_log_probs, actions, -1)
    tensor new_values = value_model.forward(states)
    (tensor policy_loss, float kl_div) = dapo_compute_policy_loss(
        new_log_probs,
        old_log_probs,
        adv_tensor,
        cfg.clip_range
    )
    tensor value_loss = dapo_compute_value_loss(
        new_values,
        ret_tensor,
        old_values,
        cfg.use_value_clipping,
        cfg.clip_range
    )
    tensor probs = tensor_ops.softmax(policy_logits, -1)
    tensor log_probs_all = tensor_ops.log_softmax(policy_logits, -1)
    tensor entropy = tensor_ops.neg(
        tensor_ops.sum(
            tensor_ops.mul(probs, log_probs_all),
            -1
        )
    )
    tensor entropy_mean = tensor_ops.mean(entropy)
    tensor total_loss = tensor_ops.add(
        policy_loss,
        tensor_ops.add(
            tensor_ops.mul_scalar(value_loss, cfg.value_loss_coef),
            tensor_ops.mul_scalar(entropy_mean, -cfg.entropy_coef)
        )
    )
    dapo_state {
        policy_logits: policy_logits,
        value_estimates: new_values,
        advantages: adv_tensor,
        returns: ret_tensor,
        old_log_probs: old_log_probs,
        action_mask: tensor_ops.ones_like(actions),
        kl_divergence: kl_div,
        policy_loss: tensor_ops.item(policy_loss),
        value_loss: tensor_ops.item(value_loss),
        entropy: tensor_ops.item(entropy_mean),
        total_loss: tensor_ops.item(total_loss),
        iteration: 0,
    }
}
