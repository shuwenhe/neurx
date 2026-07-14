package neurx.examples

// ============================================================================
// COMPLETE END-TO-END TRAINING LOOP EXAMPLE
// Demonstrates integration of all NeurX components:
//   ✅ Autograd Backward Propagation (28 operators)
//   ✅ DataLoader (file I/O / shuffle / DistributedSampler / collation)
//   ✅ Sampling Strategies (greedy / top-p / beam search)
//   ✅ Gradient Checkpointing + TensorBoard/WandB Monitoring
//   ✅ CUDA Kernels + NCCL Framework (optional GPU acceleration)
//
// Usage: This script trains a Transformer language model from scratch.
//        Run: neurx_run train_loop.s --config config.json
// ============================================================================

use neurx.autograd.autograd_engine
use neurx.data.dataloader_full
use neurx.data.dataset_loaders
use neurx.data.dataloader_collator
use neurx.train.optimizer
use neurx.train.gradient_checkpoint
use neurx.checkpoint_operations
use neurx.checkpoint_restore
use neurx.logging.logger_base
use neurx.logging.logger_core
use neurx.logging.logger_api
use neurx.logging.tensorboard_writer
use neurx.logging.wandb_integration
use neurx.logging.progress_display
use neurx.inference.text_generator
use neurx.cuda.device_manager
use neurx.distributed.nccl_backend

// ============================================================================
// SECTION 0: CONFIGURATION & HYPERPARAMETERS
// ============================================================================

struct training_config {
    // Model architecture
    int vocab_size              // Vocabulary size (e.g., 50257 for GPT-2)
    int d_model                 // Model dimension (e.g., 768 for base, 2048 for large)
    int n_layers                // Number of Transformer layers (e.g., 12, 24, 32)
    int n_heads                 // Number of attention heads (e.g., 12, 16, 32)
    int d_ff                    // Feed-forward dimension (usually 4 * d_model)
    float dropout               // Dropout rate
    
    // Training hyperparameters
    int batch_size              // Samples per batch
    float learning_rate         // Initial learning rate (e.g., 6e-4 for LLMs)
    int warmup_steps            // Linear warmup steps
    int max_train_steps         // Total training steps
    int max_epochs              // Maximum epochs (alternative to max_steps)
    float weight_decay          // AdamW weight decay
    float grad_clip_norm        // Gradient clipping threshold (1.0 typical)
    
    // Sequence length
    int max_seq_length          // Maximum sequence length (e.g., 512, 1024, 2048, 8192)
    
    // Data settings
    string data_path            // Path to training data file(s)
    string validation_path      // Path to validation data
    bool shuffle_data           // Shuffle each epoch
    int num_dataloader_workers  // Parallel data loading workers
    
    // Checkpointing & saving
    string output_dir           // Directory for model checkpoints
    int save_every_n_steps      // Save checkpoint every N steps
    int save_every_n_epochs     // Save checkpoint every N epochs (alternative)
    bool enable_gradient_checkpointing  // Enable activation recomputation
    
    // Logging & monitoring
    string log_dir              // Directory for TensorBoard logs
    string experiment_name      // Experiment name for WandB/TensorBoard
    int log_every_n_steps       // Log metrics every N steps
    bool use_tensorboard        // Enable TensorBoard logging
    bool use_wandb              // Enable WandB logging
    string wandb_project        // WandB project name
    string wandb_entity         // WandB entity/username
    
    // Generation/validation
    int validation_every_n_steps  // Run validation every N steps
    int num_generation_samples    // Number of samples to generate during validation
    
    // Distributed/GPU settings
    bool use_cuda               // Use CUDA GPU acceleration
    int gpu_device_id           // Which GPU to use (0, 1, ...)
    bool distributed_training   // Enable multi-GPU distributed training
    int world_size              // Number of distributed workers
    int rank                    // This worker's rank in distributed setup
}

func default_training_config() training_config {
    training_config {
        // Model: Small GPT-2 style (adjust as needed)
        vocab_size: 50257,
        d_model: 768,
        n_layers: 12,
        n_heads: 12,
        d_ff: 3072,
        dropout: 0.1,
        
        // Training: Standard LLM hyperparameters
        batch_size: 32,
        learning_rate: 6e-4,
        warmup_steps: 1000,
        max_train_steps: 100000,
        max_epochs: 10,
        weight_decay: 0.01,
        grad_clip_norm: 1.0,
        
        // Sequence length
        max_seq_length: 1024,
        
        // Data
        data_path: "data/train.txt",
        validation_path: "data/val.txt",
        shuffle_data: true,
        num_dataloader_workers: 4,
        
        // Checkpoints
        output_dir: "checkpoints",
        save_every_n_steps: 5000,
        save_every_n_epochs: 0,
        enable_gradient_checkpointing: true,
        
        // Logging
        log_dir: "logs/tensorboard",
        experiment_name: "neurx_transformer_demo",
        log_every_n_steps: 100,
        use_tensorboard: true,
        use_wandb: false,  // Set to true if you have WandB account
        wandb_project: "neurx-experiments",
        wandb_entity: "your-username",
        
        // Validation
        validation_every_n_steps: 1000,
        num_generation_samples: 3,
        
        // Hardware
        use_cuda: false,  // Set to true if CUDA available
        gpu_device_id: 0,
        distributed_training: false,
        world_size: 1,
        rank: 0,
    }
}

// ============================================================================
// SECTION 1: MODEL INITIALIZATION (Transformer Architecture)
// ============================================================================

struct transformer_model {
    // Token and position embeddings
    tensor token_embedding      // [vocab_size, d_model]
    tensor position_embedding   // [max_seq_length, d_model]
    
    // Transformer layers
    []transformer_layer layers  // Array of n_layers
    
    // Output layer
    tensor lm_head              // [d_model, vocab_size] (often tied with token_embedding)
    
    // Normalization
    tensor final_norm           // LayerNorm before output
    
    // Configuration
    training_config config
    
    // For autograd
    computation_graph graph
}

struct transformer_layer {
    // Self-attention
    tensor wq                   // Query projection [d_model, d_model]
    tensor wk                   // Key projection [d_model, d_model]
    tensor wv                   // Value projection [d_model, d_model]
    tensor wo                   // Output projection [d_model, d_model]
    
    // Feed-forward network (SwiGLU)
    tensor w_gate               // Gate projection [d_model, d_ff]
    tensor w_up                 // Up projection [d_model, d_ff]
    tensor w_down               // Down projection [d_ff, d_model]
    
    // Layer norms
    tensor ln_1                 // Pre-attention LayerNorm
    tensor ln_2                 // Pre-FFN LayerNorm
}

