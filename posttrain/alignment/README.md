# 🎯 Alignment Framework - Preference Optimization & RLHF Algorithms

This directory contains all preference optimization and reinforcement learning from human feedback (RLHF) algorithms for aligning language models with human preferences.

## 📁 Directory Structure

```
alignment/
├── reward/      # Reward Model - Bradley-Terry preference scoring
├── dpo/         # Direct Preference Optimization - reference-free learning
├── orpo/        # Odds Ratio Preference Optimization
├── grpo/        # Group Relative Preference Optimization
├── simpo/       # Simple Preference Optimization
├── ppo/         # PPO - Proximal Policy Optimization (RLHF alignment)
├── common/      # Shared components and utilities
└── README.md    # This file
```

## 🔧 Algorithm Overview

### Reward Model (`reward/`)
Bradley-Terry preference scoring model that learns to rank human-preferred responses higher.

**Key Files:**
- `reward_model.s` - Core reward model architecture
- `reward.s` - Reward state management
- `factual_consistency_reward.s` - Factual grounding rewards
- `factual_consistency_examples.s` - Example usage

### Direct Preference Optimization (`dpo/`)
Reference-free preference optimization that directly optimizes model to prefer good responses over bad ones without requiring a separate reward model.

**Key Files:**
- `dpo_trainer.s` - DPO training loop
- `dpo_state.s` - Training state management
- `dpo_step.s` - Single training step
- `dpo_examples.s` - Usage examples

### Odds Ratio Preference Optimization (`orpo/`)
Preference optimization using odds ratio loss for simpler, more efficient alignment.

**Key Files:**
- `orpo_trainer.s` - ORPO training implementation
- `orpo_examples.s` - ORPO usage examples

### Group Relative Preference Optimization (`grpo/`)
Group-based preference optimization for better sample efficiency in preference learning.

**Key Files:**
- `grpo_trainer.s` - GRPO training loop
- `grpo.s` - Core GRPO algorithms
- `grpo_examples.s` - Usage examples

### Simple Preference Optimization (`simpo/`)
Simplified preference optimization approach with minimal computational overhead.

**Key Files:**
- `simpo_trainer.s` - SIMPO training
- `simpo_examples.s` - Examples

### PPO & RLHF (`ppo/`)
Proximal Policy Optimization for reinforcement learning-based alignment using reward models.

**Key Files:**
- `ppo_trainer.s` - PPO training loop
- `ppo.s` - Core PPO algorithm
- `ppo_examples.s` - Usage examples
- `value_model_trainer.s` - Value function for PPO baseline
- `value_model_examples.s` - Value model examples

### Common Components (`common/`)
Shared utilities and base classes used across all alignment algorithms.

**Key Files:**
- `constitutional_ai_trainer.s` - Constitutional AI training framework
- `constitutional_ai_examples.s` - CAI usage examples
- `lora_trainer.s` - LoRA adaptation for efficient fine-tuning
- `lora_examples.s` - LoRA examples
- `clinical_alignment.s` - Domain-specific alignment for clinical/medical text

## 🚀 Quick Start

### 1. Train a Reward Model
```bash
# Define preference pairs and train
s run alignment/reward/reward_model.s
```

### 2. Direct Preference Optimization (No Reward Model)
```bash
# DPO - simplest preference-based approach
s run alignment/dpo/dpo_trainer.s
```

### 3. RLHF with PPO
```bash
# PPO + Reward Model - most powerful alignment
s run alignment/ppo/ppo_trainer.s
```

### 4. ORPO - Simpler Alternative
```bash
# Odds ratio preference optimization
s run alignment/orpo/orpo_trainer.s
```

## 📊 Algorithm Comparison

| Algorithm | Complexity | Speed | Quality | Reference Model? |
|-----------|-----------|-------|---------|------------------|
| **DPO** | Low | Fast | Good | No |
| **ORPO** | Very Low | Fastest | Good | No |
| **SIMPO** | Low | Fast | Good | No |
| **GRPO** | Medium | Medium | Better | Optional |
| **PPO** | High | Slower | Best | Yes (Reward Model) |

## 🎓 Training Pipeline

### Recommended Approach: DPO
1. Collect preference pairs (chosen vs rejected responses)
2. Run DPO trainer with your model and preference data
3. Evaluate on benchmark tasks

### Advanced: PPO with Reward Model
1. Train reward model on preference pairs
2. Generate trajectories with model
3. Score trajectories with reward model
4. Run PPO optimization steps

## 🔗 Integration with Other Components

- **Adapters** (`posttrain/adapter/`): Use LoRA for efficient fine-tuning
- **Data** (`posttrain/data/`): Preference pair datasets
- **Checkpoint** (`posttrain/checkpoint/`): Model checkpointing
- **Evaluation** (`posttrain/eval/`): Alignment quality metrics

## 📚 References

- **DPO**: Direct Preference Optimization (Rafailov et al., 2023)
- **ORPO**: Odds Ratio Preference Optimization
- **GRPO**: Group Relative Preference Optimization
- **SIMPO**: Simple Preference Optimization
- **PPO**: Proximal Policy Optimization (Schulman et al., 2017)
- **Constitutional AI**: Principle-Driven, Practical Alignment

## 📝 Configuration

Each algorithm accepts configuration via environment variables:

```bash
# Common settings
export ALIGNMENT_MODEL_PATH="/path/to/model"
export ALIGNMENT_DATA_PATH="/path/to/preferences.jsonl"
export ALIGNMENT_OUTPUT_DIR="./checkpoints/aligned_model"

# Algorithm-specific
export DPO_BETA=0.5              # DPO preference scaling
export PPO_LEARNING_RATE=1e-5    # PPO learning rate
export ORPO_LAMBDA=0.5           # ORPO weight
```

## ✅ Status

All alignment algorithms are production-ready and have been tested on various LLM alignment tasks including:
- Instruction following
- Truthfulness
- Harmlessness
- Factual consistency
- Clinical domain alignment

---

**Last Updated**: 2026-07-20  
**Status**: ✅ Production Ready
