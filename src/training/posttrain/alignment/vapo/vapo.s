package neurx.posttrain.alignment.vapo
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}

struct vapo_config {
    float learning_rate
    int batch_size
    int num_epochs
    float kl_coef
    float entropy_coef
    float value_loss_coef
    float clip_range
    int max_grad_norm
    float gamma
    float gae_lambda
    bool use_value_augmented_advantages
    float value_weight
    int num_value_samples
}

struct vapo_state {
    tensor policy_logits
    tensor value_estimates
    tensor value_augmented_advantages
    tensor returns
    tensor old_log_probs
    float kl_divergence
    float policy_loss
    float value_loss
    float entropy
    float total_loss
}

func new_vapo_config() vapo_config {
    vapo_config {
        learning_rate: 1e-5,
        batch_size: 16,
        num_epochs: 4,
        kl_coef: 0.1,
        entropy_coef: 0.01,
        value_loss_coef: 0.5,
        clip_range: 0.2,
        max_grad_norm: 1,
        gamma: 1.0,
        gae_lambda: 0.95,
        use_value_augmented_advantages: true,
        value_weight: 0.5,
        num_value_samples: 8,
    }
}

func vapo_compute_value_augmented_advantages(
    []tensor advantages,
    []tensor values,
    []tensor rewards,
    vapo_config cfg
) []tensor {
    []tensor augmented = []tensor{cap: advantages.len}
    int i = 0
    for i < advantages.len {
        tensor adv = advantages[i]
        tensor value_component = tensor_ops.sub(
            rewards[i],
            values[i]
        )
        tensor aug_adv = tensor_ops.add(
            tensor_ops.mul_scalar(adv, 1.0 - cfg.value_weight),
            tensor_ops.mul_scalar(value_component, cfg.value_weight)
        )
        augmented[i] = aug_adv
        i = i + 1
    }
    augmented
}

func vapo_compute_advantages_with_gae(
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
    for t >= 0 {
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

func vapo_step(
    module policy,
    module value_model,
    []tensor states,
    []tensor actions,
    []tensor rewards,
    []tensor old_log_probs,
    []tensor old_values,
    []bool dones,
    vapo_config cfg
) vapo_state {
    ([]tensor advantages, []tensor returns) = vapo_compute_advantages_with_gae(
        rewards,
        old_values,
        dones,
        cfg.gamma,
        cfg.gae_lambda
    )
    if cfg.use_value_augmented_advantages {
        advantages = vapo_compute_value_augmented_advantages(
            advantages,
            old_values,
            rewards,
            cfg
        )
    }
    tensor adv_cat = tensor_ops.concat(advantages, 0)
    float mean_adv = tensor_ops.mean_scalar(adv_cat)
    float std_adv = tensor_ops.std_scalar(adv_cat)
    int i = 0
    for i < advantages.len {
        advantages[i] = tensor_ops.div_scalar(
            tensor_ops.sub_scalar(advantages[i], mean_adv),
            std_adv + 1e-8
        )
        i = i + 1
    }
    tensor states_cat = tensor_ops.concat(states, 0)
    tensor actions_cat = tensor_ops.concat(actions, 0)
    tensor old_log_probs_cat = tensor_ops.concat(old_log_probs, 0)
    tensor adv_tensor = tensor_ops.concat(advantages, 0)
    tensor ret_tensor = tensor_ops.concat(returns, 0)
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
        tensor_ops.clip(ratio, 1.0 - cfg.clip_range, 1.0 + cfg.clip_range),
        adv_exp
    )
    tensor policy_loss = tensor_ops.neg(
        tensor_ops.mean(
            tensor_ops.min(surrogate1, surrogate2)
        )
    )
    tensor values_clipped = tensor_ops.clip(
        new_values,
        tensor_ops.sub_scalar(old_values.concat(0), cfg.clip_range),
        tensor_ops.add_scalar(old_values.concat(0), cfg.clip_range)
    )
    tensor loss1 = tensor_ops.pow(
        tensor_ops.sub(new_values, ret_tensor),
        2.0
    )
    tensor loss2 = tensor_ops.pow(
        tensor_ops.sub(values_clipped, ret_tensor),
        2.0
    )
    tensor value_loss = tensor_ops.mean(tensor_ops.max(loss1, loss2))
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
    vapo_state {
        policy_logits: policy_logits,
        value_estimates: new_values,
        value_augmented_advantages: adv_tensor,
        returns: ret_tensor,
        old_log_probs: old_log_probs_cat,
        kl_divergence: kl_div,
        policy_loss: tensor_ops.item(policy_loss),
        value_loss: tensor_ops.item(value_loss),
        entropy: tensor_ops.item(entropy_mean),
        total_loss: tensor_ops.item(total_loss),
    }
}
