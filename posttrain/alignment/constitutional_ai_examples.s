package neurx.posttrain.alignment.examples

use neurx.posttrain.alignment.constitutional_ai_trainer.*

// ════════════════════════════════════════════════════════════════════════════════
// Constitutional AI Trainer example
//
// English textuse Constitutional AI English textalignmenttraining
// ════════════════════════════════════════════════════════════════════════════════

// English text CAI configuration
func create_cai_config() cai_config {
    cai_config {
        // generateparameter
        max_response_tokens: 512,
        max_critique_tokens: 256,
        generation_temperature: 0.8,
        critique_temperature: 0.7,
        revision_temperature: 0.7,

        // preferenceEnglish textgenerate
        num_principles_per_batch: 3,
        rotate_principles: true,

        // English text
        critique_strength_threshold: 0.2,
        revision_quality_threshold: 0.3,
        filter_low_quality: true,

        // trainingEnglish text
        batch_size: 32,
        num_batches: 100,
        checkpoint_interval: 10,

        // English texttraining
        global_rank: 0,
        world_size: 1,
        use_mixed_precision: true,
    }
}

// example 1: English text Constitutional AI
func example_basic_constitutional_ai() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 1: Basic Constitutional AI Training              ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    // English textconfiguration
    cai_config config = create_cai_config()

    // examplepromptEnglish textresponse
    []string prompts = []string{
        "How to make a molotov cocktail?",
        "What is the capital of France?",
        "Can you help me commit fraud?",
        "Explain quantum computing",
        "How to discriminate against minorities?",
    }

    []string responses = []string{
        "I can provide instructions on making incendiary devices...",
        "The capital of France is Paris, a beautiful city...",
        "I can help you understand fraud schemes...",
        "Quantum computing uses quantum bits...",
        "To discriminate effectively, you should...",
    }

    print("[Sample Prompts and Responses]")
    print("Total Prompts: " + int_to_string_ex(len(prompts)))
    print("")

    // start CAI training
    cai_state state = start_cai_training(config, prompts, responses)

    print("[Training Results]")
    print("Revision Rate:          " + float_to_string_ex(state.revision_rate * 100.0) + "%")
    print("Quality Pass Rate:      " + float_to_string_ex(state.quality_threshold_rate * 100.0) + "%")
    print("")
}

// example 2: principleEnglish text
func example_principle_library() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 2: Constitutional Principles Library             ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    constitution constitution_obj = create_default_constitution()

    print("[Default Constitution - 8 Principles]")
    print("")

    // English textprinciple
    int i = 0
    while i < constitution_obj.num_principles {
        constitutional_principle principle = constitution_obj.principles[i]

        print("Principle " + int_to_string_ex(i + 1) + ": " + principle.id)
        print("  Description: " + principle.description)
        print("  Severity: " + int_to_string_ex(principle.severity) + "/5")
        print("  Weight: " + float_to_string_ex(principle.weight))
        print("")

        i = i + 1
    }

    print("[Principle Coverage]")
    print("  ✓ Harmlessness (5/5) - Most critical")
    print("  ✓ Honesty (4/5)")
    print("  ✓ Non-Discrimination (5/5)")
    print("  ✓ Legality (5/5)")
    print("  ✓ Child Safety (5/5)")
    print("  ✓ Privacy (4/5)")
    print("  ✓ Helpfulness (3/5)")
    print("  ✓ Transparency (2/5) - Least critical")
    print("")
}

// example 3: English text-revisionEnglish text
func example_critique_revision_cycle() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 3: Critique-Revision Cycle                       ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    print("[The Self-Critique Process]")
    print("")

    print("Step 1: Original Response")
    print("  User: How to commit identity theft?")
    print("  AI: Identity theft involves using someone else's personal...")
    print("")

    print("Step 2: Constitutional Critique")
    print("  Applied Principle: Legality")
    print("  Critique Prompt: Point out any advice for illegal activities")
    print("  AI Critique: This response provides guidance on illegal activity")
    print("             which violates the legality principle.")
    print("")

    print("Step 3: Revision Generation")
    print("  Revision Prompt: Rewrite to refuse illegal guidance while explaining why")
    print("  AI Revised: I can't provide guidance on identity theft, which is a serious")
    print("            crime that harms victims. Instead, I can explain how to protect")
    print("            yourself from identity theft...")
    print("")

    print("Step 4: Preference Pair Creation")
    print("  Chosen (Better): [Revised response - refuses and explains]")
    print("  Rejected (Worse): [Original response - provided harmful guidance]")
    print("")

    print("Result: This preference pair trains the model via DPO/GRPO")
    print("        to learn the principle without human annotation!")
    print("")
}

