package neurx.posttrain.alignment.remax
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}

struct remax_config {
    float learning_rate
    int batch_size
    int num_epochs
    float kl_coef
    float entropy_coef
    float value_loss_coef
    int max_grad_norm
    float gamma
    float gae_lambda
    float alpha
    float beta
    bool use_advantage_normalization
}

struct remax_state {
    tensor policy_logits
    tensor value_estimates
    tensor advantages
    tensor returns
    tensor old_log_probs
    float kl_divergence
    float policy_loss
    float value_loss
    float entropy
    float total_loss
    float relaxation_loss
}

func new_remax_config() remax_config {
    remax_config {
        learning_rate: 3e-6,
        batch_size: 16,
        num_epochs: 4,
        kl_coef: 0.02,
        entropy_coef: 0.01,
        value_loss_coef: 0.5,
        max_grad_norm: 1,
        gamma: 1.0,
        gae_lambda: 0.95,
        alpha: 0.5,
        beta: 2.0,
        use_advantage_normalization: true,
    }
}

func remax_compute_policy_loss(
    tensor log_probs,
    tensor old_log_probs,
    tensor advantages,
    float alpha,
    float beta
) (tensor, float) {
    tensor log_ratio = tensor_ops.sub(log_probs, old_log_probs)
    tensor ratio = tensor_ops.exp(log_ratio)
    tensor adv_exp = tensor_ops.unsqueeze(advantages, -1)
    tensor weighted_ratio = tensor_ops.pow(ratio, beta)
    tensor surrogate = tensor_ops.mul(weighted_ratio, adv_exp)
    tensor relaxation = tensor_ops.mul_scalar(
        tensor_ops.pow(log_ratio, 2.0),
        alpha
    )
    tensor policy_loss = tensor_ops.neg(
        tensor_ops.sub(
            tensor_ops.mean(surrogate),
            tensor_ops.mean(relaxation)
        )
    )
    float kl_div = tensor_ops.mean_scalar(
        tensor_ops.sub(
            tensor_ops.mul(ratio, log_ratio),
            tensor_ops.sub(ratio, tensor_ops.ones_like(ratio))
        )
    )
    (policy_loss, kl_div)
}

func remax_step(
    module policy,
    module value_model,
    []tensor states,
    []tensor actions,
    []tensor rewards,
    []tensor old_log_probs,
    []tensor old_values,
    []bool dones,
    remax_config cfg
) remax_state {
    int T = rewards.len
    []tensor advantages = []tensor{cap: T}
    []tensor returns = []tensor{cap: T}
    tensor gae = tensor_ops.zeros_like(old_values[T - 1])
    int t = T - 1
    while t >= 0 {
        tensor reward = rewards[t]
        tensor value = old_values[t]
        bool done = dones[t]
        tensor next_value = tensor_ops.zeros_like(value)
        if t < T - 1 {
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
            tensor_ops.mul_scalar(gae, cfg.gamma * cfg.gae_lambda)
        )
        if done {
            gae = tensor_ops.zeros_like(gae)
        }
        advantages[t] = gae
        returns[t] = tensor_ops.add(gae, value)
        t = t - 1
    }
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
    tensor states_cat = tensor_ops.concat(states, 0)
    tensor actions_cat = tensor_ops.concat(actions, 0)
    tensor old_log_probs_cat = tensor_ops.concat(old_log_probs, 0)
    tensor adv_tensor = tensor_ops.concat(advantages, 0)
    tensor ret_tensor = tensor_ops.concat(returns, 0)
    tensor policy_logits = policy.forward(states_cat)
    tensor new_log_probs = tensor_ops.log_softmax(policy_logits, -1)
    new_log_probs = tensor_ops.gather(new_log_probs, actions_cat, -1)
    tensor new_values = value_model.forward(states_cat)
    (tensor policy_loss, float kl_div) = remax_compute_policy_loss(
        new_log_probs,
        old_log_probs_cat,
        adv_tensor,
        cfg.alpha,
        cfg.beta
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
    tensor total_loss = tensor_ops.add(
        policy_loss,
        tensor_ops.add(
            tensor_ops.mul_scalar(value_loss, cfg.value_loss_coef),
            tensor_ops.mul_scalar(entropy_mean, -cfg.entropy_coef)
        )
    )
    remax_state {
        policy_logits: policy_logits,
        value_estimates: new_values,
        advantages: adv_tensor,
        returns: ret_tensor,
        old_log_probs: old_log_probs_cat,
        kl_divergence: kl_div,
        policy_loss: tensor_ops.item(policy_loss),
        value_loss: tensor_ops.item(value_loss),
        entropy: tensor_ops.item(entropy_mean),
        total_loss: tensor_ops.item(total_loss),
        relaxation_loss: 0.0,
    }
}