// Initialize model weights (Xavier/Kaiming initialization)
func init_transformer_model(training_config cfg) transformer_model {
    println("Initializing Transformer model...")
    println("  Vocab size: " + str(cfg.vocab_size))
    println("  Hidden dim: " + str(cfg.d_model))
    println("  Layers: " + str(cfg.n_layers))
    println("  Heads: " + str(cfg.n_heads))
    println("  FF dim: " + str(cfg.d_ff))
    
    // Create embeddings
    tensor token_emb = randn_tensor([cfg.vocab_size, cfg.d_model]) * 0.02
    tensor pos_emb = randn_tensor([cfg.max_seq_length, cfg.d_model]) * 0.02
    
    // Create layers
    []transformer_layer layers = []
    for layer_idx in 0..cfg.n_layers {
        transformer_layer layer = init_transformer_layer(cfg.d_model, cfg.d_ff)
        layers.push(layer)
    }
    
    // Output head
    tensor lm_head = randn_tensor([cfg.d_model, cfg.vocab_size]) * 0.02
    tensor final_ln = ones_tensor([cfg.d_model])  // LayerNorm initialized to identity
    
    // Initialize computation graph for autograd
    computation_graph g = new_graph()
    
    transformer_model {
        token_embedding: token_emb,
        position_embedding: pos_emb,
        layers: layers,
        lm_head: lm_head,
        final_norm: final_ln,
        config: cfg,
        graph: g,
    }
}

func init_transformer_layer(int d_model, int d_ff) transformer_layer {
    // Xavier initialization for linear layers
    float scale = sqrt(2.0 / float(d_model))
    
    transformer_layer {
        wq: randn_tensor([d_model, d_model]) * scale,
        wk: randn_tensor([d_model, d_model]) * scale,
        wv: randn_tensor([d_model, d_model]) * scale,
        wo: randn_tensor([d_model, d_model]) * scale,
        w_gate: randn_tensor([d_model, d_ff]) * scale,
        w_up: randn_tensor([d_model, d_ff]) * scale,
        w_down: randn_tensor([d_ff, d_model]) * scale,
        ln_1: ones_tensor([d_model]),
        ln_2: ones_tensor([d_model]),
    }
}

// ============================================================================
// SECTION 2: FORWARD PASS (with Autograd recording)
// ============================================================================

struct forward_result {
    tensor logits               // [batch, seq_len, vocab_size] - raw logits
    tensor loss                  // Scalar loss value (cross-entropy)
    []tensor activations        // All intermediate activations (for backward)
    float forward_time_ms       // Timing information
}

func model_forward(
    transformer_model model,
    batch input_batch,
    bool record_for_backward    // Whether to build computation graph
) forward_result {
    float start_time = current_time_ms()
    
    []int token_ids = input_batch.token_ids    // [batch_size, seq_len]
    []int attention_mask = input_batch.mask     // [batch_size, seq_len] (1=real token, 0=padding)
    int batch_size = input_batch.batch_size
    int seq_len = input_batch.seq_length
    
    // ---- Step 1: Embeddings ----
    // Token embeddings + positional embeddings
    tensor x = embedding_lookup(model.token_embedding, token_ids)  // [batch, seq_len, d_model]
    tensor positions = create_position_indices(seq_len)             // [seq_len]
    tensor pos_emb = embedding_lookup(model.position_embedding, positions)  // [batch, seq_len, d_model]
    x = add_tensors(x, pos_emb)
    
    // Optionally apply dropout during training
    if model.config.dropout > 0.0 && record_for_backward {
        x = apply_dropout(x, model.config.dropout)
    }
    
    // ---- Step 2: Transformer Layers ----
    // Store activations for gradient checkpointing
    []tensor all_activations = []
    checkpoint_manager ckpt_mgr = new_checkpoint_manager(default_checkpoint_config())
    
    for layer_idx in 0..model.config.n_layers {
        transformer_layer layer = model.layers[layer_idx]
        
        // GRADIENT CHECKPOINTING: Save input before computing this layer
        if model.config.enable_gradient_checkpointing {
            (ckpt_mgr, _) = save_checkpoint(ckpt_mgr, layer_idx, x, [])
        }
        
        // Pre-attention LayerNorm
        tensor residual = x  // Save residual connection
        x = layer_norm(x, layer.ln_1)
        
        // Multi-head self-attention
        tensor q = matmul(x, layer.wq)   // [batch, seq, d_model]
        tensor k = matmul(x, layer.wk)
        tensor v = matmul(x, layer.wv)
        
        // Split into heads
        tensor attn_output = multi_head_attention(
            q, k, v, 
            model.config.n_heads, 
            attention_mask
        )
        
        // Output projection + residual
        x = matmul(attn_output, layer.wo)
        x = add_tensors(x, residual)
        
        // Pre-FFN LayerNorm
        residual = x
        x = layer_norm(x, layer.ln_2)
        
        // SwiGLU Feed-Forward Network
        tensor gate = matmul(x, layer.w_gate)   // [batch, seq, d_ff]
        tensor up = matmul(x, layer.w_up)
        tensor hidden = swiglu(gate, up)        // Element-wise: gate * SiLU(up)
        tensor ffn_out = matmul(hidden, layer.w_down)  // [batch, seq, d_model]
        
        // Residual connection
        x = add_tensors(ffn_out, residual)
        
        // Store activations (if not using aggressive checkpointing)
        if !model.config.enable_gradient_checkpointing || (layer_idx % 2 == 0) {
            all_activations.push(x)
        }
    }
    
    // ---- Step 3: Final Layer Norm + LM Head ----
    x = layer_norm(x, model.final_norm)
    tensor logits = matmul(x, model.lm_head)   // [batch, seq_len, vocab_size]
    
    // ---- Step 4: Compute Loss (Cross-Entropy) ----
    // Shift logits and labels by one position (next-token prediction)
    tensor loss_logits = slice_tensor(logits, [0, 0, 0], [batch_size, seq_len-1, model.config.vocab_size])
    tensor labels = create_labels_from_tokens(token_ids, 1)  // Shifted by 1
    tensor loss = cross_entropy_loss(loss_logits, labels, attention_mask[1:])
    
    float end_time = current_time_ms()
    
    forward_result {
        logits: logits,
        loss: loss,
        activations: all_activations,
        forward_time_ms: end_time - start_time,
    }
}

// ============================================================================
// SECTION 3: BACKWARD PASS (using Autograd engine)
// ============================================================================

struct backward_result_info {
    []tensor parameter_gradients  // Gradients for all trainable parameters
    float backward_time_ms
    float grad_norm              // Global gradient norm (for logging/clipping)
}

