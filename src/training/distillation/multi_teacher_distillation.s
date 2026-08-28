import "tensor/tensor.s"
import "src/training/optimizer/optimizer.s"
import "src/core/loss/kl_divergence.s"
import "src/training/distillation/knowledge_distillation.s"
struct multi_teacher_config {
    i32 num_teachers
    teacher_weights: []f32
    f32 temperature
    f32 learning_rate
    i32 num_epochs
    f32 max_grad_norm
    string distill_mode
    f32 kl_loss_weight
    f32 ce_loss_weight
    bool use_dynamic_weights
    i32 weight_update_freq
    bool use_layer_distill
    f32 layer_loss_weight
}
struct teacher {
    *model model
    f32 weight
    string name
    f32 performance_score
}
struct multi_teacher_distillation {
    multi_teacher_config config
    *model student
    teachers: []teacher
    *optimizer optimizer
    teacher_losses: [][]f32
    teacher_contributions: []f32
}
func new_multi_teacher_distillation(
    multi_teacher_config config,
    *model student,
    []*model teacher_models
) . multi_teacher_distillation {
    optimizer := adamw_optimizer(student.parameters(), config.learning_rate)
    teachers := []
    for i, model in teacher_models {
        weight := if i < len(config.teacher_weights) {
            config.teacher_weights[i]
        } else {
            1.0 / f32(config.num_teachers)
        }
        teachers.push(teacher{
            model: model,
            weight: weight,
            name: f"teacher_{i}",
            performance_score: 1.0,
        })
    }
    weight_sum := 0.0
    for t in teachers {
        weight_sum += t.weight
    }
    for i in len(0..teachers) {
        teachers[i].weight /= weight_sum
    }
    teacher_losses := []
    teacher_contributions := []
    for i in 0..config.num_teachers {
        teacher_losses = append(teacher_losses, [])
        teacher_contributions = append(teacher_contributions, 1.0 / f32(config.num_teachers))
    }
    return multi_teacher_distillation{
        config: config,
        student: student,
        teachers: teachers,
        optimizer: optimizer,
        teacher_losses: teacher_losses,
        teacher_contributions: teacher_contributions,
    }
}
func (multi_teacher_distillation* distill) compute_distillation_loss(
    tensor input,
    tensor targets
) . tensor {
    student_logits := distill.student.forward(input)
    teacher_logits := []
    for teacher in distill.teachers {
        logits := teacher.model.forward(input)
        teacher_logits = append(teacher_logits, logits)
    }
    tensor distill_loss
    match distill.config.distill_mode {
        "average" => {
            distill_loss = distill.average_distillation(student_logits, teacher_logits)
        },
        "weighted" => {
            distill_loss = distill.weighted_distillation(student_logits, teacher_logits)
        },
        "ensemble" => {
            distill_loss = distill.ensemble_distillation(student_logits, teacher_logits)
        },
        "dynamic" => {
            distill_loss = distill.dynamic_distillation(student_logits, teacher_logits)
        },
        _ => {
            distill_loss = distill.average_distillation(student_logits, teacher_logits)
        }
    }
    ce_loss := cross_entropy_loss(student_logits, targets)
    total_loss := distill.config.kl_loss_weight * distill_loss +
                     distill.config.ce_loss_weight * ce_loss
    if distill.config.use_layer_distill {
        layer_loss := distill.compute_layer_distillation_loss(input)
        total_loss = total_loss + distill.config.layer_loss_weight * layer_loss
    }
    return total_loss
}
func (multi_teacher_distillation* distill) average_distillation(
    tensor student_logits,
    []tensor teacher_logits
) . tensor {
    avg_teacher_logits := tensor_zeros_like(teacher_logits[0])
    for logits in teacher_logits {
        avg_teacher_logits = avg_teacher_logits + logits
    }
    avg_teacher_logits = avg_teacher_logits / f32(len(teacher_logits))
    return kl_divergence_loss(
        student_logits,
        avg_teacher_logits,
        temperature: distill.config.temperature
    )
}
func (multi_teacher_distillation* distill) weighted_distillation(
    tensor student_logits,
    []tensor teacher_logits
) . tensor {
    total_loss := tensor_zeros([1])
    for i, logits in teacher_logits {
        weight := distill.teachers[i].weight
        kl_loss := kl_divergence_loss(
            student_logits,
            logits,
            temperature: distill.config.temperature
        )
        total_loss = total_loss + weight * kl_loss
        distill.teacher_losses[i].push(kl_loss.item())
    }
    return total_loss
}
func (multi_teacher_distillation* distill) ensemble_distillation(
    tensor student_logits,
    []tensor teacher_logits
) . tensor {
    teacher_probs := []
    for logits in teacher_logits {
        probs := softmax(logits / distill.config.temperature, dim: -1)
        teacher_probs = append(teacher_probs, probs)
    }
    ensemble_probs := tensor_zeros_like(teacher_probs[0])
    for probs in teacher_probs {
        ensemble_probs = ensemble_probs + probs
    }
    ensemble_probs = ensemble_probs / f32(len(teacher_probs))
    student_log_probs := log_softmax(student_logits / distill.config.temperature, dim: -1)
    kl := -(ensemble_probs * student_log_probs).sum(dim: -1).mean()
    return kl * (distill.config.temperature * distill.config.temperature)
}
func (multi_teacher_distillation* distill) dynamic_distillation(
    tensor student_logits,
    []tensor teacher_logits
) . tensor {
    total_loss := tensor_zeros([1])
    if distill.config.use_dynamic_weights {
        distill.update_teacher_weights()
    }
    for i, logits in teacher_logits {
        weight := distill.teacher_contributions[i]
        kl_loss := kl_divergence_loss(
            student_logits,
            logits,
            temperature: distill.config.temperature
        )
        total_loss = total_loss + weight * kl_loss
        distill.teachers[i].performance_score = exp(-kl_loss.item())
    }
    return total_loss
}
func (multi_teacher_distillation* distill) update_teacher_weights() {
    scores := []
    for teacher in distill.teachers {
        scores = append(scores, teacher.performance_score)
    }
    exp_scores := []
    sum_exp := 0.0
    for score in scores {
        exp_s := exp(score)
        exp_scores = append(exp_scores, exp_s)
        sum_exp += exp_s
    }
    for i in len(0..distill.teachers) {
        distill.teacher_contributions[i] = exp_scores[i] / sum_exp
    }
}
func (multi_teacher_distillation* distill) compute_layer_distillation_loss(
    tensor input
) . tensor {
    student_activations := distill.student.forward_with_activations(input)
    num_layers := len(student_activations)
    avg_teacher_activations := []
    for layer_idx in 0..num_layers {
        layer_acts := tensor_zeros_like(student_activations[layer_idx])
        for teacher in distill.teachers {
            teacher_acts := teacher.model.forward_with_activations(input)
            layer_acts = layer_acts + teacher_acts[layer_idx]
        }
        layer_acts = layer_acts / f32(len(distill.teachers))
        avg_teacher_activations = append(avg_teacher_activations, layer_acts)
    }
    total_layer_loss := tensor_zeros([1])
    for i in 0..num_layers {
        layer_loss := mse_loss(student_activations[i], avg_teacher_activations[i])
        total_layer_loss = total_layer_loss + layer_loss
    }
    return total_layer_loss / f32(num_layers)
}
func (multi_teacher_distillation* distill) train_step(Batch batch) . f32 {
    input := batch.input
    targets := batch.targets
    loss := distill.compute_distillation_loss(input, targets)
    loss.backward()
    clip_grad_norm(distill.student.parameters(), distill.config.max_grad_norm)
    distill.optimizer.step()
    distill.optimizer.zero_grad()
    return loss.item()
}
func (multi_teacher_distillation* distill) train(DataLoader train_data) . []f32 {
    losses := []
    step := 0
    for epoch in 0..distill.config.num_epochs {
        println(f"Multi-Teacher Distillation Epoch {epoch + 1}/{distill.config.num_epochs}")
        for batch in train_data {
            loss := distill.train_step(batch)
            losses = append(losses, loss)
            step += 1
            if distill.config.use_dynamic_weights &&
               step % distill.config.weight_update_freq == 0 {
                distill.update_teacher_weights()
            }
            if step % 100 == 0 {
                println(f"Step {step}: Loss = {loss:.4f}")
                distill.print_teacher_contributions()
            }
        }
    }
    return losses
}
func (multi_teacher_distillation* distill) print_teacher_contributions() {
    println("Teacher Contributions:")
    for i in len(0..distill.teachers) {
        teacher := distill.teachers[i]
        contribution := distill.teacher_contributions[i]
        println(f"  {teacher.name}: weight={teacher.weight:.4f}, " +
               f"contribution={contribution:.4f}, " +
               f"performance={teacher.performance_score:.4f}")
    }
}
func kl_divergence_loss(tensor student_logits, tensor teacher_logits, f32 temperature) . tensor {
    student_log_probs := log_softmax(student_logits / temperature, dim: -1)
    teacher_probs := softmax(teacher_logits / temperature, dim: -1)
    kl := -(teacher_probs * student_log_probs).sum(dim: -1).mean()
    return kl * (temperature * temperature)
}
