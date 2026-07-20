# Medical Post-Training Integration Guide

## Overview

Complete medical post-training stack in neurx, ported from medical_model project.

**4 core modules**:
1. **Clinical CDS Rewards** (`neurx/posttrain/clinical/`) - 4 reward functions
2. **6D Medical Eval** (`neurx/eval/six_dimension_eval.s`) - Comprehensive evaluation
3. **Medical Data Pipeline** (`neurx/posttrain/data/medical_data_pipeline.s`) - Data processing
4. **Clinical Coordinator** (`neurx/posttrain/alignment/clinical_alignment.s`) - Orchestration

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Clinical Alignment Coordinator                              │
│  ├─ Data Contamination Guard (test set isolation)           │
│  ├─ Safety Constraints Manager                              │
│  ├─ Stage Transition Control                                │
│  └─ Quality Checkpoint Tracking                             │
└─────────────────────────────────────────────────────────────┘
              ↓              ↓              ↓
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ SFT Stage    │    │ DPO Stage    │    │ GRPO Stage   │
│              │    │              │    │              │
│ Data:        │    │ Data:        │    │ Data:        │
│ Medical      │    │ Preference   │    │ Prompts      │
│ instruct.    │    │ pairs        │    │ (~1K)        │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│  Reward Computation                                          │
│  ├─ Fact Consistency (70%)  ← verify against MCP             │
│  ├─ Length Penalty (5%)     ← token normalization            │
│  ├─ Clarification Bonus (5%)← question underspecification    │
│  └─ External Reward (20%)   ← Qwen3.5-9B classifier         │
└─────────────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│  6-Dimension Evaluation                                      │
│  ├─ Grounding (factual accuracy)                             │
│  ├─ Coverage (completeness)                                  │
│  ├─ Depth (multi-hop reasoning)                              │
│  ├─ Tool-use (evidence integration)                          │
│  ├─ Clarity (expression + SOP)                               │
│  └─ Safety (medical safety + uncertainty)                    │
└─────────────────────────────────────────────────────────────┘
              ↓
        Checkpoint → Next Stage
```

## Complete Training Pipeline

### Step 0: Data Preparation

```bash
# Generate medical instruction data
cd neurx/posttrain/data/

# Load from MySQL, clean, dedup, output JSONL
process_medical_articles(
    articles_from_mysql,
    output: "data/medical_instruct_sft_dataset.jsonl"
)
# Output: ~1000+ samples
```

### Step 1: SFT (Supervised Fine-Tuning)

```bash
cd neurx/posttrain/sft/

# Configuration from coordinator
medical_sft_objective obj = {
    max_token_length: 1024,
    epochs: 2,
    learning_rate: 5e-5,
    quality_signals: ["medical_accuracy", "clarity", "completeness", "safety_awareness"]
}

# Train Qwen3.5-27B on medical instructions
swift sft \
    --model Qwen/Qwen3.5-27B \
    --dataset data/medical_instruct_sft_dataset.jsonl \
    --output_dir output/sft_checkpoint
    
# Output: Infoxmed2.0.2 (LoRA merged)
```

**Quality target**: overall_score >= 6.5

### Step 2: DPO (Direct Preference Optimization)

```bash
cd neurx/posttrain/dpo/

# Build preference pairs with contamination guard
check_training_data_contamination(
    dpo_samples,
    test_set_info{ seed: 42, size: 200 }
)

# Configuration from coordinator
medical_dpo_objective obj = {
    beta: 0.3,
    num_preference_pairs: 6283,
    base_model: "Infoxmed2.0.2",
    learning_rate: 1e-5
}

# Train with DPO loss
swift rlhf --rlhf_type dpo \
    --model Infoxmed2.0.2 \
    --dataset dpo_medical_train_v2.jsonl \
    --beta 0.3 \
    --output_dir output/dpo_checkpoint

