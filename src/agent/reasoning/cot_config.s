package neurx.reasoning.cot_config
    step_by_step
    detailed
    summarized
    hierarchical
}
    none
    consistency
    logical
    semantic
}

struct cot_config {
    bool enabled
    reasoning_style style
    int max_steps
    int max_tokens_per_step
    int max_tokens_total
    bool stream_intermediate
    bool include_reasoning_in_output
    validation_strategy validation
    bool auto_checkpoint
    int checkpoint_interval
    string system_prompt_template
    string step_separator
    bool enable_backtracking
    int backtrack_depth
    bool enable_branching
    int max_branches
    float confidence_threshold
    bool summarize_at_end
}

func new_default_cot_config() cot_config {
    cot_config {
        enabled: true,
        style: reasoning_style.step_by_step,
        max_steps: 20,
        max_tokens_per_step: 500,
        max_tokens_total: 4000,
        stream_intermediate: false,
        include_reasoning_in_output: true,
        validation: validation_strategy.consistency,
        auto_checkpoint: true,
        checkpoint_interval: 5,
        system_prompt_template: "Let's think step by step.\n",
        step_separator: "\nStep ",
        enable_backtracking: false,
        backtrack_depth: 3,
        enable_branching: false,
        max_branches: 3,
        confidence_threshold: 0.7,
        summarize_at_end: true,
    }
}

func new_detailed_cot_config() cot_config {
    cfg := new_default_cot_config()
    cfg.style = reasoning_style.detailed
    cfg.max_steps = 30
    cfg.max_tokens_per_step = 1000
    cfg.max_tokens_total = 8000
    cfg.include_reasoning_in_output = true
    cfg.validation = validation_strategy.semantic
    cfg
}

func new_fast_cot_config() cot_config {
    cfg := new_default_cot_config()
    cfg.style = reasoning_style.summarized
    cfg.max_steps = 10
    cfg.max_tokens_per_step = 200
    cfg.max_tokens_total = 2000
    cfg.include_reasoning_in_output = false
    cfg.validation = validation_strategy.none
    cfg
}

func new_hierarchical_cot_config() cot_config {
    cfg := new_detailed_cot_config()
    cfg.style = reasoning_style.hierarchical
    cfg.enable_branching = true
    cfg.max_branches = 3
    cfg.enable_backtracking = true
    cfg.backtrack_depth = 2
    cfg
}

func (cot_config* cfg) validate() bool {
    if cfg.max_steps <= 0 {
        return false
    }
    if cfg.max_tokens_per_step <= 0 {
        return false
    }
    if cfg.max_tokens_total <= 0 {
        return false
    }
    if cfg.max_tokens_total < cfg.max_tokens_per_step {
        return false
    }
    if cfg.confidence_threshold < 0.0 || cfg.confidence_threshold > 1.0 {
        return false
    }
    if cfg.enable_branching && cfg.max_branches <= 0 {
        return false
    }
    if cfg.enable_backtracking && cfg.backtrack_depth <= 0 {
        return false
    }
    true
}

func (cot_config* cfg) get_style_string() string {
    match cfg.style {
        reasoning_style.step_by_step: "step-by-step",
        reasoning_style.detailed: "detailed",
        reasoning_style.summarized: "summarized",
        reasoning_style.hierarchical: "hierarchical",
        default: "unknown",
    }
}

func (cot_config* cfg) get_validation_string() string {
    match cfg.validation {
        validation_strategy.none: "none",
        validation_strategy.consistency: "consistency",
        validation_strategy.logical: "logical",
        validation_strategy.semantic: "semantic",
        default: "unknown",
    }
}

func (cot_config* cfg) set_max_steps(int steps) cot_config {
    if steps > 0 {
        cfg.max_steps = steps
    }
    cfg
}

func (cot_config* cfg) set_max_tokens(int per_step, int total) cot_config {
    if per_step > 0 {
        cfg.max_tokens_per_step = per_step
    }
    if total > 0 {
        cfg.max_tokens_total = total
    }
    cfg
}

func (cot_config* cfg) clone() cot_config {
    cot_config {
        enabled: cfg.enabled,
        style: cfg.style,
        max_steps: cfg.max_steps,
        max_tokens_per_step: cfg.max_tokens_per_step,
        max_tokens_total: cfg.max_tokens_total,
        stream_intermediate: cfg.stream_intermediate,
        include_reasoning_in_output: cfg.include_reasoning_in_output,
        validation: cfg.validation,
        auto_checkpoint: cfg.auto_checkpoint,
        checkpoint_interval: cfg.checkpoint_interval,
        system_prompt_template: cfg.system_prompt_template,
        step_separator: cfg.step_separator,
        enable_backtracking: cfg.enable_backtracking,
        backtrack_depth: cfg.backtrack_depth,
        enable_branching: cfg.enable_branching,
        max_branches: cfg.max_branches,
        confidence_threshold: cfg.confidence_threshold,
        summarize_at_end: cfg.summarize_at_end,
    }
}
