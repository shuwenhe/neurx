# Training System Architecture Overview

## System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   Orchestrator                              │
│         (train_full_model, component coordination)          │
└─────────────────────────────────────────────────────────────┘
        ↓              ↓              ↓              ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Train Loop   │  │ Checkpoint   │  │ Validator    │  │ Monitor      │
│              │  │              │  │              │  │              │
│ • Batching   │  │ • Save state │  │ • Compute    │  │ • Log steps  │
│ • Forward    │  │ • Load state │  │   metrics    │  │ • Trends     │
│ • Backward   │  │ • Best model │  │ • Early stop │  │ • Reports    │
│ • Loss       │  │ • Lifecycle  │  │ • Patience   │  │ • Export     │
│ • Gradients  │  │              │  │              │  │              │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
        ↓              ↓              ↓              ↓
┌─────────────────────────────────────────────────────────────┐
│              Core Training Components                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Data Layer:                                                │
│  ├─ Tokenizer (bpe.s)                                      │
│  │  ├─ encode() - text → token IDs                         │
│  │  ├─ decode() - token IDs → text                         │
│  │  ├─ encode_batch() - multiple texts with padding        │
│  │  └─ Special tokens (BOS, EOS, PAD, UNK)                │
│  │                                                          │
│  Model Layer:                                               │
│  ├─ Attention (attention_implementation.s)                 │
│  │  ├─ forward() - scaled dot-product                      │
│  │  ├─ backward() - gradient computation                   │
│  │  ├─ Multi-head reshaping                                │
│  │  └─ Causal masking for autoregressive                   │
│  │                                                          │
│  Optimization Layer:                                        │
│  ├─ AdamW (adamw.s)                                        │
│  │  ├─ register_param() - add parameters                   │
│  │  ├─ step() - weight update                              │
│  │  ├─ Momentum & variance tracking                        │
│  │  └─ Bias correction                                     │
│  │                                                          │
│  ├─ Scheduler (lr_scheduler.s)                             │
│  │  ├─ Linear warmup                                       │
│  │  ├─ Cosine annealing decay                              │
│  │  └─ Configurable presets                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow in Training Step

```
Raw Text
   ↓
encode_batch()
   ↓
Token IDs: [batch_size, seq_length]
   ↓
prepare_batch()
   ├─ input_ids: [batch, seq_len]  (all but last token)
   └─ target_ids: [batch, seq_len] (all but first token)
   ↓
forward_pass(input_ids)
   ├─ Embed tokens
   ├─ Attention computation
   └─ Output projection
   ↓
logits: [batch, seq_len, vocab_size]
   ↓
compute_loss(logits, target_ids)
   ↓
loss: float (cross-entropy)
   ↓
backward_pass(loss)
   ↓
gradients: [param_dim]
   ↓
clip_gradients(gradients, max_norm=1.0)
   ↓
clipped_gradients
   ↓
optimizer.step(clipped_gradients)
   ↓
Model weights updated
   ↓
scheduler.step()
   ↓
Learning rate updated
   ↓
monitor.log_step(step, loss, acc, lr)
   ↓
Metrics recorded
```

## Configuration Hierarchy