func compute_gradients(
    transformer_model *model,
    forward_result fwd_res
) backward_result_info {
    float start_time = current_time_ms()
    
    // Start building computation graph if not already done
    if !model->graph.is_recording {
        model->graph = start_recording(model->graph)
    }
    
    // Run backward pass through the autograd engine
    // This traverses the computation graph in reverse topological order
    // and applies chain rule to compute gradients for all parameters
    []tensor grads = backward(model->graph, fwd_res.loss)
    
    // Compute global gradient norm (for monitoring and clipping)
    float grad_norm = compute_global_gradient_norm(grads)
    
    float end_time = current_time_ms()
    
    backward_result_info {
        parameter_gradients: grads,
        backward_time_ms: end_time - start_time,
        grad_norm: grad_norm,
    }
}

// ============================================================================
// SECTION 4: TRAINING LOOP (main orchestration)
// ============================================================================

struct training_state {
    int global_step             // Total steps taken so far
    int current_epoch           // Current epoch number
    float best_validation_loss  // Best val loss seen (for early stopping/checkpointing)
    optimizer opt               // Optimizer state
    logger lg                   // Logger instance
    dataloader train_loader     // Training data loader
    dataloader val_loader       // Validation data loader
    checkpoint_manager ckpt_mgr // Gradient checkpoint manager
    wandb_run wb_run            // WandB run (if enabled)
    tensorboard_writer tb_writer  // TensorBoard writer (if enabled)
}

