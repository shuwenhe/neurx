package neurx.reasoning.examples.advanced_cot_example

use neurx.reasoning.cot_config.{new_default_cot_config, new_hierarchical_cot_config}
use neurx.reasoning.reasoning_chain.new_reasoning_chain
use neurx.reasoning.reasoning_step.{new_reasoning_step, step_type}
use neurx.reasoning.reasoning_manager.new_reasoning_manager
use neurx.reasoning.reasoning_validator.new_reasoning_validator

func example_adaptive_reasoning_length() {
    config := new_default_cot_config()

    simple_prompt := "What is 5 + 3?"
    config_simple := config.clone()
    config_simple = config_simple.set_max_steps(3)

    chain_simple := new_reasoning_chain("simple_math", simple_prompt, config_simple)
    chain_simple = chain_simple.start()

    step1 := new_reasoning_step(1, 1, step_type.analysis)
    step1.reasoning = "We need to add 5 and 3"
    step1.intermediate_result = "5 + 3 = 8"
    step1.confidence = 1.0
    chain_simple = chain_simple.add_step(step1)

    chain_simple = chain_simple.complete("The answer is 8")

    complex_prompt := "Analyze the geopolitical implications of trade policies"
    config_complex := config.clone()
    config_complex = config_complex.set_max_steps(20)
    config_complex = config_complex.set_max_tokens(5000, 20000)

    chain_complex := new_reasoning_chain("complex_analysis", complex_prompt, config_complex)
    chain_complex = chain_complex.start()

}

func example_multi_path_reasoning() {
    config := new_hierarchical_cot_config()
    config.max_branches = 3

    prompt := "What is the best approach to climate change?"
    chain := new_reasoning_chain("climate_analysis", prompt, config)
    chain = chain.start()

    init_step := new_reasoning_step(1, 1, step_type.analysis)
    init_step.reasoning = "Identify multiple potential approaches"
    init_step.intermediate_result = "Approaches: Technology, Policy, Individual Action"
    init_step.confidence = 0.8
    chain = chain.add_step(init_step)

    tech_step := new_reasoning_step(2, 2, step_type.deduction)
    tech_step.parent_step_id = 1
    tech_step.reasoning = "Analyze technology solutions: renewable energy, carbon capture"
    tech_step.intermediate_result = "Technology can reduce 50-70% of emissions"
    tech_step.confidence = 0.7
    chain = chain.add_step(tech_step)

    policy_step := new_reasoning_step(3, 3, step_type.deduction)
    policy_step.parent_step_id = 1
    policy_step.reasoning = "Analyze policy solutions: carbon tax, regulations"
    policy_step.intermediate_result = "Policy can ensure equitable transition"
    policy_step.confidence = 0.75
    chain = chain.add_step(policy_step)

    individual_step := new_reasoning_step(4, 4, step_type.deduction)
    individual_step.parent_step_id = 1
    individual_step.reasoning = "Analyze individual actions: lifestyle changes"
    individual_step.intermediate_result = "Individual action creates cultural shift"
    individual_step.confidence = 0.6
    chain = chain.add_step(individual_step)

    synthesis := new_reasoning_step(5, 5, step_type.synthesis)
    synthesis.reasoning = "All three approaches are complementary"
    synthesis.intermediate_result = "Best approach is integrated combination"
    synthesis.confidence = 0.85
    chain = chain.add_step(synthesis)

    chain = chain.complete("An integrated approach combining technology, policy, and individual action is optimal.")
}

func example_dynamic_step_adjustment() {
    config := new_default_cot_config()
    config.checkpoint_interval = 3

    chain := new_reasoning_chain("dynamic_chain", "Complex problem", config)
    chain = chain.start()

    for step_num := 1; step_num <= 10; step_num = step_num + 1 {
        step := new_reasoning_step(step_num, step_num, step_type.analysis)
        step.reasoning = "Reasoning step " + string(step_num)
        step.intermediate_result = "Result " + string(step_num)

        if step_num == 4 {
            step.confidence = 0.3
        } else {
            step.confidence = 0.85
        }

        chain = chain.add_step(step)

        if step_num % config.checkpoint_interval == 0 {
            validator := new_reasoning_validator(config)
            validation := validator.validate_step(step)

            if !validation.is_valid && chain.can_backtrack() {
                chain = chain.backtrack(2)
            }
        }
    }
}

