// Package: neurx.reasoning.cot_config
// 思维链配置管理模块
// 提供推理链的参数配置和验证

package neurx.reasoning.cot_config

// 推理风格枚举
enum reasoning_style {
    step_by_step    // 逐步推理
    detailed        // 详细推理
    summarized      // 摘要推理
    hierarchical    // 分层推理
}

// 验证策略枚举
enum validation_strategy {
    none           // 无验证
    consistency    // 一致性检查
    logical        // 逻辑检查
    semantic       // 语义检查
}

// 推理链配置结构体
struct cot_config {
    bool enabled                           // 是否启用思维链
    reasoning_style style                  // 推理风格
    int max_steps                          // 最大推理步数
    int max_tokens_per_step                // 每步最大 token 数
    int max_tokens_total                   // 总 token 数限制
    bool stream_intermediate               // 是否流式输出中间步骤
    bool include_reasoning_in_output       // 是否包含推理过程在输出中
    validation_strategy validation         // 验证策略
    bool auto_checkpoint                   // 是否自动检查点
    int checkpoint_interval                // 检查点间隔
    string system_prompt_template          // 系统提示模板
    string step_separator                  // 步骤分隔符
    bool enable_backtracking               // 是否启用回溯
    int backtrack_depth                    // 回溯深度
    bool enable_branching                  // 是否启用分支探索
    int max_branches                       // 最大分支数
    float confidence_threshold             // 置信度阈值
    bool summarize_at_end                  // 是否在末尾总结
}

// 创建默认配置
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

// 创建详细推理配置
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

// 创建快速推理配置
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

// 创建分层推理配置
func new_hierarchical_cot_config() cot_config {
    cfg := new_detailed_cot_config()
    cfg.style = reasoning_style.hierarchical
    cfg.enable_branching = true
    cfg.max_branches = 3
    cfg.enable_backtracking = true
    cfg.backtrack_depth = 2
    cfg
}

// 验证配置有效性
func (cfg: &cot_config) validate() bool {
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

// 获取推理风格字符串
func (cfg: &cot_config) get_style_string() string {
    match cfg.style {
        reasoning_style.step_by_step: "step-by-step",
        reasoning_style.detailed: "detailed",
        reasoning_style.summarized: "summarized",
        reasoning_style.hierarchical: "hierarchical",
        default: "unknown",
    }
}

// 获取验证策略字符串
func (cfg: &cot_config) get_validation_string() string {
    match cfg.validation {
        validation_strategy.none: "none",
        validation_strategy.consistency: "consistency",
        validation_strategy.logical: "logical",
        validation_strategy.semantic: "semantic",
        default: "unknown",
    }
}

// 调整最大步数
func (cfg: &cot_config) set_max_steps(int steps) cot_config {
    if steps > 0 {
        cfg.max_steps = steps
    }
    cfg
}

// 调整最大 token 数
func (cfg: &cot_config) set_max_tokens(int per_step, int total) cot_config {
    if per_step > 0 {
        cfg.max_tokens_per_step = per_step
    }
    if total > 0 {
        cfg.max_tokens_total = total
    }
    cfg
}

// 克隆配置
func (cfg: &cot_config) clone() cot_config {
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
