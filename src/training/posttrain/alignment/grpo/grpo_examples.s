package neurx.posttrain.grpo.examples
use neurx.posttrain.grpo.grpo_trainer.*
use neurx.model.llm.neurx.*
use neurx.tokenizer.neurx.*
func create_grpo_example_config() grpo_train_config {
    grpo_train_config {
        method: "grpo",
        batch_size: 8,
        group_size: 8,
        gradient_accum_steps: 4,
        learning_rate: 1e-6,
        lr_warmup_ratio: 0.05,
        lr_schedule_type: "cosine",
        total_training_steps: 50000,
        adam_beta1: 0.9,
        adam_beta2: 0.95,
        adam_epsilon: 1e-8,
        weight_decay: 0.01,
        max_grad_norm: 1.0,
        clip_epsilon: 0.2,
        kl_coef: 0.04,
        entropy_coef: 0.0,
        use_length_penalty: true,
        length_penalty_per_100tokens: 0.005,
        max_gen_len: 8192,
        temperature: 0.7,
        top_p: 0.95,
        precision: "bf16",
        use_gradient_checkpointing: true,
        use_flash_attention: true,
        save_interval: 2500,
        eval_interval: 1000,
        log_interval: 50,
        checkpoint_dir: "./checkpoints/grpo/",
        num_workers: 4,
        pin_memory: true,
        output_dir: "./outputs/grpo/",
    }
}

func create_grpo_example_dataset() grpo_dataset {
    grpo_dataset {
        prompts: []string{},
        reference_answers: []string{},
        size: 10000,
        source_path: "./data/grpo/math_reasoning.jsonl",
        group_size: 8,
        quality_score: 0.95,
    }
}

func example_basic_grpo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║        Example 1: Basic GRPO Training for Math             ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    neurx_model model = load_pretrained_grpo_model("neurx_200b")
    neurx_model reference_model = load_pretrained_grpo_model("neurx_200b")
    tokenizer_state tokenizer = load_tokenizer_grpo()
    grpo_train_config config = create_grpo_example_config()
    grpo_dataset dataset = create_grpo_example_dataset()
    grpo_trainer_state trainer = create_grpo_trainer(
        model,
        reference_model,
        tokenizer,
        config,
        dataset,
        0,
        1
    )
    print("Starting GRPO training for math reasoning...")
    print("  - " + string(config.batch_size) + " prompts per batch")
    print("  - " + string(config.group_size) + " outputs per prompt")
    print("  - Max generation: " + string(config.max_gen_len) + " tokens")
    print("")
    grpo_train_result result = start_grpo_training(ref trainer)
    print("")
    print("✓ GRPO training completed!")
    print("  Final Loss: " + string_float(result.final_loss))
    print("  Avg Reward: " + string_float(result.avg_reward))
    print("  checkpoint: " + result.checkpoint_path)
}

func example_grpo_group_size_comparison() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║     Example 2: GRPO with Different Group Sizes             ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    int[] group_sizes = int[]{4, 8, 16}
    neurx_model model = load_pretrained_grpo_model("neurx_200b")
    neurx_model reference_model = load_pretrained_grpo_model("neurx_200b")
    tokenizer_state tokenizer = load_tokenizer_grpo()
    grpo_dataset dataset = create_grpo_example_dataset()
    int i = 0
    for i < len(group_sizes) {
        int G = group_sizes[i]
        print("")
        print("[Group Size = " + string(G) + "]")
        grpo_train_config config = create_grpo_example_config()
        config.group_size = G
        config.total_training_steps = 10000
        grpo_trainer_state trainer = create_grpo_trainer(
            model,
            reference_model,
            tokenizer,
            config,
            dataset,
            0, 1
        )
        grpo_train_result result = start_grpo_training(ref trainer)
        print("  Final Loss: " + string_float(result.final_loss))
        print("  Avg Reward: " + string_float(result.avg_reward))
        i = i + 1
    }
    print("")
    print("Key Findings:")
    print("  - Larger G → More stable advantage computation")
    print("  - Smaller G → More frequent gradient updates")
    print("  - G=8 often provides good trade-off")
}

func example_distributed_grpo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║       Example 3: Distributed GRPO on 64 GPUs              ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    int global_rank = 0
    int world_size = 64
    neurx_model model = load_pretrained_grpo_model("neurx_200b")
    neurx_model reference_model = load_pretrained_grpo_model("neurx_200b")
    tokenizer_state tokenizer = load_tokenizer_grpo()
    grpo_train_config config = create_grpo_example_config()
    config.batch_size = 8 * 8
    config.total_training_steps = 25000
    grpo_dataset dataset = create_grpo_example_dataset()
    grpo_trainer_state trainer = create_grpo_trainer(
        model,
        reference_model,
        tokenizer,
        config,
        dataset,
        global_rank,
        world_size
    )
    print("Starting distributed GRPO on " + string(world_size) + " GPUs")
    print("Rank " + string(global_rank) + " starting...")
    grpo_train_result result = start_grpo_training(ref trainer)
    if global_rank == 0 {
        print("")
        print("✓ Distributed training completed!")
    }
}