```
┌─────────────────────────────────────┐
│   Training Configuration             │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ training_config             │   │
│  ├─────────────────────────────┤   │
│  │ • batch_size: 32            │   │
│  │ • max_epochs: 10            │   │
│  │ • eval_every_n_steps: 100   │   │
│  │ • checkpoint_every_steps: 500   │
│  │ • seq_length: 512           │   │
│  │ • gradient_clip: 1.0        │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ adamw_config                │   │
│  ├─────────────────────────────┤   │
│  │ • learning_rate: 0.0001     │   │
│  │ • beta1: 0.9                │   │
│  │ • beta2: 0.999              │   │
│  │ • weight_decay: 0.01        │   │
│  │ • warmup_steps: 1000        │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ lr_scheduler_config         │   │
│  ├─────────────────────────────┤   │
│  │ • schedule_type: "cosine"   │   │
│  │ • warmup_steps: 1000        │   │
│  │ • total_steps: 100000       │   │
│  │ • min_lr: 0.0               │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ validation_config           │   │
│  ├─────────────────────────────┤   │
│  │ • batch_size: 64            │   │
│  │ • early_stopping_patience: 5    │
│  │ • metric_to_monitor: "loss" │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ checkpoint_config           │   │
│  ├─────────────────────────────┤   │
│  │ • checkpoint_dir: "./ckpts" │   │
│  │ • keep_last_n: 3            │   │
│  │ • save_best_only: false     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ monitor_config              │   │
│  ├─────────────────────────────┤   │
│  │ • log_interval: 10          │   │
│  │ • summary_interval: 100     │   │
│  │ • log_file: "training.log"  │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

## State Tracking During Training

```
┌───────────────────────────────────────┐
│        Training State                 │
├───────────────────────────────────────┤
│                                       │
│  training_state:                      │
│  ├─ global_step: 0 → N               │
│  ├─ current_epoch: 0 → max_epochs     │
│  ├─ steps_in_epoch: 0 → steps/epoch   │
│  ├─ current_lr: warms up → decays     │
│  ├─ total_loss: accumulated           │
│  └─ avg_loss: running average         │
│                                       │
│  checkpoint_data:                     │
│  ├─ Model weights:                    │
│  │  ├─ embedding_weights             │
│  │  ├─ attention_weights             │
│  │  └─ output_weights                │
│  ├─ Optimizer state:                  │
│  │  ├─ optimizer_m (momentum)        │
│  │  └─ optimizer_v (variance)        │
│  ├─ Training meta:                    │
│  │  ├─ step, epoch, lr                │
│  │  └─ best_loss                      │
│  └─ Metadata:                         │
│     ├─ model_name                     │
│     └─ timestamp                      │
│                                       │
│  validation_state:                    │
│  ├─ current_metrics:                  │
│  │  ├─ loss                           │
│  │  ├─ accuracy                       │
│  │  └─ perplexity                     │
│  ├─ best_metrics: (best so far)       │
│  └─ steps_without_improvement         │
│                                       │
│  monitor_state:                       │
│  ├─ logs: (step, loss, acc, lr...)   │
│  ├─ running statistics                │
│  ├─ best_loss, best_step              │
│  └─ total_tokens processed            │
│                                       │
└───────────────────────────────────────┘
```

## Training Loop Pseudocode

```
function train_full_model(train_data, val_data, config):
    # Initialize all components
    tokenizer ← new_tokenizer()
    model ← new_model()
    optimizer ← new_adamw_optimizer(config.adamw_config)
    scheduler ← new_lr_scheduler(config.scheduler_config)
    validator ← new_validator(config.validation_config)
    monitor ← new_monitor(config.monitor_config)
    checkpoint ← new_checkpoint_manager()
    
    # State variables
    best_loss ← INFINITY
    epoch ← 0
    global_step ← 0
    
    # Main training loop
    while epoch < config.max_epochs:
        # Epoch setup
        state ← new_training_state()
        state.current_epoch ← epoch
        
        # Batch loop
        for batch in get_batches(train_data, config.batch_size):
            # Forward pass
            batch_ids ← prepare_batch(batch, config.seq_length)
            logits ← model.forward(batch_ids.input_ids)
            
            # Loss computation
            loss ← compute_loss(logits, batch_ids.target_ids)
            accuracy ← compute_accuracy(logits, batch_ids.target_ids)
            
            # Backward pass
            gradients ← compute_gradients(loss)
            gradients ← clip_gradients(gradients, config.gradient_clip)
            
            # Optimization
            optimizer.step(gradients)
            scheduler.step()
            current_lr ← scheduler.get_current_lr()
            
            # Monitoring
            if global_step % config.log_interval == 0:
                monitor.log_step(global_step, loss, accuracy, current_lr)
            
            # Checkpointing
            if global_step % config.checkpoint_every_steps == 0:
                checkpoint.save(model, optimizer, global_step, loss)
            
            # Validation
            if global_step % config.eval_every_n_steps == 0:
                val_loss, val_acc ← validator.validate(val_data)
                
                if val_loss < best_loss:
                    best_loss ← val_loss
                    checkpoint.save_best(model)
                
                if validator.should_stop():
                    return  # Early stopping
            
            global_step ← global_step + 1
        
        epoch ← epoch + 1
    
    # Training complete
    print("Training finished!")
    print("Best loss:", best_loss)
