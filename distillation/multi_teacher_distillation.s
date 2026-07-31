import "tensor/tensor.s"
import "optimizer/optimizer.s"
import "loss/kl_divergence.s"
import "distillation/knowledge_distillation.s"
struct multi_teacher_config {
    num_teachers: i32
    teacher_weights: []f32
    temperature: f32
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    distill_mode: string
    kl_loss_weight: f32
    ce_loss_weight: f32
    use_dynamic_weights: bool
    weight_update_freq: i32
    use_layer_distill: bool
    layer_loss_weight: f32
}

struct teacher {
    model: *Model
    weight: f32
    name: string
    performance_score: f32
}

struct multi_teacher_distillation {
    config: multi_teacher_config
    student: *Model
    teachers: []teacher
    optimizer: *Optimizer
    teacher_losses: [][]f32
    teacher_contributions: []f32
}
func new_multi_teacher_distillation(
    config: multi_teacher_config,
    student: *Model,
    teacher_models: []*Model
) -> multi_teacher_distillation {
    let optimizer = adamw_optimizer(student.parameters(), config.learning_rate)
    let teachers: []teacher = []
    for i, model in teacher_models {
        let weight = if i < config.teacher_weights.len() {
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
    let weight_sum: f32 = 0.0
    for t in teachers {
        weight_sum += t.weight
    }
    for i in 0..teachers.len() {
        teachers[i].weight /= weight_sum
    }
    let teacher_losses: [][]f32 = []
    let teacher_contributions: []f32 = []
    for i in 0..config.num_teachers {
        teacher_losses.push([])
        teacher_contributions.push(1.0 / f32(config.num_teachers))
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

func (distill: *multi_teacher_distillation) compute_distillation_loss(
    input: tensor,
    targets: tensor
) -> tensor {
    let student_logits = distill.student.forward(input)
    let teacher_logits: []tensor = []
    for teacher in distill.teachers {
        let logits = teacher.model.forward(input)
        teacher_logits.push(logits)
    }
    let distill_loss: tensor
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
    let ce_loss = cross_entropy_loss(student_logits, targets)
    let total_loss = distill.config.kl_loss_weight * distill_loss +
                     distill.config.ce_loss_weight * ce_loss
    if distill.config.use_layer_distill {
        let layer_loss = distill.compute_layer_distillation_loss(input)
        total_loss = total_loss + distill.config.layer_loss_weight * layer_loss
    }
    return total_loss
}

func (distill: *multi_teacher_distillation) average_distillation(
    student_logits: tensor,
    teacher_logits: []tensor
) -> tensor {
    let avg_teacher_logits = tensor_zeros_like(teacher_logits[0])
    for logits in teacher_logits {
        avg_teacher_logits = avg_teacher_logits + logits
    }
    avg_teacher_logits = avg_teacher_logits / f32(teacher_logits.len())
    return kl_divergence_loss(
        student_logits,
        avg_teacher_logits,
        temperature: distill.config.temperature
    )
}

func (distill: *multi_teacher_distillation) weighted_distillation(
    student_logits: tensor,
    teacher_logits: []tensor
) -> tensor {
    let total_loss = tensor_zeros([1])
    for i, logits in teacher_logits {
        let weight = distill.teachers[i].weight
        let kl_loss = kl_divergence_loss(
            student_logits,
            logits,
            temperature: distill.config.temperature
        )
        total_loss = total_loss + weight * kl_loss
        distill.teacher_losses[i].push(kl_loss.item())
    }
    return total_loss
}

func (distill: *multi_teacher_distillation) ensemble_distillation(
    student_logits: tensor,
    teacher_logits: []tensor
) -> tensor {
    let teacher_probs: []tensor = []
    for logits in teacher_logits {
        let probs = softmax(logits / distill.config.temperature, dim: -1)
        teacher_probs.push(probs)
    }
    let ensemble_probs = tensor_zeros_like(teacher_probs[0])
    for probs in teacher_probs {
        ensemble_probs = ensemble_probs + probs
    }
    ensemble_probs = ensemble_probs / f32(teacher_probs.len())
    let student_log_probs = log_softmax(student_logits / distill.config.temperature, dim: -1)
    let kl = -(ensemble_probs * student_log_probs).sum(dim: -1).mean()
    return kl * (distill.config.temperature * distill.config.temperature)
}

func (distill: *multi_teacher_distillation) dynamic_distillation(
    student_logits: tensor,
    teacher_logits: []tensor
) -> tensor {
    let total_loss = tensor_zeros([1])
    if distill.config.use_dynamic_weights {
        distill.update_teacher_weights()
    }
    for i, logits in teacher_logits {
        let weight = distill.teacher_contributions[i]
        let kl_loss = kl_divergence_loss(
            student_logits,
            logits,
            temperature: distill.config.temperature
        )
        total_loss = total_loss + weight * kl_loss
        distill.teachers[i].performance_score = exp(-kl_loss.item())
    }
    return total_loss
}

func (distill: *multi_teacher_distillation) update_teacher_weights() {
    let scores: []f32 = []
    for teacher in distill.teachers {
        scores.push(teacher.performance_score)
    }
    let exp_scores: []f32 = []
    let sum_exp: f32 = 0.0
    for score in scores {
        let exp_s = exp(score)
        exp_scores.push(exp_s)
        sum_exp += exp_s
    }
    for i in 0..distill.teachers.len() {
        distill.teacher_contributions[i] = exp_scores[i] / sum_exp
    }
}

func (distill: *multi_teacher_distillation) compute_layer_distillation_loss(
    input: tensor
) -> tensor {
    let student_activations = distill.student.forward_with_activations(input)
    let num_layers = student_activations.len()
    let avg_teacher_activations: []tensor = []
    for layer_idx in 0..num_layers {
        let layer_acts = tensor_zeros_like(student_activations[layer_idx])
        for teacher in distill.teachers {
            let teacher_acts = teacher.model.forward_with_activations(input)
            layer_acts = layer_acts + teacher_acts[layer_idx]
        }
        layer_acts = layer_acts / f32(distill.teachers.len())
        avg_teacher_activations.push(layer_acts)
    }
    let total_layer_loss = tensor_zeros([1])
    for i in 0..num_layers {
        let layer_loss = mse_loss(student_activations[i], avg_teacher_activations[i])
        total_layer_loss = total_layer_loss + layer_loss
    }
    return total_layer_loss / f32(num_layers)
}

func (distill: *multi_teacher_distillation) train_step(batch: Batch) -> f32 {
    let input = batch.input
    let targets = batch.targets
    let loss = distill.compute_distillation_loss(input, targets)
    loss.backward()
    clip_grad_norm(distill.student.parameters(), distill.config.max_grad_norm)
    distill.optimizer.step()
    distill.optimizer.zero_grad()
    return loss.item()
}

func (distill: *multi_teacher_distillation) train(train_data: DataLoader) -> []f32 {
    let losses: []f32 = []
    let step = 0
    for epoch in 0..distill.config.num_epochs {
        println(f"Multi-Teacher Distillation Epoch {epoch + 1}/{distill.config.num_epochs}")
        for batch in train_data {
            let loss = distill.train_step(batch)
            losses.push(loss)
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

func (distill: *multi_teacher_distillation) print_teacher_contributions() {
    println("Teacher Contributions:")
    for i in 0..distill.teachers.len() {
        let teacher = distill.teachers[i]
        let contribution = distill.teacher_contributions[i]
        println(f"  {teacher.name}: weight={teacher.weight:.4f}, " +
               f"contribution={contribution:.4f}, " +
               f"performance={teacher.performance_score:.4f}")
    }
}

func kl_divergence_loss(student_logits: tensor, teacher_logits: tensor, temperature: f32) -> tensor {
    let student_log_probs = log_softmax(student_logits / temperature, dim: -1)
    let teacher_probs = softmax(teacher_logits / temperature, dim: -1)
    let kl = -(teacher_probs * student_log_probs).sum(dim: -1).mean()
    return kl * (temperature * temperature)
}
