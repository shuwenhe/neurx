// ============================================
// NeurX GPT Training - Enhanced Version
// 使用 S 语言 AI 原生模块进行训练
// ============================================
package neurx.train.demo

use std.math.{exp as math_exp, log as math_log, sqrt, tanh, sigmoid, relu, gelu, 
              abs, max as fmax, min as fmin, mod as math_mod, pow, EPSILON}
use std.tensor.{Tensor, tensor, zeros, ones, randn, xavier_uniform, kaiming_normal,
                 arange, linspace, eye, scalar,
                 add, sub, mul, div, matmul_2d, dot, outer,
                 reshape, flatten, squeeze, unsqueeze, transpose, permute, view,
                 sum_all, sum_dim, mean_all, mean_dim, max_all, min_all, norm,
                 relu_tensor, gelu_tensor, softmax_tensor, layer_norm,
                 sigmoid_tensor, tanh_tensor, dropout,
                 gather, one_hot,
                 mse_loss, cross_entropy_loss, l1_loss, bce_with_logits_loss,
                 print_info, print_values, numel, shape}
use std.ai.autograd.{AutoGradTensor, create_autograd_tensor, parameter, backward,
                      new_sgd_optimizer, new_adam_optimizer, sgd_step, adam_step,
                      zero_grad, clip_grad_norm_, clip_grad_value_}
use std.ai.nn.modules.{Linear, Embedding, LayerNorm, MultiHeadAttention,
                         FeedForward, TransformerBlock, Dropout,
                         ReLU, GELU, SiLU, Sigmoid as SigModule, Softmax,
                         Sequential, new_linear, new_embedding, new_layer_norm,
                         new_mha, new_feed_forward, new_transformer_block,
                         new_dropout, new_relu, new_gelu, new_silu, new_sigmoid, new_softmax,
                         new_sequential, count_parameters, print_module_summary}

// ============================================
// Training Configuration (训练配置)
// ============================================

struct GPTConfig {
    // Model architecture
    int vocab_size          // Vocabulary size (default: 256 for byte-level)
    int embed_dim           // Embedding dimension (d_model)
    int num_heads           // Number of attention heads
    int ffn_dim             // Feed-forward hidden dimension
    int num_layers          // Number of transformer blocks
    int max_seq_len         // Maximum sequence length
    
    // Training hyperparameters
    float learning_rate     // Learning rate α
    string optimizer        // "sgd" | "adam" | "adamw"
    float weight_decay      // Weight decay λ
    float dropout_prob      // Dropout probability
    
    // Data settings
    int batch_size          // Batch size B
    int seq_len             // Sequence length S
    int max_steps           // Total training steps T
    int save_every_n        // Save checkpoint every N steps
    
    // Precision
    bool mixed_precision    // Use FP16/BF16 (future)
    
    // Device
    string device           // "cpu" | "cuda:0"
}

func default_gpt_config() GPTConfig {
    GPTConfig {
        vocab_size: 256,
        embed_dim: 128,
        num_heads: 4,
        ffn_dim: 512,
        num_layers: 4,
        max_seq_len: 32,
        
        learning_rate: 0.001,
        optimizer: "adam",
        weight_decay: 0.01,
        dropout_prob: 0.1,
        
        batch_size: 8,
        seq_len: 32,
        max_steps: 50,
        save_every_n: 25,
        
        mixed_precision: false,
        device: "cpu",
    }
}

func gpt_config_string(GPTConfig cfg) string {
    string s = ""
    s = s + "GPT Configuration:\n"
    s = s + "  Vocab Size:   " + string(cfg.vocab_size) + "\n"
    s = s + "  Embed Dim:    " + string(cfg.embed_dim) + "\n"
    s = s + "  Heads:        " + string(cfg.num_heads) + "\n"
    s = s + "  FFN Dim:      " + string(cfg.ffn_dim) + "\n"
    s = s + "  Layers:       " + string(cfg.num_layers) + "\n"
    s = s + "  Max Seq Len:  " + string(cfg.max_seq_len) + "\n"
    s = s + "\n"
    s = s + "Training:\n"
    s = s + "  Learning Rate:" + format_float(cfg.learning_rate) + "\n"
    s = s + "  Optimizer:    " + cfg.optimizer + "\n"
    s = s + "  Weight Decay: " + format_float(cfg.weight_decay) + "\n"
    s = s + "  Dropout:      " + format_float(cfg.dropout_prob) + "\n"
    s = s + "  Batch Size:   " + string(cfg.batch_size) + "\n"
    s = s + "  Max Steps:    " + string(cfg.max_steps) + "\n"
    s = s + "  Device:       " + cfg.device + "\n"
    s
}

