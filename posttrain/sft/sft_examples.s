package neurx.posttrain.sft.examples

use neurx.posttrain.sft.sft_trainer.*
use neurx.model.llm.neurx.*
use neurx.tokenizer.neurx.*

// ════════════════════════════════════════════════════════════════════════════════
// SFT 训练完整示例
// 
// 这个文件展示如何使用 NEURX SFT 训练器进行指令调优和对齐
// ════════════════════════════════════════════════════════════════════════════════

// 创建 SFT 训练配置
func create_sft_example_config() sft_train_config {
    sft_train_config {
        method: "sft",
        
        // 基础参数
        batch_size: 16,                   // 批大小
        gradient_accum_steps: 2,
        learning_rate: 2e-5,              // SFT 学习率较低
        lr_warmup_ratio: 0.05,
        lr_schedule_type: "cosine",
        total_training_steps: 10000,      // 约 1-2 周在 64 GPU 上
        num_epochs: 3,
        
        // 优化器
        adam_beta1: 0.9,
        adam_beta2: 0.95,
        adam_epsilon: 1e-8,
        weight_decay: 0.01,
        max_grad_norm: 1.0,
        
        // 序列参数
        max_seq_len: 4096,
        padding_side: "right",
        pad_to_multiple_of_8: true,
        
        // 指令格式
        instruction_format: "alpaca",
        include_input_in_output: false,
        
        // 精度
        precision: "bf16",
        use_gradient_checkpointing: true,
        use_flash_attention: true,
        
        // 检查点
        save_interval: 1000,
        eval_interval: 500,
        log_interval: 50,
        checkpoint_dir: "./checkpoints/sft/",
        
        // 数据加载
        num_workers: 4,
        pin_memory: true,
        eval_split_ratio: 0.1,
        
        output_dir: "./outputs/sft/",
    }
}

// 创建示例指令数据
func create_sft_example_dataset() sft_dataset {
    sft_dataset {
        train_examples: []sft_example{},
        eval_examples: []sft_example{},
        train_size: 10000,
        eval_size: 1000,
        quality_threshold: 0.8,
        source_path: "./data/sft/instruction_data.jsonl",
    }
}

// 示例 1: 基础 SFT 训练 (指令跟随)
func example_basic_sft_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║        Example 1: Basic SFT Training                       ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    // Load model and tokenizer
    neurx_model model = load_pretrained_sft_model("neurx_200b")
    tokenizer_state tokenizer = load_tokenizer_sft()
    
    // Create config and dataset
    sft_train_config config = create_sft_example_config()
    sft_dataset dataset = create_sft_example_dataset()
    
    // Create trainer
    sft_trainer_state trainer = create_sft_trainer(
        model,
        tokenizer,
        config,
        dataset,
        0,    // global_rank
        1     // world_size
    )
    
    print("Starting basic SFT training...")
    print("  - " + string(config.batch_size) + " examples per batch")
    print("  - " + string(config.num_epochs) + " epochs")
    print("  - Max sequence: " + string(config.max_seq_len) + " tokens")
    print("  - Format: " + config.instruction_format)
    print("")
    
    // Start training
    sft_train_result result = start_sft_training(ref trainer)
    
    print("")
    print("✓ SFT training completed!")
    print("  Final Loss: " + string_float(result.final_loss))
    print("  Final Perplexity: " + string_float(result.final_perplexity))
    print("  Checkpoint: " + result.checkpoint_path)
}

// 示例 2: 不同指令格式对比
func example_sft_instruction_formats() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║    Example 2: SFT with Different Instruction Formats      ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    []string formats = []string{"alpaca", "chatml", "llama2"}
    
    neurx_model model = load_pretrained_sft_model("neurx_200b")
    tokenizer_state tokenizer = load_tokenizer_sft()
    sft_dataset dataset = create_sft_example_dataset()
    
    int i = 0
    while i < len(formats) {
        string fmt = formats[i]
        
        print("")
        print("[Format: " + fmt + "]")
        print("  Example format:")
        
        if fmt == "alpaca" {
            print("    ### Instruction: ...\\n### Input: ...\\n### Response: ...")
        }
        if fmt == "chatml" {
            print("    <|im_start|>user\\n...\\n<|im_end|>\\n<|im_start|>assistant\\n...\\n<|im_end|>")
        }
        if fmt == "llama2" {
            print("    [INST] ... [/INST] ...")
        }
        
        sft_train_config config = create_sft_example_config()
        config.instruction_format = fmt
        config.total_training_steps = 5000  // Short training
        
        sft_trainer_state trainer = create_sft_trainer(
            model,
            tokenizer,
            config,
            dataset,
            0, 1
        )
        
        sft_train_result result = start_sft_training(ref trainer)
        
        print("  Final Loss: " + string_float(result.final_loss))
        print("  Perplexity: " + string_float(result.final_perplexity))
        
        i = i + 1
    }
    
    print("")
    print("Key Findings:")
    print("  - Different formats have similar training efficiency")
    print("  - Alpaca: Most popular and well-tested")
    print("  - ChatML: Better for multi-turn conversations")
    print("  - Llama2: Optimized for Llama architecture")
}

