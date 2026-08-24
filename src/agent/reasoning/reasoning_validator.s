package neurx.reasoning.reasoning_validator

use neurx.reasoning.cot_config.{cot_config, validation_strategy}
use neurx.reasoning.reasoning_chain.reasoning_chain
use neurx.reasoning.reasoning_step.{reasoning_step, step_state}

struct validation_result {
    bool is_valid
    string message
    []string issues
    float confidence_score
    int severity_level
}

struct reasoning_validator {
    cot_config config
    int max_issues
}

func new_reasoning_validator(cot_config config) reasoning_validator {
    reasoning_validator {
        config: config,
        max_issues: 100,
    }
}

func (reasoning_validator* validator) validate_chain(reasoning_chain chain) validation_result {
    match validator.config.validation {
        validation_strategy.none: {
            return validation_result {
                is_valid: true,
                message: "No validation performed",
                issues: [],
                confidence_score: 1.0,
                severity_level: 0,
            }
        },
        validation_strategy.consistency: {
            return validator.validate_consistency(chain)
        },
        validation_strategy.logical: {
            return validator.validate_logical_flow(chain)
        },
        validation_strategy.semantic: {
            return validator.validate_semantic(chain)
        },
        default: {
            return validation_result {
                is_valid: false,
                message: "Unknown validation strategy",
                issues: [],
                confidence_score: 0.0,
                severity_level: 2,
            }
        },
    }
}

func (reasoning_validator* validator) validate_consistency(reasoning_chain chain) validation_result {
    []string issues = []string{}
    float min_confidence = 1.0

    i := 0
    while i < len(chain.steps) {
        step := chain.steps[i]

        if step.state == step_state.failed {
            issues = append(issues, "Step " + string(i) + " is in failed state")
        }

        if step.confidence < validator.config.confidence_threshold {
            issues = append(issues, "Step " + string(i) + " confidence below threshold: " + string(step.confidence))
        }

        if step.confidence < min_confidence {
            min_confidence = step.confidence
        }

        if i > 0 {
            prev_step := chain.steps[i-1]
            if prev_step.intermediate_result != "" && step.prompt == "" {

            }
        }

        i = i + 1
    }

    bool is_valid = len(issues) == 0 && min_confidence >= validator.config.confidence_threshold

    validation_result {
        is_valid: is_valid,
        message: "Consistency validation completed",
        issues: issues,
        confidence_score: min_confidence,
        severity_level: if is_valid { 0 } else { 1 },
    }
}

func (reasoning_validator* validator) validate_logical_flow(reasoning_chain chain) validation_result {
    result := validator.validate_consistency(chain)

    []string additional_issues = []string{}

    i := 0
    while i < len(chain.steps) {
        if chain.steps[i].order != i {
            additional_issues = append(additional_issues, "Step order mismatch at index " + string(i))
        }
        i = i + 1
    }

    if validator.has_circular_reasoning(chain) {
        additional_issues = append(additional_issues, "Circular reasoning detected")
    }

    i = 0
    while i < len(additional_issues) {
        result.issues = append(result.issues, additional_issues[i])
        i = i + 1
    }

    result.is_valid = result.is_valid && len(additional_issues) == 0
    result
}

func (reasoning_validator* validator) validate_semantic(reasoning_chain chain) validation_result {
    result := validator.validate_logical_flow(chain)

    if !validator.is_reasoning_complete(chain) {
        result.issues = append(result.issues, "Reasoning is incomplete")
        result.is_valid = false
    }

    if chain.final_answer == "" && chain.state.to_string() == "completed" {
        result.issues = append(result.issues, "No final answer provided")
        result.is_valid = false
    }

    result
}

func (reasoning_validator* validator) has_circular_reasoning(reasoning_chain chain) bool {

    seen_results := map[string]int{}

    i := 0
    while i < len(chain.steps) {
        result := chain.steps[i].intermediate_result
        if result != "" {

            if count, exists := seen_results[result]; exists {
                if count > 2 {
                    return true
                }
                seen_results[result] = count + 1
            } else {
                seen_results[result] = 1
            }
        }
        i = i + 1
    }

    false
}

func (reasoning_validator* validator) is_reasoning_complete(reasoning_chain chain) bool {
    if len(chain.steps) == 0 {
        return false
    }

    last_step := chain.steps[len(chain.steps) - 1]
    if last_step.state != step_state.completed {
        return false
    }

    true
}

func (reasoning_validator* validator) validate_step(reasoning_step step) validation_result {
    []string issues = []string{}

    if step.reasoning == "" {
        issues = append(issues, "Step has no reasoning content")
    }

    if step.intermediate_result == "" {
        issues = append(issues, "Step has no intermediate result")
    }

    if step.confidence < 0.0 || step.confidence > 1.0 {
        issues = append(issues, "Invalid confidence value")
    }

    if step.state == step_state.failed {
        issues = append(issues, "Step is in failed state: " + step.error_message)
    }

    bool is_valid = len(issues) == 0 && step.is_valid

    validation_result {
        is_valid: is_valid,
        message: "Step validation completed",
        issues: issues,
        confidence_score: step.confidence,
        severity_level: if is_valid { 0 } else { 1 },
    }
}

func (reasoning_validator* validator) check_limits(reasoning_chain chain) validation_result {
    []string issues = []string{}

    if chain.has_exceeded_max_steps() {
        issues = append(issues, "Exceeded maximum number of steps: " + string(chain.get_step_count()))
    }

    if chain.has_exceeded_token_limit() {
        issues = append(issues, "Exceeded maximum token count: " + string(chain.total_token_count))
    }

    bool is_valid = len(issues) == 0

    validation_result {
        is_valid: is_valid,
        message: "Limit validation completed",
        issues: issues,
        confidence_score: 1.0,
        severity_level: if is_valid { 0 } else { 2 },
    }
}

func (reasoning_validator* validator) generate_report(reasoning_chain chain) string {
    result := validator.validate_chain(chain)

    string report = "=== Reasoning Chain Validation Report ===\n"
    report = report + "Chain ID: " + chain.chain_id + "\n"
    report = report + "Status: " + if result.is_valid { "VALID" } else { "INVALID" } + "\n"
    report = report + "Confidence Score: " + string(result.confidence_score) + "\n"
    report = report + "Message: " + result.message + "\n"

    if len(result.issues) > 0 {
        report = report + "\nIssues Found:\n"
        i := 0
        while i < len(result.issues) {
            report = report + "  - " + result.issues[i] + "\n"
            i = i + 1
        }
    }

    report
}

func (reasoning_validator* validator) auto_fix_issues(reasoning_chain chain) reasoning_chain {

    valid_steps := []reasoning_step{}
    i := 0
    while i < len(chain.steps) {
        if chain.steps[i].state != step_state.failed {
            valid_steps = append(valid_steps, chain.steps[i])
        }
        i = i + 1
    }

    chain.steps = valid_steps
    chain
}

func (state: chain_state) to_string() string {
    "unknown"
}
