package neurx.posttrain.alignment.drgrpo
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}

struct drgrpo_config {
    float learning_rate
    int batch_size
    int group_size
    int num_epochs
    float kl_coef
    float entropy_coef
    int max_grad_norm
    float divergence_threshold
    float divergence_penalty
    bool use_adaptive_kl
    float target_kl
}


struct drgrpo_state {
    tensor policy_logits
    tensor log_probs
    tensor group_baselines
    tensor advantages
    tensor divergence
    float kl_divergence
    float policy_loss
    float divergence_loss
    float entropy
    float total_loss
    float avg_group_reward
}


func new_drgrpo_config() drgrpo_config {
    drgrpo_config {
        learning_rate: 1e-5,
        batch_size: 32,
        group_size: 4,
        num_epochs: 2,
        kl_coef: 0.05,
        entropy_coef: 0.01,
        max_grad_norm: 1,
        divergence_threshold: 0.1,
        divergence_penalty: 0.5,
        use_adaptive_kl: true,
        target_kl: 0.01,
    }
}


func drgrpo_compute_group_baselines(
    []tensor rewards,
    int group_size
) []tensor {
    int n = rewards.len
    []tensor baselines = []tensor{cap: n}
    int i = 0
    while i < n {
        int group_idx = i / group_size
        int group_start = group_idx * group_size
        int group_end = group_start + group_size
        tensor sum = tensor_ops.zeros_like(rewards[i])
        int count = 0
        int j = group_start
        while j < group_end {
            sum = tensor_ops.add(sum, rewards[j])
            count = count + 1
            j = j + 1
        }
        baselines[i] = tensor_ops.div_scalar(sum, count * 1.0)
        i = i + 1
    }
    baselines
}


func drgrpo_compute_divergence(
    tensor log_probs,
    tensor old_log_probs,
    int group_size
) tensor {
    int batch_size = log_probs.shape[0]
    int num_groups = batch_size / group_size
    []tensor divergences = []tensor{cap: num_groups}
    int g = 0
    while g < num_groups {
        int start = g * group_size
        int end = start + group_size
        tensor group_lp = tensor_ops.slice(log_probs, 0, start, end)
        tensor group_old_lp = tensor_ops.slice(old_log_probs, 0, start, end)
        tensor mean_lp = tensor_ops.mean(group_lp, 0, true)
        tensor kl = tensor_ops.sum(
            tensor_ops.mul(
                group_lp,
                tensor_ops.sub(group_lp, mean_lp)
            ),
            -1
        )
        divergences[g] = tensor_ops.mean(kl)
        g = g + 1
    }
    tensor_ops.concat(divergences, 0)
}


func drgrpo_step(
    module policy,
    module reference_policy,
    []tensor states,
    []tensor actions,
    []tensor rewards,
    []tensor old_log_probs,
    drgrpo_config cfg
) drgrpo_state {
    []tensor baselines = drgrpo_compute_group_baselines(
        rewards,
        cfg.group_size
    )
    []tensor advantages = []tensor{cap: rewards.len}
    int i = 0
    while i < rewards.len {
        advantages[i] = tensor_ops.sub(rewards[i], baselines[i])
        i = i + 1
    }
    tensor adv_cat = tensor_ops.concat(advantages, 0)
    float mean_adv = tensor_ops.mean_scalar(adv_cat)
    float std_adv = tensor_ops.std_scalar(adv_cat)
    i = 0
    while i < advantages.len {
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
    tensor rewards_cat = tensor_ops.concat(rewards, 0)
    tensor baselines_cat = tensor_ops.concat(baselines, 0)
    tensor policy_logits = policy.forward(states_cat)
    tensor new_log_probs = tensor_ops.log_softmax(policy_logits, -1)
    new_log_probs = tensor_ops.gather(new_log_probs, actions_cat, -1)
    tensor divergence = drgrpo_compute_divergence(
        new_log_probs,
        old_log_probs_cat,
        cfg.group_size
    )
    tensor adv_exp = tensor_ops.unsqueeze(adv_tensor, -1)
    tensor policy_grad = tensor_ops.mul(new_log_probs, adv_exp)
    tensor policy_loss = tensor_ops.neg(tensor_ops.mean(policy_grad))
    tensor divergence_mask = tensor_ops.gt(
        divergence,
        cfg.divergence_threshold
    )
    tensor divergence_penalty = tensor_ops.mul(
        divergence,
        tensor_ops.to_float(divergence_mask)
    )
    tensor divergence_loss = tensor_ops.mul_scalar(
        tensor_ops.mean(divergence_penalty),
        cfg.divergence_penalty
    )
    tensor kl_term = tensor_ops.mul(
        old_log_probs_cat,
        tensor_ops.sub(old_log_probs_cat, new_log_probs)
    )
    float kl_div = tensor_ops.mean_scalar(kl_term)
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
            divergence_loss,
            tensor_ops.sub(
                tensor_ops.mul_scalar(
                    tensor_ops.mean(kl_term),
                    cfg.kl_coef
                ),
                tensor_ops.mul_scalar(entropy_mean, cfg.entropy_coef)
            )
        )
    )
    float avg_group_reward = tensor_ops.mean_scalar(baselines_cat)
    drgrpo_state {
        policy_logits: policy_logits,
        log_probs: new_log_probs,
        group_baselines: baselines_cat,
        advantages: adv_tensor,
        divergence: divergence,
        kl_divergence: kl_div,
        policy_loss: tensor_ops.item(policy_loss),
        divergence_loss: tensor_ops.item(divergence_loss),
        entropy: tensor_ops.item(entropy_mean),
        total_loss: tensor_ops.item(total_loss),
        avg_group_reward: avg_group_reward,
    }
}

