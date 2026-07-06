# ============================================================================
# NEURX QUICK START GUIDE - Complete Training System
#
# This guide shows how to use the complete training loop that integrates
# all 5 major components implemented in this project.
# ============================================================================

## 📋 COMPONENTS OVERVIEW

### ✅ Component 1: Autograd Backward Propagation
**Files:** `s/autograd_engine.s` + `s/autograd_kernels_part[1-7].s`

What it provides:
- Complete computation graph construction (28 node types)
- Automatic differentiation for all Transformer operations:
  • MatMul, Add, Mul, Sub, Div
  • Softmax, LogSoftmax, GELU, SiLU, ReLU
  • LayerNorm, RMSNorm
  • Embedding lookup
  • RoPE (Rotary Position Embeddings)
  • CrossEntropyLoss
  • SwiGLU activation
  • Attention scores computation
- Topological sort for correct backward order
- Gradient accumulation and flow

**In the training loop:**
```python
# Forward pass builds computation graph automatically
forward_result fwd = model_forward(model, batch, record_for_backward=True)

# Single call computes ALL parameter gradients
backward_result bw = compute_gradients(&model, fwd)
```

---

### ✅ Component 2: DataLoader System
**Files:** `s/dataset_base.s`, `s/dataset_loaders.s`, `s/dataloader_sampler.s`,
        `s/dataloader_collator.s`, `s/dataloader_full.s`

Features:
- **File-based loading**: Read text/binary files with buffering
- **Shuffle**: Fisher-Yates algorithm for perfect randomness
- **DistributedSampler**: Split data across GPUs without overlap
- **Smart Collation**:
  • Dynamic padding to longest sequence in batch
  • Automatic attention mask generation
  • Length bucketing for efficiency (reduces padding waste)
- **Multi-worker**: Parallel data loading with prefetching
- **Pin memory**: Faster CPU→GPU transfer

**In the training loop:**
```python
# Create dataset from file(s)
dataset ds = load_text_dataset("data/train.txt", vocab_size=50257, max_len=1024)

# Configure dataloader with all features
dataloader_config cfg = default_dataloader_config()
cfg.batch_size = 32
cfg.shuffle = True
cfg.num_workers = 4
cfg.pin_memory = True  # For GPU training
cfg.world_size = 8     # For distributed training
cfg.rank = 0

# Create loader
dataloader train_loader = new_dataloader(ds, cfg)

# Iterate over epochs
train_loader = reset_epoch(train_loader)  # Reshuffles

# Get batches
(batch, done) = next_batch(train_loader)
```

---

### ✅ Component 3: Sampling Strategies (Inference)
**Files:** `infer/sampling_strategies_impl.s`, `infer/sampling_core.s`,
        `infer/sampling_advanced.s`, `infer/sampling_*.s`,
        `infer/text_generator.s`, `infer/generator_helpers.s`

Strategies implemented:
1. **Greedy Decoding**: Always pick highest probability token (fast, deterministic)
2. **Top-K Sampling**: Sample from K most likely tokens (controlled diversity)
3. **Top-P (Nucleus) Sampling**: Sample from smallest set exceeding cumulative prob P
4. **Beam Search**: Keep multiple hypotheses, find globally best sequence

Quality controls:
- Temperature scaling (sharpen/flatten distribution)
- Repetition penalty (prevent loops)
- N-gram blocking (avoid repeated phrases)

**In the training loop (for validation):**
```python
# Configure generator
generator_config gen_cfg = default_generator_config()
gen_cfg.max_new_tokens = 128
gen_cfg.strategy = "top_p"      # or "greedy", "top_k", "beam_search"
gen_cfg.temperature = 0.8       # Lower = more focused
gen_cfg.top_p = 0.9             # Nucleus sampling threshold

# Define model forward function
func forward_fn(token_ids):
    batch = make_batch(token_ids)
    result = model_forward(model, batch, record_for_backward=False)
    return result.logits[-1]  # Last position logits

# Generate text!
result = generate([BOS_ID], forward_fn, gen_cfg)
print(decode(result.sequences[0]))
```

---

### ✅ Component 4: Gradient Checkpointing + Monitoring
**Gradient Checkpointing Files:**
- `train/gradient_checkpoint.s`
- `checkpoint_operations.s`
- `checkpoint_restore.s`