# Output: Infoxmed2.0.4 (LoRA merged)
```

**Quality target**: grounding_score >= 7.0

### Step 3: GRPO (Group Relative Policy Optimization)

```bash
cd neurx/posttrain/grpo/

# Configuration from coordinator
medical_grpo_objective obj = {
    reward_functions: ["cds_fact_consistency_reward", 
                       "cds_length_penalty_reward",
                       "cds_clarification_bonus_reward", 
                       "cds_external_reward_model"],
    reward_weights: [0.70, 0.05, 0.05, 0.20],
    num_generations: 8,
    learning_rate: 2e-6
}

# Start reward model server (Port 8000)
python serve_reward_model.py \
    --model_path Reward_model7-9B \
    --port 8000

# Train with GRPO + custom reward functions
swift rlhf --rlhf_type grpo \
    --model Infoxmed2.0.2 \
    --reward_funcs cds_fact_consistency_reward \
                   cds_length_penalty_reward \
                   cds_clarification_bonus_reward \
                   cds_external_reward_model \
    --reward_weights 0.70 0.05 0.05 0.20 \
    --output_dir output/grpo_checkpoint

# Output: Infoxmed2.0.x (final model)
```

**Quality target**: overall_score >= 8.0, safety_score >= 9.0

### Step 4: Evaluation

```bash
cd neurx/eval/

# Evaluate on both test sets
[]medical_response_evaluation evals_medmcqa = evaluate_dataset(
    dataset: "medmcqa",
    samples: 200,
    model: "Infoxmed2.0.x"
)

[]medical_response_evaluation evals_hle = evaluate_dataset(
    dataset: "hle",
    samples: 200,
    model: "Infoxmed2.0.x"
)

# Generate report
quality_checkpoint final = evaluate_checkpoint_quality(
    evals_medmcqa + evals_hle
)

print_evaluation_report(final)
```

## File Structure

```
neurx/
├─ posttrain/
│  ├─ clinical/
│  │  ├─ clinical_cds_reward.s         (564 LOC)
│  │  └─ README_CDS.md
│  │
│  ├─ data/
│  │  ├─ medical_data_pipeline.s       (400 LOC)
│  │  └─ README_MEDICAL_DATA.md
│  │
│  ├─ alignment/
│  │  ├─ clinical_alignment.s          (300 LOC)
│  │  └─ README_CLINICAL_ALIGNMENT.md
│  │
│  ├─ sft/
│  │  ├─ sft_trainer.s                 (existing)
│  │  └─ README_SFT.md
│  │
│  ├─ dpo/
│  │  ├─ dpo_trainer.s                 (existing)
│  │  └─ README.md
│  │
│  └─ grpo/
│     ├─ grpo_trainer.s                (existing)
│     └─ README_GRPO.md
│
├─ eval/
│  ├─ six_dimension_eval.s             (600 LOC)
│  ├─ benchmark_eval.s                 (existing)
│  ├─ README_MEDICAL_EVAL.md
│  └─ README.md
│
└─ loss/
   ├─ dpo_loss.s                        (existing)
   └─ losses.s                          (existing)
```

## Key Integration Points

### 1. Reward Function Integration (GRPO)

In `train_grpo_cli_v2.sh`:

```bash
swift rlhf --rlhf_type grpo \
    --external_plugins neurx/posttrain/clinical/clinical_cds_reward.s \
    --reward_funcs \
        cds_fact_consistency_reward \
        cds_length_penalty_reward \
        cds_clarification_bonus_reward \
        cds_external_reward_model
```

### 2. Data Contamination Check

```s
// Before training
pre_training_validation_result validation = validate_before_training(
    coordinator,
    training_sample_ids
)

if !validation.ready_to_train {
    error("Data contamination or safety constraints not met")
}
```

### 3. Quality Checkpoint Tracking

```s
// After each stage
quality_checkpoint ckpt = evaluate_checkpoint_quality(eval_results)

