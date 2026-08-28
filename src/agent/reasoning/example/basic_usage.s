package neurx.reasoning.examples.basic_cot_example
use neurx.reasoning.cot_config.{new_default_cot_config}
use neurx.reasoning.reasoning_chain.new_reasoning_chain
use neurx.reasoning.reasoning_step.{new_reasoning_step, step_type}
use neurx.reasoning.reasoning_manager.new_reasoning_manager
use neurx.reasoning.prompt_engineer.new_prompt_engineer
func example_math_reasoning() {
    config := new_default_cot_config()
    user_prompt := "If a rectangle has a width of 5 and length of 10, what is its area"
    chain := new_reasoning_chain("math_chain_1", user_prompt, config)
    chain = chain.start()
    step1 := new_reasoning_step(1, 1, step_type.analysis)
    step1.prompt = user_prompt
    step1.reasoning = "We need to find the area of a rectangle."
    step1.intermediate_result = "Area = width × length"
    step1.confidence = 0.95
    step1.token_count = 50
    chain = chain.add_step(step1)
    step2 := new_reasoning_step(2, 2, step_type.deduction)
    step2.prompt = "Now apply the formula with width=5 and length=10"
    step2.reasoning = "Substitute the given values into the formula: Area = 5 × 10"
    step2.intermediate_result = "Area = 50"
    step2.confidence = 0.99
    step2.token_count = 40
    chain = chain.add_step(step2)
    step3 := new_reasoning_step(3, 3, step_type.verification)
    step3.prompt = "Verify the calculation"
    step3.reasoning = "5 × 10 = 50 ✓"
    step3.intermediate_result = "The calculation is correct"
    step3.confidence = 1.0
    step3.token_count = 30
    chain = chain.add_step(step3)
    chain = chain.complete("The area of the rectangle is 50 square units.")
    string summary = chain.get_reasoning_text()
    validator := new_reasoning_validator(config)
    result := validator.validate_chain(chain)
}
func example_logical_reasoning() {
    config := new_default_cot_config()
    user_prompt := "All humans are mortal. Socrates is a human. Is Socrates mortal"
    chain := new_reasoning_chain("logic_chain_1", user_prompt, config)
    chain = chain.start()
    step1 := new_reasoning_step(1, 1, step_type.analysis)
    step1.reasoning = "Premise 1: All humans are mortal. Premise 2: Socrates is a human."
    step1.intermediate_result = "Premises identified"
    step1.confidence = 1.0
    chain = chain.add_step(step1)
    step2 := new_reasoning_step(2, 2, step_type.deduction)
    step2.reasoning = "If all humans are mortal, and Socrates is a human, then Socrates must be mortal."
    step2.intermediate_result = "Conclusion: Socrates is mortal"
    step2.confidence = 1.0
    chain = chain.add_step(step2)
    chain = chain.complete("Yes, Socrates is mortal.")
}
func example_with_manager() {
    config := new_default_cot_config()
    manager := new_reasoning_manager(config)
    prompts := string[]{
        "What is 2 + 2",
        "What is the capital of France",
        "How do photosynthesis work",
    }
    chains := manager.batch_start_reasoning(prompts, config)
    if len(chains) > 0 {
        first_chain := chains[0]
        step1 := new_reasoning_step(1, 1, step_type.analysis)
        step1.reasoning = "We need to add 2 and 2"
        step1.intermediate_result = "2 + 2 = 4"
        step1.confidence = 1.0
        manager.add_reasoning_step(first_chain.chain_id, step1)
        manager.complete_reasoning_chain(first_chain.chain_id, "The answer is 4")
    }
    stats := manager.get_statistics()
}
func example_with_backtracking() {
    config := new_default_cot_config()
    config.enable_backtracking = true
    config.backtrack_depth = 2
    chain := new_reasoning_chain("backtrack_chain", "Solve this logic puzzle", config)
    chain = chain.start()
    for i := 1; i <= 5; i = i + 1 {
        step := new_reasoning_step(i, i, step_type.analysis)
        step.reasoning = "Reasoning step " + string(i)
        step.intermediate_result = "Result " + string(i)
        step.confidence = 0.8
        chain = chain.add_step(step)
    }
    if chain.can_backtrack() {
        chain = chain.backtrack(2)
    }
}
func example_hierarchical_reasoning() {
    config := new_detailed_cot_config()
    config.enable_branching = true
    config.max_branches = 3
    chain := new_reasoning_chain("hierarchical_chain", "Complex problem analysis", config)
    chain = chain.start()
    main_step := new_reasoning_step(1, 1, step_type.analysis)
    main_step.reasoning = "Break down the complex problem into sub-problems"
    main_step.intermediate_result = "Identified 3 sub-problems"
    main_step.confidence = 0.9
    chain = chain.add_step(main_step)
    for branch := 1; branch <= 3; branch = branch + 1 {
        sub_step := new_reasoning_step(branch+1, branch+1, step_type.deduction)
        sub_step.parent_step_id = 1
        sub_step.reasoning = "Solve sub-problem " + string(branch)
        sub_step.intermediate_result = "Sub-problem " + string(branch) + " solved"
        sub_step.confidence = 0.85
        chain = chain.add_step(sub_step)
    }
    synthesis_step := new_reasoning_step(5, 5, step_type.synthesis)
    synthesis_step.reasoning = "Combine solutions from all sub-problems"
    synthesis_step.intermediate_result = "Final solution"
    synthesis_step.confidence = 0.88
    chain = chain.add_step(synthesis_step)
}
func example_prompt_engineering() {
    config := new_default_cot_config()
    engineer := new_prompt_engineer(config)
    user_prompt := "Explain quantum computing"
    initial_prompt := engineer.get_initial_prompt(user_prompt)
    reasoning_so_far := "Quantum computing uses quantum bits (qubits)"
    intermediate := "Each qubit can be 0, 1, or superposition"
    step_prompt := engineer.get_step_prompt(reasoning_so_far, intermediate, 2)
    summary := "Qubits enable parallel computation through superposition"
    final_prompt := engineer.get_final_answer_prompt(summary)
    steps := string[]{
        "Understanding qubits",
        "Understanding superposition",
        "Understanding entanglement",
    }
    summary_prompt := engineer.get_summary_prompt(steps)
}
func example_validation() {
    config := new_default_cot_config()
    chain := new_reasoning_chain("validation_chain", "Validate reasoning", config)
    chain = chain.start()
    for i := 1; i <= 3; i = i + 1 {
        step := new_reasoning_step(i, i, step_type.analysis)
        step.reasoning = "Valid reasoning " + string(i)
        step.intermediate_result = "Valid result " + string(i)
        step.confidence = 0.9
        step.is_valid = true
        chain = chain.add_step(step)
    }
    chain = chain.complete("Final valid answer")
    validator := new_reasoning_validator(config)
    result := validator.validate_chain(chain)
    if result.is_valid {
        report := validator.generate_report(chain)
    }
}
use neurx.reasoning.reasoning_validator.new_reasoning_validator
use neurx.reasoning.cot_config.new_detailed_cot_config
