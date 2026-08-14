// Package: neurx.reasoning.reasoning_chain
// 推理链核心实现模块
// 管理整个推理链的生命周期和状态

package neurx.reasoning.reasoning_chain

use neurx.reasoning.cot_config.{cot_config, reasoning_style, validation_strategy}
use neurx.reasoning.reasoning_step.{reasoning_step, step_type, step_state}

// 推理链状态
enum chain_state {
    initialized    // 已初始化
    running        // 运行中
    completed      // 已完成
    failed         // 失败
    cancelled      // 已取消
}

// 推理链结构体
struct reasoning_chain {
    string chain_id                      // 链 ID
    cot_config config                    // 配置
    chain_state state                    // 链状态
    []reasoning_step steps               // 推理步骤列表
    int current_step_index               // 当前步骤索引
    string original_prompt               // 原始提示
    string final_answer                  // 最终答案
    int total_token_count                // 总 token 数
    float overall_confidence             // 整体置信度
    string error_message                 // 错误信息
    string execution_summary             // 执行摘要
}

// 创建新的推理链
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

// 添加推理步骤
func (chain: &reasoning_chain) add_step(reasoning_step step) reasoning_chain {
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

// 启动推理链
func (chain: &reasoning_chain) start() reasoning_chain {
    if chain.state != chain_state.initialized {
        chain.error_message = "Chain is not in initialized state"
        return chain
    }
    chain.state = chain_state.running
    chain.current_step_index = 0
    chain
}

// 完成推理链
func (chain: &reasoning_chain) complete(string answer) reasoning_chain {
    chain.state = chain_state.completed
    chain.final_answer = answer
    chain.overall_confidence = chain.calculate_overall_confidence()
    chain
}

// 标记推理链失败
func (chain: &reasoning_chain) fail(string error) reasoning_chain {
    chain.state = chain_state.failed
    chain.error_message = error
    chain
}

// 取消推理链
func (chain: &reasoning_chain) cancel() reasoning_chain {
    chain.state = chain_state.cancelled
    chain
}

// 获取步骤数
func (chain: &reasoning_chain) get_step_count() int {
    len(chain.steps)
}

// 获取当前步骤
func (chain: &reasoning_chain) get_current_step() reasoning_step {
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

// 移到下一步
func (chain: &reasoning_chain) next_step() reasoning_chain {
    if chain.current_step_index + 1 < len(chain.steps) {
        chain.current_step_index = chain.current_step_index + 1
    }
    chain
}

// 获取推理链状态字符串
func (chain: &reasoning_chain) get_state_string() string {
    match chain.state {
        chain_state.initialized: "initialized",
        chain_state.running: "running",
        chain_state.completed: "completed",
        chain_state.failed: "failed",
        chain_state.cancelled: "cancelled",
        default: "unknown",
    }
}

// 是否完成
func (chain: &reasoning_chain) is_completed() bool {
    chain.state == chain_state.completed
}

// 是否失败
func (chain: &reasoning_chain) is_failed() bool {
    chain.state == chain_state.failed
}

// 计算整体置信度
func (chain: &reasoning_chain) calculate_overall_confidence() float {
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

// 检查是否超过步骤限制
func (chain: &reasoning_chain) has_exceeded_max_steps() bool {
    len(chain.steps) >= chain.config.max_steps
}

// 检查是否超过 token 限制
func (chain: &reasoning_chain) has_exceeded_token_limit() bool {
    chain.total_token_count >= chain.config.max_tokens_total
}

// 更新总 token 计数
func (chain: &reasoning_chain) update_token_count(int count) reasoning_chain {
    chain.total_token_count = chain.total_token_count + count
    chain
}

// 支持回溯
func (chain: &reasoning_chain) can_backtrack() bool {
    chain.config.enable_backtracking && chain.current_step_index > 0
}

// 执行回溯
func (chain: &reasoning_chain) backtrack(int depth) reasoning_chain {
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

// 支持分支
func (chain: &reasoning_chain) can_branch() bool {
    chain.config.enable_branching
}

// 获取推理过程文本
func (chain: &reasoning_chain) get_reasoning_text() string {
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

// 克隆推理链
func (chain: &reasoning_chain) clone() reasoning_chain {
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