if ckpt.overall_score < threshold {
    warn("Quality below target, may need retraining")
} else {
    coordinator = coordinator_record_checkpoint(coordinator, ckpt)
    coordinator = coordinator_transition_stage(coordinator, next_stage)
}
```

### 4. Evaluation Pipeline

```s
// Comprehensive 6D evaluation
medical_response_evaluation eval = evaluate_medical_response(
    question,
    response,
    model_name: "Infoxmed2.0.x"
)

// Access individual dimensions
float grounding = eval.dimensions[0].normalized_score  // 0-10
float safety = eval.dimensions[5].normalized_score
```

## Performance Benchmarks

Target scores (0-10 scale):

| Model | Grounding | Coverage | Depth | Tool-use | Clarity | Safety | Overall |
|---|---|---|---|---|---|---|---|
| Qwen3.5-27B (baseline) | 5.2 | 5.8 | 4.1 | 2.9 | 6.8 | 7.1 | 5.3 |
| Infoxmed2.0.2 (SFT) | 6.8 | 6.5 | 5.2 | 3.8 | 7.5 | 8.2 | 6.3 |
| Infoxmed2.0.4 (DPO) | 7.5 | 7.3 | 6.1 | 4.5 | 8.0 | 8.6 | 6.8 |
| Infoxmed2.0.x (GRPO) | 8.5+ | 8.4+ | 7.2+ | 6.1+ | 8.5+ | 9.0+ | 8.0+ |

## Hardware Requirements

| Stage | GPUs | Memory | Duration |
|---|---|---|---|
| SFT | 4×A800 80GB | ~60GB/GPU | ~2-3 days |
| DPO | 4×A800 80GB | ~60GB/GPU | ~2-3 days |
| GRPO | 3×A800 80GB | ~70GB/GPU | ~3-4 days |
| Reward Model | 1×GPU (inference) | ~20GB | - |

## Quick Start

```bash
# 1. Validate environment
neurx_validate_medical_setup()

# 2. Generate data
cd neurx/posttrain/data/
process_medical_articles(articles, "medical_instruct_sft_dataset.jsonl")

# 3. Run complete pipeline
python scripts/run_full_medical_posttrain.py \
    --output_dir ./models/infoxmed \
    --eval_every 500 \
    --checkpoint_every 100

# 4. Evaluate final model
python eval/run_medical_evaluation.py \
    --model ./models/infoxmed/final \
    --datasets medmcqa hle \
    --output_dir ./results/
```

## Debugging & Troubleshooting

### Data Contamination Detected

```
ERROR: Found 3 test questions in training data
→ Check extract_data.py seed parameter (must be 42)
→ Verify DPO data excludes test IDs
```

### Reward Model Connection Failed

```
ERROR: Cannot connect to reward model server (8000)
→ Start reward model: python serve_reward_model.py --port 8000
→ Check firewall: allow localhost:8000
```

### Quality Score Declining

```
WARNING: Overall score below threshold (5.2 < 6.5)
→ Check safety_score: may be penalizing valid disclaimers
→ Verify grounding_score: fact verification too strict?
→ Review learning rate: may be too aggressive
```

## Related Documentation

- [Clinical CDS Rewards](neurx/posttrain/clinical/README_CDS.md)
- [6D Medical Evaluation](neurx/eval/README_MEDICAL_EVAL.md)
- [Medical Data Pipeline](neurx/posttrain/data/README_MEDICAL_DATA.md)
- [Clinical Alignment Coordinator](neurx/posttrain/alignment/README_CLINICAL_ALIGNMENT.md)
- [Original medical_model project](train/medical_model/README.md)

## Citation

When using this medical post-training framework, please cite:

```bibtex
@misc{neurx_medical_posttrain,
  title={Medical Post-training Module for Infoxmed2.0},
  author={Your Organization},
  year={2026},
  url={https://github.com/your-org/neurx}
}
```

---

**Status**: ✅ All 4 core modules implemented  
**Last Updated**: 2026-07-20  
**Maintainer**: ML Research Team
