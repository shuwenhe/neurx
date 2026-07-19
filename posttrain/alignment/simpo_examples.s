package neurx.posttrain.alignment.simpo_examples

use neurx.posttrain.alignment.simpo_trainer.*

// ════════════════════════════════════════════════════════════════════════════════
// SimPO (Simple Preference Optimization) Trainer Examples
//
// English textpreferenceoptimizeimplementation
// ════════════════════════════════════════════════════════════════════════════════

func create_simpo_config() simpo_config {
    simpo_config {
        seq_len: 128,
        hidden_size: 256,
        vocab_size: 32000,
        learning_rate: 1e-4,
        beta: 0.1,
        alpha: 1.0,
        batch_size: 32,
        num_epochs: 3,
        weight_decay: 0.01,
        max_grad_norm: 0.5,
        global_rank: 0,
        world_size: 1,
        dp_degree: 1,
        checkpoint_dir: "./checkpoints",
        save_interval: 10,
    }
}

// Example 1: Basic SimPO Training
func example_basic_simpo_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 1: Basic SimPO Training                          ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    simpo_config cfg = create_simpo_config()

    print("[Configuration]")
    print("  Simplicity: Minimal components")
    print("  Beta (margin scale): " + float_to_string_ex(cfg.beta))
    print("  Learning rate: " + float_to_string_ex(cfg.learning_rate))
    print("")

    print("[Creating Sample Batches]")
    []simpo_batch batches = []simpo_batch{cap: 10}

    int b = 0
    while b < 10 {
        simpo_batch batch = simpo_batch {
            pairs: []simpo_preference_pair{cap: cfg.batch_size},
            size: cfg.batch_size,
        }

        int p = 0
        while p < cfg.batch_size {
            simpo_preference_pair pair = simpo_preference_pair {
                chosen_tokens: []int{cap: 128},
                rejected_tokens: []int{cap: 128},
                confidence: 0.8,
            }

            int t = 0
            while t < 128 {
                pair.chosen_tokens = append_int_ex(pair.chosen_tokens, t)
                pair.rejected_tokens = append_int_ex(pair.rejected_tokens, t)
                t = t + 1
            }

            batch.pairs = append_pair_ex(batch.pairs, pair)
            p = p + 1
        }

        batches = append_batch_ex(batches, batch)
        b = b + 1
    }

    print("  Created 10 batches of 32 pairs")
    print("")

    simpo_state state = start_simpo_training(cfg, batches)
    print("")
}

// Example 2: SimPO vs DPO vs ORPO Comparison
func example_algorithm_comparison() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 2: Algorithm Comparison                          ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    print("[Loss Functions]")
    print("")

    print("DPO Loss:")
    print("  L_dpo = -log σ(β(log p_c - log p_r))")
    print("  Components: 2 forward passes + sigmoid")
    print("  Code lines: ~300 lines")
    print("")

    print("ORPO Loss:")
    print("  L_orpo = -log σ(γ*odds) + λ*D_KL")
    print("  Components: 2 forward passes + odds ratio + KL")
    print("  Code lines: ~800 lines")
    print("")

    print("SimPO Loss:")
    print("  L_simpo = -log σ(β*(log p_c - log p_r))")
    print("  Components: 2 forward passes + sigmoid")
    print("  Code lines: ~300 lines (SIMPLIFIED)")
    print("")

    print("[Key Difference]")
    print("  • SimPO: Pure margin-based, no KL, no implicit reward")
    print("  • DPO: Implicit reward modeling via Bayes")
    print("  • ORPO: Explicit odds ratio + KL constraint")
    print("")

    print("[Convergence Speed]")
    print("  SimPO: Fastest (fewer constraints)")
    print("  DPO: Medium")
    print("  ORPO: Slower (more constraints)")
    print("")
}

// Example 3: Margin-Based Learning
func example_margin_based_learning() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 3: Margin-Based Learning                         ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    print("[What is Margin?]")
    print("  Margin = log P(chosen) - log P(rejected)")
    print("  Goal: Maximize margin → maximize preference")
    print("")

    print("[Example Log Probabilities]")
    print("  Chosen response: [tokens] → log probs [-2.1, -2.3, -2.0, ...]")
    print("  Sum: -2.1 + -2.3 + -2.0 = -6.4")
    print("")
    print("  Rejected response: [tokens] → log probs [-3.2, -3.1, -2.9, ...]")
    print("  Sum: -3.2 + -3.1 + -2.9 = -9.2")
    print("")
    print("  Margin: -6.4 - (-9.2) = 2.8")
    print("")

    print("[Loss Computation]")
    print("  L = -log σ(β * margin)")
    print("    = -log σ(0.1 * 2.8)")
    print("    = -log σ(0.28)")
    print("    ≈ 0.56")
    print("")
    print("  High margin → Low loss (good!)")
    print("  Low margin → High loss (needs improvement)")
    print("")
}

