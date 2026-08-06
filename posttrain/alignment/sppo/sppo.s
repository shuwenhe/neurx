import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "loss/cross_entropy.s"
import "nn/linear.s"
import "posttrain/alignment/base_algorithm.s"
struct sppo_config {
    beta: f32
    learning_rate: f32
    num_iterations: i32
    win_rate_threshold: f32
    max_grad_norm: f32
    use_margin: bool
    margin: f32
}

struct sppo_trainer {
    config: sppo_config
    policy_model: *model
    reference_model: *model
    optimizer: *optimizer
    iteration: i32
    win_rates: []f32
    trajectory_buffer: []trajectory
}

struct trajectory {
    prompt: tensor
    response: tensor
    log_probs: tensor
    reward: f32
    win_rate: f32
}

func new_sppo_trainer(config: sppo_config, model: *model, ref_model: *model) -> sppo_trainer {
    let optimizer = adamw_optimizer(model.parameters(), config.learning_rate)
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

func (trainer: *sppo_trainer) self_play_rollout(prompts: tensor, num_samples: i32) -> []trajectory {
    let trajectories: []trajectory = []
    for i in 0..prompts.shape[0] {
        let prompt = prompts[i]
        for j in 0..num_samples {
            let response, log_probs = trainer.policy_model.generate(
                prompt,
                temperature: 1.0,
                top_p: 0.95,
                return_log_probs: true
            )
            let reward = trainer.compute_self_play_reward(prompt, response)
            let traj = trajectory{
                prompt: prompt,
                response: response,
                log_probs: log_probs,
                reward: reward,
                win_rate: 0.0,
            }
            trajectories.push(traj)
        }
    }
    return trajectories
}

func (trainer: *sppo_trainer) compute_self_play_reward(prompt: tensor, response: tensor) -> f32 {
    let logits = trainer.policy_model.forward(concat(prompt, response))
    let ref_logits = trainer.reference_model.forward(concat(prompt, response))
    let kl_div = compute_kl_divergence(logits, ref_logits)
    return -kl_div
}

func (trainer: *sppo_trainer) compute_win_rates(trajectories: []trajectory) -> []trajectory {
    let n = trajectories.len()
    for i in 0..n {
        let wins = 0
        let total = 0
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

func (trainer: *sppo_trainer) create_preference_pairs(trajectories: []trajectory) -> ([]trajectory, []trajectory) {
    let chosen: []trajectory = []
    let rejected: []trajectory = []
    let prompt_groups: map[string][]trajectory = {}
    for traj in trajectories {
        let key = traj.prompt.to_string()
        if key not in prompt_groups {
            prompt_groups[key] = []
        }
        prompt_groups[key].push(traj)
    }
    for _, group in prompt_groups {
        group.sort(|a, b| b.win_rate - a.win_rate)
        let mid = group.len() / 2
        for i in 0..mid {
            chosen.push(group[i])
            rejected.push(group[group.len() - 1 - i])
        }
    }
    return chosen, rejected
}

func (trainer: *sppo_trainer) compute_sppo_loss(
    chosen: []trajectory,
    rejected: []trajectory
) -> tensor {
    let batch_size = chosen.len()
    let total_loss = tensor_zeros([1])
    for i in 0..batch_size {
        let chosen_traj = chosen[i]
        let rejected_traj = rejected[i]
        let chosen_input = concat(chosen_traj.prompt, chosen_traj.response)
        let chosen_logits = trainer.policy_model.forward(chosen_input)
        let chosen_log_probs = log_softmax(chosen_logits, dim: -1)
        let rejected_input = concat(rejected_traj.prompt, rejected_traj.response)
        let rejected_logits = trainer.policy_model.forward(rejected_input)
        let rejected_log_probs = log_softmax(rejected_logits, dim: -1)
        let ref_chosen_logits = trainer.reference_model.forward(chosen_input)
        let ref_chosen_log_probs = log_softmax(ref_chosen_logits, dim: -1)
        let ref_rejected_logits = trainer.reference_model.forward(rejected_input)
        let ref_rejected_log_probs = log_softmax(ref_rejected_logits, dim: -1)
        let chosen_log_ratio = (chosen_log_probs - ref_chosen_log_probs).sum()
        let rejected_log_ratio = (rejected_log_probs - ref_rejected_log_probs).sum()
        let logits_diff = chosen_log_ratio - rejected_log_ratio
        let loss: tensor
        if trainer.config.use_margin {
            loss = -log_sigmoid(trainer.config.beta * logits_diff - trainer.config.margin)
        } else {
            loss = -log_sigmoid(trainer.config.beta * logits_diff)
        }
        total_loss = total_loss + loss
    }
    return total_loss / f32(batch_size)
}

func (trainer: *sppo_trainer) train_step(prompts: tensor) -> f32 {
    let trajectories = trainer.self_play_rollout(prompts, num_samples: 4)
    trajectories = trainer.compute_win_rates(trajectories)
    let chosen, rejected = trainer.create_preference_pairs(trajectories)
    let filtered_chosen: []trajectory = []
    let filtered_rejected: []trajectory = []
    for i in 0..chosen.len() {
        if chosen[i].win_rate >= trainer.config.win_rate_threshold {
            filtered_chosen.push(chosen[i])
            filtered_rejected.push(rejected[i])
        }
    }
    if filtered_chosen.len() == 0 {
        return 0.0
    }
    let loss = trainer.compute_sppo_loss(filtered_chosen, filtered_rejected)
    loss.backward()
    clip_grad_norm(trainer.policy_model.parameters(), trainer.config.max_grad_norm)
    trainer.optimizer.step()
    trainer.optimizer.zero_grad()
    trainer.iteration += 1
    return loss.item()
}

func (trainer: *sppo_trainer) train(train_data: DataLoader) -> []f32 {
    let losses: []f32 = []
    for batch in train_data {
        let prompts = batch.prompts
        let loss = trainer.train_step(prompts)
        losses.push(loss)
        if trainer.iteration % 100 == 0 {
            println(f"Iteration {trainer.iteration}, Loss: {loss}")
        }
    }
    return losses
}

func compute_kl_divergence(p_logits: tensor, q_logits: tensor) -> f32 {
    let p = softmax(p_logits, dim: -1)
    let log_p = log_softmax(p_logits, dim: -1)
    let log_q = log_softmax(q_logits, dim: -1)
    let kl = (p * (log_p - log_q)).sum()
    return kl.item()
}

func log_sigmoid(x: tensor) -> tensor {
    return -softplus(-x)
}

func softplus(x: tensor) -> tensor {
    return log(1.0 + exp(x))
}