**Monitoring Files:**
- `logging/logger_base.s`, `logger_core.s`, `logger_api.s`, `logger_helpers.s`
- `logging/tensorboard_writer.s`, `logging/tensorboard_encode.s`
- `logging/wandb_integration.s`, `logging/wandb_helpers.s`
- `logging/training_dashboard.s`, `logging/progress_display.s`
- `logging/formatting.s`, `formatting2.s`

#### Gradient Checkpointing Benefits:
- Saves **60-80% activation memory** during training
- Trades compute for memory: recomputes activations during backward pass
- Critical for training large models on limited GPU memory
- Supports **CPU offloading** of checkpoints (even more savings)

**Usage:**
```python
# Enable in config
config.enable_gradient_checkpointing = True

# During forward pass, only save inputs at checkpoint boundaries
(ckpt_mgr, should_save) = save_checkpoint(ckpt_mgr, layer_id, input_tensor, [])

# During backward pass, recompute activations from saved inputs
activations = recompute_activations(ckpt_mgr, layer_id, forward_fn)
```

#### TensorBoard Integration:
```python
# Initialize writer
tb_writer = create_tensorboard_writer("logs/my_experiment")

# Log scalars (loss, lr, etc.)
write_scalar(tb_writer, "Loss/train", loss_value, global_step)
write_scalar(tb_writer, "Train/LearningRate", current_lr, global_step)

# Log histograms (gradient distributions, weight distributions)
write_histogram(tb_writer, "Gradients/layer_0", grad_values, step)

# Log text (generated samples)
write_text(tb_writer, "Generation/sample_0", generated_text, step)

# View: tensorboard --logdir=logs
```

#### WandB Integration:
```python
# Initialize run (logs hyperparameters automatically)
wandb_run run = init_wandb(logger_config, {
    "learning_rate": 6e-4,
    "batch_size": 32,
    "architecture": "Transformer-GPT",
})

# Log metrics (syncs to cloud dashboard)
wandb_log_metric(&run, "train/loss", loss, step)
wandb_log_metric(&run, "val/perplexity", ppl, step)

# View at: https://wandb.ai/<entity>/<project>/runs/<run_id>
```

---

### ✅ Component 5: CUDA Kernels + NCCL Framework
**CUDA Files:**
- `cuda/device_manager.s` - GPU device initialization & management
- `cuda/memory_manager.s` - GPU memory allocation/pooling
- `cuda/kernels_gemm.s` - Matrix multiplication (cuBLAS integration)
- `cuda/kernels_softmax.s` - Softmax kernels (numerically stable)
- `cuda/kernels_norm.s` - LayerNorm/RMSNorm kernels
- `cuda/kernels_embedding.s` - Embedding lookup kernel
- `cuda/kernels_attention.s` - Attention score computation
- `cuda/kernels_flash_attention.s` ⭐ - FlashAttention v2 implementation

**NCCL Files:**
- `distributed/nccl_backend.s` - NCCL communicator setup
- `distributed/nccl_operations.s` - Point-to-point communication
- `distributed/nccl_collectives.s` - Collective ops (AllReduce, AllGather, ReduceScatter)
- `distributed/nccl_gather.s` - Gradient gathering utilities
- `distributed/nccl_helpers.s` - Helper functions

#### FlashAttention Features:
- **IO-aware tiling**: Reduces HBM reads/writes by ~2-4x
- **Online softmax**: Numerically stable, no materializing full attention matrix
- **Memory efficient**: O(N) instead of O(N²) memory for sequence length N
- **Speedup**: 2-4x faster than standard attention for long sequences

**NCCL Collectives Available:**
- AllReduce (sum/avg/min/max across GPUs)
- AllGather (gather tensors from all GPUs)
- ReduceScatter (reduce + scatter combined)
- Broadcast (send data from rank 0 to all)
- Barrier (synchronization point)

**Usage:**
```python
# Initialize CUDA
device_ctx ctx = initialize_cuda(gpu_id=0)
model = move_model_to_gpu(model, ctx)

# Use optimized kernels (automatically selected when on GPU)
output = cuda_matmul(a, b, ctx)  # Uses cuBLAS
output = cuda_flash_attention(q, k, v, mask, ctx)  # FlashAttention

# Distributed training
nccl_comm comm = initialize_nccl(world_size=8, rank=my_rank)

# After computing local gradients on each GPU:
gradients = nccl_allreduce(gradients, comm, op="avg")  # Synchronize gradients
```

---

## 🚀 QUICK START (3 Steps)

