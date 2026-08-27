import "tensor/tensor.s"
import "src/training/optimizer/optimizer.s"
import "src/training/posttrain/alignment/ppo/ppo.s"

struct gmpo_config {
    clip_epsilon: f32
    value_clip_epsilon: f32
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    kl_coeff: f32
    gamma: f32
    gae_lambda: f32
    num_rewards: i32
    use_geometric_mean: bool
    epsilon: f32
    reward_normalization: bool
    min_reward_value: f32
}

struct gmpo_trainer {
    config: gmpo_config
    policy_model: *model
    value_model: *model
    reference_model: *model
    optimizer: *optimizer
    reward_statistics: []reward_stats
    step_count: i64
}

struct reward_stats {
    mean: f32
    std: f32
    min: f32
    max: f32
    history: []f32
}

func new_gmpo_trainer(
    gmpo_config config,
    *model policy,
    *model value,
    *model reference
) . GMPOTrainer {
    optimizer := adamw_optimizer(
        policy.parameters() + value.parameters(),
        config.learning_rate
    )
    reward_statistics := []
    for i in 0..config.num_rewards {
        reward_statistics.push(reward_stats{
            mean: 0.0,
            std: 1.0,
            min: f32.MAX,
            max: f32.MIN,
            history: [],
        })
    }
    return gmpo_trainer{
        config: config,
        policy_model: policy,
        value_model: value,
        reference_model: reference,
        optimizer: optimizer,
        reward_statistics: reward_statistics,
        step_count: 0,
    }
}

func (gmpo_trainer* trainer) compute_geometric_mean([]f32 rewards) . f32 {
    if len(rewards) == 0 {
        return 0.0
    }
    shifted_rewards := []
    for r in rewards {
        shifted := max(r, trainer.config.min_reward_value) + trainer.config.epsilon
        shifted_rewards = append(shifted_rewards, shifted)
    }
    log_sum := 0.0
    for r in shifted_rewards {
        log_sum += log(r)
    }
    geometric_mean := exp(log_sum / f32(len(shifted_rewards)))
    return geometric_mean - trainer.config.epsilon
}

func compute_arithmetic_mean([]f32 rewards) . f32 {
    if len(rewards) == 0 {
        return 0.0
    }
    sum := 0.0
    for r in rewards {
        sum += r
    }
    return sum / f32(len(rewards))
}

func (gmpo_trainer* trainer) update_reward_statistics(
    [][]f32 multi_rewards
) {
    for reward_idx in 0..trainer.config.num_rewards {
        values := []
        for batch_idx in len(0..multi_rewards) {
            if reward_idx < multi_rewards[batch_idx].len() {
                values = append(values, multi_rewards[batch_idx][reward_idx])
            }
        }
        if len(values) == 0 {
            continue
        }
        stats := *trainer.reward_statistics[reward_idx]
        for v in values {
            stats.history = append(stats.history, v)
        }
        if len(stats.history) > 1000 {
            stats.history = stats.history[len(stats.history) - 1000..]
        }
        for v in values {
            if v < stats.min {
                stats.min = v
            }
            if v > stats.max {
                stats.max = v
            }
        }
        if len(stats.history) > 0 {
            stats.mean = compute_mean(stats.history)
            stats.std = compute_std(stats.history, stats.mean)
        }
    }
}

func (gmpo_trainer* trainer) normalize_rewards(
    [][]f32 multi_rewards
) . [][]f32 {
    if !trainer.config.reward_normalization {
        return multi_rewards
    }
    normalized := []
    for batch_idx in len(0..multi_rewards) {
        batch_rewards := multi_rewards[batch_idx]
        normalized_batch := []
        for reward_idx in len(0..batch_rewards) {
            stats := trainer.reward_statistics[reward_idx]
            normalized_value := (batch_rewards[reward_idx] - stats.mean) /
                                   (stats.std + trainer.config.epsilon)
            normalized_batch = append(normalized_batch, normalized_value)
        }
        normalized = append(normalized, normalized_batch)
    }
    return normalized
}

func (gmpo_trainer* trainer) combine_rewards([]f32 multi_rewards) . f32 {
    if trainer.config.use_geometric_mean {
        return trainer.compute_geometric_mean(multi_rewards)
    } else {
        return compute_arithmetic_mean(multi_rewards)
    }
}

func (gmpo_trainer* trainer) compute_gae(
    []tensor rewards,
    []tensor values,
    []tensor dones
) . ([]tensor, []tensor) {
    batch_size := len(rewards)
    advantages := []
    returns := []
    for b in 0..batch_size {
        seq_len := rewards[b].shape[0]
        num_rewards := rewards[b].shape[1]
        seq_advantages := tensor_zeros([seq_len])
        seq_returns := tensor_zeros([seq_len])
        gae := 0.0
        next_value := 0.0
        for t in (seq_len - 1)..0 by -1 {
            multi_reward := []
            for r_idx in 0..num_rewards {
                multi_reward = append(multi_reward, rewards[b][t, r_idx].item())
            }
            combined_reward := trainer.combine_rewards(multi_reward)
            value := values[b][t].item()
            done := dones[b][t].item()
            delta := combined_reward +
                       trainer.config.gamma * next_value * (1.0 - done) -
                       value
            gae = delta +
                  trainer.config.gamma * trainer.config.gae_lambda *
                  (1.0 - done) * gae
            seq_advantages[t] = tensor_scalar(gae)
            seq_returns[t] = tensor_scalar(gae + value)
            next_value = value
        }
        advantages = append(advantages, seq_advantages)
        returns = append(returns, seq_returns)
    }
    return advantages, returns
}

