package neurx.posttrain.dpo.examples

use neurx.posttrain.dpo.dpo_trainer.*
use neurx.model.llm.neurx.*
use neurx.tokenizer.neurx.*

// ════════════════════════════════════════════════════════════════════════════════
// DPO 训练完整示例
// 
// 这个文件展示如何使用 NEURX DPO 训练器进行对齐微调
// ════════════════════════════════════════════════════════════════════════════════

// 创建 DPO 训练配置
func create_dpo_example_config() dpo_train_config {
    dpo_train_config {
        method: "dpo",
        
        // 基础参数
        batch_size: 16,
        gradient_accum_steps: 4,
        learning_rate: 5e-7,
        lr_warmup_ratio: 0.05,
        lr_schedule_type: "cosine",
        total_training_steps: 100000,  // 约 3-4 天在 64 GPU 上
        
        // 优化器
        adam_beta1: 0.9,
        adam_beta2: 0.95,
        adam_epsilon: 1e-8,
        weight_decay: 0.01,
        max_grad_norm: 1.0,
        
        // DPO 参数
        dpo_beta: 0.1,              // KL 权重
        label_smoothing: 0.0,
        dpo_loss_type: "sigmoid",
        use_reference_free: false,
        
        // 精度
        precision: "bf16",
        use_gradient_checkpointing: true,
        use_flash_attention: true,
        
        // 检查点
        save_interval: 5000,
        eval_interval: 2000,
        log_interval: 100,
        checkpoint_dir: "./checkpoints/dpo/",
        
        // 数据加载
        num_workers: 4,
        pin_memory: true,
        
        output_dir: "./outputs/dpo/",
    }
}

// 创建示例数据集
func create_dpo_example_dataset() dpo_dataset {
    dpo_dataset {
        pairs: []dpo_preference_pair{},
        size: 50000,           // 50K 偏好对
        source_path: "./data/dpo/preferences.jsonl",
        quality_score: 0.95,   // 95% 质量分数
        train_test_split: 45000,
        avg_prompt_len: 256.0,
        avg_response_len: 512.0,
        domain_distribution: []float{0.4, 0.3, 0.2, 0.1},  // 4 个域
    }
}

// 示例 1: 基础 DPO 训练
func example_basic_dpo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║          Example 1: Basic DPO Training                    ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    // Load model and tokenizer
    neurx_model model = load_pretrained_model("neurx_200b")
    neurx_model reference_model = load_pretrained_model("neurx_200b")  // Load initial weights
    tokenizer_state tokenizer = load_tokenizer()
    
    // Create config and dataset
    dpo_train_config config = create_dpo_example_config()
    dpo_dataset dataset = create_dpo_example_dataset()
    
    // Validate dataset
    if !validate_dpo_dataset(dataset) {
        print("ERROR: Invalid dataset")
        return
    }
    
    // Create trainer
    dpo_trainer_state trainer = create_dpo_trainer(
        model,
        reference_model,
        tokenizer,
        config,
        dataset,
        0,    // global_rank
        1     // world_size
    )
    
    // Start training
    dpo_train_result result = start_dpo_training(ref trainer)
    
    print("")
    print("✓ Training completed!")
    print("  Final Loss: " + string_float(result.final_loss))
    print("  Best Metric: " + string_float(result.best_metric))
    print("  Checkpoint: " + result.checkpoint_path)
}

// 示例 2: 多 GPU 分布式 DPO 训练
func example_distributed_dpo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║      Example 2: Distributed DPO on 64 GPUs                ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    // Get distributed environment
    // int global_rank = get_rank()
    // int world_size = get_world_size()
    
    // For demo, simulate 64 GPU setup
    int global_rank = 0     // Would be rank from environment
    int world_size = 64
    
    // Load model (sharded across GPUs)
    neurx_model model = load_pretrained_model("neurx_200b")
    neurx_model reference_model = load_pretrained_model("neurx_200b")
    tokenizer_state tokenizer = load_tokenizer()
    
    // Create config (adjusted for 64 GPU)
    dpo_train_config config = create_dpo_example_config()
    config.batch_size = 16 * 8  // 8 GPUs per node * 16 batch
    config.total_training_steps = 50000  // Fewer steps for demo
    
    dpo_dataset dataset = create_dpo_example_dataset()
    
    // Create trainer
    dpo_trainer_state trainer = create_dpo_trainer(
        model,
        reference_model,
        tokenizer,
        config,
        dataset,
        global_rank,
        world_size
    )
    
    print("Starting distributed DPO training on " + string(world_size) + " GPUs")
    print("Rank " + string(global_rank) + " starting...")
    
    // Start training
    dpo_train_result result = start_dpo_training(ref trainer)
    
    if global_rank == 0 {
        print("")
        print("✓ Distributed training completed!")
        print("  Final Loss: " + string_float(result.final_loss))
        print("  Checkpoint: " + result.checkpoint_path)
    }
}

