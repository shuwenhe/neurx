import "tensor/tensor.s"
import "src/training/optimizer/optimizer.s"
import "src/core/loss/cross_entropy.s"
import "src/core/nn/linear.s"
import "src/training/posttrain/alignment/base_algorithm.s"
struct sppo_config {
    f32 beta
    f32 learning_rate
    i32 num_iterations
    f32 win_rate_threshold
    f32 max_grad_norm
    bool use_margin
    f32 margin
}
struct sppo_trainer {
    sppo_config config
    *model policy_model
    *model reference_model
    *optimizer optimizer
    i32 iteration
    win_rates: []f32
    trajectory_buffer: []trajectory
}
struct trajectory {
    tensor prompt
    tensor response
    tensor log_probs
    f32 reward
    f32 win_rate
}
func new_sppo_trainer(sppo_config config, *model model, *model ref_model) . sppo_trainer {
    optimizer := adamw_optimizer(model.parameters(), config.learning_rate)
    return sppo_trainer{
        config: config,
        policy_model: model,
        reference_model: ref_model,
        optimizer: optimizer,
        iteration: 0,
        win_rates: [],
        trajectory_buffer: [],
    }
}
func (sppo_trainer* trainer) self_play_rollout(tensor prompts, i32 num_samples) . []trajectory {
    trajectories := []
    for i in 0..prompts.shape[0] {
        prompt := prompts[i]
        for j in 0..num_samples {
            response, log_probs  := trainer.policy_model.generate(
                prompt,
                temperature: 1.0,
                top_p: 0.95,
                true return_log_probs
            )
            reward := trainer.compute_self_play_reward(prompt, response)
            traj := trajectory{
                prompt: prompt,
                response: response,
                log_probs: log_probs,
                reward: reward,
                win_rate: 0.0,
            }
            trajectories = append(trajectories, traj)
        }
    }
    return trajectories
}
func (sppo_trainer* trainer) compute_self_play_reward(tensor prompt, tensor response) . f32 {
    logits := trainer.policy_model.forward(concat(prompt, response))
    ref_logits := trainer.reference_model.forward(concat(prompt, response))
    kl_div := compute_kl_divergence(logits, ref_logits)
    return -kl_div
}
func (sppo_trainer* trainer) compute_win_rates([]trajectory trajectories) . []trajectory {
    n := len(trajectories)
    for i in 0..n {
        wins := 0
        total := 0
        for j in 0..n {
            if i == j {
                continue
            }
            if trajectories[i].prompt.equals(trajectories[j].prompt) {
                total += 1
                if trajectories[i].reward > trajectories[j].reward {
                    wins += 1
                }
            }
        }
        if total > 0 {
            trajectories[i].win_rate = f32(wins) / f32(total)
        }
    }
    return trajectories
}
func (sppo_trainer* trainer) create_preference_pairs([]trajectory trajectories) . ([]trajectory, []trajectory) {
    chosen := []
    rejected := []
    prompt_groups := {}
    for traj in trajectories {
        key := traj.prompt.to_string()
        if key not in prompt_groups {
            prompt_groups[key] = []
        }
        prompt_groups[key].push(traj)
    }
    for _, group in prompt_groups {
        group.sort(|a, b| b.win_rate - a.win_rate)
        mid := len(group) / 2
        for i in 0..mid {
            chosen = append(chosen, group[i])
            rejected = append(rejected, group[len(group) - 1 - i])
        }
    }
    return chosen, rejected
}
func (sppo_trainer* trainer) compute_sppo_loss(
    []trajectory chosen,
    []trajectory rejected
) . tensor {
    batch_size := len(chosen)
    total_loss := tensor_zeros([1])
    for i in 0..batch_size {
        chosen_traj := chosen[i]
        rejected_traj := rejected[i]
        chosen_input := concat(chosen_traj.prompt, chosen_traj.response)
        chosen_logits := trainer.policy_model.forward(chosen_input)
        chosen_log_probs := log_softmax(chosen_logits, dim: -1)
        rejected_input := concat(rejected_traj.prompt, rejected_traj.response)
        rejected_logits := trainer.policy_model.forward(rejected_input)
        rejected_log_probs := log_softmax(rejected_logits, dim: -1)
        ref_chosen_logits := trainer.reference_model.forward(chosen_input)
        ref_chosen_log_probs := log_softmax(ref_chosen_logits, dim: -1)
        ref_rejected_logits := trainer.reference_model.forward(rejected_input)
        ref_rejected_log_probs := log_softmax(ref_rejected_logits, dim: -1)
        chosen_log_ratio := (chosen_log_probs - ref_chosen_log_probs).sum()
        rejected_log_ratio := (rejected_log_probs - ref_rejected_log_probs).sum()
        logits_diff := chosen_log_ratio - rejected_log_ratio
        tensor loss
        if trainer.config.use_margin {
            loss = -log_sigmoid(trainer.config.beta * logits_diff - trainer.config.margin)
        } else {
            loss = -log_sigmoid(trainer.config.beta * logits_diff)
        }
        total_loss = total_loss + loss
    }
    return total_loss / f32(batch_size)
}
func (sppo_trainer* trainer) train_step(tensor prompts) . f32 {
    trajectories := trainer.self_play_rollout(prompts, num_samples: 4)
    trajectories = trainer.compute_win_rates(trajectories)
    chosen, rejected  := trainer.create_preference_pairs(trajectories)
    filtered_chosen := []
    filtered_rejected := []
    for i in len(0..chosen) {
        if chosen[i].win_rate >= trainer.config.win_rate_threshold {
            filtered_chosen = append(filtered_chosen, chosen[i])
            filtered_rejected = append(filtered_rejected, rejected[i])
        }
    }
    if len(filtered_chosen) == 0 {
        return 0.0
    }
    loss := trainer.compute_sppo_loss(filtered_chosen, filtered_rejected)
    loss.backward()
    clip_grad_norm(trainer.policy_model.parameters(), trainer.config.max_grad_norm)
    trainer.optimizer.step()
    trainer.optimizer.zero_grad()
    trainer.iteration += 1
    return loss.item()
}
func (sppo_trainer* trainer) train(DataLoader train_data) . []f32 {
    losses := []
    for batch in train_data {
        prompts := batch.prompts
        loss := trainer.train_step(prompts)
        losses = append(losses, loss)
        if trainer.iteration % 100 == 0 {
            println(f"Iteration {trainer.iteration}, Loss: {loss}")
        }
    }
    return losses
}
func compute_kl_divergence(tensor p_logits, tensor q_logits) . f32 {
    p := softmax(p_logits, dim: -1)
    log_p := log_softmax(p_logits, dim: -1)
    log_q := log_softmax(q_logits, dim: -1)
    kl := (p * (log_p - log_q)).sum()
    return kl.item()
}
func log_sigmoid(tensor x) . tensor {
    return -softplus(-x)
}
func softplus(tensor x) . tensor {
    return log(1.0 + exp(x))
}
