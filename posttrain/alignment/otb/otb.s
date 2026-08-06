import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "posttrain/alignment/ppo/ppo.s"

struct otb_config {
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    gamma: f32
    baseline_type: string
    use_token_wise_baseline: bool
    ema_alpha: f32
    use_learned_baseline: bool
    baseline_lr: f32
    baseline_loss_coeff: f32
    compute_variance: bool
    use_whitening: bool
    use_clipping: bool
    clip_epsilon: f32
    entropy_coeff: f32
}

struct otb_trainer {
    config: OTBConfig
    policy_model: *model
    baseline_model: *model
    optimizer: *optimizer
    baseline_optimizer: *optimizer
    token_ema_baselines: map[i64]f32
    advantage_variance_before: f32
    advantage_variance_after: f32
    step_count: i64
}

func new_otb_trainer(
    config: OTBConfig,
    policy: *model,
    baseline: *model
) -> OTBTrainer {
    let optimizer = adamw_optimizer(policy.parameters(), config.learning_rate)
    let baseline_optimizer: *optimizer = nil
    if config.use_learned_baseline {
        baseline_optimizer = adamw_optimizer(
            baseline.parameters(),
            config.baseline_lr
        )
    }
    return otb_trainer{
        config: config,
        policy_model: policy,
        baseline_model: baseline,
        optimizer: optimizer,
        baseline_optimizer: baseline_optimizer,
        token_ema_baselines: {},
        advantage_variance_before: 0.0,
        advantage_variance_after: 0.0,
        step_count: 0,
    }
}

func (trainer: *otb_trainer) compute_token_baseline(
    tokens: Tensor,
    rewards: Tensor
) -> Tensor {
    let seq_len = tokens.shape[0]
    let baselines = tensor_zeros([seq_len])
    match trainer.config.baseline_type {
        "optimal" => {
            for t in 0..seq_len {
                let token_id = tokens[t].item_i64()
                let reward = rewards[t].item()
                if token_id in trainer.token_ema_baselines {
                    let old_baseline = trainer.token_ema_baselines[token_id]
                    let new_baseline = trainer.config.ema_alpha * reward +
                                     (1.0 - trainer.config.ema_alpha) * old_baseline
                    trainer.token_ema_baselines[token_id] = new_baseline
                    baselines[t] = tensor_scalar(new_baseline)
                } else {
                    trainer.token_ema_baselines[token_id] = reward
                    baselines[t] = tensor_scalar(reward)
                }
            }
        },
        "mean" => {
            let mean_reward = rewards.mean()
            baselines = tensor_full([seq_len], mean_reward.item())
        },
        "ema" => {
            for t in 0..seq_len {
                let position_key = i64(1000000 + t)
                let reward = rewards[t].item()
                if position_key in trainer.token_ema_baselines {
                    let old_baseline = trainer.token_ema_baselines[position_key]
                    let new_baseline = trainer.config.ema_alpha * reward +
                                     (1.0 - trainer.config.ema_alpha) * old_baseline
                    trainer.token_ema_baselines[position_key] = new_baseline
                    baselines[t] = tensor_scalar(new_baseline)
                } else {
                    trainer.token_ema_baselines[position_key] = reward
                    baselines[t] = tensor_scalar(reward)
                }
            }
        },
        "learned" => {
            if trainer.config.use_learned_baseline {
                baselines = trainer.baseline_model.forward(tokens)
            } else {
                baselines = tensor_zeros([seq_len])
            }
        },
        _ => {
            baselines = tensor_zeros([seq_len])
        }
    }
    return baselines
}

func (trainer: *otb_trainer) compute_advantages(
    tokens: Tensor,
    rewards: Tensor
) -> Tensor {
    let baselines = trainer.compute_token_baseline(tokens, rewards)
    let raw_advantages = rewards.clone()
    if trainer.config.compute_variance {
        trainer.advantage_variance_before = compute_variance_tensor(raw_advantages)
    }
    let advantages = rewards - baselines
    if trainer.config.compute_variance {
        trainer.advantage_variance_after = compute_variance_tensor(advantages)
    }
    if trainer.config.use_whitening {
        let adv_mean = advantages.mean()
        let adv_std = advantages.std()
        advantages = (advantages - adv_mean) / (adv_std + 1e-8)
    }
    return advantages
}

