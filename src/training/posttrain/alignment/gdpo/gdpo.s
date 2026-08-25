import "tensor/tensor.s"
import "src/training/optimizer/optimizer.s"
import "src/training/posttrain/alignment/dpo/dpo.s"

struct gdpo_config {
    beta: f32
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    num_rewards: i32
    reward_weights: []f32
    use_weighted_loss: bool
    aggregation_method: string
    label_smoothing: f32
}

struct rubric {
    reward_names: []string
    reward_values: []f32
    weights: []f32
}

struct gdpo_trainer {
    config: gdpo_config
    policy_model: *model
    reference_model: *model
    optimizer: *optimizer
    reward_scales: []f32
    reward_histories: [][]f32
}

func new_gdpo_trainer(gdpo_config config, *model model, *model ref_model) . gdpo_trainer {
    optimizer := adamw_optimizer(model.parameters(), config.learning_rate)
    reward_scales := []
    reward_histories := []
    for i in 0..config.num_rewards {
        reward_scales.push(1.0)
        reward_histories.push([])
    }
    return gdpo_trainer{
        config: config,
        policy_model: model,
        reference_model: ref_model,
        optimizer: optimizer,
        reward_scales: reward_scales,
        reward_histories: reward_histories,
    }
}

func (gdpo_trainer* trainer) aggregate_rewards(rubric rubric) . f32 {
    aggregated := 0.0
    match trainer.config.aggregation_method {
        "sum" => {
            for r in rubric.reward_values {
                aggregated += r
            }
        },
        "max" => {
            aggregated = rubric.reward_values[0]
            for r in rubric.reward_values {
                if r > aggregated {
                    aggregated = r
                }
            }
        },
        "min" => {
            aggregated = rubric.reward_values[0]
            for r in rubric.reward_values {
                if r < aggregated {
                    aggregated = r
                }
            }
        },
        "weighted_sum" => {
            for i in 0..rubric.reward_values.len() {
                weight := if i < trainer.config.reward_weights.len() {
                    trainer.config.reward_weights[i]
                } else {
                    1.0
                }
                aggregated += rubric.reward_values[i] * weight
            }
        },
        _ => {
            for r in rubric.reward_values {
                aggregated += r
            }
        }
    }
    return aggregated
}

func (gdpo_trainer* trainer) normalize_rubric(rubric rubric) . rubric {
    normalized := rubric{
        reward_names: rubric.reward_names.clone(),
        reward_values: [],
        weights: rubric.weights.clone(),
    }
    for i in 0..rubric.reward_values.len() {
        trainer.reward_histories[i].push(rubric.reward_values[i])
        if trainer.reward_histories[i].len() > 1000 {
            trainer.reward_histories[i] = trainer.reward_histories[i][1..]
        }
        mean := compute_mean(trainer.reward_histories[i])
        std := compute_std(trainer.reward_histories[i], mean)
        normalized_value := (rubric.reward_values[i] - mean) / (std + 1e-8)
        normalized.reward_values.push(normalized_value)
        trainer.reward_scales[i] = std
    }
    return normalized
}