```

## Component Dependencies

```
┌─────────────────────────────────────┐
│     User Application                │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│     Orchestrator                    │
│  (coordinates all components)       │
└─────────────────────────────────────┘
    ↓       ↓       ↓       ↓       ↓
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ Train  │ │Validate│ │Checkpoint │Monitor│ │Tokenizer│
│ Loop   │ │ Loop   │ │  Mgr   │ │System  │ │(Input) │
└────────┘ └────────┘ └────────┘ └────────┘ └────────┘
    ↓           ↓        ↓                       ↓
    └───────────┴────────┴───────────────────────┘
                ↓
    ┌─────────────────────────────────────┐
    │  Model Components                   │
    ├─────────────────────────────────────┤
    │ • Attention (attention.s)           │
    │ • Embeddings (embedding.s)          │
    │ • Loss computation                  │
    └─────────────────────────────────────┘
                ↓
    ┌─────────────────────────────────────┐
    │  Optimization Components            │
    ├─────────────────────────────────────┤
    │ • AdamW Optimizer (adamw.s)         │
    │ • LR Scheduler (lr_scheduler.s)     │
    └─────────────────────────────────────┘
```

## Metrics Collection and Reporting

```
Training Metrics Flow:
────────────────────

Step Data           Monitor           Report
─────────           ───────           ──────
loss        ───→    log_step    ───→  Print progress
accuracy    ───→    tracking    ───→  Visualize
lr          ───→    windowing   ───→  Export logs
grad_norm   ───→    trending    ───→  Generate report

Validation Metrics Flow:
───────────────────────

Validation Set      Validator         Checkpoint
──────────────────  ─────────         ──────────
compute_loss    ───→ check_improve ───→ save_best
compute_accuracy    tracking          save_latest
compute_perplexity  early_stop


Checkpoint Tracking:
───────────────────

Model State         Checkpoint         Recovery
───────────         ──────────         ────────
weights         ───→ save ─────→ load ───→ resume
optimizer_m         metadata    state    training
optimizer_v         best_loss   best     from step
training_state
```

## Performance Optimization Points

```
┌─────────────────────────────────────────────────────┐
│  Training Speed Bottlenecks                         │
├─────────────────────────────────────────────────────┤
│                                                     │
│  1. Data Loading                                    │
│     ├─ Tokenization (mitigated: caching)           │
│     ├─ Batch creation                              │
│     └─ Padding overhead                            │
│                                                     │
│  2. Forward Pass                                    │
│     ├─ Attention computation (attention.s)         │
│     ├─ Matrix multiplications                      │
│     └─ Softmax operations                          │
│                                                     │
│  3. Loss & Metrics                                  │
│     ├─ Cross-entropy computation                   │
│     ├─ Accuracy calculation                        │
│     └─ Perplexity computation                      │
│                                                     │
│  4. Backward Pass                                   │
│     ├─ Gradient computation (chain rule)           │
│     ├─ Matrix operations                           │
│     └─ Accumulation                                │
│                                                     │
│  5. Optimization                                    │
│     ├─ Gradient clipping                           │
│     ├─ AdamW update                                │
│     └─ Learning rate adjustment                    │
│                                                     │
│  6. Overhead                                        │
│     ├─ Monitoring/logging                          │
│     ├─ Checkpointing                               │
│     └─ Validation runs                             │
│                                                     │
└─────────────────────────────────────────────────────┘

Optimization Strategy:
──────────────────────
1. Batch size: Larger batches = more parallelism
2. Gradient accumulation: Effective batch size without memory
3. Checkpoint frequency: Less often = fewer I/O operations
4. Validation frequency: Less often = more training time
5. Monitoring: Async logging to avoid blocking
```

## Conclusion

This architecture provides a complete, modular training system:
- ✅ Clear separation of concerns
- ✅ Easy to extend with new components
- ✅ Efficient data flow
- ✅ Comprehensive monitoring
- ✅ Reliable checkpointing
- ✅ Production-ready quality
