# Clinical Alignment Coordinator (neurx/posttrain/alignment/clinical_alignment.s)

## Overview

Orchestrates medical-specific alignment across all post-training stages (SFT → DPO → GRPO).

**Role**: Master coordinator for clinical safety, stage transitions, quality checkpoints, and test set isolation.

## Key Responsibilities

### 1. Data Contamination Prevention
Ensures training data doesn't overlap with test sets (MedMCQA + HLE, 200 each).

```s
contamination_check_result check = check_training_data_contamination(
    training_ids,
    test_set_info{ sample_seed: 42, sample_size: 200 }
)

if !check.is_clean {
    print("ERROR: Found", check.contaminated_samples, "test questions in training data")
}
```

### 2. Stage-Specific Medical Objectives

#### SFT Objective
```s
medical_sft_objective{
    system_prompt: "你是infoxmed医疗大模型。",
    max_token_length: 1024,
    epochs: 2,
    learning_rate: 5e-5,
    quality_signals: ["medical_accuracy", "clarity", "completeness", "safety_awareness"]
}
```

#### DPO Objective
```s
medical_dpo_objective{
    beta: 0.3,                          // KL divergence weight
    rpo_alpha: 0.1,                     // RPO loss alpha
    num_preference_pairs: 6283,
    base_model: "Infoxmed2.0.2",
    learning_rate: 1e-5
}
```

#### GRPO Objective
```s
medical_grpo_objective{
    reward_functions: [
        "cds_fact_consistency_reward",     // 70%
        "cds_length_penalty_reward",       // 5%
        "cds_clarification_bonus_reward",  // 5%
        "cds_external_reward_model"        // 20%
    ],
    num_generations: 8,
    learning_rate: 2e-6,
    use_vllm: true
}
```

### 3. Safety Constraints During Training

4 key constraints enforced during training:

| Constraint | Violation Pattern | Penalty Weight |
|---|---|---|
| **avoid_overconfidence** | 肯定, 一定, 100% | 0.10 |
| **require_disclaimers** | Missing medical disclaimers | 0.05 |
| **no_unapproved_drugs** | 实验性, 未经批准 | 0.15 |
| **prompt_clinician_consultation** | Missing "咨询医生" | 0.05 |

```s
float penalty = evaluate_safety_constraints(response)
// penalty += 0.10 if overconfident language detected
// penalty += 0.05 if no disclaimers
```

### 4. Iterative Quality Feedback

Track quality metrics across checkpoints:

```s
quality_checkpoint ckpt = quality_checkpoint{
    step: 1000,
    stage: "sft",
    grounding_score: 7.2,
    coverage_score: 6.8,
    depth_score: 5.9,
    tool_use_score: 4.2,
    clarity_score: 8.1,
    safety_score: 8.9,
    overall_score: 6.85,
    meets_threshold: false  // needs 7.0
}
```

**Stage progression logic**:
- SFT → DPO: when overall_score >= 6.5
- DPO → GRPO: when grounding_score >= 7.0 AND safety_score >= 8.5

## Coordinator Lifecycle

### 1. Initialization

```s
clinical_alignment_coordinator coord = new_clinical_alignment_coordinator()

// coord.test_info loaded (400 test questions)
// coord.sft_obj, dpo_obj, grpo_obj configured
// coord.current_stage = "sft"
```

### 2. Pre-training Validation

```s
pre_training_validation_result validation = validate_before_training(
    coord,
    training_sample_ids
)

if !validation.ready_to_train {
    if !validation.data_clean {
        print("ERROR: Data contamination detected!")
    }
    if !validation.constraints_configured {
        print("ERROR: Safety constraints not configured!")
    }
    return
}

print("✓ All validation checks passed. Ready to train.")
```

### 3. Stage Transitions

```s
// After SFT completes:
coord = coordinator_transition_stage(coord, "dpo")
// coord.stage_history = ["sft", "dpo"]
// coord.current_stage = "dpo"

// Record checkpoint after evaluation:
quality_checkpoint ckpt = evaluate_checkpoint_quality(eval_results)
coord = coordinator_record_checkpoint(coord, ckpt)
```

### 4. Monitoring During Training

```s
// Every N steps:
if should_evaluate(step) {
    []medical_response_evaluation evals = evaluate_responses(
        sample_responses,
        model_name: "Infoxmed2.0.2"
    )
    
    quality_checkpoint ckpt = evaluate_checkpoint_quality(evals)
    
    if !ckpt.meets_threshold {
        print("Warning: Quality below 7.0, current:", ckpt.overall_score)
        // Can trigger early stopping or learning rate adjustment
    }
    
    coord = coordinator_record_checkpoint(coord, ckpt)
}
```

## Data Contamination Guard

Prevents test data leakage with seed-based sampling:

```
Test Set Isolation (seed=42):
├─ MedMCQA: samples [0-199] from 4183 dev questions
├─ HLE: samples [0-199] from 2500 questions
└─ Total: 400 questions locked for evaluation only

DPO Dataset Construction:
├─ Load all preference pairs
├─ Explicitly exclude question IDs in test set
└─ Verify: contamination_check_result.is_clean == true
```

## Quality Thresholds

Target scores for stage progression:

| Stage | Grounding | Coverage | Depth | Tool-use | Clarity | Safety | Overall |
|---|---|---|---|---|---|---|---|
| **SFT baseline** | 5.0+ | 6.0+ | 4.0+ | 3.0+ | 7.0+ | 8.0+ | 5.5+ |
| **After DPO** | 7.0+ | 7.5+ | 5.5+ | 4.5+ | 8.0+ | 8.5+ | 6.8+ |
| **After GRPO** | 8.5+ | 8.5+ | 7.0+ | 6.0+ | 8.5+ | 9.0+ | 8.0+ |

## Integration Points

### With SFT Trainer
```s
medical_sft_objective sft_cfg = coord.sft_obj
// Use sft_cfg.system_prompt in training
// Monitor sft_cfg.medical_quality_signals
```

### With DPO Trainer
```s
medical_dpo_objective dpo_cfg = coord.dpo_obj
// Load DPO data without test questions
// Apply DPO-specific safety constraints
```

### With GRPO Trainer
```s
medical_grpo_objective grpo_cfg = coord.grpo_obj
// Initialize reward functions from grpo_cfg.reward_functions
// Set weights from grpo_cfg.reward_weights
```

### With Evaluation Framework
```s
// Checkpoint evaluation:
[]medical_response_evaluation evals = evaluate_medical_response(
    question,
    response,
    model_name: "Infoxmed2.0.2"
)

quality_checkpoint = evaluate_checkpoint_quality(evals)
```

## Related Files

- `neurx/posttrain/clinical/clinical_cds_reward.s` - Reward signals
- `neurx/eval/six_dimension_eval.s` - Evaluation framework
- `neurx/posttrain/data/medical_data_pipeline.s` - Data processing
- `train/medical_model/Post_train/alignment_coordinator.py` - Python reference