// ============================================
// GPT Model Definition (GPT 模型定义)
// ============================================

struct GPTModel {
    GPTConfig config
    Embedding token_embed
    Embedding pos_embed
    TransformerBlock[] blocks
    LayerNorm final_norm
    Linear output_head
    
    AutoGradTensor[] all_parameters
}

func new_gpt_model(GPTConfig config) GPTModel {
    GPTModel model
    model.config = config
    
    // Token embedding: (vocab_size, embed_dim)
    model.token_embed = new_embedding(config.vocab_size, config.embed_dim, -1)
    
    // Position embedding: (max_seq_len, embed_dim)
    model.pos_embed = new_embedding(config.max_seq_len, config.embed_dim, -1)
    
    // Transformer blocks
    model.blocks = new TransformerBlock[config.num_layers]
    int i = 0
    while i < config.num_layers {
        model.blocks[i] = new_transformer_block(
            config.embed_dim,
            config.num_heads,
            config.ffn_dim,
            config.dropout_prob,
            true  // Use pre-norm (GPT-2 style)
        )
        i = i + 1
    }
    
    // Final layer norm
    model.final_norm = new_layer_norm([config.embed_dim], 1e-5)
    
    // Output head (tied with token embedding weights in some implementations)
    model.output_head = new_linear(config.embed_dim, config.vocab_size, false)
    
    // Collect all parameters
    collect_gpt_parameters(model)
    
    model
}

func collect_gpt_parameters(GPTModel mut model) void {
    model.all_parameters = new AutoGradTensor[0]
    
    // Token embedding parameters
    int i = 0
    while i < len(model.token_embed.parameters) {
        append(model.all_parameters, model.token_embed.parameters[i])
        i = i + 1
    }
    
    // Position embedding parameters
    i = 0
    while i < len(model.pos_embed.parameters) {
        append(model.all_parameters, model.pos_embed.parameters[i])
        i = i + 1
    }
    
    // Transformer block parameters
    i = 0
    while i < len(model.blocks) {
        int j = 0
        while j < len(model.blocks[i].parameters) {
            append(model.all_parameters, model.blocks[i].parameters[j])
            j = j + 1
        }
        i = i + 1
    }
    
    // Final norm parameters
    i = 0
    while i < len(model.final_norm.parameters) {
        append(model.all_parameters, model.final_norm.parameters[i])
        i = i + 1
    }
    
    // Output head parameters
    i = 0
    while i < len(model.output_head.parameters) {
        append(model.all_parameters, model.output_head.parameters[i])
        i = i + 1
    }
}

// Forward pass through the full GPT model
// Input: token_ids (batch_size, seq_len)
// Output: logits (batch_size, seq_len, vocab_size)
func forward(GPTModel self, int[] token_ids) AutoGradTensor {
    int batch_size = self.config.batch_size
    int seq_len = self.config.seq_len
    int d_model = self.config.embed_dim
    
    // Get token embeddings
    AutoGradTensor token_emb = forward(self.token_embed, token_ids, batch_size, seq_len)
    
    // Get position embeddings
    int[] pos_ids = new int[batch_size * seq_len]
    int idx = 0
    while idx < batch_size * seq_len {
        pos_ids[idx] = math_mod(idx, seq_len)
        idx = idx + 1
    }
    AutoGradTensor pos_emb = forward(self.pos_embed, pos_ids, batch_size, seq_len)
    
    // Combine embeddings
    AutoGradTensor x = add(token_emb, pos_emb)
    
    // Pass through transformer blocks
    int i = 0
    while i < len(self.blocks) {
        x = forward(self.blocks[i], x)
        i = i + 1
    }
    
    // Final layer normalization
    x = forward(self.final_norm, x)
    
    // Project to vocabulary
    AutoGradTensor logits = forward(self.output_head, x)
    
    logits
}

