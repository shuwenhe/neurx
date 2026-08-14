// Package: neurx.reasoning.examples.basic_cot_example
// 基础思维链示例
// 演示如何使用推理链进行简单的逐步推理

package neurx.reasoning.examples.basic_cot_example

use neurx.reasoning.cot_config.{new_default_cot_config}
use neurx.reasoning.reasoning_chain.new_reasoning_chain
use neurx.reasoning.reasoning_step.{new_reasoning_step, step_type}
use neurx.reasoning.reasoning_manager.new_reasoning_manager
use neurx.reasoning.prompt_engineer.new_prompt_engineer

// 示例 1: 基础数学推理
func example_math_reasoning() {
    // 创建配置
    config := new_default_cot_config()
    
    // 创建推理链
    user_prompt := "If a rectangle has a width of 5 and length of 10, what is its area?"
    chain := new_reasoning_chain("math_chain_1", user_prompt, config)
    chain = chain.start()
    
    // 步骤 1: 分析问题
    step1 := new_reasoning_step(1, 1, step_type.analysis)
    step1.prompt = user_prompt
    step1.reasoning = "We need to find the area of a rectangle."
    step1.intermediate_result = "Area = width × length"
    step1.confidence = 0.95
    step1.token_count = 50
    chain = chain.add_step(step1)
    
    // 步骤 2: 代入数值
    step2 := new_reasoning_step(2, 2, step_type.deduction)
    step2.prompt = "Now apply the formula with width=5 and length=10"
    step2.reasoning = "Substitute the given values into the formula: Area = 5 × 10"
    step2.intermediate_result = "Area = 50"
    step2.confidence = 0.99
    step2.token_count = 40
    chain = chain.add_step(step2)
    
    // 步骤 3: 验证
    step3 := new_reasoning_step(3, 3, step_type.verification)
    step3.prompt = "Verify the calculation"
    step3.reasoning = "5 × 10 = 50 ✓"
    step3.intermediate_result = "The calculation is correct"
    step3.confidence = 1.0
    step3.token_count = 30
    chain = chain.add_step(step3)
    
    // 完成推理链
    chain = chain.complete("The area of the rectangle is 50 square units.")
    
    // 输出结果
    string summary = chain.get_reasoning_text()
    // 在实际应用中，这会被打印或记录
    
    // 验证
    validator := new_reasoning_validator(config)
    result := validator.validate_chain(chain)
    // result.is_valid should be true
}

// 示例 2: 逻辑推理
func example_logical_reasoning() {
    config := new_default_cot_config()
    
    user_prompt := "All humans are mortal. Socrates is a human. Is Socrates mortal?"
    chain := new_reasoning_chain("logic_chain_1", user_prompt, config)
    chain = chain.start()
    
    // 步骤 1: 识别前提
    step1 := new_reasoning_step(1, 1, step_type.analysis)
    step1.reasoning = "Premise 1: All humans are mortal. Premise 2: Socrates is a human."
    step1.intermediate_result = "Premises identified"
    step1.confidence = 1.0
    chain = chain.add_step(step1)
    
    // 步骤 2: 应用逻辑规则
    step2 := new_reasoning_step(2, 2, step_type.deduction)
    step2.reasoning = "If all humans are mortal, and Socrates is a human, then Socrates must be mortal."
    step2.intermediate_result = "Conclusion: Socrates is mortal"
    step2.confidence = 1.0
    chain = chain.add_step(step2)
    
    // 完成
    chain = chain.complete("Yes, Socrates is mortal.")
}

// 示例 3: 使用推理管理器
func example_with_manager() {
    config := new_default_cot_config()
    manager := new_reasoning_manager(config)
    
    // 启动多个推理链
    prompts := []string{
        "What is 2 + 2?",
        "What is the capital of France?",
        "How do photosynthesis work?",
    }
    
    chains := manager.batch_start_reasoning(prompts, config)
    
    // 为第一个链添加步骤
    if len(chains) > 0 {
        first_chain := chains[0]
        
        step1 := new_reasoning_step(1, 1, step_type.analysis)
        step1.reasoning = "We need to add 2 and 2"
        step1.intermediate_result = "2 + 2 = 4"
        step1.confidence = 1.0
        
        manager.add_reasoning_step(first_chain.chain_id, step1)
        manager.complete_reasoning_chain(first_chain.chain_id, "The answer is 4")
    }
    
    // 获取统计信息
    stats := manager.get_statistics()
    // 输出统计数据
}