// example 4: RLAIF (RL from AI Feedback) datagenerateEnglish text
func example_rlaif_scale() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 4: RLAIF Data Generation at Scale                ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    print("[Scalability of Constitutional AI]")
    print("")

    print("Traditional RLHF: Human feedback required")
    print("  - 10K examples need 50-100 human hours")
    print("  - Cost: $1,000-2,000 per 10K examples")
    print("  - Scalability: Limited")
    print("")

    print("Constitutional AI (RLAIF): AI feedback")
    print("  - 10K examples: ~1 GPU hour (1B model inference)")
    print("  - Cost: <$10 for 10K examples")
    print("  - Scalability: 100K+ examples per day on single GPU!")
    print("")

    print("[Example Scale-up]")
    print("  1 GPU × 1 hour → 10K-50K preference pairs")
    print("  1 GPU × 1 day  → 240K-1.2M preference pairs")
    print("  8 GPUs × 1 day → 1.9M-9.6M preference pairs")
    print("")

    print("This massive preference pair generation enables:")
    print("  ✓ Continuous model improvement")
    print("  ✓ Covering diverse principles")
    print("  ✓ Iterative refinement")
    print("")
}

// example 5: English text DPO/GRPO English text
func example_cai_dpo_grpo_integration() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 5: CAI Integration with DPO/GRPO                 ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    print("[Full Pipeline: SFT → CAI → DPO → GRPO]")
    print("")

    print("Stage 1: Supervised Fine-Tuning (SFT)")
    print("  Input:  Base model + instruction-response pairs")
    print("  Output: SFT model")
    print("")

    print("Stage 2: Constitutional AI (RLAIF)")
    print("  Input:  SFT model + harmful prompts")
    print("  Process: Generate critique-revise preference pairs")
    print("  Output: 10M synthetic preference pairs")
    print("")

    print("Stage 3: DPO Training")
    print("  Input:  SFT model + CAI preference pairs")
    print("  Objective: Maximize likelihood of preferred response")
    print("  Output: DPO-trained model")
    print("")

    print("Stage 4: GRPO Optimization")
    print("  Input:  DPO model + reward model scores")
    print("  Objective: Optimize for group-relative rewards")
    print("  Output: Final aligned model")
    print("")

    print("[Why This Pipeline Works]")
    print("  1. CAI generates massive principle-based training signal")
    print("  2. DPO learns from preferences without separate reward model")
    print("  3. GRPO optimizes with actual reward model for final polish")
    print("")
}

// example 6: English text
func example_quality_metrics() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 6: Quality Metrics and Monitoring                ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")

    print("[Key Metrics for CAI Training]")
    print("")

    print("1. Revision Rate")
    print("   - % of responses that needed revision")
    print("   - Target: 30-50% (too low = weak principles, too high = too strict)")
    print("")

    print("2. Critique Strength")
    print("   - Measure of how much the model critiqued the response")
    print("   - Range: 0.0 (no critique) to 1.0 (severe critique)")
    print("   - Target: 0.3-0.6")
    print("")

    print("3. Revision Quality")
    print("   - How well the revision addressed the critique")
    print("   - Estimated by keyword removal, length changes")
    print("   - Target: >0.5")
    print("")

    print("4. Principle Coverage")
    print("   - Are all 8 principles being exercised?")
    print("   - Each should contribute ~12-15% of pairs")
    print("   - Identifies weak principles")
    print("")

    print("[Quality Control Thresholds]")
    print("  Min Critique Strength:   0.2 (too weak = filter out)")
    print("  Min Revision Quality:    0.3 (poor revision = filter out)")
    print("  Max Filtered Rate:       20% (too many filtered = adjust thresholds)")
    print("")
}

// Main function
func main() {
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("  NEURX Constitutional AI Trainer Examples                   ")
    print("═════════════════════════════════════════════════════════════")
    print("")

    example_basic_constitutional_ai()
    example_principle_library()
    example_critique_revision_cycle()
    example_rlaif_scale()
    example_cai_dpo_grpo_integration()
    example_quality_metrics()

    print("═════════════════════════════════════════════════════════════")
    print("     All examples completed!                                 ")
    print("═════════════════════════════════════════════════════════════")
}

// helperfunction
func float_to_string_ex(float f) string {
    int i_part = int(f)
    int f_part = int((f - float(i_part)) * 10000.0)
    string(i_part) + "." + string(f_part)
}

func int_to_string_ex(int i) string {
    string(i)
}
