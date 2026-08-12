import "tensor/tensor.s"
import "optimizer/optimizer.s"
struct grpo_pass_k_config {
    learning_rate: f32
    num_epochs: i32
    max_grad_norm: f32
    gamma: f32
    k_samples: i32
    use_passk_advantage: bool
    passk_temperature: f32
    test_case_weight: f32
    compilation_weight: f32
    style_weight: f32
    use_majority_voting: bool
    normalize_advantages: bool
    advantage_clip: f32
    use_value_loss: bool
    value_loss_coeff: f32
}

struct code_evaluation {
    compiles: bool
    passes_tests: bool
    num_tests_passed: i32
    num_tests_total: i32
    style_score: f32
    execution_time: f32
    correctness_score: f32
}

struct grpo_pass_k_trainer {
    config: GRPOPassKConfig
    policy_model: *model
    value_model: *model
    reference_model: *model
    optimizer: *optimizer
    passk_history: []f32
    success_rate: f32
    step_count: i64
}

func new_grpo_passk_trainer(
    config: GRPOPassKConfig,
    policy: *model,
    value: *model,
    reference: *model
) -> GRPOPassKTrainer {
    let params = policy.parameters()
    if config.use_value_loss {
        params = params + value.parameters()
    }
    let optimizer = adamw_optimizer(params, config.learning_rate)
    return grpo_pass_k_trainer{
        config: config,
        policy_model: policy,
        value_model: value,
        reference_model: reference,
        optimizer: optimizer,
        passk_history: [],
        success_rate: 0.0,
        step_count: 0,
    }
}

func evaluate_code(string code, test_cases: []test_case) -> CodeEvaluation {
    return code_evaluation{
        compiles: true,
        passes_tests: true,
        num_tests_passed: test_cases.len(),
        num_tests_total: test_cases.len(),
        style_score: 1.0,
        execution_time: 0.1,
        correctness_score: 1.0,
    }
}

func compute_passk(evaluations: []code_evaluation, i32 k) -> f32 {
    let num_passed = 0
    for eval in evaluations {
        if eval.passes_tests {
            num_passed += 1
        }
    }
    if num_passed > 0 {
        return 1.0
    }
    return 0.0
}

func (trainer: *grpo_pass_k_trainer) compute_code_reward(eval: CodeEvaluation) -> f32 {
    let reward: f32 = 0.0
    if eval.compiles {
        reward += trainer.config.compilation_weight
    }
    let test_ratio = f32(eval.num_tests_passed) / f32(eval.num_tests_total + 1)
    reward += test_ratio * trainer.config.test_case_weight
    reward += eval.style_score * trainer.config.style_weight
    return reward
}

func (trainer: *grpo_pass_k_trainer) compute_passk_advantages(
    evaluations: [][]code_evaluation,
    rewards: [][]f32
) -> [][]f32 {
    let batch_size = evaluations.len()
    let k = trainer.config.k_samples
    let advantages: [][]f32 = []
    for b in 0..batch_size {
        let group_evals = evaluations[b]
        let group_rewards = rewards[b]
        let passk = compute_passk(group_evals, k)
        let baseline: f32
        if trainer.config.use_majority_voting {
            let sorted_rewards = sort(group_rewards)
            baseline = sorted_rewards[k / 2]
        } else {
            baseline = compute_mean(group_rewards)
        }
        let group_advantages: []f32 = []
        for i in 0..k {
            let adv = group_rewards[i] - baseline
            if trainer.config.use_passk_advantage && group_evals[i].passes_tests {
                adv *= (1.0 + passk)
            }
            group_advantages.push(adv)
        }
        advantages.push(group_advantages)
    }
    return advantages
}

