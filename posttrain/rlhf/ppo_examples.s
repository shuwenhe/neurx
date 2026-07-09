package neurx.posttrain.rlhf.examples

use neurx.posttrain.rlhf.ppo_trainer.*

// ════════════════════════════════════════════════════════════════════════════════
// PPO Trainer 示例
// 
// 展示如何使用 PPO 进行 RLHF 对齐训练
// ════════════════════════════════════════════════════════════════════════════════

// 创建基础 PPO 配置
func create_ppo_config() ppo_config {
    ppo_config {
        // 模型参数
        vocab_size: 128000,
        hidden_size: 4096,
        seq_len: 2048,
        num_layers: 40,
        
        // 训练参数
        learning_rate: 5e-6,
        learning_rate_policy: 5e-6,
        learning_rate_value: 5e-6,
        
        // PPO 参数
        clip_epsilon: 0.2,          // 标准 PPO 裁剪范围
        entropy_coef: 0.01,         // 熵鼓励探索
        value_coef: 0.5,            // 价值损失权重
        gamma: 0.99,                // 折扣因子
        gae_lambda: 0.95,           // GAE 参数
        
        // KL 控制
        target_kl: 0.015,           // 目标 KL 散度
        kl_coef: 0.01,              // KL 惩罚
        
        // 训练流程
        horizon: 2048,              // 采样轨迹长度
        mini_batch_size: 256,
        num_epochs: 4,              // PPO 更新轮数
        num_mini_batches: 8,
        
        // 分布式训练
        global_rank: 0,
        world_size: 1,
        dp_degree: 1,
        use_mixed_precision: true,
        
        // 检查点
        checkpoint_interval: 100,
        eval_interval: 50,
    }
}

// 示例 1: 基础 PPO 训练
func example_basic_ppo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 1: Basic PPO Training Loop                       ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    ppo_config config = create_ppo_config()
    config.horizon = 512              // 演示用的较小 horizon
    config.num_epochs = 2
    config.checkpoint_interval = 10
    config.eval_interval = 5
    
    print("[Configuration]")
    print("  Learning Rate:      5e-6")
    print("  Clip Epsilon:       0.2")
    print("  Entropy Coef:       0.01")
    print("  Value Coef:         0.5")
    print("  Horizon:            512")
    print("  Num Epochs:         2")
    print("")
    
    // 启动训练 (演示模式, 少量步骤)
    ppo_state state = start_ppo_training(config, 10)
    
    print("Training completed!")
    print("  Total Steps:        " + int_to_string_ex(state.total_steps))
    print("  Total Trajectories: " + int_to_string_ex(state.total_trajectories))
    print("  Final Policy Loss:  " + float_to_string_ex(state.avg_policy_loss))
    print("  Final Value Loss:   " + float_to_string_ex(state.avg_value_loss))
    print("")
}

// 示例 2: 分布式 PPO 训练
func example_distributed_ppo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 2: Distributed PPO Training (Multi-GPU)          ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    ppo_config config = create_ppo_config()
    
    // 模拟 8 GPU 分布式设置
    config.world_size = 8
    config.dp_degree = 8
    config.global_rank = 0
    config.horizon = 2048
    config.num_epochs = 4
    
    print("[Distributed Configuration]")
    print("  World Size:         8 GPUs")
    print("  Data Parallel:      8")
    print("  Global Rank:        0")
    print("  Batch Size:         256 × 8 = 2048 total")
    print("  Horizon per GPU:    2048 steps")
    print("")
    
    print("[Key Distributed Features]")
    print("  ✓ Data Parallel across 8 GPUs")
    print("  ✓ Synchronized gradient updates")
    print("  ✓ Distributed checkpoint saving")
    print("  ✓ Per-rank metrics aggregation")
    print("")
    
    // 初始化状态
    ppo_state state = init_ppo_state(config)
    
    print("[Training Setup]")
    print("  Rank 0 of " + int_to_string_ex(config.world_size))
    print("  Ready for distributed training")
    print("")
}

// 示例 3: PPO 与不同的超参数对比
func example_hyperparameter_comparison() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 3: Hyperparameter Comparison                     ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    // 配置 A: 保守的设置
    ppo_config config_a = create_ppo_config()
    config_a.clip_epsilon = 0.1        // 更严格的裁剪
    config_a.value_coef = 0.3
    config_a.entropy_coef = 0.001
    
    // 配置 B: 标准设置
    ppo_config config_b = create_ppo_config()
    
    // 配置 C: 激进设置
    ppo_config config_c = create_ppo_config()
    config_c.clip_epsilon = 0.3        // 更宽松的裁剪
    config_c.value_coef = 0.7
    config_c.entropy_coef = 0.05
    
    print("[Configuration A: Conservative]")
    print("  Clip Epsilon:   0.1")
    print("  Value Coef:     0.3")
    print("  Entropy Coef:   0.001")
    print("")
    
    print("[Configuration B: Standard]")
    print("  Clip Epsilon:   0.2")
    print("  Value Coef:     0.5")
    print("  Entropy Coef:   0.01")
    print("")
    
    print("[Configuration C: Aggressive]")
    print("  Clip Epsilon:   0.3")
    print("  Value Coef:     0.7")
    print("  Entropy Coef:   0.05")
    print("")
    
    print("Effect Summary:")
    print("  Smaller clip_epsilon   → More conservative policy updates")
    print("  Larger value_coef      → Stronger value network training")
    print("  Higher entropy_coef    → More exploration, less exploitation")
    print("")
}