func example_error_correction() {
    config := new_default_cot_config()

    chain := new_reasoning_chain("error_correction_chain", "Solve equation: 2x + 3 = 7", config)
    chain = chain.start()

    attempt1 := new_reasoning_step(1, 1, step_type.deduction)
    attempt1.reasoning = "2x + 3 = 7, so 2x = 7 - 3 = 4"
    attempt1.intermediate_result = "x = 2"
    attempt1.confidence = 0.6
    chain = chain.add_step(attempt1)

    validator := new_reasoning_validator(config)
    validation := validator.validate_step(attempt1)

    if !validation.is_valid {

        attempt2 := new_reasoning_step(2, 2, step_type.verification)
        attempt2.reasoning = "Let's verify: 2(2) + 3 = 4 + 3 = 7. Correct!"
        attempt2.intermediate_result = "x = 2 is verified correct"
        attempt2.confidence = 0.95
        chain = chain.add_step(attempt2)
    }

    chain = chain.complete("x = 2")
}

func example_cross_chain_coordination() {
    config := new_default_cot_config()
    manager := new_reasoning_manager(config)

    related_prompts := []string{
        "What is photosynthesis?",
        "What is the role of chlorophyll?",
        "How do light reactions work?",
    }

    chains := manager.batch_start_reasoning(related_prompts, config)

    if len(chains) > 0 {
        step1 := new_reasoning_step(1, 1, step_type.analysis)
        step1.reasoning = "Photosynthesis is the process plants use to convert light into chemical energy"
        step1.intermediate_result = "Definition established"
        step1.confidence = 1.0
        manager.add_reasoning_step(chains[0].chain_id, step1)
        manager.complete_reasoning_chain(chains[0].chain_id, "Photosynthesis converts light energy into glucose")
    }

    if len(chains) > 1 {
        step2 := new_reasoning_step(1, 1, step_type.analysis)
        step2.reasoning = "Chlorophyll is the pigment that absorbs light energy"
        step2.intermediate_result = "Role identified based on first chain"
        step2.confidence = 0.95
        manager.add_reasoning_step(chains[1].chain_id, step2)
        manager.complete_reasoning_chain(chains[1].chain_id, "Chlorophyll absorbs light and initiates energy transfer")
    }

    if len(chains) > 2 {
        step3 := new_reasoning_step(1, 1, step_type.analysis)
        step3.reasoning = "Light reactions occur in thylakoids and produce ATP and NADPH"
        step3.intermediate_result = "Process mapped using insights from previous chains"
        step3.confidence = 0.9
        manager.add_reasoning_step(chains[2].chain_id, step3)
        manager.complete_reasoning_chain(chains[2].chain_id, "Light reactions provide energy carriers for Calvin cycle")
    }

    stats := manager.get_statistics()
}

func example_context_aware_reasoning() {
    config := new_default_cot_config()

    domain := "mathematics"

    match domain {
        "mathematics": {
            config = config.clone()
            config.validation = validation_strategy.logical
            config.summarize_at_end = true
        },
        "literature": {
            config = config.clone()
            config.validation = validation_strategy.semantic
            config.include_reasoning_in_output = true
        },
        "science": {
            config = config.clone()
            config.validation = validation_strategy.consistency
            config.enable_backtracking = true
        },
        default: {},
    }

    prompt := "Prove that the sum of angles in a triangle is 180 degrees"
    chain := new_reasoning_chain("math_proof", prompt, config)
    chain = chain.start()

}

func example_performance_monitoring() {
    config := new_default_cot_config()
    manager := new_reasoning_manager(config)

    chain := manager.start_reasoning_chain("Complex optimization problem", config)

    total_tokens := 0
    for i := 1; i <= 5; i = i + 1 {
        step := new_reasoning_step(i, i, step_type.analysis)
        step.reasoning = "Step " + string(i)
        step.intermediate_result = "Result " + string(i)
        step.confidence = 0.8
        step.token_count = 100 * i

        manager.add_reasoning_step(chain.chain_id, step)
        total_tokens = total_tokens + step.token_count

        updated_chain := manager.get_chain(chain.chain_id)
        updated_chain = updated_chain.update_token_count(step.token_count)

        if updated_chain.has_exceeded_token_limit() {

            break
        }
    }

    stats := manager.get_statistics()

}

func example_reasoning_export() {
    config := new_default_cot_config()

    chain := new_reasoning_chain("export_chain", "Sample reasoning", config)
    chain = chain.start()

    for i := 1; i <= 3; i = i + 1 {
        step := new_reasoning_step(i, i, step_type.analysis)
        step.reasoning = "Reasoning " + string(i)
        step.intermediate_result = "Result " + string(i)
        step.confidence = 0.85 + float(i) * 0.05
        chain = chain.add_step(step)
    }

    chain = chain.complete("Final answer")

    reasoning_text := chain.get_reasoning_text()

    validator := new_reasoning_validator(config)
    report := validator.generate_report(chain)
}

use neurx.reasoning.cot_config.validation_strategy