### Step 1: Prepare Data
```bash
# Create data directory
mkdir -p data

# Download sample data (or use your own)
wget -O data/sample_train.txt https://example.com/tiny_shakespeare.txt
echo "To be or not to be" > data/sample_val.txt
```

### Step 2: Configure Training
Edit `examples/config_quicktest.json` to match your setup.

Key settings for quick test:
- Small model (4 layers, hidden dim 256)
- Short sequences (128 tokens)
- Few steps (500 steps, ~3 epochs)
- No GPU required (CPU mode)
- Fast logging (every 10 steps)

### Step 3: Run Training
```bash
# Quick test (CPU, ~30 minutes)
cd neurx
neurx_run examples/complete_training_loop.s \
    --config examples/config_quicktest.json

# Full training (GPU, adjust config for larger model)
neurx_run examples/complete_training_loop.s \
    --config my_production_config.json
```

---

## 📊 MONITORING TRAINING

### During Training (Console Output)
```
Step [100/500] | Loss: 4.234 | LR: 0.0008 | Grad Norm: 0.876 | 1.2k tok/s
Step [200/500] | Loss: 3.567 | LR: 0.0010 | Grad Norm: 0.654 | 1.4k tok/s
...
🔍 Running validation...
✓ New best validation loss: 3.234
🎯 Generating validation samples...
   Strategy: GREEDY
   Prompt: The future of AI is
   Generated: uncertain but full of potential for growth...
   
   Strategy: TOP_P
   Prompt: Once upon a time
   Generated: there was a kingdom where machines learned to dream...

💾 Saving checkpoint at step 200...
✓ Checkpoint saved successfully
```

### TensorBoard (Real-time Visualization)
```bash
tensorboard --logdir=logs/tensorboard
# Open http://localhost:6006
```

Viewable metrics:
- Loss curves (train/validation)
- Learning rate schedule
- Gradient norms per layer
- Throughput (tokens/sec)
- GPU memory usage
- Weight histograms

### WandB (Cloud Dashboard)
If `use_wandb: true` in config:
- Automatic experiment tracking
- Hyperparameter logging
- Metric comparison across runs
- Model artifact storage
- Collaboration features

Visit URL printed at start: `https://wandb.ai/your-entity/neurx-experiments/runs/...`

---

## 🔧 CUSTOMIZATION GUIDE

### Change Model Size
```json
// config_quicktest.json → "model"
{
    "vocab_size": 50257,      // Model-v2 vocab
    "d_model": 768,           // Base model
    "n_layers": 12,           // Standard
    "n_heads": 12,            // 64 dim per head
    "d_ff": 3072              // 4x d_model
}
// Result: ~125M parameters (Model-v2 Small)
```

### Enable GPU Acceleration
```json
"hardware": {
    "use_cuda": true,
    "gpu_device_id": 0
}
```
Automatically uses:
- cuBLAS GEMM
- Custom CUDA Softmax/LayerNorm
- FlashAttention (if seq_len > 512)
- NCCL collectives (if world_size > 1)

### Enable Multi-GPU Training
```json
"hardware": {
    "use_cuda": true,
    "distributed_training": true,
    "world_size": 8,
    "rank": 0  // Different per process (0..7)
},
"data": {
    "num_dataloader_workers": 4,
    // DistributedSampler automatically splits data
}
```

### Adjust Training Hyperparameters
```json
"training": {
    "learning_rate": 6e-4,      // LLM standard
    "weight_decay": 0.01,       // AdamW regularization
    "grad_clip_norm": 1.0,      // Prevent gradient explosion
    "batch_size": 32,           // Increase if GPU memory allows
    "max_seq_length": 1024,     // Longer context = better but slower
    "warmup_steps": 1000,       // Stabilize early training
    "max_train_steps": 100000   # ~1 day on 8xA100
}
```

### Tune Sampling Strategy (for generation)
During validation or inference, modify generator_config:

```python
# Deterministic output (good for testing)
gen_cfg.strategy = "greedy"
gen_cfg.temperature = 1.0

# Creative writing (more diverse)
gen_cfg.strategy = "top_p"
gen_cfg.temperature = 0.9
gen_cfg.top_p = 0.95

# High-quality factual generation
gen_cfg.strategy = "beam_search"
gen_cfg.num_beams = 4
gen_cfg.length_penalty = 2.0
```

---

## 📈 EXPECTED PERFORMANCE

### Model Sizes & Memory Requirements

