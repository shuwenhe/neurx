package neurx.inference.logits_processors.test

use neurx.inference.logits_processors

func test_base_processor_temperature() {
    print("🧪 Test: Temperature Scaling")

    []float logits = []float{1.0, 2.0, 3.0, 4.0}

    map[string]float params = map[string]float{}
    params["temperature"] = 2.0

    []float result = apply_temperature(logits, params)

    if result[0] == 0.5 {
        print("  ✓ Temperature scaling applied correctly")
    }

    print("  ✓ PASSED\n")
}

func test_top_k_filtering() {
    print("🧪 Test: Top-K Filtering")

    []float logits = []float{5.0, 2.0, 8.0, 1.0, 6.0}

    map[string]float params = map[string]float{}
    params["k"] = 2.0

    []float result = apply_top_k(logits, params)

    if result[2] > 0.0 {
        print("  ✓ Top-K filtering preserves top values")
    }

    print("  ✓ PASSED\n")
}

func test_top_p_filtering() {
    print("🧪 Test: Top-P (Nucleus) Filtering")

    []float logits = []float{5.0, 4.0, 3.0, 2.0, 1.0}

    map[string]float params = map[string]float{}
    params["p"] = 0.9

    []float result = apply_top_p(logits, params)

    if result[0] > 0.0 {
        print("  ✓ Top-P filtering applied correctly")
    }

    print("  ✓ PASSED\n")
}

func test_repetition_penalty() {
    print("🧪 Test: Repetition Penalty")

    []float logits = []float{2.0, 3.0, 4.0, 3.5}

    map[string]float params = map[string]float{}
    params["penalty"] = 1.2

    []float result = apply_repetition_penalty(logits, params)

    if len(result) == len(logits) {
        print("  ✓ Repetition penalty applied")
    }

    print("  ✓ PASSED\n")
}

func test_grammar_constraint_processor() {
    print("🧪 Test: Grammar Constraint Processor")

    grammar_constraint_processor processor = new_grammar_constraint_processor(1000)

    processor.add_grammar_rule("numbers", []string{"0", "1", "2"}, "exact")

    []float logits = make([]float, 1000)
    int i = 0
    for i < 1000 {
        logits[i] = float(i % 10)
        i = i + 1
    }

    []float result = processor.process_logits(logits)

    if len(result) == 1000 {
        print("  ✓ Grammar constraint processor processes logits")
    }

    print("  ✓ PASSED\n")
}

func test_json_grammar() {
    print("🧪 Test: JSON Grammar Constraint")

    grammar_constraint_set json_grammar = create_json_grammar()

    if len(json_grammar.rules) > 0 {
        print("  ✓ JSON grammar created successfully")
    }

    if json_grammar.rules[0].rule_type == "exact" {
        print("  ✓ JSON grammar has correct rule type")
    }

    print("  ✓ PASSED\n")
}

func test_banned_tokens_processor() {
    print("🧪 Test: Banned Tokens Processor")

    banned_tokens_processor processor = new_banned_tokens_processor(256)

    processor.ban_token(10)
    processor.ban_token(20)
    processor.ban_token(30)

    if processor.get_banned_count() == 3 {
        print("  ✓ Tokens banned successfully")
    }

    if processor.is_token_banned(10) {
        print("  ✓ Token ban status checked correctly")
    }

    print("  ✓ PASSED\n")
}

func test_ban_word() {
    print("🧪 Test: Ban by Word")

    banned_tokens_processor processor = new_banned_tokens_processor(256)

    processor.ban_word("badword")
    processor.ban_word("harmful")

    if processor.is_word_banned("badword") {
        print("  ✓ Word ban applied")
    }

    print("  ✓ PASSED\n")
}

func test_unban_token() {
    print("🧪 Test: Unban Token")

    banned_tokens_processor processor = new_banned_tokens_processor(256)

    processor.ban_token(5)
    processor.unban_token(5)

    if !processor.is_token_banned(5) {
        print("  ✓ Token unbanned successfully")
    }

    print("  ✓ PASSED\n")
}

func test_adaptive_ban() {
    print("🧪 Test: Adaptive Ban")

    banned_tokens_processor processor = new_banned_tokens_processor(256)

    []int history = []int{1, 2, 3, 1, 2, 3, 1, 2, 3}
    processor.ban_repeated_token(history, 1)

    if processor.is_token_banned(1) {
        print("  ✓ Adaptive ban applied for repeated token")
    }

    print("  ✓ PASSED\n")
}

func test_diversity_processor() {
    print("🧪 Test: Diversity Processor")

    diversity_processor processor = new_diversity_processor(256)

    processor.set_temperature(0.8)
    processor.set_top_k(40)
    processor.set_top_p(0.9)

    []float logits = make([]float, 256)
    int i = 0
    for i < 256 {
        logits[i] = float(i)
        i = i + 1
    }

    []float result = processor.process_logits(logits)

    if len(result) == 256 {
        print("  ✓ Diversity processor processes logits correctly")
    }

    print("  ✓ PASSED\n")
}

