package neurx.reasoning.tests.reasoning_tests

use neurx.reasoning.cot_config.{new_default_cot_config, new_fast_cot_config, validation_strategy}
use neurx.reasoning.reasoning_chain.{new_reasoning_chain, chain_state}
use neurx.reasoning.reasoning_step.{new_reasoning_step, step_type, step_state}
use neurx.reasoning.reasoning_manager.new_reasoning_manager
use neurx.reasoning.prompt_engineer.new_prompt_engineer
use neurx.reasoning.reasoning_validator.new_reasoning_validator

struct test_result {
    string test_name
    bool passed
    string error_message
    int assertions_passed
    int assertions_failed
}

struct test_logger {
    []test_result results
}

func new_test_logger() test_logger {
    test_logger {
        results: []test_result{},
    }
}

func (logger: &test_logger) add_result(test_result result) {
    logger.results = append(logger.results, result)
}

func (logger: &test_logger) get_summary() string {
    passed := 0
    failed := 0

    for _, result := range logger.results {
        if result.passed {
            passed = passed + 1
        } else {
            failed = failed + 1
        }
    }

    string summary = "=== Test Summary ===\n"
    summary = summary + "Total: " + string(len(logger.results)) + "\n"
    summary = summary + "Passed: " + string(passed) + "\n"
    summary = summary + "Failed: " + string(failed) + "\n"
    summary
}

func test_config_creation(test_logger logger) test_result {
    test_name := "Config Creation and Validation"

    config := new_default_cot_config()

    if !config.validate() {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Default config validation failed",
            assertions_passed: 0,
            assertions_failed: 1,
        }
    }

    cloned := config.clone()
    if cloned.max_steps != config.max_steps {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Config cloning failed",
            assertions_passed: 1,
            assertions_failed: 1,
        }
    }

    return test_result{
        test_name: test_name,
        passed: true,
        error_message: "",
        assertions_passed: 2,
        assertions_failed: 0,
    }
}

func test_step_creation(test_logger logger) test_result {
    test_name := "Reasoning Step Creation"

    step := new_reasoning_step(1, 1, step_type.analysis)

    if step.id != 1 || step.order != 1 {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Step creation failed",
            assertions_passed: 0,
            assertions_failed: 1,
        }
    }

    step = step.start_processing()
    if step.state != step_state.processing {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Step state transition failed",
            assertions_passed: 1,
            assertions_failed: 1,
        }
    }

    step = step.complete("Reasoning content", "Result", 0.9)
    if step.state != step_state.completed || step.confidence != 0.9 {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Step completion failed",
            assertions_passed: 2,
            assertions_failed: 1,
        }
    }

    return test_result{
        test_name: test_name,
        passed: true,
        error_message: "",
        assertions_passed: 3,
        assertions_failed: 0,
    }
}

func test_chain_creation(test_logger logger) test_result {
    test_name := "Reasoning Chain Creation"

    config := new_default_cot_config()
    chain := new_reasoning_chain("test_chain", "Test prompt", config)

    if chain.chain_id != "test_chain" {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Chain ID mismatch",
            assertions_passed: 0,
            assertions_failed: 1,
        }
    }

    chain = chain.start()
    if chain.state != chain_state.running {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Chain startup failed",
            assertions_passed: 1,
            assertions_failed: 1,
        }
    }

    step := new_reasoning_step(1, 1, step_type.analysis)
    step = step.complete("Reasoning", "Result", 0.85)
    chain = chain.add_step(step)

    if chain.get_step_count() != 1 {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Step addition failed",
            assertions_passed: 2,
            assertions_failed: 1,
        }
    }

    return test_result{
        test_name: test_name,
        passed: true,
        error_message: "",
        assertions_passed: 3,
        assertions_failed: 0,
    }
}