// 示例 4: 与奖励模型集成
func example_ppo_with_reward_model() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 4: PPO with Reward Model Integration             ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    ppo_config config = create_ppo_config()
    config.horizon = 1024
    
    print("[Integration Architecture]")
    print("")
    print("1. Policy Model (SFT checkpoint)")
    print("   - Generates responses for prompts")
    print("   - Updated via PPO loss")
    print("")
    
    print("2. Reward Model")
    print("   - Pre-trained on human preferences")
    print("   - Scores response quality")
    print("   - Provides reward signal")
    print("")
    
    print("3. Value Network")
    print("   - Estimates expected future rewards")
    print("   - Used for advantage computation")
    print("   - Trained with value loss")
    print("")
    
    print("[Training Flow]")
    print("  Prompt → Policy → Response → Reward Model → Reward")
    print("           ↑                                      ↓")
    print("           ← PPO Update ← Value Network ← Advantage")
    print("")
    
    print("[Practical Scenario]")
    print("  Prompt: 'Explain quantum computing'")
    print("  Policy generates: [full response]")
    print("  Reward Model scores: 0.85 (high quality, factual)")
    print("  Value Network estimates: 0.75")
    print("  Advantage: 0.85 - 0.75 = 0.10 (positive, update encouraged)")
    print("")
}

// 示例 5: KL 约束和早停
func example_kl_constraint_and_early_stopping() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 5: KL Constraint & Early Stopping                ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    ppo_config config = create_ppo_config()
    config.target_kl = 0.015
    config.kl_coef = 0.01
    
    print("[KL Divergence Control]")
    print("")
    print("Purpose: Prevent policy from diverging too much from reference")
    print("")
    
    print("Configuration:")
    print("  Target KL:          0.015")
    print("  KL Coef:            0.01 (penalty weight)")
    print("")
    
    print("How it works:")
    print("  1. Compute KL(new || old) for each update step")
    print("  2. Track cumulative KL divergence")
    print("  3. If KL > target_kl, early stop the PPO epochs")
    print("  4. Continue to next trajectory")
    print("")
    
    print("Example trajectory:")
    print("  Epoch 1: KL = 0.008 ✓ (continue)")
    print("  Epoch 2: KL = 0.012 ✓ (continue)")
    print("  Epoch 3: KL = 0.016 ✗ (STOP - exceeds target)")
    print("  → Move to next trajectory")
    print("")
    
    print("Benefits:")
    print("  ✓ Prevents catastrophic policy collapse")
    print("  ✓ Maintains reference model knowledge")
    print("  ✓ Improves training stability")
    print("")
}

// 示例 6: PPO 训练管道 (SFT → PPO)
func example_complete_alignment_pipeline() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 6: Complete Alignment Pipeline                   ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    
    print("[Stage 1: Supervised Fine-Tuning (SFT)]")
    print("  Input:     Instruction-response pairs (human examples)")
    print("  Model:     Base LLM")
    print("  Loss:      Cross-entropy (token prediction)")
    print("  Output:    SFT Model")
    print("  Duration:  ~1 week on 64 A100s")
    print("")
    
    print("[Stage 2: Reward Model Training]")
    print("  Input:     Human preference pairs (chosen vs rejected)")
    print("  Model:     SFT Model (as backbone)")
    print("  Loss:      Bradley-Terry (preference loss)")
    print("  Output:    Reward Model")
    print("  Duration:  ~2 days on 16 A100s")
    print("")
    
    print("[Stage 3: PPO Optimization]")
    print("  Policy:    SFT Model (being optimized)")
    print("  Reference: SFT Model (frozen, for KL penalty)")
    print("  Rewards:   Reward Model scores")
    print("  Value Fn:  Separate network (critic)")
    print("  Objective: Maximize reward while staying close to SFT")
    print("  Duration:  ~2 weeks on 64 A100s")
    print("")
    
    ppo_config config = create_ppo_config()
    
    print("[Key Configuration for Full Pipeline]")
    print("  Total PPO Steps:    100,000")
    print("  Trajectories/Step:  1 (8 GPU batch)")
    print("  Horizon:            2048 (max new tokens)")
    print("  PPO Epochs:         4 (update rounds per trajectory)")
    print("  Total Training:     ~2 weeks")
    print("")
}

// Main 函数
func main() {
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("  NEURX PPO Trainer Examples                                 ")
    print("═════════════════════════════════════════════════════════════")
    print("")
    
    example_basic_ppo_training()
    example_distributed_ppo_training()
    example_hyperparameter_comparison()
    example_ppo_with_reward_model()
    example_kl_constraint_and_early_stopping()
    example_complete_alignment_pipeline()
    
    print("═════════════════════════════════════════════════════════════")
    print("     All examples completed!                                 ")
    print("═════════════════════════════════════════════════════════════")
}

// 辅助函数
func float_to_string_ex(float f) string {
    int i_part = int(f)
    int f_part = int((f - float(i_part)) * 10000.0)
    string(i_part) + "." + string(f_part)
}

func int_to_string_ex(int i) string {
    string(i)
}