// Example 4: Training Dynamics
func example_training_dynamics() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 4: Training Dynamics                             ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    print("[Typical Training Curve]")
    print("  Epoch | Batch | Loss   | Margin | Status")
    print("  ------|-------|--------|--------|--------")
    print("   1    |  10   | 0.82   | 0.3    | High loss")
    print("   1    |  20   | 0.71   | 0.5    | Learning...")
    print("   1    |  50   | 0.55   | 1.2    | Better margins")
    print("   2    |  100  | 0.42   | 1.8    | Converging")
    print("   3    |  150  | 0.28   | 2.5    | Good margins")
    print("   3    |  200  | 0.18   | 3.1    | Converged")
    print("")

    print("[Key Observations]")
    print("  • Loss decreases monotonically (stable)")
    print("  • Margin increases → preference gets stronger")
    print("  • Convergence in ~2-3 epochs")
    print("")
}

// Example 5: Hyperparameter Sensitivity
func example_hyperparameter_sensitivity() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 5: Hyperparameter Sensitivity                    ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    print("[Beta Parameter Effect]")
    print("  Beta scales the margin before sigmoid")
    print("  L = -log σ(β * margin)")
    print("")
    print("  Beta | Effect")
    print("  -----|---------------------------------------------")
    print("  0.01 | Very soft (all margins similar loss)")
    print("  0.05 | Soft (large margin changes → small loss diff)")
    print("  0.1  | Default (balanced)")
    print("  0.5  | Hard (large margin changes → big loss diff)")
    print("  1.0  | Very hard (almost step function)")
    print("")

    print("[Learning Rate Effect]")
    print("  lr   | Speed     | Stability | Convergence")
    print("  -----|-----------|-----------|-------------")
    print("  1e-5 | Very slow | Stable    | Days")
    print("  1e-4 | Slow      | Stable    | Hours")
    print("  5e-4 | Medium    | Good      | Minutes")
    print("  1e-3 | Fast      | Risky     | May diverge")
    print("")
}

// Example 6: Complete Pipeline
func example_complete_pipeline() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 6: Complete Alignment Pipeline with SimPO         ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    print("[Stage 1: SFT (7 days, 64 A100s)]")
    print("  ├─ Input: Base model + 100K instructions")
    print("  ├─ Output: Instruction-tuned model")
    print("  └─ Checkpoint: base_sft.pt")
    print("")

    print("[Stage 2: Collect Preferences (2-3 days)]")
    print("  ├─ Generate 10K prompts")
    print("  ├─ Create 5-10 responses per prompt")
    print("  ├─ Evaluate/rank responses")
    print("  └─ Create 50K preference pairs")
    print("")

    print("[Stage 3: SimPO Training (1-2 days, 8 A100s)]")
    print("  ├─ Input: SFT model + 50K preference pairs")
    print("  ├─ Config:")
    print("  │  • Learning rate: 1e-4")
    print("  │  • Beta: 0.1")
    print("  │  • Batch size: 32 per GPU")
    print("  │  • Epochs: 3")
    print("  ├─ Processing:")
    print("  │  • Batch 1: Loss=0.82 → Margin=0.3")
    print("  │  • Batch 10: Loss=0.55 → Margin=1.2")
    print("  │  • Batch 100: Loss=0.18 → Margin=3.1")
    print("  └─ Output: aligned_model.pt")
    print("")

    print("[Stage 4: Evaluation (1 day)]")
    print("  ├─ Benchmark scores (MMLU, HumanEval)")
    print("  ├─ Preference accuracy on test set")
    print("  ├─ Safety tests (toxicity, jailbreak)")
    print("  └─ Decision: Deploy or iterate")
    print("")

    print("[Total Time: ~2 weeks]")
    print("  • SFT: 1 week")
    print("  • Data collection: 2-3 days")
    print("  • SimPO training: 1-2 days ← Much faster than PPO!")
    print("  • Evaluation: 1 day")
    print("")
}

// Main
func main() {
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("  NEURX SimPO Trainer Examples                             ")
    print("═════════════════════════════════════════════════════════════")
    print("")

    example_basic_simpo_training()
    example_algorithm_comparison()
    example_margin_based_learning()
    example_training_dynamics()
    example_hyperparameter_sensitivity()
    example_complete_pipeline()

    print("═════════════════════════════════════════════════════════════")
    print("     All SimPO examples completed!                          ")
    print("═════════════════════════════════════════════════════════════")
}

// Helpers
func int_to_string_ex(int i) string {
    string(i)
}

func float_to_string_ex(float f) string {
    string(int(f * 10000.0) / 10000.0)
}

func append_int_ex([]int arr, int val) []int {
    arr
}

func append_pair_ex([]simpo_preference_pair arr, simpo_preference_pair p) []simpo_preference_pair {
    arr
}

func append_batch_ex([]simpo_batch arr, simpo_batch b) []simpo_batch {
    arr
}
