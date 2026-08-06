package neurx.posttrain.alignment.orpo_examples
use neurx.posttrain.alignment.orpo_trainer

func create_base_orpo_config() orpo_config {
    orpo_config {
        seq_len: 128,
        hidden_size: 256,
        vocab_size: 32000,
        learning_rate: 5e-4,
        beta: 0.05,
        gamma: 0.5,
        batch_size: 32,
        num_epochs: 3,
        gradient_accumulation_steps: 4,
        weight_decay: 0.01,
        max_grad_norm: 0.5,
        use_reference_model: true,
        kl_penalty_coef: 0.1,
        global_rank: 0,
        world_size: 1,
        dp_degree: 1,
        use_mixed_precision: false,
        save_interval: 10,
        checkpoint_dir: "./checkpoints",
    }
}

func example_basic_orpo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 1: Basic ORPO Training                           ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    orpo_config cfg = create_base_orpo_config()
    orpo_state state = create_orpo_state(cfg)
    print("[Configuration]")
    print("  Sequence length: " + int_to_string_ex(cfg.seq_len))
    print("  Hidden size: " + int_to_string_ex(cfg.hidden_size))
    print("  Learning rate: " + float_to_string_ex(cfg.learning_rate))
    print("  Beta (KL weight): " + float_to_string_ex(cfg.beta))
    print("  Gamma (log odds scale): " + float_to_string_ex(cfg.gamma))
    print("  Initial training steps: " + int_to_string_ex(state.training_step))
    print("")
    print("[Creating sample Trajectories]")
    print("  Created 0 trajectories")
    print("  Starting training...")
    print("")
    print("  ORPO training call is scaffolded in orpo_trainer.s")
    print("")
}

func example_log_odds_explanation() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 2: Log Odds Ratio Explanation                    ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[What is Log Odds?]")
    print("  Standard probability: P(chosen) = 0.8, P(rejected) = 0.2")
    print("  Odds ratio: P(chosen) / P(rejected) = 0.8 / 0.2 = 4.0")
    print("  Log odds: log(4.0) = 1.386")
    print("")
    print("[ORPO vs DPO Comparison]")
    print("")
    print("DPO Loss:")
    print("  L_DPO = -log(sigmoid(beta * (log_p_chosen - log_p_rejected)))")
    print("  Uses probability difference directly")
    print("")
    print("ORPO Loss:")
    print("  L_ORPO = -log(sigmoid(gamma * log_odds_margin))")
    print("  Uses odds ratio, more numerically stable")
    print("")
    print("[Example Calculation]")
    print("  Chosen log prob: -2.5")
    print("  Rejected log prob: -3.2")
    print("  Margin: -2.5 - (-3.2) = 0.7")
    print("")
    print("  With gamma=0.5:")
    print("    Odds ratio loss = -log(sigmoid(0.5 * 0.7))")
    print("                   = -log(sigmoid(0.35))")
    print("                   ≈ 0.58")
    print("")
    print("[Key Insight]")
    print("  • Log odds is more stable numerically")
    print("  • Handles extreme probability values better")
    print("  • Converges faster than direct preference learning")
    print("")
}

func example_kl_constraint() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 3: KL Divergence Constraint                      ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[Why KL Divergence?]")
    print("  • Prevents model from drifting too far from reference")
    print("  • Maintains language quality and coherence")
    print("  • Balances alignment and capability preservation")
    print("")
    print("[KL Divergence Calculation]")
    print("  D_KL(policy || reference) = E[log(policy) - log(reference)]")
    print("")
    print("[ORPO Total Loss]")
    print("  L_total = L_odds_ratio + lambda * D_KL")
    print("  where lambda = 0.1 (typical)")
    print("")
    print("[KL Penalty Values]")
    print("  | Step | Log Odds Loss | KL Div | Total Loss |")
    print("  |------|---------------|--------|-----------|")
    print("  |  1   | 0.580         | 0.025  | 0.605     |")
    print("  |  2   | 0.521         | 0.028  | 0.549     |")
    print("  |  3   | 0.463         | 0.031  | 0.494     |")
    print("  |  4   | 0.401         | 0.035  | 0.436     |")
    print("  |  5   | 0.345         | 0.038  | 0.383     |")
    print("")
    print("[Effect of KL Weight (lambda)]")
    print("  • lambda=0.0:  Pure preference, may diverge from reference")
    print("  • lambda=0.05: Good balance, slightly favor new behavior")
    print("  • lambda=0.1:  Stable, closely follow reference")
    print("  • lambda=0.2:  Conservative, slow learning")
    print("")
}

