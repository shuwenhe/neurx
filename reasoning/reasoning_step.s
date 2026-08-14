// Package: neurx.reasoning.reasoning_step
// 推理步骤管理模块
// 定义和管理单个推理步骤的数据结构

package neurx.reasoning.reasoning_step

// 推理步骤状态
enum step_state {
    pending       // 待处理
    processing    // 处理中
    completed     // 已完成
    failed        // 失败
    backtracked   // 已回溯
}

// 步骤类型
enum step_type {
    analysis      // 分析
    deduction     // 演绎
    verification  // 验证
    synthesis     // 综合
    correction    // 纠正
}

// 推理步骤结构体
struct reasoning_step {
    int id                           // 步骤 ID
    int order                        // 步骤顺序
    step_type step_type              // 步骤类型
    step_state state                 // 步骤状态
    string prompt                    // 输入提示
    string reasoning                 // 推理过程
    string intermediate_result       // 中间结果
    float confidence                 // 置信度 (0-1)
    int token_count                  // Token 数量
    string error_message             // 错误信息
    int retry_count                  // 重试次数
    int parent_step_id               // 父步骤 ID (用于分支)
    []int child_step_ids             // 子步骤 ID (用于分支)
    bool is_valid                    // 是否有效
    string validation_message        // 验证信息
}

// 创建新的推理步骤
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

// 设置步骤为处理中
func (step: &reasoning_step) start_processing() reasoning_step {
    step.state = step_state.processing
    step
}

// 完成步骤处理
func (step: &reasoning_step) complete(string reasoning, string result, float confidence) reasoning_step {
    step.state = step_state.completed
    step.reasoning = reasoning
    step.intermediate_result = result
    step.confidence = confidence
    step
}

// 标记步骤失败
func (step: &reasoning_step) fail(string error) reasoning_step {
    step.state = step_state.failed
    step.error_message = error
    step.retry_count = step.retry_count + 1
    step
}

// 标记步骤为已回溯
func (step: &reasoning_step) mark_backtracked() reasoning_step {
    step.state = step_state.backtracked
    step
}

// 验证步骤
func (step: &reasoning_step) validate(bool is_valid, string message) reasoning_step {
    step.is_valid = is_valid
    step.validation_message = message
    step
}

// 更新 token 计数
func (step: &reasoning_step) update_token_count(int count) reasoning_step {
    step.token_count = count
    step
}

// 获取步骤状态字符串
func (step: &reasoning_step) get_state_string() string {
    match step.state {
        step_state.pending: "pending",
        step_state.processing: "processing",
        step_state.completed: "completed",
        step_state.failed: "failed",
        step_state.backtracked: "backtracked",
        default: "unknown",
    }
}

// 获取步骤类型字符串
func (step: &reasoning_step) get_type_string() string {
    match step.step_type {
        step_type.analysis: "analysis",
        step_type.deduction: "deduction",
        step_type.verification: "verification",
        step_type.synthesis: "synthesis",
        step_type.correction: "correction",
        default: "unknown",
    }
}

// 是否可以重试
func (step: &reasoning_step) can_retry(int max_retries) bool {
    step.state == step_state.failed && step.retry_count < max_retries
}

// 检查步骤是否完成
func (step: &reasoning_step) is_completed() bool {
    step.state == step_state.completed && step.is_valid
}

// 添加子步骤
func (step: &reasoning_step) add_child_step(int child_id) reasoning_step {
    child_ids := []int{cap: len(step.child_step_ids) + 1}
    i := 0
    while i < len(step.child_step_ids) {
        child_ids[i] = step.child_step_ids[i]
        i = i + 1
    }
    child_ids[len(step.child_step_ids)] = child_id
    step.child_step_ids = child_ids
    step
}

// 克隆步骤
func (step: &reasoning_step) clone() reasoning_step {
    child_ids := []int{cap: len(step.child_step_ids)}
    i := 0
    while i < len(step.child_step_ids) {
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

// 格式化步骤信息
func (step: &reasoning_step) format_step() string {
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