func example_alignment_methods_comparison() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 4: GRPO vs PPO vs DPO Comparison                 ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("┌──────────────────────────────────────────────────────────┐")
    print("│ Aspect           │ DPO    │ GRPO    │ PPO                │")
    print("├──────────────────────────────────────────────────────────┤")
    print("│ Reward model     │ No     │ Rules   │ Yes (required)     │")
    print("│ Value Network    │ No     │ No      │ Yes                │")
    print("│ Group Relative   │ No     │ Yes     │ No                 │")
    print("│ Training Time    │ Fast   │ Medium  │ Slow               │")
    print("│ Memory Usage     │ Low    │ Medium  │ High               │")
    print("│ task Type        │ Pref.  │ Reason  │ General            │")
    print("│ Stability        │ High   │ High    │ Medium             │")
    print("│ Convergence      │ 3-5d   │ 7-14d   │ 7-10d              │")
    print("└──────────────────────────────────────────────────────────┘")
    print("")
    print("GRPO Best For:")
    print("  ✓ Math reasoning problems")
    print("  ✓ Code generation with testable outputs")
    print("  ✓ Tasks with clear reward signals")
    print("  ✓ Multi-solution problems")
    print("")
    print("When to Use GRPO:")
    print("  → Prefer over PPO: Better sample efficiency, no critic model")
    print("  → Prefer over DPO: Multiple outputs per prompt needed")
    print("  → Prefer DPO: General instruction following")
}

func example_grpo_long_context() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║   Example 5: GRPO with Long Context (32K tokens)          ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    grpo_train_config config = create_grpo_example_config()
    config.max_gen_len = 32768
    config.total_training_steps = 20000
    print("Configuration for long context GRPO:")
    print("  - Max generation: " + string(config.max_gen_len) + " tokens")
    print("  - KL coefficient: " + string_float(config.kl_coef))
    print("  - Length penalty: " + string_float(config.length_penalty_per_100tokens) + " per 100 tokens")
    print("")
    print("Benefits of long context:")
    print("  ✓ Support complex reasoning chains")
    print("  ✓ Allow detailed explanations")
    print("  ✓ Better context utilization")
    print("  ✓ Suitable for code generation")
}

func example_custom_reward_functions() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║   Example 6: Custom Reward Functions for Domain Tasks      ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("Domain-Specific Reward Examples:")
    print("")
    print("1. Math Problem Solving:")
    print("   - Format reward: <think>...</think><answer>...</answer>")
    print("   - Accuracy reward: Final answer matches reference")
    print("   - Step reward: Correct reasoning steps")
    print("")
    print("2. Code Generation:")
    print("   - Format reward: Valid Python/Java syntax")
    print("   - Test reward: Pass unit tests")
    print("   - Efficiency reward: O(n) complexity preferred")
    print("")
    print("3. Factual Q*A:")
    print("   - Format reward: Clear structure")
    print("   - Citation reward: Supporting evidence provided")
    print("   - Accuracy reward: Fact-checked against ground truth")
    print("")
}

func main() {
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("  NEURX GRPO (Group Relative Policy Optimization) Examples   ")
    print("═════════════════════════════════════════════════════════════")
    print("")
    example_alignment_methods_comparison()
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("     All examples completed!                                 ")
    print("═════════════════════════════════════════════════════════════")
}

func load_pretrained_grpo_model(string model_name) neurx_model {
    neurx_model{}
}

func load_tokenizer_grpo() tokenizer_state {
    tokenizer_state{}
}

func create_grpo_trainer(
    neurx_model model,
    neurx_model ref_model,
    tokenizer_state tokenizer,
    grpo_train_config config,
    grpo_dataset dataset,
    int global_rank,
    int world_size
) grpo_trainer_state {
    grpo_trainer_state {
        model: model,
        reference_model: ref_model,
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
        best_eval_metric: 999999.0,
        best_step: 0,
        running_loss: 0.0,
        running_policy_loss: 0.0,
        running_kl_loss: 0.0,
        running_clip_fraction: 0.0,
        running_group_reward: 0.0,
        running_advantage_magnitude: 0.0,
        loss_history: []float{},
        reward_history: []float{},
        kl_history: []float{},
        train_loader: dataloader{},
        eval_loader: dataloader{},
    }
}

func string_float(float f) string {
    int int_part = int(f)
    int frac_part = int((f - float_of_int(int_part)) * 10000.0)
    string(int_part) + "." + string(frac_part)
}