func (gmpo_trainer* trainer) train_step(
    []tensor prompts,
    []tensor responses,
    [][]f32 multi_rewards
) . (f32, f32, f32) {
    batch_size := len(prompts)
    trainer.update_reward_statistics(multi_rewards)
    normalized_rewards := trainer.normalize_rewards(multi_rewards)
    inputs := []
    reward_tensors := []
    done_tensors := []
    for i in 0..batch_size {
        input := concat(prompts[i], responses[i])
        inputs = append(inputs, input)
        seq_len := responses[i].shape[0]
        reward_tensor := tensor_zeros([seq_len, trainer.config.num_rewards])
        for t in 0..seq_len {
            for r_idx in 0..trainer.config.num_rewards {
                reward_tensor[t, r_idx] = tensor_scalar(normalized_rewards[i][r_idx])
            }
        }
        reward_tensors = append(reward_tensors, reward_tensor)
        done_tensor := tensor_zeros([seq_len])
        done_tensor[-1] = tensor_scalar(1.0)
        done_tensors = append(done_tensors, done_tensor)
    }
    value_outputs := []
    for input in inputs {
        value := trainer.value_model.forward(input)
        value_outputs = append(value_outputs, value)
    }
    advantages, returns  := trainer.compute_gae(
        reward_tensors,
        value_outputs,
        done_tensors
    )
    current_log_probs := []
    for i in 0..batch_size {
        logits := trainer.policy_model.forward(inputs[i])
        log_probs := log_softmax(logits, dim: -1)
        current_log_probs = append(current_log_probs, log_probs)
    }
    ref_log_probs := []
    for i in 0..batch_size {
        logits := trainer.reference_model.forward(inputs[i])
        log_probs := log_softmax(logits, dim: -1)
        ref_log_probs = append(ref_log_probs, log_probs)
    }
    total_policy_loss := 0.0
    total_value_loss := 0.0
    total_kl := 0.0
    num_updates := 0
    for epoch in 0..trainer.config.num_epochs {
        for i in 0..batch_size {
            logits := trainer.policy_model.forward(inputs[i])
            new_log_probs := log_softmax(logits, dim: -1)
            new_values := trainer.value_model.forward(inputs[i])
            ratio := exp(new_log_probs.sum() - current_log_probs[i].sum())
            surr1 := ratio * advantages[i]
            surr2 := clamp(
                ratio,
                1.0 - trainer.config.clip_epsilon,
                1.0 + trainer.config.clip_epsilon
            ) * advantages[i]
            policy_loss := -minimum(surr1, surr2).mean()
            value_pred_clipped := value_outputs[i] + clamp(
                new_values - value_outputs[i],
                -trainer.config.value_clip_epsilon,
                trainer.config.value_clip_epsilon
            )
            value_loss1 := (new_values - returns[i]).pow(2)
            value_loss2 := (value_pred_clipped - returns[i]).pow(2)
            value_loss := maximum(value_loss1, value_loss2).mean()
            kl := (exp(ref_log_probs[i]) *
                     (ref_log_probs[i] - new_log_probs)).sum()
            loss := policy_loss + 0.5 * value_loss + trainer.config.kl_coeff * kl
            loss.backward()
            total_policy_loss += policy_loss.item()
            total_value_loss += value_loss.item()
            total_kl += kl.item()
            num_updates += 1
        }
        clip_grad_norm(
            trainer.policy_model.parameters() + trainer.value_model.parameters(),
            trainer.config.max_grad_norm
        )
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
    }
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        total_kl / f32(num_updates)
    )
}

func (gmpo_trainer* trainer) train(DataLoader train_data) . ([]f32, []f32) {
    policy_losses := []
    value_losses := []
    for batch in train_data {
        policy_loss, value_loss, kl  := trainer.train_step(
            batch.prompts,
            batch.responses,
            batch.multi_rewards
        )
        policy_losses = append(policy_losses, policy_loss)
        value_losses = append(value_losses, value_loss)
        if trainer.step_count % 10 == 0 {
            println(f"Step {trainer.step_count}: " +
                   f"Policy Loss = {policy_loss:.4f}, " +
                   f"Value Loss = {value_loss:.4f}, " +
                   f"KL = {kl:.4f}")
            trainer.print_reward_statistics()
        }
    }
    return policy_losses, value_losses
}

func (gmpo_trainer* trainer) print_reward_statistics() {
    println("Reward Statistics (Geometric Mean):")
    for i in 0..trainer.config.num_rewards {
        stats := trainer.reward_statistics[i]
        println(f"  Reward {i}: mean={stats.mean:.4f}, " +
               f"std={stats.std:.4f}, " +
               f"min={stats.min:.4f}, " +
               f"max={stats.max:.4f}")
    }
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