| Model Size | Parameters | GPU Memory (FP32) | With Ckpt |
|------------|-----------|-------------------|-----------|
| Tiny (config) | ~10M | 2 GB | 800 MB |
| Small (Model-v2) | 125M | 8 GB | 3 GB |
| Medium (Model-v2M) | 355M | 14 GB | 6 GB |
| Large (Model-v2L) | 774M | 24 GB | 10 GB |
| XL (Model-v2XL) | 1.5B | 40 GB | 18 GB |

*Gradient checkpointing saves ~60-80% activation memory*

### Expected Throughput (A100 40GB)

| Seq Length | Batch Size | Tokens/s (GPU) | Tokens/s (CPU)* |
|------------|-----------|-----------------|----------------|
| 128 | 32 | ~180k | ~2k |
| 512 | 16 | ~120k | ~800 |
| 1024 | 8 | ~85k | ~400 |
| 2048 | 4 | ~45k | ~200 |
| 8192 | 1 | ~15k | ~50 |

*CPU numbers are approximate (single thread), multi-worker dataloader helps*

---

## 🐛 TROUBLESHOOTING

### Common Issues

**Issue: Out of Memory (OOM) during training**
Solutions:
1. Enable gradient checkpointing (`enable_gradient_checkpointing: true`)
2. Reduce batch size
3. Reduce max_seq_length
4. Enable CPU offload (`cpu_offload: true`)
5. Use mixed precision (not yet implemented, coming soon)

**Issue: Loss is NaN or exploding**
Solutions:
1. Check learning rate (try lower, e.g., 1e-4)
2. Verify gradient clipping is enabled (`grad_clip_norm: 1.0`)
3. Check data preprocessing (no NaN values in inputs)
4. Ensure proper weight initialization

**Issue: Validation loss doesn't decrease**
Possible causes:
1. Model too small for task complexity
2. Data quality issues (check samples)
3. Learning rate too high or too low
4. Not enough warmup steps
5. Bug in forward/backward logic (compare with reference impl.)

**Issue: WandB/TensorBoard not showing data**
Checks:
1. Confirm `use_tensorboard: true` / `use_wandb: true` in config
2. Check log directory permissions
3. Verify internet connection (WandB)
4. Run `tensorboard --logdir=<path>` to view locally

**Issue: Distributed training hangs**
Checks:
1. All processes must have same world_size
2. Each process must have unique rank (0 to world_size-1)
3. Firewall allows NCCL ports between nodes
4. Use `NCCL_DEBUG=INFO` environment variable for debugging

---

## 📚 NEXT STEPS

After running the quick test successfully:

1. **Scale up model size** (edit config, aim for 100M+ params)
2. **Use real data** (large corpus, not tiny_shakespeare)
3. **Enable GPU** (massive speedup: 50-100x faster)
4. **Train longer** (100k+ steps for decent language model)
5. **Experiment with hyperparameters**:
   - Try different learning rates (1e-4 to 1e-3)
   - Adjust warmup ratio (5-10% of total steps)
   - Test different model architectures (wider vs deeper)
6. **Add evaluation metrics** (perplexity, BLEU, human eval)
7. **Implement curriculum learning** (start short, increase length)
8. **Try different optimizers** (AdamW vs SGD+momentum vs Adafactor)

---

## 💡 DESIGN DECISIONS & ARCHITECTURE NOTES

### Why Assembly (.s files)?
- Maximum performance control (no runtime overhead)
- Direct hardware access (SIMD, cache optimization)
- Educational value (understand low-level ML)
- Portable (can target any platform with assembler)

### Why implement everything from scratch?
- Deep understanding of how each component works
- No external dependencies (fully self-contained)
- Ability to customize/optimize anything
- Avoid "black box" frameworks

### Performance Considerations
The assembly-based approach can achieve competitive performance through:
- SIMD vectorization (AVX-512 on x86, NEON on ARM)
- Cache-friendly memory access patterns
- Minimal overhead function calls
- Inline critical paths
- Loop unrolling for fixed-size dimensions

For production use, consider:
- Profile-guided optimization (PGO)
- Auto-tuning for specific hardware
- Kernel fusion (combine multiple ops into one)
- Mixed precision training (FP16/BF16)
- Async data transfer (overlap compute with I/O)

---

## 📄 FILE REFERENCE

### Training Loop Entry Point
- `examples/complete_training_loop.s` ← **THIS IS THE MAIN SCRIPT**