func (trainer: *grpo_pass_k_trainer) normalize_advantages(
    advantages: [][]f32
) -> [][]f32 {
    if !trainer.config.normalize_advantages {
        return advantages
    }
    let all_advantages: []f32 = []
    for group in advantages {
        for adv in group {
            all_advantages.push(adv)
        }
    }
    let mean = compute_mean(all_advantages)
    let std = compute_std(all_advantages, mean)
    let normalized: [][]f32 = []
    for group in advantages {
        let norm_group: []f32 = []
        for adv in group {
            let norm_adv = (adv - mean) / (std + 1e-8)
            if trainer.config.advantage_clip > 0.0 {
                norm_adv = clamp_scalar(norm_adv, -trainer.config.advantage_clip, trainer.config.advantage_clip)
            }
            norm_group.push(norm_adv)
        }
        normalized.push(norm_group)
    }
    return normalized
}

func (trainer: *grpo_pass_k_trainer) train_step(
    prompts: []string,
    test_cases: [][]test_case
) -> (f32, f32, f32) {
    let batch_size = prompts.len()
    let k = trainer.config.k_samples
    let all_codes: [][]string = []
    let all_log_probs: [][]tensor = []
    for prompt in prompts {
        let codes: []string = []
        let log_probs: []tensor = []
        for i in 0..k {
            let code, log_prob = trainer.policy_model.generate(
                prompt,
                temperature: trainer.config.passk_temperature,
                return_log_probs: true
            )
            codes.push(code)
            log_probs.push(log_prob)
        }
        all_codes.push(codes)
        all_log_probs.push(log_probs)
    }
    let all_evaluations: [][]code_evaluation = []
    let all_rewards: [][]f32 = []
    for b in 0..batch_size {
        let evaluations: []code_evaluation = []
        let rewards: []f32 = []
        for i in 0..k {
            let eval = evaluate_code(all_codes[b][i], test_cases[b])
            let reward = trainer.compute_code_reward(eval)
            evaluations.push(eval)
            rewards.push(reward)
        }
        all_evaluations.push(evaluations)
        all_rewards.push(rewards)
    }
    let advantages = trainer.compute_passk_advantages(all_evaluations, all_rewards)
    let normalized_advantages = trainer.normalize_advantages(advantages)
    let total_policy_loss: f32 = 0.0
    let total_value_loss: f32 = 0.0
    let total_passk: f32 = 0.0
    let num_updates = 0
    for epoch in 0..trainer.config.num_epochs {
        for b in 0..batch_size {
            let passk = compute_passk(all_evaluations[b], k)
            total_passk += passk
            for i in 0..k {
                let input = concat_prompt_code(prompts[b], all_codes[b][i])
                let logits = trainer.policy_model.forward(input)
                let new_log_probs = log_softmax(logits, dim: -1)
                let advantage = normalized_advantages[b][i]
                let policy_loss = -new_log_probs.sum() * advantage
                let value_loss = tensor_zeros([1])
                if trainer.config.use_value_loss {
                    let value_pred = trainer.value_model.forward(input)
                    let target = all_rewards[b][i]
                    value_loss = (value_pred - target).pow(2).mean()
                }
                let loss = policy_loss + trainer.config.value_loss_coeff * value_loss
                loss.backward()
                total_policy_loss += policy_loss.item()
                total_value_loss += value_loss.item()
                num_updates += 1
            }
        }
        let params = trainer.policy_model.parameters()
        if trainer.config.use_value_loss {
            params = params + trainer.value_model.parameters()
        }
        clip_grad_norm(params, trainer.config.max_grad_norm)
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
    }
    let avg_passk = total_passk / f32(batch_size)
    trainer.passk_history.push(avg_passk)
    trainer.success_rate = avg_passk
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        avg_passk
    )
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

func compute_std(values: []f32, f32 mean) -> f32 {
    if values.len() == 0 {
        return 1.0
    }
    let sum_sq: f32 = 0.0
    for v in values {
        sum_sq += (v - mean) * (v - mean)
    }
    return sqrt(sum_sq / f32(values.len()))
}

func clamp_scalar(f32 x, f32 min_val, f32 max_val) -> f32 {
    if x < min_val {
        return min_val
    }
    if x > max_val {
        return max_val
    }
    return x
}

func sort(values: []f32) -> []f32 {
    return values
}

func concat_prompt_code(string prompt, string code) -> Tensor {
    return tensor_zeros([1])
}

struct test_case {
    input: string
    expected_output: string
    timeout_ms: i32
}