func (trainer: *otb_trainer) train_step(
    prompts: []tensor,
    responses: []tensor,
    rewards: []tensor
) -> (f32, f32, f32) {
    let batch_size = prompts.len()
    let inputs: []tensor = []
    for i in 0..batch_size {
        inputs.push(concat(prompts[i], responses[i]))
    }
    let total_policy_loss: f32 = 0.0
    let total_baseline_loss: f32 = 0.0
    let total_entropy: f32 = 0.0
    let num_updates = 0
    for epoch in 0..trainer.config.num_epochs {
        for i in 0..batch_size {
            let advantages = trainer.compute_advantages(
                responses[i],
                rewards[i]
            )
            let logits = trainer.policy_model.forward(inputs[i])
            let log_probs = log_softmax(logits, dim: -1)
            let policy_obj: Tensor
            if trainer.config.use_clipping {
                policy_obj = log_probs * advantages
            } else {
                policy_obj = log_probs * advantages
            }
            let policy_loss = -policy_obj.mean()
            let probs = exp(log_probs)
            let entropy = -(probs * log_probs).sum()
            let loss = policy_loss - trainer.config.entropy_coeff * entropy
            loss.backward()
            total_policy_loss += policy_loss.item()
            total_entropy += entropy.item()
            let baseline_loss = tensor_zeros([1])
            if trainer.config.use_learned_baseline {
                let predicted_baseline = trainer.baseline_model.forward(responses[i])
                baseline_loss = (predicted_baseline - rewards[i]).pow(2).mean()
                baseline_loss = baseline_loss * trainer.config.baseline_loss_coeff
                baseline_loss.backward()
                total_baseline_loss += baseline_loss.item()
            }
            num_updates += 1
        }
        clip_grad_norm(trainer.policy_model.parameters(), trainer.config.max_grad_norm)
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
        if trainer.config.use_learned_baseline {
            clip_grad_norm(trainer.baseline_model.parameters(), trainer.config.max_grad_norm)
            trainer.baseline_optimizer.step()
            trainer.baseline_optimizer.zero_grad()
        }
    }
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_baseline_loss / f32(num_updates),
        total_entropy / f32(num_updates)
    )
}

func (trainer: *otb_trainer) train(train_data: DataLoader) -> []f32 {
    let policy_losses: []f32 = []
    for batch in train_data {
        let policy_loss, baseline_loss, entropy = trainer.train_step(
            batch.prompts,
            batch.responses,
            batch.rewards
        )
        policy_losses.push(policy_loss)
        if trainer.step_count % 10 == 0 {
            println(f"Step {trainer.step_count} (OTB {trainer.config.baseline_type}):")
            println(f"  Policy Loss = {policy_loss:.4f}, " +
                   f"Entropy = {entropy:.4f}")
            if trainer.config.use_learned_baseline {
                println(f"  Baseline Loss = {baseline_loss:.4f}")
            }
            if trainer.config.compute_variance {
                let variance_reduction =
                    (trainer.advantage_variance_before - trainer.advantage_variance_after) /
                    (trainer.advantage_variance_before + 1e-8)
                println(f"  Variance Reduction = {variance_reduction:.2%}")
                println(f"  Before = {trainer.advantage_variance_before:.4f}, " +
                       f"After = {trainer.advantage_variance_after:.4f}")
            }
            println(f"  Token Baselines Tracked = {trainer.token_ema_baselines.len()}")
        }
    }
    return policy_losses
}

func (trainer: *otb_trainer) get_variance_reduction() -> f32 {
    if trainer.advantage_variance_before < 1e-8 {
        return 0.0
    }
    return (trainer.advantage_variance_before - trainer.advantage_variance_after) /
           trainer.advantage_variance_before
}

func compute_variance_tensor(x: Tensor) -> f32 {
    let mean = x.mean()
    let variance = (x - mean).pow(2).mean()
    return variance.item()
}

func compute_mean(values: []f32) -> f32 {
    if values.len() == 0 {
        return 0.0
    }
    let sum: f32 = 0.0
    for v in values {
        sum += v
    }
    return sum / f32(values.len())
}

func compute_variance(values: []f32, mean: f32) -> f32 {
    if values.len() == 0 {
        return 0.0
    }
    let sum_sq: f32 = 0.0
    for v in values {
        sum_sq += (v - mean) * (v - mean)
    }
    return sum_sq / f32(values.len())
}