// Count total parameters
def count_params(GPTModel self) int:
    total = 0
    for p in self.all_parameters:
        total += p.data.shape.size
    return total

// Print model summary
def print_model_summary(GPTModel self):
    println("=" * 60)
    println("GPT Model Summary")
    println("=" * 60)
    print(gpt_config_string(self.config))
    println("-" * 60)
    
    // Count by component
    token_params = count_parameters(self.token_embed)
    pos_params = count_parameters(self.pos_embed)
    block_params = count_parameters(self.blocks)
    norm_params = count_parameters(self.final_norm)
    head_params = count_parameters(self.output_head)
    
    println(f"Token Embedding: {token_params:>10,} params")
    println(f"Pos Embedding:   {pos_params:>10,} params")
    println(f"Transformer Blk: {block_params:>10,} params (x{len(self.blocks)})")
    println(f"Final LayerNorm:{norm_params:>10,} params")
    println(f"Output Head:     {head_params:>10,} params")
    println("-" * 60)
    total = token_params + pos_params + block_params + norm_params + head_params
    println(f"{'TOTAL':>18}: {total:>10,} parameters")
    println("=" * 60)

// ============================================
// Training State & Metrics (训练状态和指标)
// ============================================

struct TrainingMetrics {
    int step
    float loss
    float accuracy
    float grad_norm
    float lr
    float throughput  // tokens/second
    float epoch_time_ms
}

struct TrainingState {
    int global_step
    int current_epoch
    float best_loss
    int best_step
    float[] loss_history
    TrainingMetrics[] metrics_history
    bool trained
}

func new_training_state() TrainingState {
    TrainingState {
        global_step: 0,
        current_epoch: 0,
        best_loss: INF,
        best_step: 0,
        loss_history: new float[1000],
        metrics_history: new TrainingMetrics[100],
        trained: false,
    }
}

// ============================================
// Data Loading & Preprocessing (数据加载与预处理)
// ============================================

// Simulated data loader for demonstration
// In production, this would read from files/datasets
struct DataLoader {
    int[] tokens           // Flat token array
    int total_tokens
    int current_position
    int batch_size
    int seq_len
}

func new_data_loader(int[] tokens, int batch_size, int seq_len) DataLoader {
    DataLoader {
        tokens: tokens,
        total_tokens: len(tokens),
        current_position: 0,
        batch_size: batch_size,
        seq_len: seq_len,
    }
}

