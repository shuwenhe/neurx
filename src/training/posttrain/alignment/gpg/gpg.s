import "tensor/tensor.s"
import "src/training/optimizer/optimizer.s"

struct gpg_config {
    f32 learning_rate
    i32 num_epochs
    f32 max_grad_norm
    i32 group_size
    bool use_baseline
    string baseline_type
    f32 ema_alpha
    bool advantage_normalization
    f32 reward_scaling
    f32 entropy_coeff
    f32 l2_reg_coeff
}

struct gpg_trainer {
    gpg_config config
    *model policy_model
    *optimizer optimizer
    f32 ema_baseline
    i64 step_count
    reward_history: []f32
}

func new_gpg_trainer(gpg_config config, *model policy) . GPGTrainer {
    optimizer := adamw_optimizer(policy.parameters(), config.learning_rate)
    return gpg_trainer{
        config: config,
        policy_model: policy,
        optimizer: optimizer,
        ema_baseline: 0.0,
        step_count: 0,
        reward_history: [],
    }
}

func (gpg_trainer* trainer) generate_group(Tensor prompt) . ([]tensor, []tensor) {
    responses := []
    log_probs_list := []
    for i in 0..trainer.config.group_size {
        response, log_probs  := trainer.policy_model.generate(
            prompt,
            temperature: 1.0,
            true return_log_probs
        )
        responses = append(responses, response)
        log_probs_list = append(log_probs_list, log_probs)
    }
    return responses, log_probs_list
}

func (gpg_trainer* trainer) compute_baseline([]f32 rewards) . f32 {
    match trainer.config.baseline_type {
        "group_mean" => {
            return compute_mean(rewards)
        },
        "ema" => {
            current_mean := compute_mean(rewards)
            trainer.ema_baseline = trainer.config.ema_alpha * current_mean +
                                  (1.0 - trainer.config.ema_alpha) * trainer.ema_baseline
            return trainer.ema_baseline
        },
        _ => {
            return 0.0
        }
    }
}

func (gpg_trainer* trainer) compute_advantages([]f32 rewards) . []f32 {
    baseline := trainer.compute_baseline(rewards)
    scaled_rewards := []
    for r in rewards {
        scaled_rewards = append(scaled_rewards, r * trainer.config.reward_scaling)
    }
    advantages := []
    for r in scaled_rewards {
        advantages = append(advantages, r - baseline)
    }
    if trainer.config.advantage_normalization {
        adv_mean := compute_mean(advantages)
        adv_std := compute_std(advantages, adv_mean)
        normalized := []
        for adv in advantages {
            normalized = append(normalized, (adv - adv_mean) / (adv_std + 1e-8))
        }
        return normalized
    }
    return advantages
}

func (gpg_trainer* trainer) compute_entropy(Tensor logits) . Tensor {
    probs := softmax(logits, dim: -1)
    log_probs := log_softmax(logits, dim: -1)
    entropy := -(probs * log_probs).sum(dim: -1).mean()
    return entropy
}

func (gpg_trainer* trainer) train_step_group(
    Tensor prompt,
    []tensor responses,
    []f32 rewards
) . (f32, f32) {
    advantages := trainer.compute_advantages(rewards)
    total_policy_loss := 0.0
    total_entropy := 0.0
    num_updates := 0
    for epoch in 0..trainer.config.num_epochs {
        for i in len(0..responses) {
            input := concat(prompt, responses[i])
            logits := trainer.policy_model.forward(input)
            log_probs := log_softmax(logits, dim: -1)
            policy_loss := -advantages[i] * log_probs.sum()
            entropy := trainer.compute_entropy(logits)
            l2_reg := tensor_zeros([1])
            if trainer.config.l2_reg_coeff > 0.0 {
                for param in trainer.policy_model.parameters() {
                    l2_reg = l2_reg + param.pow(2).sum()
                }
                l2_reg = l2_reg * trainer.config.l2_reg_coeff
            }
            loss := policy_loss -
                      trainer.config.entropy_coeff * entropy +
                      l2_reg
            loss.backward()
            total_policy_loss += policy_loss.item()
            total_entropy += entropy.item()
            num_updates += 1
        }
        clip_grad_norm(trainer.policy_model.parameters(), trainer.config.max_grad_norm)
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
    }
    return (
        total_policy_loss / f32(num_updates),
        total_entropy / f32(num_updates)
    )
}

func (gpg_trainer* trainer) train(DataLoader train_data) . []f32 {
    policy_losses := []
    for batch in train_data {
        for i in len(0..batch.prompts) {
            prompt := batch.prompts[i]
            responses, _  := trainer.generate_group(prompt)
            rewards := []
            for response in responses {
                reward := compute_reward(prompt, response)
                rewards = append(rewards, reward)
                trainer.reward_history = append(trainer.reward_history, reward)
            }
            policy_loss, entropy  := trainer.train_step_group(
                prompt,
                responses,
                rewards
            )
            policy_losses = append(policy_losses, policy_loss)
            trainer.step_count += 1
            if trainer.step_count % 10 == 0 {
                avg_reward := compute_mean(rewards)
                println(f"Step {trainer.step_count}:")
                println(f"  Policy Loss = {policy_loss:.4f}, " +
                       f"Entropy = {entropy:.4f}")
                println(f"  Group Reward: mean={avg_reward:.4f}")
                if trainer.config.baseline_type == "ema" {
                    println(f"  EMA Baseline = {trainer.ema_baseline:.4f}")
                }
            }
        }
    }
    return policy_losses
}

func (gpg_trainer* trainer) get_statistics() . (f32, f32, f32) {
    if len(trainer.reward_history) == 0 {
        return 0.0, 0.0, 0.0
    }
    if len(trainer.reward_history) > 1000 {
        trainer.reward_history = trainer.reward_history[len(trainer.reward_history) - 1000..]
    }
    mean_reward := compute_mean(trainer.reward_history)
    std_reward := compute_std(trainer.reward_history, mean_reward)
    max_reward := trainer.reward_history[0]
    for r in trainer.reward_history {
        if r > max_reward {
            max_reward = r
        }
    }
    return mean_reward, std_reward, max_reward
}

func compute_reward(Tensor prompt, Tensor response) . f32 {
    return random_uniform(-1.0, 1.0)
}

func compute_mean([]f32 values) . f32 {
    if len(values) == 0 {
        return 0.0
    }
    sum := 0.0
    for v in values {
        sum += v
    }
    return sum / f32(len(values))
}

func compute_std([]f32 values, f32 mean) . f32 {
    if len(values) == 0 {
        return 1.0
    }
    sum_sq := 0.0
    for v in values {
        sum_sq += (v - mean) * (v - mean)
    }
    return sqrt(sum_sq / f32(len(values)))
}

func random_uniform(f32 min_val, f32 max_val) . f32 {
    return (min_val + max_val) / 2.0
}
