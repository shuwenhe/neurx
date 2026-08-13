import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "posttrain/alignment/grpo/grpo.s"
import "distributed/moe_all_to_all.s"

struct gspo_config {
    group_size: i32
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    kl_coeff: f32
    sequence_level_aggregation: bool
    moe_load_balance_coeff: f32
    expert_capacity_factor: f32
    use_aux_loss: bool
    sequence_group_method: string
}

struct gspo_trainer {
    config: gspo_config
    policy_model: *model
    reference_model: *model
    optimizer: *optimizer
    expert_routing_counts: []i32
    load_balance_losses: []f32
}

func new_gspo_trainer(config: gspo_config, model: *model, ref_model: *model) -> gspo_trainer {
    let optimizer = adamw_optimizer(model.parameters(), config.learning_rate)
    return gspo_trainer{
        config: config,
        policy_model: model,
        reference_model: ref_model,
        optimizer: optimizer,
        expert_routing_counts: [],
        load_balance_losses: [],
    }
}

func (trainer: *gspo_trainer) group_sequences(sequences: []tensor) -> [][]tensor {
    match trainer.config.sequence_group_method {
        "length" => return trainer.group_by_length(sequences),
        "similarity" => return trainer.group_by_similarity(sequences),
        "random" => return trainer.group_randomly(sequences),
        _ => return trainer.group_randomly(sequences),
    }
}

func (trainer: *gspo_trainer) group_by_length(sequences: []tensor) -> [][]tensor {
    let sorted_seqs = sequences.clone()
    sorted_seqs.sort(|a, b| a.shape[0] - b.shape[0])
    let groups: [][]tensor = []
    let current_group: []tensor = []
    for i, seq in sorted_seqs {
        current_group.push(seq)
        if current_group.len() >= trainer.config.group_size {
            groups.push(current_group)
            current_group = []
        }
    }
    if current_group.len() > 0 {
        groups.push(current_group)
    }
    return groups
}

func (trainer: *gspo_trainer) group_by_similarity(sequences: []tensor) -> [][]tensor {
    let embeddings: []tensor = []
    for seq in sequences {
        let emb = trainer.policy_model.encode(seq)
        embeddings.push(emb.mean(dim: 0))
    }
    let num_groups = sequences.len() / trainer.config.group_size
    let cluster_assignments = kmeans_clustering(embeddings, num_groups)
    let groups: [][]tensor = []
    for i in 0..num_groups {
        groups.push([])
    }
    for i, assignment in cluster_assignments {
        groups[assignment].push(sequences[i])
    }
    return groups
}

func (trainer: *gspo_trainer) group_randomly(sequences: []tensor) -> [][]tensor {
    let shuffled = sequences.clone()
    shuffled.shuffle()
    let groups: [][]tensor = []
    let current_group: []tensor = []
    for seq in shuffled {
        current_group.push(seq)
        if current_group.len() >= trainer.config.group_size {
            groups.push(current_group)
            current_group = []
        }
    }
    if current_group.len() > 0 {
        groups.push(current_group)
    }
    return groups
}

func (trainer: *gspo_trainer) compute_sequence_advantages(
    group: []tensor,
    rewards: []f32
) -> []f32 {
    let mean_reward: f32 = 0.0
    for r in rewards {
        mean_reward += r
    }
    mean_reward /= f32(rewards.len())
    let std_reward: f32 = 0.0
    for r in rewards {
        std_reward += (r - mean_reward) * (r - mean_reward)
    }
    std_reward = sqrt(std_reward / f32(rewards.len()))
    let advantages: []f32 = []
    for r in rewards {
        let adv = (r - mean_reward) / (std_reward + 1e-8)
        advantages.push(adv)
    }
    return advantages
}

func (trainer: *gspo_trainer) compute_load_balance_loss(router_logits: tensor) -> tensor {
    let batch_size = router_logits.shape[0]
    let seq_len = router_logits.shape[1]
    let num_experts = router_logits.shape[2]
    let routing_probs = softmax(router_logits, dim: -1)
    let expert_fractions = routing_probs.mean(dim: [0, 1])
    let ideal_fraction = 1.0 / f32(num_experts)
    let lb_loss = expert_fractions.var() * f32(num_experts)
    return lb_loss * trainer.config.moe_load_balance_coeff
}

