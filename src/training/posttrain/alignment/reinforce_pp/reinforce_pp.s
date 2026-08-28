package neurx.posttrain.alignment.reinforce_pp
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}
struct reinforce_pp_config {
    float learning_rate
    int batch_size
    int num_samples_per_prompt
    float kl_coef
    float entropy_coef
    int max_grad_norm
    float gamma
    float baseline_momentum
    bool use_reward_whitening
    bool use_advantage_normalization
    float clip_range_reward
}
struct reinforce_pp_state {
    tensor policy_logits
    tensor log_probs
    tensor rewards
    tensor baseline
    tensor advantages
    float kl_divergence
    float policy_loss
    float entropy
    float total_loss
    float avg_reward
    float ema_baseline
}
func new_reinforce_pp_config() reinforce_pp_config {
    reinforce_pp_config {
        learning_rate: 1e-5,
        batch_size: 32,
        num_samples_per_prompt: 4,
        kl_coef: 0.1,
        entropy_coef: 0.01,
        max_grad_norm: 1,
        gamma: 1.0,
        baseline_momentum: 0.9,
        use_reward_whitening: true,
        use_advantage_normalization: true,
        clip_range_reward: 10.0,
    }
}
func reinforce_pp_compute_baseline(
    []tensor rewards,
    int num_samples_per_prompt,
    float ema_baseline,
    float momentum
) (tensor, float) {
    int n = rewards.len
    []tensor group_means = []tensor{cap: n}
    int i = 0
    for i < n {
        int group_idx = i / num_samples_per_prompt
        int group_start = group_idx * num_samples_per_prompt
        int group_end = group_start + num_samples_per_prompt
        tensor sum = tensor_ops.zeros_like(rewards[i])
        int count = 0
        int j = group_start
        for j < group_end {
            sum = tensor_ops.add(sum, rewards[j])
            count = count + 1
            j = j + 1
        }
        group_means[i] = tensor_ops.div_scalar(sum, count * 1.0)
        i = i + 1
    }
    tensor baseline = tensor_ops.concat(group_means, 0)
    float current_mean = tensor_ops.mean_scalar(baseline)
    float new_ema = momentum * ema_baseline + (1.0 - momentum) * current_mean
    (baseline, new_ema)
}
func reinforce_pp_step(
    module policy,
    module reference_policy,
    []tensor states,
    []tensor actions,
    []tensor rewards,
    []tensor old_log_probs,
    float ema_baseline,
    reinforce_pp_config cfg
) reinforce_pp_state {
    int i = 0
    for i < rewards.len {
        rewards[i] = tensor_ops.clip_scalar(
            rewards[i],
            -cfg.clip_range_reward,
            cfg.clip_range_reward
        )
        i = i + 1
    }
    (tensor baseline, float new_ema) = reinforce_pp_compute_baseline(
        rewards,
        cfg.num_samples_per_prompt,
        ema_baseline,
        cfg.baseline_momentum
    )
    tensor rewards_cat = tensor_ops.concat(rewards, 0)
    if cfg.use_reward_whitening {
        float mean_r = tensor_ops.mean_scalar(rewards_cat)
        float std_r = tensor_ops.std_scalar(rewards_cat)
        rewards_cat = tensor_ops.div_scalar(
            tensor_ops.sub_scalar(rewards_cat, mean_r),
            std_r + 1e-8
        )
    }
    tensor advantages = tensor_ops.sub(rewards_cat, baseline)
    if cfg.use_advantage_normalization {
        float mean_adv = tensor_ops.mean_scalar(advantages)
        float std_adv = tensor_ops.std_scalar(advantages)
        advantages = tensor_ops.div_scalar(
            tensor_ops.sub_scalar(advantages, mean_adv),
            std_adv + 1e-8
        )
    }
    tensor states_cat = tensor_ops.concat(states, 0)
    tensor actions_cat = tensor_ops.concat(actions, 0)
    tensor old_log_probs_cat = tensor_ops.concat(old_log_probs, 0)
    tensor policy_logits = policy.forward(states_cat)
    tensor new_log_probs = tensor_ops.log_softmax(policy_logits, -1)
    new_log_probs = tensor_ops.gather(new_log_probs, actions_cat, -1)
    tensor adv_exp = tensor_ops.unsqueeze(advantages, -1)
    tensor policy_grad = tensor_ops.mul(new_log_probs, adv_exp)
    tensor kl_term = tensor_ops.mul(
        old_log_probs_cat,
        tensor_ops.sub(old_log_probs_cat, new_log_probs)
    )
    float kl_div = tensor_ops.mean_scalar(kl_term)
    tensor policy_loss = tensor_ops.neg(
        tensor_ops.sub(
            tensor_ops.mean(policy_grad),
            tensor_ops.mul_scalar(
                tensor_ops.mean(kl_term),
                cfg.kl_coef
            )
        )
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
    reinforce_pp_state {
        policy_logits: policy_logits,
        log_probs: new_log_probs,
        rewards: rewards_cat,
        baseline: baseline,
        advantages: advantages,
        kl_divergence: kl_div,
        policy_loss: tensor_ops.item(policy_loss),
        entropy: tensor_ops.item(entropy_mean),
        total_loss: tensor_ops.item(total_loss),
        avg_reward: avg_reward,
        ema_baseline: new_ema,
    }
}