func (gdpo_trainer* trainer) compute_gdpo_loss(
    []tensor chosen_prompts,
    []tensor chosen_responses,
    []tensor rejected_prompts,
    []tensor rejected_responses,
    []rubric chosen_rubrics,
    []rubric rejected_rubrics
) . tensor {
    batch_size := chosen_prompts.len()
    total_loss := tensor_zeros([1])
    for i in 0..batch_size {
        norm_chosen_rubric := trainer.normalize_rubric(chosen_rubrics[i])
        norm_rejected_rubric := trainer.normalize_rubric(rejected_rubrics[i])
        chosen_reward := trainer.aggregate_rewards(norm_chosen_rubric)
        rejected_reward := trainer.aggregate_rewards(norm_rejected_rubric)
        chosen_input := concat(chosen_prompts[i], chosen_responses[i])
        rejected_input := concat(rejected_prompts[i], rejected_responses[i])
        chosen_logits := trainer.policy_model.forward(chosen_input)
        chosen_log_probs := log_softmax(chosen_logits, dim: -1).sum()
        rejected_logits := trainer.policy_model.forward(rejected_input)
        rejected_log_probs := log_softmax(rejected_logits, dim: -1).sum()
        ref_chosen_logits := trainer.reference_model.forward(chosen_input)
        ref_chosen_log_probs := log_softmax(ref_chosen_logits, dim: -1).sum()
        ref_rejected_logits := trainer.reference_model.forward(rejected_input)
        ref_rejected_log_probs := log_softmax(ref_rejected_logits, dim: -1).sum()
        chosen_log_ratio := chosen_log_probs - ref_chosen_log_probs
        rejected_log_ratio := rejected_log_probs - ref_rejected_log_probs
        reward_margin := chosen_reward - rejected_reward
        logits_diff := trainer.config.beta * (chosen_log_ratio - rejected_log_ratio)
        loss: tensor
        if trainer.config.label_smoothing > 0.0 {
            smooth_loss := -log_sigmoid(logits_diff)
            uniform_loss := log(2.0)
            loss = (1.0 - trainer.config.label_smoothing) * smooth_loss +
                   trainer.config.label_smoothing * uniform_loss
        } else {
            loss = -log_sigmoid(logits_diff)
        }
        loss = loss * (1.0 + abs(reward_margin))
        total_loss = total_loss + loss
    }
    return total_loss / f32(batch_size)
}

func (gdpo_trainer* trainer) train_step(
    []tensor chosen_prompts,
    []tensor chosen_responses,
    []tensor rejected_prompts,
    []tensor rejected_responses,
    []rubric chosen_rubrics,
    []rubric rejected_rubrics
) . f32 {
    loss := trainer.compute_gdpo_loss(
        chosen_prompts,
        chosen_responses,
        rejected_prompts,
        rejected_responses,
        chosen_rubrics,
        rejected_rubrics
    )
    loss.backward()
    clip_grad_norm(trainer.policy_model.parameters(), trainer.config.max_grad_norm)
    trainer.optimizer.step()
    trainer.optimizer.zero_grad()
    return loss.item()
}

func (gdpo_trainer* trainer) train(DataLoader train_data) . []f32 {
    losses := []
    for epoch in 0..trainer.config.num_epochs {
        println(f"GDPO Epoch {epoch + 1}/{trainer.config.num_epochs}")
        for batch in train_data {
            loss := trainer.train_step(
                batch.chosen_prompts,
                batch.chosen_responses,
                batch.rejected_prompts,
                batch.rejected_responses,
                batch.chosen_rubrics,
                batch.rejected_rubrics
            )
            losses.push(loss)
            if losses.len() % 100 == 0 {
                println(f"Step {losses.len()}: Loss = {loss}")
                trainer.print_reward_statistics()
            }
        }
    }
    return losses
}

func (gdpo_trainer* trainer) print_reward_statistics() {
    println("Reward Statistics:")
    for i in 0..trainer.config.num_rewards {
        if trainer.reward_histories[i].len() > 0 {
            mean := compute_mean(trainer.reward_histories[i])
            std := compute_std(trainer.reward_histories[i], mean)
            println(f"  Reward {i}: mean={mean:.4f}, std={std:.4f}")
        }
    }
}

func compute_mean([]f32 values) . f32 {
    if values.len() == 0 {
        return 0.0
    }
    sum := 0.0
    for v in values {
        sum += v
    }
    return sum / f32(values.len())
}

func compute_std([]f32 values, f32 mean) . f32 {
    if values.len() == 0 {
        return 1.0
    }
    sum_sq := 0.0
    for v in values {
        sum_sq += (v - mean) * (v - mean)
    }
    return sqrt(sum_sq / f32(values.len()))
}

func log_sigmoid(tensor x) . tensor {
    return -softplus(-x)
}

func softplus(tensor x) . tensor {
    return log(1.0 + exp(x))
}
