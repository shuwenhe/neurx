package neurx.posttrain.alignment.prime
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}

struct prime_config {
    float learning_rate
    int batch_size
    int num_epochs
    float kl_coef
    float entropy_coef
    float value_loss_coef
    int max_grad_norm
    float gamma
    bool use_process_supervision
    int num_intermediate_rewards
    float intermediate_reward_weight
}

struct prime_state {
    tensor policy_logits
    tensor value_estimates
    tensor step_rewards
    tensor cumulative_rewards
    tensor advantages
    float kl_divergence
    float policy_loss
    float value_loss
    float entropy
    float total_loss
}

struct process_reward_model {
    module backbone
    []module step_heads
    int num_steps
}

func new_prime_config() prime_config {
    prime_config {
        learning_rate: 1e-5,
        batch_size: 16,
        num_epochs: 4,
        kl_coef: 0.1,
        entropy_coef: 0.01,
        value_loss_coef: 0.5,
        max_grad_norm: 1,
        gamma: 0.99,
        use_process_supervision: true,
        num_intermediate_rewards: 8,
        intermediate_reward_weight: 0.5,
    }
}

func prime_compute_process_rewards(
    process_reward_model rm,
    []tensor states,
    []tensor actions
) []tensor {
    []tensor step_rewards = make([]tensor, states.len)
    int i = 0
    for i < states.len {
        int step_idx = i % rm.num_steps
        tensor embeddings = rm.backbone.forward(states[i])
        tensor reward = rm.step_heads[step_idx].forward(embeddings)
        step_rewards[i] = reward
        i = i + 1
    }
    step_rewards
}

func prime_compute_cumulative_rewards(
    []tensor step_rewards,
    float gamma,
    float intermediate_weight
) []tensor {
    int n = step_rewards.len
    []tensor cumulative = make([]tensor, n)
    tensor running_reward = tensor_ops.zeros_like(step_rewards[n - 1])
    int i = n - 1
    for i >= 0 {
        running_reward = tensor_ops.add(
            tensor_ops.mul_scalar(step_rewards[i], intermediate_weight),
            tensor_ops.mul_scalar(running_reward, gamma)
        )
        cumulative[i] = running_reward
        i = i - 1
    }
    cumulative
}

func prime_step(
    module policy,
    module value_model,
    process_reward_model reward_model,
    []tensor states,
    []tensor actions,
    []tensor old_log_probs,
    []tensor old_values,
    bool[] dones,
    prime_config cfg
) prime_state {
    []tensor step_rewards = []tensor{}
    if cfg.use_process_supervision {
        step_rewards = prime_compute_process_rewards(
            reward_model,
            states,
            actions
        )
    } else {
        int i = 0
        for i < states.len {
            step_rewards[i] = tensor_ops.zeros([1])
            i = i + 1
        }
    }
    []tensor cumulative_rewards = prime_compute_cumulative_rewards(
        step_rewards,
        cfg.gamma,
        cfg.intermediate_reward_weight
    )
    []tensor advantages = make([]tensor, states.len)
    []tensor returns = make([]tensor, states.len)
    tensor gae = tensor_ops.zeros_like(old_values[states.len - 1])
    int t = states.len - 1
    for t >= 0 {
        tensor reward = cumulative_rewards[t]
        tensor value = old_values[t]
        bool done = dones[t]
        tensor next_value = tensor_ops.zeros_like(value)
        if t < states.len - 1 {
            next_value = old_values[t + 1]
        }
        if done {
            next_value = tensor_ops.zeros_like(value)
        }
        tensor delta = tensor_ops.add(
            reward,
            tensor_ops.sub(
                tensor_ops.mul_scalar(next_value, cfg.gamma),
                value
            )
        )
        gae = tensor_ops.add(
            delta,
            tensor_ops.mul_scalar(gae, cfg.gamma * 0.95)
        )
        if done {
            gae = tensor_ops.zeros_like(gae)
        }
        advantages[t] = gae
        returns[t] = tensor_ops.add(gae, value)
        t = t - 1
    }
    tensor states_cat = tensor_ops.concat(states, 0)
    tensor actions_cat = tensor_ops.concat(actions, 0)
    tensor old_log_probs_cat = tensor_ops.concat(old_log_probs, 0)
    tensor adv_tensor = tensor_ops.concat(advantages, 0)
    tensor ret_tensor = tensor_ops.concat(returns, 0)
    tensor step_rewards_cat = tensor_ops.concat(step_rewards, 0)
    tensor cumulative_cat = tensor_ops.concat(cumulative_rewards, 0)
    float mean_adv = tensor_ops.mean_scalar(adv_tensor)
    float std_adv = tensor_ops.std_scalar(adv_tensor)
    adv_tensor = tensor_ops.div_scalar(
        tensor_ops.sub_scalar(adv_tensor, mean_adv),
        std_adv + 1e-8
    )
    tensor policy_logits = policy.forward(states_cat)
    tensor new_log_probs = tensor_ops.log_softmax(policy_logits, -1)
    new_log_probs = tensor_ops.gather(new_log_probs, actions_cat, -1)
    tensor new_values = value_model.forward(states_cat)
    tensor ratio = tensor_ops.exp(
        tensor_ops.sub(new_log_probs, old_log_probs_cat)
    )
    tensor adv_exp = tensor_ops.unsqueeze(adv_tensor, -1)
    tensor surrogate1 = tensor_ops.mul(ratio, adv_exp)
    tensor surrogate2 = tensor_ops.mul(
        tensor_ops.clip(ratio, 1.0 - 0.2, 1.0 + 0.2),
        adv_exp
    )
    tensor policy_loss = tensor_ops.neg(
        tensor_ops.mean(
            tensor_ops.min(surrogate1, surrogate2)
        )
    )
    tensor value_loss = tensor_ops.mean(
        tensor_ops.pow(tensor_ops.sub(new_values, ret_tensor), 2.0)
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
    float kl_div = tensor_ops.mean_scalar(
        tensor_ops.mul(
            old_log_probs_cat,
            tensor_ops.sub(old_log_probs_cat, new_log_probs)
        )
    )
    tensor total_loss = tensor_ops.add(
        policy_loss,
        tensor_ops.add(
            tensor_ops.mul_scalar(value_loss, cfg.value_loss_coef),
            tensor_ops.mul_scalar(entropy_mean, -cfg.entropy_coef)
        )
    )
    prime_state {
        policy_logits: policy_logits,
        value_estimates: new_values,
        step_rewards: step_rewards_cat,
        cumulative_rewards: cumulative_cat,
        advantages: adv_tensor,
        kl_divergence: kl_div,
        policy_loss: tensor_ops.item(policy_loss),
        value_loss: tensor_ops.item(value_loss),
        entropy: tensor_ops.item(entropy_mean),
        total_loss: tensor_ops.item(total_loss),
    }
}