func test_confidence_calculation(test_logger logger) test_result {
    test_name := "Confidence Calculation"

    config := new_default_cot_config()
    chain := new_reasoning_chain("conf_test", "Test", config)
    chain = chain.start()

    confidences := []float{0.9, 0.8, 0.95}

    for i := 0; i < len(confidences); i = i + 1 {
        step := new_reasoning_step(i+1, i+1, step_type.analysis)
        step = step.complete("Reasoning", "Result", confidences[i])
        step.is_valid = true
        chain = chain.add_step(step)
    }

    chain = chain.complete("Final answer")

    expected := (0.9 + 0.8 + 0.95) / 3.0
    if chain.overall_confidence < expected - 0.01 || chain.overall_confidence > expected + 0.01 {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Confidence calculation mismatch",
            assertions_passed: 0,
            assertions_failed: 1,
        }
    }

    return test_result{
        test_name: test_name,
        passed: true,
        error_message: "",
        assertions_passed: 1,
        assertions_failed: 0,
    }
}

func test_validator(test_logger logger) test_result {
    test_name := "Chain Validator"

    config := new_default_cot_config()
    config.validation = validation_strategy.consistency

    chain := new_reasoning_chain("val_test", "Test", config)
    chain = chain.start()

    step := new_reasoning_step(1, 1, step_type.analysis)
    step = step.complete("Good reasoning", "Good result", 0.95)
    step.is_valid = true
    chain = chain.add_step(step)

    chain = chain.complete("Final answer")

    validator := new_reasoning_validator(config)
    result := validator.validate_chain(chain)

    if !result.is_valid {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Valid chain failed validation",
            assertions_passed: 0,
            assertions_failed: 1,
        }
    }

    return test_result{
        test_name: test_name,
        passed: true,
        error_message: "",
        assertions_passed: 1,
        assertions_failed: 0,
    }
}

func test_manager(test_logger logger) test_result {
    test_name := "Reasoning Manager"

    config := new_default_cot_config()
    manager := new_reasoning_manager(config)

    chain := manager.start_reasoning_chain("Manager test", config)
    if chain.chain_id == "" {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Chain creation in manager failed",
            assertions_passed: 0,
            assertions_failed: 1,
        }
    }

    step := new_reasoning_step(1, 1, step_type.analysis)
    step = step.complete("Test reasoning", "Test result", 0.8)

    success := manager.add_reasoning_step(chain.chain_id, step)
    if !success {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Step addition through manager failed",
            assertions_passed: 1,
            assertions_failed: 1,
        }
    }

    success = manager.complete_reasoning_chain(chain.chain_id, "Final answer")
    if !success {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Chain completion through manager failed",
            assertions_passed: 2,
            assertions_failed: 1,
        }
    }

    return test_result{
        test_name: test_name,
        passed: true,
        error_message: "",
        assertions_passed: 3,
        assertions_failed: 0,
    }
}

func test_backtracking(test_logger logger) test_result {
    test_name := "Backtracking"

    config := new_default_cot_config()
    config.enable_backtracking = true
    config.backtrack_depth = 2

    chain := new_reasoning_chain("backtrack_test", "Test", config)
    chain = chain.start()

    for i := 1; i <= 5; i = i + 1 {
        step := new_reasoning_step(i, i, step_type.analysis)
        step = step.complete("Reasoning " + string(i), "Result " + string(i), 0.8)
        chain = chain.add_step(step)
    }

    if chain.current_step_index != 0 {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Initial step index wrong",
            assertions_passed: 0,
            assertions_failed: 1,
        }
    }

    for i := 0; i < 4; i = i + 1 {
        chain = chain.next_step()
    }

    if chain.current_step_index != 4 {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Navigation failed",
            assertions_passed: 1,
            assertions_failed: 1,
        }
    }

    chain = chain.backtrack(2)
    if chain.current_step_index != 2 {
        return test_result{
            test_name: test_name,
            passed: false,
            error_message: "Backtrack failed",
            assertions_passed: 2,
            assertions_failed: 1,
        }
    }

    return test_result{
        test_name: test_name,
        passed: true,
        error_message: "",
        assertions_passed: 3,
        assertions_failed: 0,
    }
}

func run_all_tests() test_logger {
    logger := new_test_logger()

    logger.add_result(test_config_creation(logger))
    logger.add_result(test_step_creation(logger))
    logger.add_result(test_chain_creation(logger))
    logger.add_result(test_confidence_calculation(logger))
    logger.add_result(test_validator(logger))
    logger.add_result(test_manager(logger))
    logger.add_result(test_backtracking(logger))

    logger
}

func print_results(test_logger logger) {
    for _, result := range logger.results {
        string status = if result.passed { "✓ PASS" } else { "✗ FAIL" }

    }
}
