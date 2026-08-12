package neurx.posttrain.rlhf.examples
use neurx.posttrain.rlhf.ppo_trainer.*
func create_ppo_config() ppo_config {
    ppo_config {
        vocab_size: 128000,
        hidden_size: 4096,
        seq_len: 2048,
        num_layers: 40,
        learning_rate: 5e-6,
        learning_rate_policy: 5e-6,
        learning_rate_value: 5e-6,
        clip_epsilon: 0.2,
        entropy_coef: 0.01,
        value_coef: 0.5,
        gamma: 0.99,
        gae_lambda: 0.95,
        target_kl: 0.015,
        kl_coef: 0.01,
        horizon: 2048,
        mini_batch_size: 256,
        num_epochs: 4,
        num_mini_batches: 8,
        global_rank: 0,
        world_size: 1,
        dp_degree: 1,
        use_mixed_precision: true,
        checkpoint_interval: 100,
        eval_interval: 50,
    }
}

func example_basic_ppo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 1: Basic PPO Training Loop                       ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    ppo_config config = create_ppo_config()
    config.horizon = 512
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
    ppo_state state = start_ppo_training(config, 10)
    print("Training completed!")
    print("  Total Steps:        " + int_to_string_ex(state.total_steps))
    print("  Total Trajectories: " + int_to_string_ex(state.total_trajectories))
    print("  Final Policy Loss:  " + float_to_string_ex(state.avg_policy_loss))
    print("  Final Value Loss:   " + float_to_string_ex(state.avg_value_loss))
    print("")
}

func example_distributed_ppo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 2: Distributed PPO Training (Multi-GPU)          ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    ppo_config config = create_ppo_config()
    config.world_size = 8
    config.dp_degree = 8
    config.global_rank = 0
    config.horizon = 2048
    config.num_epochs = 4
    print("[Distributed Configuration]")
    print("  World Size:         8 GPUs")
    print("  Data Parallel:      8")
    print("  Global Rank:        0")
    print("  batch_2 Size:         256 × 8 = 2048 total")
    print("  Horizon per GPU:    2048 steps")
    print("")
    print("[Key Distributed Features]")
    print("  ✓ Data Parallel across 8 GPUs")
    print("  ✓ Synchronized gradient updates")
    print("  ✓ Distributed checkpoint saving")
    print("  ✓ Per-rank metrics aggregation")
    print("")
    ppo_state state = init_ppo_state(config)
    print("[Training Setup]")
    print("  Rank 0 of " + int_to_string_ex(config.world_size))
    print("  Ready for distributed training")
    print("")
}

func example_hyperparameter_comparison() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 3: Hyperparameter Comparison                     ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    ppo_config config_a = create_ppo_config()
    config_a.clip_epsilon = 0.1
    config_a.value_coef = 0.3
    config_a.entropy_coef = 0.001
    ppo_config config_b = create_ppo_config()
    ppo_config config_c = create_ppo_config()
    config_c.clip_epsilon = 0.3
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

func example_ppo_with_reward_model() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 4: PPO with Reward model Integration             ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    ppo_config config = create_ppo_config()
    config.horizon = 1024
    print("[Integration Architecture]")
    print("")
    print("1. Policy model (SFT checkpoint)")
    print("   - Generates responses for prompts")
    print("   - Updated via PPO loss")
    print("")
    print("2. Reward model")
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
    print("  Prompt → Policy → Response → Reward model → Reward")
    print("           ↑                                      ↓")
    print("           ← PPO Update ← Value Network ← Advantage")
    print("")
    print("[Practical Scenario]")
    print("  Prompt: 'Explain quantum computing'")
    print("  Policy generates: [full response]")
    print("  Reward model scores: 0.85 (high quality, factual)")
    print("  Value Network estimates: 0.75")
    print("  Advantage: 0.85 - 0.75 = 0.10 (positive, update encouraged)")
    print("")
}

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

func example_complete_alignment_pipeline() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 6: Complete Alignment Pipeline                   ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[Stage 1: Supervised Fine-Tuning (SFT)]")
    print("  Input:     Instruction-response pairs (human examples)")
    print("  model:     Base LLM")
    print("  Loss:      Cross-entropy (token prediction)")
    print("  Output:    SFT model")
    print("  Duration:  ~1 week on 64 A100s")
    print("")
    print("[Stage 2: Reward model Training]")
    print("  Input:     Human preference pairs (chosen vs rejected)")
    print("  model:     SFT model (as backbone)")
    print("  Loss:      Bradley-Terry (preference loss)")
    print("  Output:    Reward model")
    print("  Duration:  ~2 days on 16 A100s")
    print("")
    print("[Stage 3: PPO Optimization]")
    print("  Policy:    SFT model (being optimized)")
    print("  Reference: SFT model (frozen, for KL penalty)")
    print("  Rewards:   Reward model scores")
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

func float_to_string_ex(float f) string {
    int i_part = int(f)
    int f_part = int((f - float(i_part)) * 10000.0)
    string(i_part) + "." + string(f_part)
}

func int_to_string_ex(int i) string {
    string(i)
}