func (trainer: *gspo_trainer) train_step(batch: Batch) -> (f32, f32) {
    let prompts = batch.prompts
    let rewards = batch.rewards
    let groups = trainer.group_sequences(prompts)
    let total_policy_loss: f32 = 0.0
    let total_lb_loss: f32 = 0.0
    let num_groups = groups.len()
    for group in groups {
        let responses: []tensor = []
        let log_probs_list: []tensor = []
        let router_logits_list: []tensor = []
        for prompt in group {
            let resp, log_probs, router_logits = trainer.policy_model.generate(
                prompt,
                temperature: 1.0,
                return_log_probs: true,
                return_router_logits: true
            )
            responses.push(resp)
            log_probs_list.push(log_probs)
            router_logits_list.push(router_logits)
        }
        let group_rewards: []f32 = []
        for i, resp in responses {
            let r = compute_reward(group[i], resp)
            group_rewards.push(r)
        }
        let advantages = trainer.compute_sequence_advantages(group, group_rewards)
        let group_policy_loss = tensor_zeros([1])
        for i in 0..group.len() {
            let log_probs = log_probs_list[i]
            let advantage = advantages[i]
            let seq_loss = -log_probs.sum() * advantage
            group_policy_loss = group_policy_loss + seq_loss
            if trainer.config.use_aux_loss {
                let lb_loss = trainer.compute_load_balance_loss(router_logits_list[i])
                group_policy_loss = group_policy_loss + lb_loss
                total_lb_loss += lb_loss.item()
            }
        }
        group_policy_loss = group_policy_loss / f32(group.len())
        total_policy_loss += group_policy_loss.item()
        group_policy_loss.backward()
    }
    total_policy_loss /= f32(num_groups)
    total_lb_loss /= f32(num_groups)
    clip_grad_norm(trainer.policy_model.parameters(), trainer.config.max_grad_norm)
    trainer.optimizer.step()
    trainer.optimizer.zero_grad()
    return total_policy_loss, total_lb_loss
}

func (trainer: *gspo_trainer) train(train_data: DataLoader) -> ([]f32, []f32) {
    let policy_losses: []f32 = []
    let lb_losses: []f32 = []
    for epoch in 0..trainer.config.num_epochs {
        println(f"GSPO Epoch {epoch + 1}/{trainer.config.num_epochs}")
        for batch in train_data {
            let policy_loss, lb_loss = trainer.train_step(batch)
            policy_losses.push(policy_loss)
            lb_losses.push(lb_loss)
            if policy_losses.len() % 100 == 0 {
                println(f"Step {policy_losses.len()}: Policy Loss = {policy_loss}, LB Loss = {lb_loss}")
            }
        }
    }
    return policy_losses, lb_losses
}

func kmeans_clustering(embeddings: []tensor, i32 k) -> []i32 {
    let n = embeddings.len()
    let dim = embeddings[0].shape[0]
    let centroids: []tensor = []
    let indices = random_permutation(n)
    for i in 0..k {
        centroids.push(embeddings[indices[i]])
    }
    let assignments: []i32 = array_filled(n, 0)
    for iter in 0..10 {
        for i in 0..n {
            let min_dist = f32.MAX
            let best_cluster = 0
            for j in 0..k {
                let dist = (embeddings[i] - centroids[j]).pow(2).sum().item()
                if dist < min_dist {
                    min_dist = dist
                    best_cluster = j
                }
            }
            assignments[i] = best_cluster
        }
        for j in 0..k {
            let cluster_points: []tensor = []
            for i in 0..n {
                if assignments[i] == j {
                    cluster_points.push(embeddings[i])
                }
            }
            if cluster_points.len() > 0 {
                centroids[j] = stack(cluster_points).mean(dim: 0)
            }
        }
    }
    return assignments
}

func compute_reward(prompt: tensor, response: tensor) -> f32 {
    return random_uniform(-1.0, 1.0)
}
