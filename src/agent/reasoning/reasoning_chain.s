package neurx.reasoning.reasoning_chain

use neurx.reasoning.cot_config.{cot_config, reasoning_style, validation_strategy}
use neurx.reasoning.reasoning_step.{reasoning_step, step_type, step_state}

enum chain_state {
    initialized
    running
    completed
    failed
    cancelled
}

struct reasoning_chain {
    string chain_id
    cot_config config
    chain_state state
    []reasoning_step steps
    int current_step_index
    string original_prompt
    string final_answer
    int total_token_count
    float overall_confidence
    string error_message
    string execution_summary
}

func new_reasoning_chain(string chain_id, string prompt, cot_config config) reasoning_chain {
    reasoning_chain {
        chain_id: chain_id,
        config: config,
        state: chain_state.initialized,
        steps: [],
        current_step_index: 0,
        original_prompt: prompt,
        final_answer: "",
        total_token_count: 0,
        overall_confidence: 0.0,
        error_message: "",
        execution_summary: "",
    }
}

func (reasoning_chain* chain) add_step(reasoning_step step) reasoning_chain {
    if chain.state != chain_state.running && chain.state != chain_state.initialized {
        return chain
    }

    steps := []reasoning_step{cap: len(chain.steps) + 1}
    i := 0
    while i < len(chain.steps) {
        steps[i] = chain.steps[i]
        i = i + 1
    }
    steps[len(chain.steps)] = step

    chain.steps = steps
    chain
}

func (reasoning_chain* chain) start() reasoning_chain {
    if chain.state != chain_state.initialized {
        chain.error_message = "Chain is not in initialized state"
        return chain
    }
    chain.state = chain_state.running
    chain.current_step_index = 0
    chain
}

func (reasoning_chain* chain) complete(string answer) reasoning_chain {
    chain.state = chain_state.completed
    chain.final_answer = answer
    chain.overall_confidence = chain.calculate_overall_confidence()
    chain
}

func (reasoning_chain* chain) fail(string error) reasoning_chain {
    chain.state = chain_state.failed
    chain.error_message = error
    chain
}

func (reasoning_chain* chain) cancel() reasoning_chain {
    chain.state = chain_state.cancelled
    chain
}

func (reasoning_chain* chain) get_step_count() int {
    len(chain.steps)
}

func (reasoning_chain* chain) get_current_step() reasoning_step {
    if chain.current_step_index >= 0 && chain.current_step_index < len(chain.steps) {
        return chain.steps[chain.current_step_index]
    }
    reasoning_step {
        id: -1,
        order: -1,
        step_type: step_type.analysis,
        state: step_state.failed,
        prompt: "",
        reasoning: "",
        intermediate_result: "",
        confidence: 0.0,
        token_count: 0,
        error_message: "No current step",
        retry_count: 0,
        parent_step_id: -1,
        child_step_ids: [],
        is_valid: false,
        validation_message: "",
    }
}

func (reasoning_chain* chain) next_step() reasoning_chain {
    if chain.current_step_index + 1 < len(chain.steps) {
        chain.current_step_index = chain.current_step_index + 1
    }
    chain
}

func (reasoning_chain* chain) get_state_string() string {
    match chain.state {
        chain_state.initialized: "initialized",
        chain_state.running: "running",
        chain_state.completed: "completed",
        chain_state.failed: "failed",
        chain_state.cancelled: "cancelled",
        default: "unknown",
    }
}

func (reasoning_chain* chain) is_completed() bool {
    chain.state == chain_state.completed
}

func (reasoning_chain* chain) is_failed() bool {
    chain.state == chain_state.failed
}

func (reasoning_chain* chain) calculate_overall_confidence() float {
    if len(chain.steps) == 0 {
        return 0.0
    }

    float sum = 0.0
    i := 0
    while i < len(chain.steps) {
        if chain.steps[i].is_valid {
            sum = sum + chain.steps[i].confidence
        }
        i = i + 1
    }

    sum / float(len(chain.steps))
}

func (reasoning_chain* chain) has_exceeded_max_steps() bool {
    len(chain.steps) >= chain.config.max_steps
}

func (reasoning_chain* chain) has_exceeded_token_limit() bool {
    chain.total_token_count >= chain.config.max_tokens_total
}

func (reasoning_chain* chain) update_token_count(int count) reasoning_chain {
    chain.total_token_count = chain.total_token_count + count
    chain
}

func (reasoning_chain* chain) can_backtrack() bool {
    chain.config.enable_backtracking && chain.current_step_index > 0
}

func (reasoning_chain* chain) backtrack(int depth) reasoning_chain {
    if !chain.can_backtrack() {
        return chain
    }

    int target = chain.current_step_index - depth
    if target < 0 {
        target = 0
    }

    i := target
    while i < len(chain.steps) {
        if chain.steps[i].state != step_state.backtracked {
            chain.steps[i] = chain.steps[i].mark_backtracked()
        }
        i = i + 1
    }

    chain.current_step_index = target
    chain
}

func (reasoning_chain* chain) can_branch() bool {
    chain.config.enable_branching
}

func (reasoning_chain* chain) get_reasoning_text() string {
    string text = "# Reasoning Chain: " + chain.chain_id + "\n"
    text = text + "Original Prompt: " + chain.original_prompt + "\n\n"

    i := 0
    while i < len(chain.steps) {
        text = text + chain.steps[i].format_step() + "\n"
        i = i + 1
    }

    text = text + "\n# Final Answer\n"
    text = text + chain.final_answer + "\n"
    text = text + "Overall Confidence: " + string(chain.overall_confidence) + "\n"

    text
}

func (reasoning_chain* chain) clone() reasoning_chain {
    steps := []reasoning_step{cap: len(chain.steps)}
    i := 0
    while i < len(chain.steps) {
        steps[i] = chain.steps[i].clone()
        i = i + 1
    }

    reasoning_chain {
        chain_id: chain.chain_id,
        config: chain.config.clone(),
        state: chain.state,
        steps: steps,
        current_step_index: chain.current_step_index,
        original_prompt: chain.original_prompt,
        final_answer: chain.final_answer,
        total_token_count: chain.total_token_count,
        overall_confidence: chain.overall_confidence,
        error_message: chain.error_message,
        execution_summary: chain.execution_summary,
    }
}
