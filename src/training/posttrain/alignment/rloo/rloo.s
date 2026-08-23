package neurx.posttrain.alignment.rloo
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}

struct rloo_config {
    float learning_rate
    int batch_size
    int num_samples
    float kl_coef
    float entropy_coef
    int max_grad_norm
    float gamma
    bool use_baseline_normalization
    float clip_range_reward
}

struct rloo_state {
    tensor policy_logits
    tensor log_probs
    tensor rewards
    tensor baselines
    tensor advantages
    float kl_divergence
    float policy_loss
    float entropy
    float total_loss
    float avg_reward
    float baseline_var
}

func new_rloo_config() rloo_config {
    rloo_config {
        learning_rate: 1e-5,
        batch_size: 32,
        num_samples: 8,
        kl_coef: 0.1,
        entropy_coef: 0.01,
        max_grad_norm: 1,
        gamma: 1.0,
        use_baseline_normalization: true,
        clip_range_reward: 10.0,
    }
}

func rloo_compute_loo_baselines(
    []tensor rewards,
    int num_samples
) []tensor {
    int n = rewards.len
    []tensor baselines = []tensor{cap: n}
    int i = 0
    while i < n {
        int group_idx = i / num_samples
        int group_start = group_idx * num_samples
        int group_end = group_start + num_samples
        tensor sum_others = tensor_ops.zeros_like(rewards[i])
        int count = 0
        int j = group_start
        while j < group_end {
            if j != i {
                sum_others = tensor_ops.add(sum_others, rewards[j])
                count = count + 1
            }
            j = j + 1
        }
        if count > 0 {
            baselines[i] = tensor_ops.div_scalar(sum_others, count * 1.0)
        } else {
            baselines[i] = tensor_ops.zeros_like(rewards[i])
        }
        i = i + 1
    }
    baselines
}

func rloo_compute_policy_loss(
    tensor log_probs,
    tensor old_log_probs,
    tensor advantages,
    float kl_coef
) (tensor, float) {
    tensor adv_exp = tensor_ops.unsqueeze(advantages, -1)
    tensor policy_grad = tensor_ops.mul(log_probs, adv_exp)
    tensor kl_term = tensor_ops.mul(
        old_log_probs,
        tensor_ops.sub(old_log_probs, log_probs)
    )
    float kl_div = tensor_ops.mean_scalar(kl_term)
    tensor policy_loss = tensor_ops.neg(
        tensor_ops.sub(
            tensor_ops.mean(policy_grad),
            tensor_ops.mul_scalar(
                tensor_ops.mean(kl_term),
                kl_coef
            )
        )
    )
    (policy_loss, kl_div)
}

func rloo_step(
    module policy,
    module reference_policy,
    []tensor states,
    []tensor actions,
    []tensor rewards,
    []tensor old_log_probs,
    rloo_config cfg
) rloo_state {
    int i = 0
    while i < rewards.len {
        rewards[i] = tensor_ops.clip_scalar(
            rewards[i],
            -cfg.clip_range_reward,
            cfg.clip_range_reward
        )
        i = i + 1
    }
    []tensor baselines = rloo_compute_loo_baselines(
        rewards,
        cfg.num_samples
    )
    []tensor advantages = []tensor{cap: rewards.len}
    i = 0
    while i < rewards.len {
        advantages[i] = tensor_ops.sub(rewards[i], baselines[i])
        i = i + 1
    }
    if cfg.use_baseline_normalization {
        tensor all_adv = tensor_ops.concat(advantages, 0)
        float mean_adv = tensor_ops.mean_scalar(all_adv)
        float std_adv = tensor_ops.std_scalar(all_adv)
        i = 0
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
    tensor rewards_cat = tensor_ops.concat(rewards, 0)
    tensor baselines_cat = tensor_ops.concat(baselines, 0)
    tensor policy_logits = policy.forward(states_cat)
    tensor new_log_probs = tensor_ops.log_softmax(policy_logits, -1)
    new_log_probs = tensor_ops.gather(new_log_probs, actions_cat, -1)
    (tensor policy_loss, float kl_div) = rloo_compute_policy_loss(
        new_log_probs,
        old_log_probs_cat,
        adv_tensor,
        cfg.kl_coef
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
    tensor total_loss = tensor_ops.sub(
        policy_loss,
        tensor_ops.mul_scalar(entropy_mean, cfg.entropy_coef)
    )
    float avg_reward = tensor_ops.mean_scalar(rewards_cat)
    float baseline_var = tensor_ops.std_scalar(baselines_cat)
    rloo_state {
        policy_logits: policy_logits,
        log_probs: new_log_probs,
        rewards: rewards_cat,
        baselines: baselines_cat,
        advantages: adv_tensor,
        kl_divergence: kl_div,
        policy_loss: tensor_ops.item(policy_loss),
        entropy: tensor_ops.item(entropy_mean),
        total_loss: tensor_ops.item(total_loss),
        avg_reward: avg_reward,
        baseline_var: baseline_var,
    }
}