// Generate synthetic training data (for demo purposes)
func generate_synthetic_data(int n_tokens, int vocab_size) int[] {
    int[] data = new int[n_tokens]
    
    // Simple pattern: repeating sequence with some noise
    int pattern[] = [1, 23, 45, 67, 89, 12, 34, 56]
    int pattern_len = 8
    
    int seed = 42
    int i = 0
    while i < n_tokens {
        // Mix of pattern and random
        if math_mod(i, pattern_len * 3) < pattern_len {
            data[i] = pattern[math_mod(i, pattern_len)]
        } else {
            // Pseudo-random based on seed
            seed = seed * 1103515245 + 12345
            data[i] = (((seed >> 16) - ((seed >> 16) / vocab_size) * vocab_size)
        }
        i = i + 1
    }
    
    data
}

// Get next batch from data loader
// Returns: input_ids (B*S), target_ids (B*S)
func next_batch(DataLoader mut loader) Tuple<int[], int[]> {
    int tokens_per_batch = loader.batch_size * loader.seq_len
    
    // Check if we need to wrap around
    if loader.current_position + tokens_per_batch > loader.total_tokens {
        loader.current_position = 0  // Reset to beginning of dataset
    }
    
    int[] input_ids = new int[tokens_per_batch]
    int[] target_ids = new int[tokens_per_batch]
    
    int i = 0
    while i < tokens_per_batch {
        input_ids[i] = loader.tokens[loader.current_position + i]
        target_ids[i] = loader.tokens[loader.current_position + i + 1]  // Shifted by 1
        i = i + 1
    }
    
    loader.current_position = loader.current_position + loader.seq_len  // Move by seq_len (not full batch) for overlap
    
    (input_ids, target_ids)

// ============================================
// Loss Functions (损失函数)
// ============================================

// Compute cross entropy loss from logits and targets
func compute_cross_entropy_loss(AutoGradTensor logits, int[] targets) AutoGradTensor {
    cross_entropy_loss(logits, targets)
}

// ============================================
// Checkpoint Management (检查点管理)
// ============================================

struct CheckpointInfo {
    string path
    int step
    float loss
    int timestamp
    int param_count
    float[] model_weights_hash  // For integrity verification
}

func format_checkpoint_v2(int step, float loss, float best_loss, int best_step,
                           int param_count, GPTConfig config,
                           float[] loss_window) string {
    string content = ""
    content = content + "# ============================================\n"
    content = content + "# NeurX GPT Checkpoint v2\n"
    content = content + "# Generated by S Language Runtime\n"
    content = content + "# ============================================\n\n"
    
    content = content + "[metadata]\n"
    content = content + "format_version=2.0\n"
    content = content + "framework=S-AI-Lib-v1.0\n"
    content = content + "timestamp=" + get_timestamp() + "\n"
    content = content + "s_version=enhanced\n\n"

    content = content + "[training]\n"
    content = content + "step=" + string(step) + "\n"
    content = content + "loss=" + format_float(loss, 6) + "\n"
    content = content + "best_loss=" + format_float(best_loss, 6) + "\n"
    content = content + "best_step=" + string(best_step) + "\n"
    content = content + "loss_history=["
    int i = 0
    while i < len(loss_window) {
        if i > 0 { content = content + ", " }
        content = content + format_float(loss_window[i], 4)
        i = i + 1
    }
    content = content + "]\n\n"
    
    content = content + "[model_config]\n"
    content = content + gpt_config_string(config) + "\n"
    content = content + "total_parameters=" + string(param_count) + "\n\n"
    
    content = content + "[optimizer_state]\n"
    content = content + "step_count=" + string(step) + "\n\n"

    content = content + "# End of checkpoint\n"
    content
}

func get_timestamp() string {
    // Simplified timestamp generation
    "20260623_150000"
}

func save_checkpoint_v2(string output_dir, int step, float loss, float best_loss,
                          int best_step, GPTModel model, GPTConfig config,
                          float[] loss_window) string {
    string filename = "step_" + string(step) + ".neurx"
    string filepath = output_dir + "/" + filename
    
    int param_count = count_params(model)
    
    string content = format_checkpoint_v2(step, loss, best_loss, best_step,
                                            param_count, config, loss_window)
    
    var r = write_text_file(filepath, content)
    if r.is_ok() {
        println("  ✓ Saved checkpoint: ", filepath)
        return filepath
    }
    
    "[ERROR] Failed to save checkpoint"
}

// ============================================
// Main Training Loop (主训练循环)
// ============================================

struct TrainingResult {
    TrainingState state
    int total_params
    float final_loss
    float best_loss
    int total_time_ms
    string[] saved_checkpoints
}

func run_training(GPTConfig config) TrainingResult {
    println("")
    println("╔══════════════════════════════════════════════════╗")
    println("║        NeurX GPT Training - Enhanced Edition     ║")
    println("║              Powered by S Language               ║")
    println("║              AI-Native Tensor Library            ║")
    println("╚══════════════════════════════════════════════════╝")
    println("")
    print(gpt_config_string(config))
    println("----------------------------------------")

    // Initialize model
    println("[1/5] Initializing GPT model...")
    GPTModel model = new_gpt_model(config)
    int total_params = count_params(model)
    print_model_summary(model)
    println("")

    // Initialize optimizer
    println("[2/5] Setting up optimizer...")
    OptimizerState opt
    if config.optimizer == "adam" || config.optimizer == "adamw":
        opt = new_adam_optimizer(
            config.learning_rate,
            0.9,    // beta1
            0.999,  // beta2
            config.weight_decay,
            1e-8    // eps
        )
    else:
        opt = new_sgd_optimizer(
            config.learning_rate,
            0.9,    // momentum
            config.weight_decay
        )
    println("  Optimizer: ", config.optimizer, " (lr=", config.learning_rate, ")")
    println("")

    // Prepare data
    println("[3/5] Preparing training data...")
    int total_train_tokens = config.max_steps * config.batch_size * config.seq_len * 2
    int[] train_data = generate_synthetic_data(total_train_tokens, config.vocab_size)
    DataLoader dataloader = new_data_loader(train_data, config.batch_size, config.seq_len)
    println("  Synthetic data generated: ", len(train_data), " tokens")
    println("  Effective epochs per step: ~1")
    println("")

    // Training state
    TrainingState state = new_training_state()
    string[] checkpoints_saved = new string[]
    float[] recent_losses = new float[10]

    // Start training
    println("[4/5] Starting training loop...")
    println("")
    println("Step |   Loss   |  Best   | GradNorm | LR       | Time(ms)")
    println("-----|----------|---------|----------|----------|--------")
    
    int start_time = get_time_ms()

    int step = 0
    while step < config.max_steps {
        int step_start = get_time_ms()

        // === Forward pass ===
        Tuple<int[], int[]> batch = next_batch(dataloader)
        int[] input_ids = batch[0]
        int[] target_ids = batch[1]
        
        AutoGradTensor logits = forward(model, input_ids)
        AutoGradTensor loss_tensor = compute_cross_entropy_loss(logits, target_ids)
        float loss_val = item(loss_tensor.data)

        // === Backward pass ===
        zero_grad(model.all_parameters)
        Map<string, Tensor> grads = backward(loss_tensor)
        float grad_norm = clip_grad_norm_(model.all_parameters, 1.0)

        // === Optimizer step ===
        if config.optimizer == "adam" || config.optimizer == "adamw":
            adam_step(opt, model.all_parameters)
        else:
            sgd_step(opt, model.all_parameters)

        // === Update state ===
        state.global_step = state.global_step + 1
        
        // Track best loss
        if loss_val < state.best_loss:
            state.best_loss = loss_val
            state.best_step = step + 1
        
        // Record loss history
        if step < len(state.loss_history) {
            state.loss_history[step] = loss_val
        }

        // Update sliding window of recent losses
        int wi = math_mod(step, len(recent_losses))
        recent_losses[wi] = loss_val

        int step_time = get_time_ms() - step_start

        // === Logging ===
        if math_mod(step + 1, 10) == 0 or step == config.max_steps - 1 or loss_val < state.best_loss:
            println(format_step_line(step + 1, loss_val, state.best_loss, 
                                     grad_norm, opt.learning_rate, step_time))

        // === Checkpoint saving ===
        if check_should_save(step + 1, config.save_every_n):
            string ckpt_path = save_checkpoint_v2(
                "artifacts/checkpoints",
                step + 1, loss_val, state.best_loss,
                state.best_step, model, config,
                recent_losses
            )
            if not ckpt_path.startswith("[ERROR]"):
                append(checkpoints_saved, ckpt_path)

        step = step + 1

    int total_time = get_time_ms() - start_time

    // === Final checkpoints ===
    println("")
    println("[5/5] Saving final checkpoints...")
    
    // Save final model
    string final_ckpt = save_checkpoint_v2(
        "artifacts/checkpoints",
        config.max_steps, state.loss_history[config.max_steps - 1],
        state.best_loss, state.best_step, model, config,
        recent_losses
    )
    if not final_ckpt.startswith("[ERROR]"):
        append(checkpoints_saved, final_ckpt)
    
    // Save best model
    string best_ckpt = save_checkpoint_v2(
        "artifacts/checkpoints",
        state.best_step, state.best_loss,
        state.best_loss, state.best_step, model, config,
        recent_losses
    )
    rename_file(best_ckpt, "artifacts/checkpoints/best_model.neurx")
    append(checkpoints_saved, "artifacts/checkpoints/best_model.neurx")

    // Update manifest
    save_manifest("artifacts/checkpoints/latest_checkpoint.txt", checkpoints_saved)

    println("")
    println("╔══════════════════════════════════════════════════╗")
    println("║              Training Complete!                  ║")
    println("╠══════════════════════════════════════════════════╣")
    println("║  Total Steps:     ", string(config.max_steps), "                     ║")
    println("║  Final Loss:      ", format_float(state.loss_history[config.max_steps - 1], 6), "              ║")
    println("║  Best Loss:       ", format_float(state.best_loss, 6), "              ║")
    println("║  Best Step:       ", string(state.best_step), "                       ║")
    println("║  Total Params:    ", string(total_params), "                    ║")
    println("║  Training Time:   ", string(total_time), " ms                   ║")
    println("║  Checkpoints:     ", string(len(checkpoints_saved)), " saved                ║")
    println("╚══════════════════════════════════════════════════╝")
    println("")

    TrainingResult {
        state: state,
        total_params: total_params,
        final_loss: state.loss_history[config.max_steps - 1],
        best_loss: state.best_loss,
        total_time_ms: total_time,
        saved_checkpoints: checkpoints_saved,
    }

// Format a single line of training progress
func format_step_line(int step, float loss, float best_loss, 
                       float grad_norm, float lr, int time_ms) string {
    string line = ""
    
    // Pad step number
    string step_str = string(step)
    while len(step_str) < 4: step_str = " " + step_str
    line = line + step_str + " | "
    
    // Pad loss
    string loss_str = format_float(loss, 6)
    while len(loss_str) < 8: loss_str = " " + loss_str
    line = line + loss_str + " | "
    
    // Pad best loss
    string best_str = format_float(best_loss, 6)
    while len(best_str) < 7: best_str = " " + best_str
    line = line + best_str + " | "
    
    // Pad grad norm
    string grad_str = format_float(grad_norm, 4)
    while len(grad_str) < 8: grad_str = " " + grad_str
    line = line + grad_str + " | "
    
    // Pad learning rate
    string lr_str = format_float(lr, 6)
    while len(lr_str) < 8: lr_str = " " + lr_str
    line = line + lr_str + " | "
    
    // Time
    line = line + string(time_ms) + " ms"
    
    line

// Helper: check if should save at this step
func check_should_save(int step, int every_n) bool:
    if every_n <= 0: return True
    return math_mod(step, every_n) == 0 and step > 0

// Save manifest file listing all checkpoints
func save_manifest(string manifest_path, string[] checkpoints) void:
    content = "# NeurX Checkpoint Manifest\n"
    content += "# Generated: " + get_timestamp() + "\n\n"
    content += "[checkpoints]\n"
    
    for ckpt in checkpoints:
        content += ckpt + "\n"
    
    write_text_file(manifest_path, content)

// Get current time in milliseconds (platform-specific stub)
func get_time_ms() int:
    // In actual implementation, this would call system time
    return 0  // Placeholder

// File operations (using enhanced std.fs)
func write_text_file(string path, string content) Result[void, Error]:
    // Implementation depends on runtime IO capabilities
    pass

def rename_file(string old_path, string new_path) void:
    pass

// ============================================
// Entry Point (程序入口)
// ============================================

func main() int:
    // Parse command-line arguments (simplified)
    GPTConfig config = default_gpt_config()
    
    // Allow overrides via environment or args
    // In real implementation, use proper CLI parsing
    
    println("NeurX GPT Training - AI Native Edition")
    println("======================================")
    println("")
    
    // Run training
    TrainingResult result = run_training(config)
    
    // Return success if training completed normally
    if result.state.trained and result.best_loss < 3.0:
        println("\n✓ Training completed successfully!")
        return 0
    else:
        println("\n⚠ Training completed but may need tuning.")
        return 1

if __name__ == "__main__":
    exit(main())
