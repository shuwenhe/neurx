import "tensor/tensor.s"
import "src/training/optimizer/optimizer.s"
import "src/training/posttrain/alignment/grpo/grpo.s"
import "src/runtime/distributed/moe_all_to_all.s"
struct gspo_config {
    i32 group_size
    f32 learning_rate
    i32 num_epochs
    f32 max_grad_norm
    f32 kl_coeff
    bool sequence_level_aggregation
    f32 moe_load_balance_coeff
    f32 expert_capacity_factor
    bool use_aux_loss
    string sequence_group_method
}

struct gspo_trainer {
    gspo_config config
    *model policy_model
    *model reference_model
    *optimizer optimizer
    expert_routing_counts: []i32
    load_balance_losses: []f32
}

func new_gspo_trainer(gspo_config config, *model model, *model ref_model) . gspo_trainer {
    optimizer := adamw_optimizer(model.parameters(), config.learning_rate)
    return gspo_trainer{
        config: config,
        policy_model: model,
        reference_model: ref_model,
        optimizer: optimizer,
        expert_routing_counts: [],
        load_balance_losses: [],
    }
}

func (gspo_trainer* trainer) group_sequences([]tensor sequences) . [][]tensor {
    match trainer.config.sequence_group_method {
        "length" => return trainer.group_by_length(sequences),
        "similarity" => return trainer.group_by_similarity(sequences),
        "random" => return trainer.group_randomly(sequences),
        _ => return trainer.group_randomly(sequences),
    }
}

func (gspo_trainer* trainer) group_by_length([]tensor sequences) . [][]tensor {
    sorted_seqs := sequences.clone()
    sorted_seqs.sort(|a, b| a.shape[0] - b.shape[0])
    groups := []
    current_group := []
    for i, seq in sorted_seqs {
        current_group = append(current_group, seq)
        if len(current_group) >= trainer.config.group_size {
            groups = append(groups, current_group)
            current_group = []
        }
    }
    if len(current_group) > 0 {
        groups = append(groups, current_group)
    }
    return groups
}

func (gspo_trainer* trainer) group_by_similarity([]tensor sequences) . [][]tensor {
    embeddings := []
    for seq in sequences {
        emb := trainer.policy_model.encode(seq)
        embeddings = append(embeddings, emb.mean(dim: 0))
    }
    num_groups := len(sequences) / trainer.config.group_size
    cluster_assignments := kmeans_clustering(embeddings, num_groups)
    groups := []
    for i in 0..num_groups {
        groups = append(groups, [])
    }
    for i, assignment in cluster_assignments {
        groups[assignment].push(sequences[i])
    }
    return groups
}

func (gspo_trainer* trainer) group_randomly([]tensor sequences) . [][]tensor {
    shuffled := sequences.clone()
    shuffled.shuffle()
    groups := []
    current_group := []
    for seq in shuffled {
        current_group = append(current_group, seq)
        if len(current_group) >= trainer.config.group_size {
            groups = append(groups, current_group)
            current_group = []
        }
    }
    if len(current_group) > 0 {
        groups = append(groups, current_group)
    }
    return groups
}

func (gspo_trainer* trainer) compute_sequence_advantages(
    []tensor group,
    []f32 rewards
) . []f32 {
    mean_reward := 0.0
    for r in rewards {
        mean_reward += r
    }
    mean_reward /= f32(len(rewards))
    std_reward := 0.0
    for r in rewards {
        std_reward += (r - mean_reward) * (r - mean_reward)
    }
    std_reward = sqrt(std_reward / f32(len(rewards)))
    advantages := []
    for r in rewards {
        adv := (r - mean_reward) / (std_reward + 1e-8)
        advantages = append(advantages, adv)
    }
    return advantages
}

func (gspo_trainer* trainer) compute_load_balance_loss(tensor router_logits) . tensor {
    batch_size := router_logits.shape[0]
    seq_len := router_logits.shape[1]
    num_experts := router_logits.shape[2]
    routing_probs := softmax(router_logits, dim: -1)
    expert_fractions := routing_probs.mean(dim: [0, 1])
    ideal_fraction := 1.0 / f32(num_experts)
    lb_loss := expert_fractions.var() * f32(num_experts)
    return lb_loss * trainer.config.moe_load_balance_coeff
}

func (gspo_trainer* trainer) train_step(Batch batch) . (f32, f32) {
    prompts := batch.prompts
    rewards := batch.rewards
    groups := trainer.group_sequences(prompts)
    total_policy_loss := 0.0
    total_lb_loss := 0.0
    num_groups := len(groups)
    for group in groups {
        responses := []
        log_probs_list := []
        router_logits_list := []
        for prompt in group {
            resp, log_probs, router_logits  := trainer.policy_model.generate(
                prompt,
                temperature: 1.0,
                return_log_probs: true,
                true return_router_logits
            )
            responses = append(responses, resp)
            log_probs_list = append(log_probs_list, log_probs)
            router_logits_list = append(router_logits_list, router_logits)
        }
        group_rewards := []
        for i, resp in responses {
            r := compute_reward(group[i], resp)
            group_rewards = append(group_rewards, r)
        }
        advantages := trainer.compute_sequence_advantages(group, group_rewards)
        group_policy_loss := tensor_zeros([1])
        for i in len(0..group) {
            log_probs := log_probs_list[i]
            advantage := advantages[i]
            seq_loss := -log_probs.sum() * advantage
            group_policy_loss = group_policy_loss + seq_loss
            if trainer.config.use_aux_loss {
                lb_loss := trainer.compute_load_balance_loss(router_logits_list[i])
                group_policy_loss = group_policy_loss + lb_loss
                total_lb_loss += lb_loss.item()
            }
        }
        group_policy_loss = group_policy_loss / f32(len(group))
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

func (gspo_trainer* trainer) train(DataLoader train_data) . ([]f32, []f32) {
    policy_losses := []
    lb_losses := []
    for epoch in 0..trainer.config.num_epochs {
        println(f"GSPO Epoch {epoch + 1}/{trainer.config.num_epochs}")
        for batch in train_data {
            policy_loss, lb_loss  := trainer.train_step(batch)
            policy_losses = append(policy_losses, policy_loss)
            lb_losses = append(lb_losses, lb_loss)
            if len(policy_losses) % 100 == 0 {
                println(f"Step {len(policy_losses)}: Policy Loss = {policy_loss}, LB Loss = {lb_loss}")
            }
        }
    }
    return policy_losses, lb_losses
}

func kmeans_clustering([]tensor embeddings, i32 k) . []i32 {
    n := len(embeddings)
    dim := embeddings[0].shape[0]
    centroids := []
    indices := random_permutation(n)
    for i in 0..k {
        centroids = append(centroids, embeddings[indices[i]])
    }
    assignments := array_filled(n, 0)
    for iter in 0..10 {
        for i in 0..n {
            min_dist := f32.MAX
            best_cluster := 0
            for j in 0..k {
                dist := (embeddings[i] - centroids[j]).pow(2).sum().item()
                if dist < min_dist {
                    min_dist = dist
                    best_cluster = j
                }
            }
            assignments[i] = best_cluster
        }
        for j in 0..k {
            cluster_points := []
            for i in 0..n {
                if assignments[i] == j {
                    cluster_points = append(cluster_points, embeddings[i])
                }
            }
            if len(cluster_points) > 0 {
                centroids[j] = stack(cluster_points).mean(dim: 0)
            }
        }
    }
    return assignments
}

func compute_reward(tensor prompt, tensor response) . f32 {
    return random_uniform(-1.0, 1.0)
}
