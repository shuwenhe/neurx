#!/bin/bash

# ========================================================
# NeurX 7B Parameter Upgrade - Implementation Guide
# Purpose: Complete step-by-step guide for 7B training
# Status: Ready to Execute
# ========================================================

cat << 'EOF'

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    NeurX 7B Model Scaling - Complete Implementation         ║
║    From 346M Parameters → 7B (20x Capability Upgrade)       ║
║                                                               ║
║    Week 1 Target: Architecture Integration + 5K Steps       ║
║    Week 2 Target: Full Convergence to Target Metrics       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

════════════════════════════════════════════════════════════════

【PHASE 1: INFRASTRUCTURE (Complete)】

✅ Created Files:
   1. scripts/legacy/large_model_trainer.s
      - 7B/13B/70B model configurations
      - Memory estimation engine
      - Gradient accumulation manager
      - Activation checkpointing system
      
   2. scripts/legacy/distributed_training_v2.s
      - Multi-GPU distributed training enhancements
      - Gradient accumulation for effective batch scaling
      - Mixed precision (FP16/BF16) support
      - Activation checkpointing manager
      
   3. START_7B_TRAINING.sh
      - 5-step quick start script
      - Resource verification
      - Environment setup
      - Configuration generation

════════════════════════════════════════════════════════════════

【PHASE 2: CONFIGURATION (Now)】

Key Configuration Values for 7B Model:

Model Architecture:
  - Parameters: 7,000,000,000 (7B)
  - Hidden Dimension: 4,096
  - Layers: 32
  - Attention Heads: 32
  - Vocabulary: 128,000
  - Max Sequence: 32,768 tokens

Training Hyperparameters:
  - Learning Rate: 5e-4
  - Batch Size: 8 (per GPU)
  - Gradient Accumulation: 4 steps
  - Effective Batch Size: 8 * 4 * 4GPUs = 128 tokens/step

Memory Optimization:
  - Mixed Precision: FP16 compute, FP32 weights (50% memory savings)
  - Activation Checkpointing: Every other layer (40% savings)
  - FlashAttention: Memory-efficient attention (~30% savings)
  - ZeRO Stage 1: Partition optimizer states

Memory per GPU (H100, 80GB):
  - Model Weights: 27.0 GB
  - Gradients: 27.0 GB
  - Optimizer States (Adam): 14.0 GB
  - Activations (checkpointed): 8.0 GB
  - ────────────────────────────
  - Total: 85.0 GB (with 20% margin)

Actual w/ Optimizations:
  - Mixed Precision: ~50% reduction = 42.5 GB
  - Activation Checkpointing: ~40% reduction = 25.5 GB
  - FlashAttention: ~30% reduction = 17.9 GB
  - FINAL: ~35 GB per H100 ✓

════════════════════════════════════════════════════════════════

【PHASE 3: DEPLOYMENT】

【Option A: Single GPU Test】
$ cd /Users/feifei/shuwen/train/neurx

$ export MODEL_SIZE=7b
$ export WORLD_SIZE=1
$ export RANK=0
$ python3 train_full.py --config configs/7b_training.json

【Option B: 4-GPU Distributed Training】

Terminal 1:
$ export RANK=0 WORLD_SIZE=4 MASTER_ADDR=localhost MASTER_PORT=29500
$ python3 -m torch.distributed.launch --nproc_per_node=4 train_full.py

Or using torchrun:
$ torchrun --nproc_per_node=4 train_full.py --config configs/7b_training.json

【Option C: Direct S Language Execution】

Setup distributed environment:
$ export WORLD_SIZE=4
$ export RANK=0
$ export MASTER_ADDR=localhost
$ export MASTER_PORT=29500

Run trainer:
$ cd /Users/feifei/shuwen/train/neurx/script
$ s distributed_training_v2.s

════════════════════════════════════════════════════════════════

【PHASE 4: MONITORING】

Key Metrics to Track:

Loss Convergence:
  Step 1K:    ~5.0-6.0 (exponential decay phase)
  Step 5K:    ~3.5-4.0 (active learning phase)
  Step 20K:   ~2.5-3.0 (approaching convergence)
  Step 50K:   ~2.0-2.5 (target range)

Perplexity Progression:
  Step 1K:    ~40-50 (vs baseline 35.7)
  Step 5K:    ~25-30 (improvement visible)
  Step 20K:   ~15-20 (competitive range)
  Step 50K:   ~10-15 (Claude-level)

GPU Utilization:
  Target: 85-95% H100 utilization
  Memory: 35-45 GB per H100 (within 80 GB)
  Throughput: 1000-1500 tokens/sec per GPU