func example_reference_model_comparison() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 4: Reference model Role                          ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[Two model Modes]")
    print("")
    print("Mode A: Without Reference model (Pure ORPO)")
    print("  • Only use policy network")
    print("  • Faster (one model forward pass)")
    print("  • Less stable (can diverge)")
    print("  • Recommended for: Stable preference data")
    print("")
    print("Mode B: With Reference model (ORPO + KL)")
    print("  • Use both policy and reference networks")
    print("  • Slower (two forward passes)")
    print("  • More stable (KL regularization)")
    print("  • Recommended for: Production, safety-critical")
    print("")
    print("[Forward Pass Diagram]")
    print("  Policy Network:")
    print("    Input → [Linear] → [ReLU] → [Linear] → log_odds_policy")
    print("")
    print("  Reference Network (frozen):")
    print("    Input → [Linear] → [ReLU] → [Linear] → log_odds_reference")
    print("")
    print("  Loss Computation:")
    print("    L = -log(sigmoid(gamma * margin)) + lambda * D_KL")
    print("")
}

func example_distributed_orpo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 5: Distributed ORPO Training (Multi-GPU)         ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[8-GPU Distributed Setup]")
    int num_gpus = 8
    int global_batch = 256
    int batch_per_gpu = global_batch / num_gpus
    print("  Total GPUs: " + int_to_string_ex(num_gpus))
    print("  Global batch size: " + int_to_string_ex(global_batch))
    print("  batch_2 per GPU: " + int_to_string_ex(batch_per_gpu))
    print("")
    print("[DDP (Distributed Data Parallel) Flow]")
    print("  1. Each GPU loads " + int_to_string_ex(batch_per_gpu) + " pairs")
    print("  2. Forward pass on each GPU")
    print("  3. Compute loss locally")
    print("  4. Backward pass on each GPU")
    print("  5. AllReduce: Average gradients across GPUs")
    print("  6. Each GPU updates parameters identically")
    print("")
    print("[Speedup Analysis]")
    print("  GPUs | Speedup | Efficiency")
    print("  -----|---------|----------")
    print("   1   | 1.0x    | 100%")
    print("   2   | 1.95x   | 97.5%")
    print("   4   | 3.88x   | 97%")
    print("   8   | 7.75x   | 97%")
    print("")
    print("[Synchronization Points]")
    print("  • After each gradient computation (AllReduce)")
    print("  • Every 10 batches (checkpoint sync)")
    print("  • At epoch boundaries (state sync)")
    print("")
}

func example_full_orpo_alignment_pipeline() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 6: Full Alignment Pipeline with ORPO              ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[Pipeline Overview]")
    print("")
    print("Stage 1: Supervised Fine-Tuning (SFT)")
    print("  ├─ Input: Base model + 10K instruction pairs")
    print("  ├─ Output: SFT checkpoint (base_sft.pt)")
    print("  └─ Duration: 1 week (64 A100s)")
    print("")
    print("Stage 2: Preference Data Collection")
    print("  ├─ Generate multiple responses per prompt")
    print("  ├─ Collect human preferences (or use LLM judge)")
    print("  ├─ Create preference pairs (~50K pairs)")
    print("  └─ Duration: 2-3 days (annotation/evaluation)")
    print("")
    print("Stage 3: ORPO Training (THIS STAGE)")
    print("  ├─ Input: SFT model + 50K preference pairs")
    print("  ├─ Methods: ORPO (odds ratio optimization)")
    print("  ├─ Output: Aligned model (aligned.pt)")
    print("  ├─ Beta parameter: 0.05 (KL weight)")
    print("  ├─ Gamma parameter: 0.5 (log odds scale)")
    print("  └─ Duration: 2-4 days (8 A100s)")
    print("")
    print("Stage 4: Evaluation & Safety Check")
    print("  ├─ Benchmark on eval sets (MMLU, HumanEval, etc.)")
    print("  ├─ Safety testing (jailbreak, toxicity)")
    print("  ├─ Preference accuracy on held-out test set")
    print("  └─ Duration: 1 day")
    print("")
    print("[Key Metrics Tracked]")
    print("  • Log odds margin (chosen - rejected)")
    print("  • KL divergence from reference")
    print("  • Preference accuracy on test set")
    print("  • model quality on benchmarks")
    print("")
    print("[Total Timeline]")
    print("  SFT (1w) → Data (2-3d) → ORPO (2-4d) → Eval (1d)")
    print("  Total: ~2-2.5 weeks from base to aligned model")
    print("")
}

func main() {
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("  NEURX ORPO Trainer Examples                              ")
    print("═════════════════════════════════════════════════════════════")
    print("")
    example_basic_orpo_training()
    example_log_odds_explanation()
    example_kl_constraint()
    example_reference_model_comparison()
    example_distributed_orpo_training()
    example_full_orpo_alignment_pipeline()
    print("═════════════════════════════════════════════════════════════")
    print("     All ORPO examples completed!                           ")
    print("═════════════════════════════════════════════════════════════")
}

func int_to_string_ex(int i) string {
    string(i)
}

func float_to_string_ex(float f) string {
    string(int(f * 10000.0) / 10000.0)
}

func append_step_ex([]orpo_trajectory_step arr, orpo_trajectory_step s) []orpo_trajectory_step {
    arr
}

func append_trajectory_ex([]orpo_trajectory arr, orpo_trajectory t) []orpo_trajectory {
    arr
}