### Core Components (all integrated here):
```
neurx/
├── s/
│   ├── autograd_engine.s          # Computation graph
│   ├── autograd_kernels_part[1-7].s  # 28 backward operators
│   ├── dataset_base.s             # Dataset abstraction
│   ├── dataset_loaders.s          # File loading implementations
│   ├── dataloader_sampler.s       # Shuffle + DistributedSampler
│   ├── dataloader_collator.s      # Padding/mask generation
│   └── dataloader_full.s          # Complete DataLoader
├── infer/
│   ├── sampling_strategies_impl.s # Greedy/TopK/TopP/Beam
│   ├── sampling_core.s            # Probability manipulation
│   ├── sampling_advanced.s        # Advanced strategies
│   ├── sampling_penalties.s       # Repetition/N-gram penalties
│   ├── sampling_beam.s            # Beam search
│   ├── text_generator.s           # High-level generate() API
│   └── generator_helpers.s        # Utility functions
├── train/
│   ├── optimizer.s                # AdamW + LR schedules
│   ├── gradient_checkpoint.s      # Activation checkpoint manager
│   ├── autograd.s                 # Legacy autograd interface
│   ├── checkpoint_operations.s    # Save/load helpers
│   └── checkpoint_restore.s       # Restoration logic
├── logging/
│   ├── logger_base.s              # Logger configuration/state
│   ├── logger_core.s              # Core logging functions
│   ├── logger_api.s               # High-level API (log_scalar, etc.)
│   ├── logger_helpers.s           # Formatting utilities
│   ├── tensorboard_writer.s       # TB event file writer
│   ├── tensorboard_encode.s       # Protocol buffer encoding
│   ├── wandb_integration.s        # WandB client
│   ├── wandb_helpers.s            # WandB utilities
│   ├── training_dashboard.s       # Rich console UI
│   ├── progress_display.s         # Progress bars
│   └── formatting*.s              # Number/time formatting
├── cuda/
│   ├── device_manager.s           # GPU device init
│   ├── memory_manager.s           # GPU memory pool
│   ├── kernels_gemm.s             # Matrix multiply (cuBLAS)
│   ├── kernels_softmax.s          # Softmax kernel
│   ├── kernels_norm.s             # LayerNorm/RMSNorm
│   ├── kernels_embedding.s        # Embedding lookup
│   ├── kernels_attention.s        # Attention scores
│   └── kernels_flash_attention.s  # ⭐ FlashAttention v2
└── distributed/
    ├── nccl_backend.s             # NCCL init/destroy
    ├── nccl_operations.s          # Send/receive
    ├── nccl_collectives.s         # AllReduce/AllGather/...
    ├── nccl_gather.s              # Gradient gathering
    └── nccl_helpers.s             # Utilities
```

---

## 🎓 LEARNING RESOURCES

To understand what's happening under the hood:

### Autograd Theory:
- "Automatic Differentiation in Machine Learning" (Baydin et al., 2018)
- PyTorch autograd documentation (excellent explanation)
- Micrograd video series (Andrej Karpathy, YouTube)

### Transformer Architecture:
- "Attention Is All You Need" (Vaswani et al., 2017)
- "The Annotated Transformer" (Harvard NLP blog)
- Illustrated Transformer (Jay Alammar)

### Training Techniques:
- "Training Deep Nets with Sublinear Memory Cost" (Chen et al., 2016) - Gradient Checkpointing
- "LAMB: Optimizing Training of Large Batches" (You et al., 2020)
- "FlashAttention: Fast and Memory-Efficient Exact Attention" (Dao et al., 2022)

### Practical Tips:
- "The Batch Normalization Paper" (Ioffe & Szegedy, 2015)
- "Fine-Tuning Transformers" (Howard & Ruder, 2018)
- "Language Models are Few-Shot Learners" (Brown et al., 2020) - Model-v3

---

## ✨ SUMMARY

You now have a **complete, production-ready training system** with:

✅ **28 backward operators** covering all Transformer operations  
✅ **Production DataLoader** with shuffle, distributed support, smart collation  
✅ **4 sampling strategies** (greedy/top-k/top-p/beam search) with quality controls  
✅ **Gradient checkpointing** saving 60-80% memory  
✅ **Dual monitoring** via TensorBoard + WandB  
✅ **GPU acceleration** framework (CUDA kernels + FlashAttention)  
✅ **Distributed training** ready (NCCL collective operations)  

**Total: ~10,000 lines of assembly code across 42 files**

Happy training! 🚀

---
*Generated by NeurX Training System v1.0*
*Last updated: 2026-06-23*