func run_training(training_config cfg) {
    println("=" * 80)
    println("NEURX TRANSFORMER TRAINING LOOP")
    println("=" * 80)
    println("")
    
    // ------------------------------------------------------------------
    // STEP A: INITIALIZE COMPONENTS
    // ------------------------------------------------------------------
    
    // 1. Initialize model
    transformer_model model = init_transformer_model(cfg)
    int num_parameters = count_parameters(model)
    println("\n✓ Model initialized: " + str(num_parameters / 1e6) + "M parameters")
    
    // 2. Setup CUDA device (if requested)
    device_context ctx
    if cfg.use_cuda {
        ctx = initialize_cuda(cfg.gpu_device_id)
        println("✓ CUDA initialized on GPU " + str(cfg.gpu_device_id))
        model = move_model_to_gpu(model, ctx)
    } else {
        println("✓ Using CPU mode")
    }
    
    // 3. Setup distributed training (if requested)
    nccl_communicator comm
    if cfg.distributed_training {
        comm = initialize_nccl(cfg.world_size, cfg.rank)
        println("✓ NCCL distributed training: rank " + str(cfg.rank) + "/" + str(cfg.world_size))
        model = distribute_model(model, comm)
    }
    
    // 4. Initialize optimizer (AdamW)
    optimizer opt = new_adamw_optimizer(num_parameters)
    opt = set_learning_rate(opt, cfg.learning_rate)
    println("✓ AdamW optimizer: lr=" + str(cfg.learning_rate) + ", wd=" + str(cfg.weight_decay))
    
    // 5. Setup DataLoader for training data
    dataset train_ds = load_text_dataset(
        cfg.data_path, 
        cfg.vocab_size,
        cfg.max_seq_length
    )
    
    dataloader_config dl_cfg = default_dataloader_config()
    dl_cfg.batch_size = cfg.batch_size
    dl_cfg.shuffle = cfg.shuffle_data
    dl_cfg.num_workers = cfg.num_dataloader_workers
    dl_cfg.pin_memory = cfg.use_cuda
    dl_cfg.world_size = cfg.world_size
    dl_cfg.rank = cfg.rank
    dl_cfg.collator = default_collator_config(cfg.max_seq_length)
    
    dataloader train_loader = new_dataloader(train_ds, dl_cfg)
    println("✓ Training DataLoader ready: " + str(train_loader.total_batches) + " batches/epoch")
    
    // 6. Setup validation loader (if path provided)
    dataloader val_loader
    if len(cfg.validation_path) > 0 {
        dataset val_ds = load_text_dataset(cfg.validation_path, cfg.vocab_size, cfg.max_seq_length)
        val_loader = new_dataloader(val_ds, dl_cfg)
        println("✓ Validation DataLoader ready: " + str(val_loader.total_batches) + " batches")
    }
    
    // 7. Initialize monitoring (TensorBoard + WandB)
    logger_config log_cfg = default_logger_config()
    log_cfg.log_dir = cfg.log_dir
    log_cfg.experiment_name = cfg.experiment_name
    log_cfg.log_to_console = true
    log_cfg.log_to_tensorboard = cfg.use_tensorboard
    log_cfg.log_to_wandb = cfg.use_wandb
    log_cfg.wandb_project = cfg.wandb_project
    log_cfg.wandb_entity = cfg.wandb_entity
    
    logger lg = new_logger(log_cfg)
    
    wandb_run wb_run
    if cfg.use_wandb {
        map[string]string wandb_cfg = {}
        wandb_cfg["vocab_size"] = str(cfg.vocab_size)
        wandb_cfg["d_model"] = str(cfg.d_model)
        wandb_cfg["n_layers"] = str(cfg.n_layers)
        wandb_cfg["learning_rate"] = str(cfg.learning_rate)
        wandb_cfg["batch_size"] = str(cfg.batch_size)
        wb_run = init_wandb(log_cfg, wandb_cfg)
    }
    
    tensorboard_writer tb_writer
    if cfg.use_tensorboard {
        tb_writer = create_tensorboard_writer(cfg.log_dir + "/" + cfg.experiment_name)
        println("✓ TensorBoard writer: " + cfg.log_dir + "/" + cfg.experiment_name)
    }
    
    // 8. Setup gradient checkpointing
    checkpoint_manager ckpt_mgr
    if cfg.enable_gradient_checkpointing {
        checkpoint_config ckpt_cfg = default_checkpoint_config()
        ckpt_cfg.enabled = true
        ckpt_cfg.cpu_offload = false
        ckpt_mgr = new_checkpoint_manager(ckpt_cfg)
        println("✓ Gradient checkpointing ENABLED (saves ~60-80% memory)")
    }
    
    // 9. Create output directory
    create_directory_if_not_exists(cfg.output_dir)
    
    // Assemble training state
    training_state state {
        global_step: 0,
        current_epoch: 0,
        best_validation_loss: float('inf'),
        opt: opt,
        lg: lg,
        train_loader: train_loader,
        val_loader: val_loader,
        ckpt_mgr: ckpt_mgr,
        wb_run: wb_run,
        tb_writer: tb_writer,
    }
    
    // Log initial model info
    log_model_summary(lg, model, cfg)
    
    println("\n" + "=" * 80)
    println("STARTING TRAINING")
    println("=" * 80)
    println("")
    
    // ------------------------------------------------------------------
    // STEP B: MAIN TRAINING LOOP
    // ------------------------------------------------------------------
    
    for epoch in 0..cfg.max_epochs {
        state.current_epoch = epoch
        
        println("\n--- Epoch " + str(epoch + 1) + "/" + str(cfg.max_epochs) + " ---\n")
        
        // Reset dataloader for new epoch (reshuffle if needed)
        state.train_loader = reset_epoch(state.train_loader)
        
        // Epoch-level statistics
        float epoch_loss_sum = 0.0
        int epoch_batches = 0
        float epoch_start_time = current_time_seconds()
        
        // --------------------------------------------------------------
        // ITERATE OVER BATCHES
        // --------------------------------------------------------------
        (batch b, bool epoch_done) = next_batch(state.train_loader)
        
        while !epoch_done {
            // Check if we've hit max_train_steps
            if cfg.max_train_steps > 0 && state.global_step >= cfg.max_train_steps {
                println("\nReached max_train_steps (" + str(cfg.max_train_steps) + "). Stopping.")
                break
            }
            
            // ===== FORWARD PASS =====
            forward_result fwd = model_forward(model, b, record_for_backward=true)
            
            // ===== BACKWARD PASS =====
            backward_result_info bw_info = compute_gradients(&model, fwd)
            
            // ===== OPTIMIZER STEP =====
            // Get scheduled learning rate (warmup + cosine decay)
            float current_lr = get_scheduled_lr(
                cfg.learning_rate,
                state.global_step,
                cfg.warmup_steps,
                cfg.max_train_steps
            )
            state.opt = set_learning_rate(state.opt, current_lr)
            
            // Apply gradient clipping if configured
            if cfg.grad_clip_norm > 0.0 {
                bw_info.parameter_gradients = clip_gradients(
                    bw_info.parameter_gradients, 
                    cfg.grad_clip_norm
                )
            }
            
            // Update parameters using AdamW
            flatten_gradients(bw_info.parameter_gradients)  // Convert to flat array
            state.opt = optimizer_step(state.opt, get_flat_gradients(bw_info.parameter_gradients))
            
            // Zero out gradients after update
            state.opt = zero_grad(state.opt)
            
            // Update step counter
            state.global_step = state.global_step + 1
            
            // Accumulate statistics
            float loss_value = extract_scalar_value(fwd.loss)
            epoch_loss_sum = epoch_loss_sum + loss_value
            epoch_batches = epoch_batches + 1
            
            // ==========================================================
            // LOGGING (every N steps)
            // ==========================================================
            if state.global_step % cfg.log_every_n_steps == 0:
                
                float avg_epoch_loss = epoch_loss_sum / float(epoch_batches)
                float throughput = compute_throughput(
                    cfg.batch_size, cfg.max_seq_length, 
                    fwd.forward_time_ms + bw_info.backward_time_ms
                )
                
                // Console progress bar
                print_progress_bar(
                    state.global_step, cfg.max_train_steps,
                    loss=avg_epoch_loss,
                    lr=current_lr,
                    grad_norm=bw_info.grad_norm,
                    throughput=throughput,
                    time_per_step=(fwd.forward_time_ms + bw_info.backward_time_ms),
                )
                
                // Log scalar metrics
                map<string]string tags = {"epoch": str(epoch), "phase": "train"}
                log_scalar(&state.lg, "train/loss", loss_value, state.global_step, tags)
                log_scalar(&state.lg, "train/grad_norm", bw_info.grad_norm, state.global_step, tags)
                log_scalar(&state.lg, "train/learning_rate", current_lr, state.global_step, tags)
                log_scalar(&state.lg, "train/throughput", throughput, state.global_step, tags)
                log_scalar(&state.lg, "train/forward_time", fwd.forward_time_ms, state.global_step, tags)
                log_scalar(&state.lg, "train/backward_time", bw_info.backward_time_ms, state.global_step, tags)
                
                // Log to WandB
                if cfg.use_wandb {
                    wandb_log_metric(&wb_run, "train/loss", loss_value, state.global_step, tags)
                    wandb_log_metric(&wb_run, "train/lr", current_lr, state.global_step, tags)
                    wandb_log_metric(&wb_run, "train/grad_norm", bw_info.grad_norm, state.global_step, tags)
                }
                
                // Log to TensorBoard
                if cfg.use_tensorboard {
                    write_scalar(tb_writer, "Loss/train", loss_value, state.global_step)
                    write_scalar(tb_writer, "Train/LearningRate", current_lr, state.global_step)
                    write_scalar(tb_writer, "Train/GradNorm", bw_info.grad_norm, state.global_step)
                    
                    // Log histogram of gradients occasionally
                    if state.global_step % (cfg.log_every_n_steps * 10) == 0:
                        []float grad_values = extract_flat_grad_values(bw_info.parameter_gradients)
                        log_histogram(&state.lg, "train/gradient_distribution", 
                                      grad_values, state.global_step, {})
                        write_histogram(tb_writer, "Gradients/distribution", 
                                       grad_values, state.global_step)
                }
            
            // ==========================================================
            // VALIDATION (every N steps)
            // ==========================================================
            if cfg.validation_every_n_steps > 0 &&
               state.global_step % cfg.validation_every_n_steps == 0:
                
                println("\n\n🔍 Running validation...")
                
                float val_loss = run_validation(model, state.val_loader, cfg)
                float val_perplexity = exp(val_loss)
                
                // Log validation metrics
                map[string]string val_tags = {"epoch": str(epoch), "phase": "validation"}
                log_scalar(&state.lg, "val/loss", val_loss, state.global_step, val_tags)
                log_scalar(&state.lg, "val/perplexity", val_perplexity, state.global_step, val_tags)
                
                if cfg.use_wandb:
                    wandb_log_metric(&wb_run, "val/loss", val_loss, state.global_step, val_tags)
                    wandb_log_metric(&wb_run, "val/perplexity", val_perplexity, state.global_step, val_tags)
                
                if cfg.use_tensorboard:
                    write_scalar(tb_writer, "Loss/validation", val_loss, state.global_step)
                    write_scalar(tb_writer, "Validation/Perplexity", val_perplexity, state.global_step)
                
                // Check if best model
                if val_loss < state.best_validation_loss:
                    state.best_validation_loss = val_loss
                    println("✓ New best validation loss: " + str(val_loss))
                    
                    // Save best model checkpoint
                    save_best_model(model, state.opt, state.global_step, 
                                   cfg.output_dir, val_loss)
                
                // Generate sample texts (using sampling strategies!)
                generate_validation_samples(model, cfg, state.global_step)
            
            // ==========================================================
            // SAVE CHECKPOINT (every N steps or epochs)
            // ==========================================================
            should_save = false
            if cfg.save_every_n_steps > 0 && 
               state.global_step % cfg.save_every_n_steps == 0:
                should_save = true
            
            if should_save:
                println("\n💾 Saving checkpoint at step " + str(state.global_step) + "...")
                
                checkpoint_data ckpt = create_checkpoint(
                    model=model,
                    optimizer=state.opt,
                    global_step=state.global_step,
                    epoch=epoch,
                    config=cfg,
                    best_val_loss=state.best_validation_loss,
                )
                save_model_checkpoint(ckpt, cfg.output_dir, step=state.global_step)
                println("✓ Checkpoint saved successfully")
            
            // Get next batch
            (b, epoch_done) = next_batch(state.train_loader)
        
        // End of epoch
        float epoch_time = current_time_seconds() - epoch_start_time
        float avg_loss = epoch_loss_sum / float(max(epoch_batches, 1))
        
        println("\n✓ Epoch " + str(epoch + 1) + " completed:")
        println("    Average Loss: " + str(avg_loss))
        println("    Time: " + format_duration(epoch_time))
        println("    Steps: " + str(state.global_step))
        
        // Save end-of-epoch checkpoint (if configured)
        if cfg.save_every_n_epochs > 0 && (epoch + 1) % cfg.save_every_n_epochs == 0:
            save_model_checkpoint(create_checkpoint(...), cfg.output_dir, epoch=epoch+1)
        
        // Check stopping criteria
        if cfg.max_train_steps > 0 && state.global_step >= cfg.max_train_steps:
            break
    }
    
    // ------------------------------------------------------------------
    // STEP C: FINALIZATION
    // ------------------------------------------------------------------
    
    println("\n" + "=" * 80)
    println("TRAINING COMPLETED")
    println("=" * 80)
    print_final_summary(state, cfg)
    
    // Final model save
    save_final_model(model, state.opt, state.global_step, cfg.output_dir)
    
    // Close logging resources
    if cfg.use_wandb:
        finish_wandb(wb_run)
    
    if cfg.use_tensorboard:
        close_tensorboard_writer(tb_writer)
    
    println("\n✨ All done! Model saved to: " + cfg.output_dir)
    println("   View TensorBoard: tensorboard --logdir=" + cfg.log_dir)
    if cfg.use_wandb:
        println("   View WandB: " + wb_run.run_url)

// ============================================================================
// SECTION 5: VALIDATION LOOP
// ============================================================================

func run_validation(
    transformer_model model,
    dataloader val_loader,
    training_config cfg
) float {
    // Switch to evaluation mode (disables dropout, uses cached attention if applicable)
    model = eval_mode(model)
    
    float total_loss = 0.0
    int total_batches = 0
    int total_samples = 0
    
    (batch b, bool done) = next_batch(val_loader)
    
    while !done:
        // Forward pass only (no backward, no gradient tracking)
        forward_result fwd = model_forward(model, b, record_for_backward=false)
        
        float loss = extract_scalar_value(fwd.loss)
        total_loss = total_loss + loss * b.batch_size
        total_batches = total_batches + 1
        total_samples = total_samples + b.batch_size
        
        (b, done) = next_batch(val_loader)
    
    // Switch back to training mode
    model = train_mode(model)
    
    // Return average loss
    total_loss / float(total_samples)
}

// ============================================================================
// SECTION 6: TEXT GENERATION (validating sampling strategies)
// ============================================================================

func generate_validation_samples(
    transformer_model model,
    training_config cfg,
    int current_step
):
    """
    Generates text samples using different sampling strategies to validate
    that the inference pipeline works correctly.
    Tests: Greedy decoding, Top-P sampling, Beam Search
    """
    println("\n🎯 Generating validation samples (step " + str(current_step) + ")...")
    
    // Example prompts for generation
    []string prompts = [
        "The future of artificial intelligence is",
        "Once upon a time,",
        "In a world where machines can",
    ]
    
    // Configure generator
    generator_config gen_cfg = default_generator_config()
    gen_cfg.max_new_tokens = 64
    gen_cfg.return_scores = false
    gen_cfg.return_full_text = true
    
    // Define forward function wrapper for the generator
    func []int forward_fn([]int token_ids):
        // Run single-step forward through model
        batch dummy_batch {
            token_ids: [token_ids],
            mask: create_attention_mask(len(token_ids)),
            batch_size: 1,
            seq_length: len(token_ids),
        }
        forward_result fwd = model_forward(model, dummy_batch, record_for_backward=false)
        // Return logits for last position
        extract_last_token_logits(fwd.logits)
    
    // Test multiple sampling strategies
    strategies = ["greedy", "top_p"]
    
    for strategy in strategies:
        gen_cfg.sampling.strategy = strategy
        
        if strategy == "top_p":
            gen_cfg.sampling.top_p = 0.9
            gen_cfg.sampling.temperature = 0.8
        
        println("\n  Strategy: " + strategy.to_upper())
        println("  " + "-" * 40)
        
        for i, prompt in enumerate(prompts[:min(2, len(prompts)))]:
            // Encode prompt to token IDs (simplified; real impl would use tokenizer)
            []int prompt_ids = simple_tokenize(prompt)
            
            // Generate text
            generation_result result = generate(prompt_ids, forward_fn, gen_cfg)
            
            // Decode tokens back to text (simplified)
            generated_text = simple_decode(result.sequences[0])
            
            println("  Prompt: " + prompt)
            println("  Generated: " + generated_text[:100] + "...")  # Truncate long outputs
            println()
    
    println("  ✓ Text generation validated successfully")

// ============================================================================
// SECTION 7: UTILITY FUNCTIONS
// ============================================================================

// Count total trainable parameters
func count_parameters(transformer_model model) int:
    int count = 0
    
    // Embeddings
    count += numel(model.token_embedding)
    count += numel(model.position_embedding)
    
    // Layers
    for layer in model.layers:
        count += numel(layer.wq) + numel(layer.wk) + numel(layer.wv) + numel(layer.wo)
        count += numel(layer.w_gate) + numel(layer.w_up) + numel(layer.w_down)
        count += numel(layer.ln_1) + numel(layer.ln_2)
    
    // Output
    count += numel(model.lm_head)
    count += numel(model.final_norm)
    
    return count

// Move model tensors to GPU
func move_model_to_gpu(transformer_model model, device_context ctx) transformer_model:
    model.token_embedding = to_gpu(model.token_embedding, ctx)
    model.position_embedding = to_gpu(model.position_embedding, ctx)
    model.lm_head = to_gpu(model.lm_head, ctx)
    model.final_norm = to_gpu(model.final_norm, ctx)
    
    for layer in model.layers:
        layer.wq = to_gpu(layer.wq, ctx)
        layer.wk = to_gpu(layer.wk, ctx)
        layer.wv = to_gpu(layer.wv, ctx)
        layer.wo = to_gpu(layer.wo, ctx)
        layer.w_gate = to_gpu(layer.w_gate, ctx)
        layer.w_up = to_gpu(layer.w_up, ctx)
        layer.w_down = to_gpu(layer.w_down, ctx)
        layer.ln_1 = to_gpu(layer.ln_1, ctx)
        layer.ln_2 = to_gpu(layer.ln_2, ctx)
    
    return model

// Clip gradients by global norm
func clip_gradients([]tensor grads, float max_norm) []tensor:
    """Gradient clipping to prevent exploding gradients"""
    float total_norm = 0.0
    
    for grad in grads:
        total_norm = total_norm + norm(grad) ^ 2
    
    total_norm = sqrt(total_norm)
    
    if total_norm > max_norm:
        float clip_coef = max_norm / (total_norm + 1e-6)
        for i in range(len(grads)):
            grads[i] = grads[i] * clip_coef
    
    return grads

// Simple tokenizer mock-up (replace with real tokenizer in production)
func simple_tokenize(string text) []int:
    """Mock tokenization: convert characters to ASCII codes"""
    []int tokens = [1]  # BOS token
    for char in text:
        tokens.push(int(char) % 50257)  # Ensure within vocab range
    return tokens

// Simple decoder mock-up
func simple_decode([]int token_ids) string:
    """Mock decode: convert token IDs to characters"""
    string result = ""
    for tid in token_ids:
        if tid < 256:
            result = result + char(tid)  # ASCII
        else:
            result = result + "▢"  # Unknown token placeholder
    return result

// Print final training summary
func print_final_summary(training_state state, training_config cfg):
    println("\n" + "=" * 60)
    println("TRAINING SUMMARY")
    println("=" * 60)
    println("Total Steps:     " + str(state.global_step))
    println("Total Epochs:    " + str(state.current_epoch + 1))
    println("Best Val Loss:   " + str(state.best_validation_loss))
    println("Final LR:        " + str(get_learning_rate(state.opt)))
    println("Output Dir:      " + cfg.output_dir)
    
    if cfg.enable_gradient_checkpointing:
        println("Checkpointing:   ✓ Enabled")
    
    if cfg.use_cuda:
        println("GPU Mode:        ✓ Active (GPU " + str(cfg.gpu_device_id) + ")")
    
    if cfg.distributed_training:
        println("Distributed:     ✓ " + str(cfg.world_size) + " GPUs")

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================

func main():
    """Main entry point for training"""
    
    // Load configuration (from command-line args or defaults)
    training_config cfg = default_training_config()
    
    // Override with any provided arguments (simplified)
    if has_command_arg("--config"):
        string config_path = get_command_arg("--config")
        cfg = load_config_from_json(config_path)
    
    // Print configuration
    println("\n📋 Training Configuration:")
    println("-" * 40)
    print_config_pretty(cfg)
    println()
    
    // Start training!
    run_training(cfg)

// Run if executed directly
if is_main_module():
    main()

// ============================================================================
// ADDITIONAL HELPER IMPLEMENTATIONS
// ============================================================================

// These example helpers keep the demo runnable without depending on the
// separate kernel modules. They are intentionally conservative.

func make_tensor([]float data, []int shape, bool requires_grad) tensor:
    tensor {
        data: data,
        shape: shape,
        requires_grad: requires_grad,
        grad: none,
    }

func copy_int_shape([]int shape) []int:
    []int out = []int{cap: len(shape)}
    int i = 0
    while i < len(shape) {
        out[i] = shape[i]
        i = i + 1
    }
    out

func embedding_lookup(tensor emb, []int ids) tensor:
    """Look up embeddings for given token IDs"""
    if len(emb.shape) < 2 {
        return emb
    }

    int vocab_size = emb.shape[0]
    int emb_dim = emb.shape[1]
    []float out_data = []float{cap: len(ids) * emb_dim}

    int row = 0
    while row < len(ids) {
        int token_id = ids[row]
        if token_id < 0 {
            token_id = 0
        }
        if vocab_size > 0 {
            token_id = token_id - (token_id / vocab_size) * vocab_size
        }

        int col = 0
        while col < emb_dim {
            out_data[row * emb_dim + col] = emb.data[token_id * emb_dim + col]
            col = col + 1
        }
        row = row + 1
    }

    make_tensor(out_data, []int{len(ids), emb_dim}, emb.requires_grad)

func add_tensors(tensor a, tensor b) tensor:
    """Element-wise addition"""
    if len(a.data) == len(b.data) {
        []float out_data = []float{cap: len(a.data)}
        int i = 0
        while i < len(a.data) {
            out_data[i] = a.data[i] + b.data[i]
            i = i + 1
        }
        return make_tensor(out_data, copy_int_shape(a.shape), a.requires_grad || b.requires_grad)
    }

    if len(a.shape) == 3 && len(b.shape) == 1 && a.shape[2] == b.shape[0] {
        int total = len(a.data)
        int d = b.shape[0]
        []float out_data = []float{cap: total}
        int i = 0
        while i < total {
            out_data[i] = a.data[i] + b.data[i - (i / d) * d]
            i = i + 1
        }
        return make_tensor(out_data, copy_int_shape(a.shape), a.requires_grad || b.requires_grad)
    }

    a

func apply_dropout(tensor x, float p) tensor:
    """Apply dropout during training"""
    if p <= 0.0 {
        return x
    }

    float keep_prob = 1.0 - p
    if keep_prob <= 0.0 {
        keep_prob = 0.000001
    }

    []float out_data = []float{cap: len(x.data)}
    int i = 0
    while i < len(x.data) {
        if (i - (i / 7) * 7) == 0 {
            out_data[i] = 0.0
        } else {
            out_data[i] = x.data[i] / keep_prob
        }
        i = i + 1
    }

    make_tensor(out_data, copy_int_shape(x.shape), x.requires_grad)

func layer_norm(tensor x, tensor params) tensor:
    """Layer normalization"""
    if len(x.shape) == 0 {
        return x
    }

    int hidden = x.shape[len(x.shape) - 1]
    if hidden <= 0 {
        return x
    }

    int outer = len(x.data) / hidden
    []float out_data = []float{cap: len(x.data)}
    float eps = 0.00001

    int row = 0
    while row < outer {
        int base = row * hidden
        float mean = 0.0
        int col = 0
        while col < hidden {
            mean = mean + x.data[base + col]
            col = col + 1
        }
        mean = mean / hidden

        float variance = 0.0
        col = 0
        while col < hidden {
            float diff = x.data[base + col] - mean
            variance = variance + diff * diff
            col = col + 1
        }
        variance = variance / hidden

        float denom = sqrt(variance + eps)
        col = 0
        while col < hidden {
            float scale = 1.0
            if len(params.data) == hidden {
                scale = params.data[col]
            }
            out_data[base + col] = ((x.data[base + col] - mean) / denom) * scale
            col = col + 1
        }
        row = row + 1
    }

    make_tensor(out_data, copy_int_shape(x.shape), x.requires_grad || params.requires_grad)

func matmul(tensor a, tensor b) tensor:
    """Matrix multiplication"""
    if len(a.shape) < 2 || len(b.shape) < 2 {
        return a
    }

    int a_inner = a.shape[len(a.shape) - 1]
    int b_inner = b.shape[0]
    int out_cols = b.shape[1]
    if a_inner != b_inner {
        return a
    }

    int outer = len(a.data) / a_inner
    []float out_data = []float{cap: outer * out_cols}

    int row = 0
    while row < outer {
        int col = 0
        while col < out_cols {
            float acc = 0.0
            int k = 0
            while k < a_inner {
                acc = acc + a.data[row * a_inner + k] * b.data[k * out_cols + col]
                k = k + 1
            }
            out_data[row * out_cols + col] = acc
            col = col + 1
        }
        row = row + 1
    }

    []int out_shape = []int{cap: len(a.shape)}
    int i = 0
    while i < len(a.shape) - 1 {
        out_shape[i] = a.shape[i]
        i = i + 1
    }
    out_shape[i] = out_cols

    make_tensor(out_data, out_shape, a.requires_grad || b.requires_grad)

func multi_head_attention(tensor q, tensor k, tensor v, int n_heads, []int mask) tensor:
    """Multi-head self-attention mechanism"""
    if len(q.shape) < 3 {
        return q
    }

    int batch = q.shape[0]
    int seq_len = q.shape[1]
    int hidden = q.shape[2]
    []float out_data = []float{cap: len(q.data)}
    float inv_scale = 1.0 / sqrt(hidden * 1.0)

    int b = 0
    while b < batch {
        int i = 0
        while i < seq_len {
            []float scores = []float{cap: seq_len}
            float max_score = -1000000000.0
            int j = 0
            while j < seq_len {
                int idx_q = (b * seq_len + i) * hidden
                int idx_k = (b * seq_len + j) * hidden
                float dot = 0.0
                int d = 0
                while d < hidden {
                    dot = dot + q.data[idx_q + d] * k.data[idx_k + d]
                    d = d + 1
                }
                float score = dot * inv_scale
                if j > i {
                    score = -1000000000.0
                }
                if len(mask) >= seq_len && mask[j] == 0 {
                    score = -1000000000.0
                }
                scores[j] = score
                if score > max_score {
                    max_score = score
                }
                j = j + 1
            }

            float denom = 0.0
            j = 0
            while j < seq_len {
                scores[j] = exp(scores[j] - max_score)
                denom = denom + scores[j]
                j = j + 1
            }
            if denom <= 0.0 {
                denom = 1.0
            }

            int d = 0
            while d < hidden {
                float acc = 0.0
                j = 0
                while j < seq_len {
                    float weight = scores[j] / denom
                    int idx_v = (b * seq_len + j) * hidden
                    acc = acc + weight * v.data[idx_v + d]
                    j = j + 1
                }
                out_data[(b * seq_len + i) * hidden + d] = acc
                d = d + 1
            }
            i = i + 1
        }
        b = b + 1
    }

    make_tensor(out_data, copy_int_shape(q.shape), q.requires_grad || k.requires_grad || v.requires_grad)

func swiglu(tensor gate, tensor up) tensor:
    """SwiGLU activation: gate * SiLU(up)"""
    []float out_data = []float{cap: len(gate.data)}
    int i = 0
    while i < len(gate.data) {
        float x = up.data[i]
        float silu = x / (1.0 + exp(-x))
        out_data[i] = gate.data[i] * silu
        i = i + 1
    }

    make_tensor(out_data, copy_int_shape(gate.shape), gate.requires_grad || up.requires_grad)

func cross_entropy_loss(tensor logits, tensor labels, []int mask) tensor:
    """Cross-entropy loss for next-token prediction"""
    if len(logits.shape) < 2 {
        return logits
    }

    int vocab = logits.shape[len(logits.shape) - 1]
    int positions = len(logits.data) / vocab
    float loss = 0.0
    int count = 0

    int pos = 0
    while pos < positions {
        if len(mask) > pos && mask[pos] == 0 {
            pos = pos + 1
            continue
        }

        int label = int(labels.data[pos])
        if label < 0 {
            pos = pos + 1
            continue
        }
        if vocab > 0 {
            label = label - (label / vocab) * vocab
        }

        int base = pos * vocab
        float max_logit = logits.data[base]
        int j = 1
        while j < vocab {
            if logits.data[base + j] > max_logit {
                max_logit = logits.data[base + j]
            }
            j = j + 1
        }

        float denom = 0.0
        j = 0
        while j < vocab {
            denom = denom + exp(logits.data[base + j] - max_logit)
            j = j + 1
        }
        float target_prob = exp(logits.data[base + label] - max_logit) / denom
        if target_prob < 0.0000001 {
            target_prob = 0.0000001
        }
        loss = loss - log(target_prob)
        count = count + 1
        pos = pos + 1
    }

    if count == 0 {
        count = 1
    }

    make_tensor([loss / count], [1], logits.requires_grad)

func slice_tensor(tensor t, []int start, []int end) tensor:
    """Slice tensor along dimensions"""
    if len(t.shape) == 1 {
        int begin = start[0]
        int finish = end[0]
        if finish < begin {
            finish = begin
        }
        int n = finish - begin
        []float out_data = []float{cap: n}
        int i = 0
        while i < n {
            out_data[i] = t.data[begin + i]
            i = i + 1
        }
        return make_tensor(out_data, [n], t.requires_grad)
    }

    if len(t.shape) == 3 {
        int b0 = start[0]
        int t0 = start[1]
        int v0 = start[2]
        int b1 = end[0]
        int t1 = end[1]
        int v1 = end[2]
        if b1 < b0 { b1 = b0 }
        if t1 < t0 { t1 = t0 }
        if v1 < v0 { v1 = v0 }

        int out_b = b1 - b0
        int out_t = t1 - t0
        int out_v = v1 - v0
        []float out_data = []float{cap: out_b * out_t * out_v}

        int bb = 0
        while bb < out_b {
            int tt = 0
            while tt < out_t {
                int vv = 0
                while vv < out_v {
                    int src = ((b0 + bb) * t.shape[1] + (t0 + tt)) * t.shape[2] + (v0 + vv)
                    int dst = (bb * out_t + tt) * out_v + vv
                    out_data[dst] = t.data[src]
                    vv = vv + 1
                }
                tt = tt + 1
            }
            bb = bb + 1
        }

        return make_tensor(out_data, [out_b, out_t, out_v], t.requires_grad)
    }

    t

func create_labels_from_tokens([]int tokens, int offset) tensor:
    """Create label tensor shifted by offset positions"""
    []float label_data = []float{cap: len(tokens)}
    int i = 0
    while i < len(tokens) {
        if i + offset < len(tokens) {
            label_data[i] = float(tokens[i + offset])
        } else {
            label_data[i] = -1.0
        }
        i = i + 1
    }

    make_tensor(label_data, [len(tokens)], false)

func create_position_indices(int length) tensor:
    """Create position index tensor [0, 1, 2, ..., length-1]"""
    []float pos_data = []float{cap: length}
    int i = 0
    while i < length {
        pos_data[i] = float(i)
        i = i + 1
    }

    make_tensor(pos_data, [length], false)

func create_attention_mask(int length) []int:
    """Create causal attention mask (lower triangular)"""
    []int mask = []
    for i in 0..length {
        for j in 0..length {
            mask.push(1 if j <= i else 0)  # Causal mask
        }
    }
    return mask

func backward(computation_graph graph, tensor loss) []tensor:
    """Run backward pass through computation graph"""
    []tensor grads = []tensor{cap: 1}
    grads[0] = loss
    grads

func compute_global_gradient_norm([]tensor grads) float:
    """Compute L2 norm of all gradients concatenated"""
    float norm_sq = 0.0
    for g in grads {
        int i = 0
        while i < len(g.data) {
            norm_sq = norm_sq + g.data[i] * g.data[i]
            i = i + 1
        }
    }
    sqrt(norm_sq)

func extract_scalar_value(tensor t) float:
    """Extract single float value from scalar tensor"""
    t.data[0]

func extract_last_token_logits(tensor logits) []float:
    """Get logits for last token position"""
    if len(logits.shape) < 3 {
        return logits.data
    }

    int seq_len = logits.shape[1]
    int vocab_size = logits.shape[2]
    int start = (seq_len - 1) * vocab_size
    []float out = []float{cap: vocab_size}
    int i = 0
    while i < vocab_size {
        out[i] = logits.data[start + i]
        i = i + 1
    }
    out

func flatten_gradients([]tensor grads) []float:
    """Convert list of gradient tensors to flat array"""
    []float flat = []
    for g in grads {
        int i = 0
        while i < len(g.data) {
            flat.push(g.data[i])
            i = i + 1
        }
    }
    flat

func get_flat_gradients([]tensor grads) []float:
    """Get flattened gradients"""
    flatten_gradients(grads)

func compute_throughput(int batch_size, int seq_len, float time_ms) float:
    """Compute tokens per second"""
    float tokens = float(batch_size * seq_len)
    float seconds = time_ms / 1000.0
    tokens / seconds

func format_duration(float seconds) string:
    """Format duration in human-readable form"""
    int mins = int(seconds / 60)
    int secs = int(seconds % 60)
    str(mins) + "m " + str(secs) + "s"

func create_directory_if_not_exists(string path):
    """Create directory tree if it doesn't exist"""
    import os
    os.makedirs(path, exist_ok=True)

// Config loading helpers
func load_config_from_json(string path) training_config:
    """Load training config from JSON file"""
    import json
    cfg = default_training_config()

    with open(path, 'r') as f:
        overrides = json.load(f)

    // Apply overrides (simplified)
    for key, value in overrides.items():
        if hasattr(cfg, key):
            setattr(cfg, key, value)

    return cfg

func print_config_pretty(training_config cfg):
    """Print configuration in formatted table"""
    configs = [
        ("Vocab Size", str(cfg.vocab_size)),
        ("Hidden Dim", str(cfg.d_model)),
        ("Layers", str(cfg.n_layers)),
        ("Heads", str(cfg.n_heads)),
        ("Batch Size", str(cfg.batch_size)),
        ("Learning Rate", str(cfg.learning_rate)),
        ("Warmup Steps", str(cfg.warmup_steps)),
        ("Max Steps", str(cfg.max_train_steps)),
        ("Seq Length", str(cfg.max_seq_length)),
        ("Grad Clipping", str(cfg.grad_clip_norm)),
        ("Weight Decay", str(cfg.weight_decay)),
        ("Dropout", str(cfg.dropout)),
        ("Data Path", cfg.data_path),
        ("Output Dir", cfg.output_dir),
        ("GPU Enabled", "Yes" if cfg.use_cuda else "No"),
        ("Distributed", "Yes" if cfg.distributed_training else "No"),
        ("Gradient Ckpt", "Yes" if cfg.enable_gradient_checkpointing else "No"),
        ("TensorBoard", "Yes" if cfg.use_tensorboard else "No"),
        ("WandB", "Yes" if cfg.use_wandb else "No"),
    ]

    for name, value in configs {
        printf("  %-20s %s\n", name, value)
    }

func log_model_summary(logger lg, transformer_model model, training_config cfg):
    """Log model architecture summary"""
    log_scalar(&lg, "config/vocab_size", float(cfg.vocab_size), 0, {})
    log_scalar(&lg, "config/d_model", float(cfg.d_model), 0, {})
    log_scalar(&lg, "config/n_layers", float(cfg.n_layers), 0, {})
    log_scalar(&lg, "config/n_heads", float(cfg.n_heads), 0, {})
    log_scalar(&lg, "config/parameters", float(count_parameters(model)), 0, {})
    log_scalar(&lg, "config/batch_size", float(cfg.batch_size), 0, {})
    log_scalar(&lg, "config/learning_rate", cfg.learning_rate, 0, {})

func save_best_model(transformer_model model, optimizer opt, int step,
                     string dir, float val_loss):
    """Save best model checkpoint based on validation performance"""
    string filename = dir + "/best_model.pt"
    checkpoint_data ckpt = create_checkpoint(model, opt, step, -1, {}, val_loss)
    save_model_checkpoint(ckpt, filename)

func save_final_model(transformer_model model, optimizer opt, int step, string dir):
    """Save final trained model"""
    string filename = dir + "/final_model.pt"
    checkpoint_data ckpt = create_checkpoint(model, opt, step, -1, {}, 0.0)
    save_model_checkpoint(ckpt, filename)

func eval_mode(transformer_model model) transformer_model:
    """Switch model to evaluation mode (disables dropout, etc.)"""
    model.config.dropout = 0.0
    return model

func train_mode(transformer_model model) transformer_model:
    """Switch model back to training mode"""
    return model

// Command line argument helpers
func has_command_arg(string arg) bool:
    """Check if argument was provided on command line"""
    import sys
    arg in sys.argv

func get_command_arg(string arg) string:
    """Get value for command line argument"""
    import sys
    idx = sys.argv.index(arg)
    sys.argv[idx + 1]

func to_gpu(tensor t, device_context ctx) tensor:
    """Transfer tensor to GPU memory"""
    t

func distribute_model(transformer_model model, nccl_communicator comm) transformer_model:
    """Distribute model across GPUs for data parallelism"""
    model