// 示例 4: 带回溯的推理
func example_with_backtracking() {
    config := new_default_cot_config()
    config.enable_backtracking = true
    config.backtrack_depth = 2
    
    chain := new_reasoning_chain("backtrack_chain", "Solve this logic puzzle", config)
    chain = chain.start()
    
    // 添加多个步骤
    for i := 1; i <= 5; i = i + 1 {
        step := new_reasoning_step(i, i, step_type.analysis)
        step.reasoning = "Reasoning step " + string(i)
        step.intermediate_result = "Result " + string(i)
        step.confidence = 0.8
        chain = chain.add_step(step)
    }
    
    // 如果需要回溯
    if chain.can_backtrack() {
        chain = chain.backtrack(2)
        // 现在从步骤 3 重新开始
    }
}

// 示例 5: 分层推理
func example_hierarchical_reasoning() {
    config := new_detailed_cot_config()
    config.enable_branching = true
    config.max_branches = 3
    
    chain := new_reasoning_chain("hierarchical_chain", "Complex problem analysis", config)
    chain = chain.start()
    
    // 高层分析
    main_step := new_reasoning_step(1, 1, step_type.analysis)
    main_step.reasoning = "Break down the complex problem into sub-problems"
    main_step.intermediate_result = "Identified 3 sub-problems"
    main_step.confidence = 0.9
    chain = chain.add_step(main_step)
    
    // 每个分支可以有自己的步骤序列
    for branch := 1; branch <= 3; branch = branch + 1 {
        sub_step := new_reasoning_step(branch+1, branch+1, step_type.deduction)
        sub_step.parent_step_id = 1
        sub_step.reasoning = "Solve sub-problem " + string(branch)
        sub_step.intermediate_result = "Sub-problem " + string(branch) + " solved"
        sub_step.confidence = 0.85
        chain = chain.add_step(sub_step)
    }
    
    // 综合阶段
    synthesis_step := new_reasoning_step(5, 5, step_type.synthesis)
    synthesis_step.reasoning = "Combine solutions from all sub-problems"
    synthesis_step.intermediate_result = "Final solution"
    synthesis_step.confidence = 0.88
    chain = chain.add_step(synthesis_step)
}

// 示例 6: 提示工程
func example_prompt_engineering() {
    config := new_default_cot_config()
    engineer := new_prompt_engineer(config)
    
    // 生成初始提示
    user_prompt := "Explain quantum computing"
    initial_prompt := engineer.get_initial_prompt(user_prompt)
    // initial_prompt 包含系统提示和用户提示
    
    // 生成步骤提示
    reasoning_so_far := "Quantum computing uses quantum bits (qubits)"
    intermediate := "Each qubit can be 0, 1, or superposition"
    step_prompt := engineer.get_step_prompt(reasoning_so_far, intermediate, 2)
    
    // 生成最终答案提示
    summary := "Qubits enable parallel computation through superposition"
    final_prompt := engineer.get_final_answer_prompt(summary)
    
    // 生成总结提示
    steps := []string{
        "Understanding qubits",
        "Understanding superposition",
        "Understanding entanglement",
    }
    summary_prompt := engineer.get_summary_prompt(steps)
}

// 示例 7: 验证推理
func example_validation() {
    config := new_default_cot_config()
    
    chain := new_reasoning_chain("validation_chain", "Validate reasoning", config)
    chain = chain.start()
    
    // 添加有效的步骤
    for i := 1; i <= 3; i = i + 1 {
        step := new_reasoning_step(i, i, step_type.analysis)
        step.reasoning = "Valid reasoning " + string(i)
        step.intermediate_result = "Valid result " + string(i)
        step.confidence = 0.9
        step.is_valid = true
        chain = chain.add_step(step)
    }
    
    chain = chain.complete("Final valid answer")
    
    // 验证
    validator := new_reasoning_validator(config)
    result := validator.validate_chain(chain)
    
    if result.is_valid {
        report := validator.generate_report(chain)
        // 输出验证报告
    }
}

// 导入必要的模块
use neurx.reasoning.reasoning_validator.new_reasoning_validator
use neurx.reasoning.cot_config.new_detailed_cot_config
