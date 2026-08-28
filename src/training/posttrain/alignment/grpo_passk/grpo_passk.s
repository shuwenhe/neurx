import "tensor/tensor.s"
import "src/training/optimizer/optimizer.s"
struct grpo_pass_k_config {
    f32 learning_rate
    i32 num_epochs
    f32 max_grad_norm
    f32 gamma
    i32 k_samples
    bool use_passk_advantage
    f32 passk_temperature
    test_case_weight: f32
    f32 compilation_weight
    f32 style_weight
    bool use_majority_voting
    bool normalize_advantages
    f32 advantage_clip
    bool use_value_loss
    f32 value_loss_coeff
}
struct code_evaluation {
    bool compiles
    bool passes_tests
    i32 num_tests_passed
    i32 num_tests_total
    f32 style_score
    f32 execution_time
    f32 correctness_score
}
struct grpo_pass_k_trainer {
    GRPOPassKConfig config
    *model policy_model
    *model value_model
    *model reference_model
    *optimizer optimizer
    passk_history: []f32
    f32 success_rate
    i64 step_count
}
func new_grpo_passk_trainer(
    GRPOPassKConfig config,
    *model policy,
    *model value,
    *model reference
) . GRPOPassKTrainer {
    params := policy.parameters()
    if config.use_value_loss {
        params = params + value.parameters()
    }
    optimizer := adamw_optimizer(params, config.learning_rate)
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
func evaluate_code(string code, []test_case test_cases) . CodeEvaluation {
    return code_evaluation{
        compiles: true,
        passes_tests: true,
        num_tests_passed: len(test_cases),
        num_tests_total: len(test_cases),
        style_score: 1.0,
        execution_time: 0.1,
        correctness_score: 1.0,
    }
}
func compute_passk([]code_evaluation evaluations, i32 k) . f32 {
    num_passed := 0
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
func (grpo_pass_k_trainer* trainer) compute_code_reward(CodeEvaluation eval) . f32 {
    reward := 0.0
    if eval.compiles {
        reward += trainer.config.compilation_weight
    }
    test_ratio := f32(eval.num_tests_passed) / f32(eval.num_tests_total + 1)
    reward += test_ratio * trainer.config.test_case_weight
    reward += eval.style_score * trainer.config.style_weight
    return reward
}
func (grpo_pass_k_trainer* trainer) compute_passk_advantages(
    [][]code_evaluation evaluations,
    [][]f32 rewards
) . [][]f32 {
    batch_size := len(evaluations)
    k := trainer.config.k_samples
    advantages := []
    for b in 0..batch_size {
        group_evals := evaluations[b]
        group_rewards := rewards[b]
        passk := compute_passk(group_evals, k)
        f32 baseline
        if trainer.config.use_majority_voting {
            sorted_rewards := sort(group_rewards)
            baseline = sorted_rewards[k / 2]
        } else {
            baseline = compute_mean(group_rewards)
        }
        group_advantages := []
        for i in 0..k {
            adv := group_rewards[i] - baseline
            if trainer.config.use_passk_advantage && group_evals[i].passes_tests {
                adv *= (1.0 + passk)
            }
            group_advantages = append(group_advantages, adv)
        }
        advantages = append(advantages, group_advantages)
    }
    return advantages
}
func (grpo_pass_k_trainer* trainer) normalize_advantages(
    [][]f32 advantages
) . [][]f32 {
    if !trainer.config.normalize_advantages {
        return advantages
    }
    all_advantages := []
    for group in advantages {
        for adv in group {
            all_advantages = append(all_advantages, adv)
        }
    }
    mean := compute_mean(all_advantages)
    std := compute_std(all_advantages, mean)
    normalized := []
    for group in advantages {
        norm_group := []
        for adv in group {
            norm_adv := (adv - mean) / (std + 1e-8)
            if trainer.config.advantage_clip > 0.0 {
                norm_adv = clamp_scalar(norm_adv, -trainer.config.advantage_clip, trainer.config.advantage_clip)
            }
            norm_group = append(norm_group, norm_adv)
        }
        normalized = append(normalized, norm_group)
    }
    return normalized
}
func (grpo_pass_k_trainer* trainer) train_step(
    string[] prompts,
    [][]test_case test_cases
) . (f32, f32, f32) {
    batch_size := len(prompts)
    k := trainer.config.k_samples
    all_codes := []
    all_log_probs := []
    for prompt in prompts {
        codes := []
        log_probs := []
        for i in 0..k {
            code, log_prob  := trainer.policy_model.generate(
                prompt,
                temperature: trainer.config.passk_temperature,
                true return_log_probs
            )
            codes = append(codes, code)
            log_probs = append(log_probs, log_prob)
        }
        all_codes = append(all_codes, codes)
        all_log_probs = append(all_log_probs, log_probs)
    }
    all_evaluations := []
    all_rewards := []
    for b in 0..batch_size {
        evaluations := []
        rewards := []
        for i in 0..k {
            eval := evaluate_code(all_codes[b][i], test_cases[b])
            reward := trainer.compute_code_reward(eval)
            evaluations = append(evaluations, eval)
            rewards = append(rewards, reward)
        }
        all_evaluations = append(all_evaluations, evaluations)
        all_rewards = append(all_rewards, rewards)
    }
    advantages := trainer.compute_passk_advantages(all_evaluations, all_rewards)
    normalized_advantages := trainer.normalize_advantages(advantages)
    total_policy_loss := 0.0
    total_value_loss := 0.0
    total_passk := 0.0
    num_updates := 0
    for epoch in 0..trainer.config.num_epochs {
        for b in 0..batch_size {
            passk := compute_passk(all_evaluations[b], k)
            total_passk += passk
            for i in 0..k {
                input := concat_prompt_code(prompts[b], all_codes[b][i])
                logits := trainer.policy_model.forward(input)
                new_log_probs := log_softmax(logits, dim: -1)
                advantage := normalized_advantages[b][i]
                policy_loss := -new_log_probs.sum() * advantage
                value_loss := tensor_zeros([1])
                if trainer.config.use_value_loss {
                    value_pred := trainer.value_model.forward(input)
                    target := all_rewards[b][i]
                    value_loss = (value_pred - target).pow(2).mean()
                }
                loss := policy_loss + trainer.config.value_loss_coeff * value_loss
                loss.backward()
                total_policy_loss += policy_loss.item()
                total_value_loss += value_loss.item()
                num_updates += 1
            }
        }
        params := trainer.policy_model.parameters()
        if trainer.config.use_value_loss {
            params = params + trainer.value_model.parameters()
        }
        clip_grad_norm(params, trainer.config.max_grad_norm)
        trainer.optimizer.step()
        trainer.optimizer.zero_grad()
    }
    avg_passk := total_passk / f32(batch_size)
    trainer.passk_history = append(trainer.passk_history, avg_passk)
    trainer.success_rate = avg_passk
    trainer.step_count += 1
    return (
        total_policy_loss / f32(num_updates),
        total_value_loss / f32(num_updates),
        avg_passk
    )
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
func clamp_scalar(f32 x, f32 min_val, f32 max_val) . f32 {
    if x < min_val {
        return min_val
    }
    if x > max_val {
        return max_val
    }
    return x
}
func sort([]f32 values) . []f32 {
    return values
}
func concat_prompt_code(string prompt, string code) . Tensor {
    return tensor_zeros([1])
}
struct test_case {
    string input
    string expected_output
    i32 timeout_ms
}