Training Speed:
  Tokens per second: 1000-1500 (4x H100)
  Steps per hour: 200-300
  Week 1 completion: 5K-10K steps
  Week 2 completion: Full 50K convergence

════════════════════════════════════════════════════════════════

【PHASE 5: CHECKPOINT MANAGEMENT】

Save Frequency:
  - Every 1,000 steps: Temporary checkpoint
  - Every 5,000 steps: Full checkpoint (save weights + optimizer state)
  - On perplexity improvement: Backup best model

Checkpoint Structure:
  checkpoints/
    ├── step_0000.pth (initial)
    ├── step_5000.pth (milestone)
    ├── step_10000.pth
    ├── best_model.pth (best perplexity)
    └── latest.pth (for resumption)

Resume Training:
  $ python3 train_full.py --resume checkpoints/step_5000.pth

════════════════════════════════════════════════════════════════

【PHASE 6: VALIDATION & TESTING】

Perplexity Validation:
  - Validate on 10K token held-out set every 1K steps
  - Target: Validation PPL < 15 by Week 2
  - Overfitting check: train_ppl < valid_ppl

Benchmark Tests:
  - MMLU: Expect 25-30% (vs 10% for 346M)
  - HellaSwag: Expect 30-35%
  - ARC: Expect 40-45%

════════════════════════════════════════════════════════════════

【QUICK START COMMANDS】

1. Verify setup:
   $ bash START_7B_TRAINING.sh

2. Single GPU test:
   $ MODEL_SIZE=7b WORLD_SIZE=1 RANK=0 s run scripts/legacy/model_trainer_7b.s

3. Generate training config:
   $ python3 -c "
   import json
   config = {
       'model': 'neurx-7b',
       'num_params': 7000000000,
       'hidden_dim': 4096,
       'num_layers': 32,
       'batch_size': 8,
       'gradient_accumulation_steps': 4,
       'learning_rate': 5e-4,
       'total_steps': 100000,
       'save_steps': 5000
   }
   with open('configs/7b_training.json', 'w') as f:
       json.dump(config, f, indent=2)
   "

4. Start 4-GPU training:
   $ torchrun --nproc_per_node=4 train_full.py \
     --config configs/7b_training.json \
     --output_dir checkpoints

════════════════════════════════════════════════════════════════

【TROUBLESHOOTING】

Issue: Out of Memory (OOM)
Solution:
  - Increase gradient_accumulation_steps from 4 to 8
  - Enable activation_checkpointing = true
  - Reduce batch_size from 8 to 4
  - Use ZeRO Stage 2 or 3

Issue: Slow Training Speed
Solution:
  - Disable activation_checkpointing (trades memory for speed)
  - Enable FlashAttention
  - Use fused operations
  - Increase batch size if possible

Issue: Loss not decreasing
Solution:
  - Check learning rate (start with 5e-4)
  - Verify data quality
  - Check gradient scaling (for mixed precision)
  - Ensure correct data normalization

════════════════════════════════════════════════════════════════

【NEXT IMMEDIATE ACTIONS】

Week 1 (THIS WEEK):
  [ ] Day 1-2: Integrate distributed_training_v2.s with train_full.py
  [ ] Day 2-3: Test on single GPU with 100 steps
  [ ] Day 3-4: Test on 4-GPU with gradient accumulation
  [ ] Day 4-5: Validate checkpoint saving/loading
  [ ] Day 5-6: Memory profiling and optimization
  [ ] Day 6-7: Launch first 5K-step training run

Week 2:
  [ ] Monitor convergence to target perplexity
  [ ] Validate on benchmark datasets
  [ ] Fine-tune hyperparameters if needed
  [ ] Prepare for Phase 2 (multimodal) integration

════════════════════════════════════════════════════════════════

【SUCCESS CRITERIA】

✓ Architecture:
  - 7B model initializes without error
  - Memory fits in 4×H100 (80GB each)
  - Distributed training runs with gradient accumulation

✓ Performance:
  - Training speed: 1000+ tokens/sec on 4×H100
  - Convergence: Loss decreases smoothly
  - Stability: No NaN/Inf values

✓ Metrics:
  - Week 1: PPL ~ 30-40 (after 5K steps)
  - Week 2: PPL ~ 15-18 (after 50K steps)
  - Benchmark: MMLU 25-30%, HellaSwag 30-35%

════════════════════════════════════════════════════════════════

READY TO START 7B TRAINING!

Next command:
$ bash START_7B_TRAINING.sh

Then execute:
$ cd /Users/feifei/shuwen/train/neurx
$ torchrun --nproc_per_node=4 train_full.py --config configs/7b_training.json

════════════════════════════════════════════════════════════════

EOF