// 示例 3: DPO with 不同的 Beta 值
func example_dpo_with_different_betas() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║     Example 3: DPO with Different Beta Values             ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    // Test different beta values
    []float betas = []float{0.05, 0.1, 0.2, 0.5}
    
    neurx_model model = load_pretrained_model("neurx_200b")
    neurx_model reference_model = load_pretrained_model("neurx_200b")
    tokenizer_state tokenizer = load_tokenizer()
    
    dpo_dataset dataset = create_dpo_example_dataset()
    
    int i = 0
    while i < len(betas) {
        float beta = betas[i]
        
        print("")
        print("[Beta = " + string_float(beta) + "]")
        
        dpo_train_config config = create_dpo_example_config()
        config.dpo_beta = beta
        config.total_training_steps = 10000  // Short training for comparison
        
        dpo_trainer_state trainer = create_dpo_trainer(
            model,
            reference_model,
            tokenizer,
            config,
            dataset,
            0,  // global_rank
            1   // world_size
        )
        
        dpo_train_result result = start_dpo_training(ref trainer)
        
        print("  Final Loss: " + string_float(result.final_loss))
        print("  Best Metric: " + string_float(result.best_metric))
        
        i = i + 1
    }
    
    print("")
    print("✓ Comparison complete! Check outputs/dpo/ for details")
}

// 示例 4: 从检查点恢复训练
func example_dpo_resume_from_checkpoint() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║      Example 4: DPO Resume from Checkpoint                ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    string checkpoint_path = "./checkpoints/dpo/step_50000"
    
    // Load from checkpoint
    (dpo_trainer_state trainer, int resume_step) = load_dpo_checkpoint(checkpoint_path)
    
    print("Resuming training from step " + string(resume_step))
    print("Resuming with config:")
    print("  Learning Rate: " + string_float(trainer.current_learning_rate))
    print("  Best Metric: " + string_float(trainer.best_eval_metric))
    
    // Continue training
    dpo_train_result result = start_dpo_training(ref trainer)
    
    print("")
    print("✓ Resume completed!")
}

// 示例 5: DPO vs RLHF 对比
func example_dpo_vs_rlhf_comparison() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║           Example 5: DPO vs RLHF Comparison              ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    print("┌─────────────────────────────────────────────────────────┐")
    print("│ Aspect              │ DPO        │ RLHF                  │")
    print("├─────────────────────────────────────────────────────────┤")
    print("│ Reward Model        │ No         │ Yes (required)        │")
    print("│ Training Stability  │ High       │ Medium                │")
    print("│ Speed               │ Fast       │ Slow                  │")
    print("│ KL Divergence       │ Implicit   │ Explicit              │")
    print("│ GPU Memory          │ Lower      │ Higher                │")
    print("│ Hyperparameters     │ Few        │ Many                  │")
    print("│ Convergence         │ 3-5 days   │ 7-10 days             │")
    print("└─────────────────────────────────────────────────────────┘")
    print("")
    
    print("Key Advantages of DPO:")
    print("  ✓ No need to train separate reward model")
    print("  ✓ Simpler training pipeline")
    print("  ✓ Lower computational cost")
    print("  ✓ More stable convergence")
    print("  ✓ Better performance in practice")
    print("")
}

// Main: 运行所有示例
func main() {
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("     NEURX DPO (Direct Preference Optimization) Examples     ")
    print("═════════════════════════════════════════════════════════════")
    print("")
    
    // example_basic_dpo_training()
    // example_distributed_dpo_training()
    // example_dpo_with_different_betas()
    // example_dpo_resume_from_checkpoint()
    example_dpo_vs_rlhf_comparison()
    
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("     All examples completed!                                 ")
    print("═════════════════════════════════════════════════════════════")
}

// 辅助函数
func load_pretrained_model(string model_name) neurx_model {
    // TODO: Load model from checkpoint
    neurx_model{}
}

func load_tokenizer() tokenizer_state {
    // TODO: Load tokenizer
    tokenizer_state{}
}

func string_float(float f) string {
    int int_part = int(f)
    int frac_part = int((f - float_of_int(int_part)) * 10000.0)
    string(int_part) + "." + string(frac_part)
}