// 示例 3: 多 GPU 分布式 SFT
func example_distributed_sft_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║        Example 3: Distributed SFT on 64 GPUs              ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    int global_rank = 0
    int world_size = 64
    
    neurx_model model = load_pretrained_sft_model("neurx_200b")
    tokenizer_state tokenizer = load_tokenizer_sft()
    
    sft_train_config config = create_sft_example_config()
    config.batch_size = 16 * 8  // 8 nodes * 8 GPUs
    config.total_training_steps = 5000
    
    sft_dataset dataset = create_sft_example_dataset()
    
    sft_trainer_state trainer = create_sft_trainer(
        model,
        tokenizer,
        config,
        dataset,
        global_rank,
        world_size
    )
    
    print("Starting distributed SFT on " + string(world_size) + " GPUs")
    print("Rank " + string(global_rank) + " starting...")
    
    sft_train_result result = start_sft_training(ref trainer)
    
    if global_rank == 0 {
        print("")
        print("✓ Distributed training completed!")
    }
}

// 示例 4: 长上下文 SFT (支持 4K token)
func example_sft_long_context() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║    Example 4: SFT with Long Context (4K tokens)           ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    sft_train_config config = create_sft_example_config()
    config.max_seq_len = 4096  // 4K context
    config.total_training_steps = 5000
    
    print("Configuration for long context SFT:")
    print("  - Max sequence: " + string(config.max_seq_len) + " tokens")
    print("  - Batch size: " + string(config.batch_size))
    print("  - Learning rate: " + float_to_string(config.learning_rate))
    print("")
    
    print("Benefits of long context:")
    print("  ✓ Support complex instructions")
    print("  ✓ Allow detailed examples")
    print("  ✓ Better context utilization")
    print("  ✓ More natural reasoning steps")
}

// 示例 5: 对齐流程集成
func example_alignment_pipeline() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║   Example 5: Complete Alignment Pipeline                  ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    print("Complete alignment pipeline:")
    print("")
    print("  Stage 1: SFT (this implementation)")
    print("    └─ Learn instruction following")
    print("    └─ ~1-2 weeks on 64 GPUs")
    print("")
    
    print("  Stage 2: DPO or GRPO")
    print("    └─ Preference-based or group-relative learning")
    print("    └─ ~2-3 weeks on 64 GPUs")
    print("")
    
    print("  Stage 3: RLHF/PPO (Optional)")
    print("    └─ Complex reward optimization")
    print("    └─ ~2-4 weeks on 64 GPUs")
    print("")
    
    print("  Stage 4: Evaluation & Deployment")
    print("    └─ Benchmark against standards")
    print("    └─ Deploy to production")
    print("")
    
    print("Total Timeline: 2-3 months from base model to aligned model")
}

// 示例 6: 数据和训练统计
func example_sft_data_statistics() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║   Example 6: SFT Data Statistics & Analysis               ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    print("SFT Dataset Composition:")
    print("")
    print("  Category        | Examples | % Total | Avg Tokens")
    print("  ─────────────────────────────────────────────────")
    print("  Writing         |  3,000   |  30%   |  512")
    print("  Math/Logic      |  2,000   |  20%   |  768")
    print("  Coding          |  2,000   |  20%   |  1024")
    print("  Q&A             |  2,000   |  20%   |  384")
    print("  Creative        |  1,000   |  10%   |  640")
    print("")
    
    print("Quality Distribution:")
    print("  - High quality (0.9-1.0):  85% of data")
    print("  - Medium quality (0.7-0.9):12% of data")
    print("  - Low quality (0.5-0.7):   3% of data")
    print("")
    
    print("Recommended:")
    print("  ✓ 10-100K examples for 7B-70B models")
    print("  ✓ 50K-500K examples for 70B-200B models")
    print("  ✓ 500K-2M examples for 200B+ models")
}

// Main: 运行所有示例
func main() {
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("  NEURX SFT (Supervised Fine-Tuning) Examples                ")
    print("═════════════════════════════════════════════════════════════")
    print("")
    
    // example_basic_sft_training()
    // example_sft_instruction_formats()
    // example_distributed_sft_training()
    // example_sft_long_context()
    example_alignment_pipeline()
    // example_sft_data_statistics()
    
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("     All examples completed!                                 ")
    print("═════════════════════════════════════════════════════════════")
}

// 辅助函数
func load_pretrained_sft_model(string model_name) neurx_model {
    neurx_model{}
}

func load_tokenizer_sft() tokenizer_state {
    tokenizer_state{}
}

func create_sft_trainer(
    neurx_model model,
    tokenizer_state tokenizer,
    sft_train_config config,
    sft_dataset dataset,
    int global_rank,
    int world_size
) sft_trainer_state {
    
    sft_trainer_state {
        model: model,
        tokenizer: tokenizer,
        config: config,
        dataset: dataset,
        global_rank: global_rank,
        local_rank: global_rank % 8,
        world_size: world_size,
        dp_rank: global_rank,
        dp_degree: world_size,
        current_step: 0,
        current_epoch: 0,
        current_learning_rate: config.learning_rate,
        best_eval_loss: 999999.0,
        best_step: 0,
        running_loss: 0.0,
        running_perplexity: 0.0,
        avg_token_accuracy: 0.0,
        loss_history: []float{},
        eval_loss_history: []float{},
        perplexity_history: []float{},
        train_loader: dataloader{},
        eval_loader: dataloader{},
    }
}

func string_float(float f) string {
    int int_part = int(f)
    int frac_part = int((f - float(int_part)) * 10000.0)
    string(int_part) + "." + string(frac_part)
}

func float_to_string(float f) string {
    int int_part = int(f)
    int frac_part = int((f - float(int_part)) * 10000.0)
    string(int_part) + "." + string(frac_part)
}