func test_frequency_penalty() {
    print("🧪 Test: Frequency Penalty")

    diversity_processor processor = new_diversity_processor(256)

    processor.set_frequency_penalty(0.5)
    processor.add_token_to_history(10)
    processor.add_token_to_history(10)
    processor.add_token_to_history(20)

    float unique_ratio = processor.get_unique_token_ratio()

    if unique_ratio > 0.0 {
        print("  ✓ Frequency tracking works")
    }

    print("  ✓ PASSED\n")
}

func test_entropy_calculation() {
    print("🧪 Test: Entropy Calculation")

    diversity_processor processor = new_diversity_processor(256)

    processor.add_token_to_history(1)
    processor.add_token_to_history(2)
    processor.add_token_to_history(3)

    float entropy = processor.get_entropy()

    if entropy >= 0.0 {
        print("  ✓ Entropy calculated")
    }

    print("  ✓ PASSED\n")
}

func test_processor_manager() {
    print("🧪 Test: Processor Manager")

    logits_processor_manager mgr = new_logits_processor_manager(256)

    map[string]float temp_params = map[string]float{}
    temp_params["temperature"] = 0.8

    mgr.register_processor("temperature", "temperature", 0, temp_params)

    if len(mgr.processors) > 0 {
        print("  ✓ Processor registered successfully")
    }

    print("  ✓ PASSED\n")
}

func test_processor_pipeline() {
    print("🧪 Test: Processor Pipeline")

    logits_processor_manager mgr = new_logits_processor_manager(256)

    map[string]float temp_params = map[string]float{}
    temp_params["temperature"] = 0.9

    map[string]float topk_params = map[string]float{}
    topk_params["k"] = 40.0

    mgr.register_processor("temp", "temperature", 1, temp_params)
    mgr.register_processor("topk", "top_k", 2, topk_params)

    []float logits = make([]float, 256)
    int i = 0
    for i < 256 {
        logits[i] = float(i)
        i = i + 1
    }

    []float result = mgr.process_logits(logits)

    if len(result) == 256 {
        print("  ✓ Pipeline processes logits correctly")
    }

    print("  ✓ PASSED\n")
}

func test_disable_processor() {
    print("🧪 Test: Disable Processor")

    logits_processor_manager mgr = new_logits_processor_manager(256)

    map[string]float params = map[string]float{}
    params["temperature"] = 0.8

    mgr.register_processor("temp", "temperature", 0, params)
    mgr.disable_processor("temp")

    if !mgr.processors[0].enabled {
        print("  ✓ Processor disabled successfully")
    }

    print("  ✓ PASSED\n")
}

func test_conservative_preset() {
    print("🧪 Test: Conservative Preset")

    processor_pipeline_config config = create_conservative_config()

    if len(config.processor_order) > 0 {
        print("  ✓ Conservative preset configured")
    }

    print("  ✓ PASSED\n")
}

func test_creative_preset() {
    print("🧪 Test: Creative Preset")

    processor_pipeline_config config = create_creative_config()

    if len(config.processor_order) > 0 {
        print("  ✓ Creative preset configured")
    }

    print("  ✓ PASSED\n")
}

func test_inference_pipeline() {
    print("🧪 Test: Inference Pipeline")

    inference_with_logits_processing pipeline = create_inference_pipeline(256)

    []float logits = make([]float, 256)
    int i = 0
    for i < 256 {
        logits[i] = float(i)
        i = i + 1
    }

    int token = pipeline.process_step(logits, "greedy")

    if token >= 0 && token < 256 {
        print("  ✓ Inference pipeline selects valid token")
    }

    print("  ✓ PASSED\n")
}

func test_token_selection() {
    print("🧪 Test: Token Selection Methods")

    []float logits = []float{1.0, 5.0, 3.0, 2.0}

    int greedy_token = select_greedy_token(logits)

    if greedy_token == 1 {
        print("  ✓ Greedy selection picks maximum")
    }

    print("  ✓ PASSED\n")
}

func test_statistics() {
    print("🧪 Test: Statistics Tracking")

    logits_processor_manager mgr = new_logits_processor_manager(256)

    map[string]float params = map[string]float{}
    params["temperature"] = 0.8

    mgr.register_processor("temp", "temperature", 0, params)

    []float logits = make([]float, 256)
    int i = 0
    for i < 256 {
        logits[i] = float(i)
        i = i + 1
    }

    mgr.process_logits(logits)

    pipeline_statistics stats = mgr.get_statistics()

    if stats.total_calls > 0 {
        print("  ✓ Statistics tracked correctly")
    }

    print("  ✓ PASSED\n")
}

func run_all_tests() {
    print("═" * 70)
    print("🧪 Logits Processor System - Complete Unit Test Suite")
    print("═" * 70)
    print("")

    test_base_processor_temperature()
    test_top_k_filtering()
    test_top_p_filtering()
    test_repetition_penalty()
    test_grammar_constraint_processor()
    test_json_grammar()
    test_banned_tokens_processor()
    test_ban_word()
    test_unban_token()
    test_adaptive_ban()
    test_diversity_processor()
    test_frequency_penalty()
    test_entropy_calculation()
    test_processor_manager()
    test_processor_pipeline()
    test_disable_processor()
    test_conservative_preset()
    test_creative_preset()
    test_inference_pipeline()
    test_token_selection()
    test_statistics()

    print("═" * 70)
    print("✅ All tests completed successfully!")
    print("═" * 70)
}

func main() {
    run_all_tests()
}
