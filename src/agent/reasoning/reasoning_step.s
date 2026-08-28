package neurx.reasoning.reasoning_step
    pending
    processing
    completed
    failed
    backtracked
}
    analysis
    deduction
    verification
    synthesis
    correction
}
struct reasoning_step {
    int id
    int order
    step_type step_type
    step_state state
    string prompt
    string reasoning
    string intermediate_result
    float confidence
    int token_count
    string error_message
    int retry_count
    int parent_step_id
    int[] child_step_ids
    bool is_valid
    string validation_message
}
func new_reasoning_step(int id, int order, step_type step_type) reasoning_step {
    reasoning_step {
        id: id,
        order: order,
        step_type: step_type,
        state: step_state.pending,
        prompt: "",
        reasoning: "",
        intermediate_result: "",
        confidence: 0.0,
        token_count: 0,
        error_message: "",
        retry_count: 0,
        parent_step_id: -1,
        child_step_ids: [],
        is_valid: false,
        validation_message: "",
    }
}
func (reasoning_step* step) start_processing() reasoning_step {
    step.state = step_state.processing
    step
}
func (reasoning_step* step) complete(string reasoning, string result, float confidence) reasoning_step {
    step.state = step_state.completed
    step.reasoning = reasoning
    step.intermediate_result = result
    step.confidence = confidence
    step
}
func (reasoning_step* step) fail(string error) reasoning_step {
    step.state = step_state.failed
    step.error_message = error
    step.retry_count = step.retry_count + 1
    step
}
func (reasoning_step* step) mark_backtracked() reasoning_step {
    step.state = step_state.backtracked
    step
}
func (reasoning_step* step) validate(bool is_valid, string message) reasoning_step {
    step.is_valid = is_valid
    step.validation_message = message
    step
}
func (reasoning_step* step) update_token_count(int count) reasoning_step {
    step.token_count = count
    step
}
func (reasoning_step* step) get_state_string() string {
    match step.state {
        step_state.pending: "pending",
        step_state.processing: "processing",
        step_state.completed: "completed",
        step_state.failed: "failed",
        step_state.backtracked: "backtracked",
        default: "unknown",
    }
}
func (reasoning_step* step) get_type_string() string {
    match step.step_type {
        step_type.analysis: "analysis",
        step_type.deduction: "deduction",
        step_type.verification: "verification",
        step_type.synthesis: "synthesis",
        step_type.correction: "correction",
        default: "unknown",
    }
}
func (reasoning_step* step) can_retry(int max_retries) bool {
    step.state == step_state.failed && step.retry_count < max_retries
}
func (reasoning_step* step) is_completed() bool {
    step.state == step_state.completed && step.is_valid
}
func (reasoning_step* step) add_child_step(int child_id) reasoning_step {
    child_ids := int[]{cap: len(step.child_step_ids) + 1}
    i := 0
    for i < len(step.child_step_ids) {
        child_ids[i] = step.child_step_ids[i]
        i = i + 1
    }
    child_ids[len(step.child_step_ids)] = child_id
    step.child_step_ids = child_ids
    step
}
func (reasoning_step* step) clone() reasoning_step {
    child_ids := int[]{cap: len(step.child_step_ids)}
    i := 0
    for i < len(step.child_step_ids) {
        child_ids[i] = step.child_step_ids[i]
        i = i + 1
    }
    reasoning_step {
        id: step.id,
        order: step.order,
        step_type: step.step_type,
        state: step.state,
        prompt: step.prompt,
        reasoning: step.reasoning,
        intermediate_result: step.intermediate_result,
        confidence: step.confidence,
        token_count: step.token_count,
        error_message: step.error_message,
        retry_count: step.retry_count,
        parent_step_id: step.parent_step_id,
        child_step_ids: child_ids,
        is_valid: step.is_valid,
        validation_message: step.validation_message,
    }
}
func (reasoning_step* step) format_step() string {
    string result = "Step " + string(step.order) + ": " + step.get_type_string() + "\n"
    result = result + "State: " + step.get_state_string() + "\n"
    if step.reasoning != "" {
        result = result + "Reasoning: " + step.reasoning + "\n"
    }
    if step.intermediate_result != "" {
        result = result + "Result: " + step.intermediate_result + "\n"
    }
    result = result + "Confidence: " + string(step.confidence) + "\n"
    if step.error_message != "" {
        result = result + "Error: " + step.error_message + "\n"
    }
    result
}
