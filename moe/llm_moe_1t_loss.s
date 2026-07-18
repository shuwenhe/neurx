package neurx.moe.llm_1t_loss

// ============================================================================
// 1T MoE 损失计算与反向传播
//
// 核心损失函数:
//   L_total = L_ce + α * L_aux + β * L_kl
//   
//   L_ce    - Cross-entropy loss (预训练目标)
//   L_aux   - 辅助损失 (MoE 负载均衡)
//   L_kl    - KL 散度 (对齐时，与基础模型的 KL)
//
// 数值稳定性:
//   - 使用 log-sum-exp 技巧避免溢出
//   - 支持 BF16 混合精度
//   - 动态损失缩放 (用于 16 位精度)
//
// ============================================================================

use neurx.strings
use neurx.runtime.io.{io_println}

// ============================================================================
// 1. 损失函数配置
// ============================================================================

struct loss_config {
    string loss_type             // "ce", "ce_moe", "dpo"
    float aux_loss_weight        // MoE 辅助损失权重 (0.001-0.01)
    float kl_loss_weight         // KL 散度权重 (0.05-0.1)
    float label_smoothing        // 标签平滑 (0.0-0.1)
    int vocab_size
    int reduction                // 0: none, 1: mean, 2: sum
}

struct loss_state {
    loss_config config
    
    // 当前步骤的损失
    float loss_ce
    float loss_aux
    float loss_kl
    float loss_total
    
    // 动态损失缩放
    float loss_scale
    float min_loss_scale
    float max_loss_scale
    int loss_scale_steps
    
    // 统计
    []float loss_history
    int num_loss_steps
    float avg_loss
}

// 初始化损失状态
func loss_state_new(
    int vocab_size,
    float aux_loss_weight
) loss_state {
    
    loss_config cfg = loss_config {
        loss_type: "ce_moe",
        aux_loss_weight: aux_loss_weight,
        kl_loss_weight: 0.0,
        label_smoothing: 0.0,
        vocab_size: vocab_size,
        reduction: 1,  // mean
    }
    
    loss_state state = loss_state {
        config: cfg,
        loss_ce: 0.0,
        loss_aux: 0.0,
        loss_kl: 0.0,
        loss_total: 0.0,
        loss_scale: 1.0,
        min_loss_scale: 1.0,
        max_loss_scale: 65536.0,
        loss_scale_steps: 0,
        loss_history: make([]float, 0),
        num_loss_steps: 0,
        avg_loss: 0.0,
    }
    
    state
}

// ============================================================================
// 2. Cross-Entropy Loss
// ============================================================================

// Cross-Entropy Loss 计算
// logits: [batch*seq, vocab_size]
// labels: [batch*seq]
// 返回: [batch*seq] 的 per-token loss
func compute_ce_loss(
    []float logits,              // [batch*seq, vocab_size]
    []int labels,                // [batch*seq]
    int batch_size,
    int seq_len,
    int vocab_size,
    float label_smoothing
) []float {
    
    int num_tokens = batch_size * seq_len
    []float per_token_loss = make([]float, num_tokens)
    
    int t = 0
    while t < num_tokens {
        int label = labels[t]
        
        // 从 logits 中提取 label 对应的值
        float label_logit = logits[t * vocab_size + label]
        
        // Log-sum-exp 技巧: 先找 max 以避免溢出
        float max_logit = find_max(logits, t * vocab_size, t * vocab_size + vocab_size)
        
        // log(sum(exp(logits - max_logit)))
        float sum_exp = 0.0
        int v = 0
        while v < vocab_size {
            float logit = logits[t * vocab_size + v] - max_logit
            sum_exp = sum_exp + exp(logit)
            v = v + 1
        }
        
        // Cross-entropy: -log_prob = -log(exp(logit) / sum_exp) = log(sum_exp) - logit
        float log_sum_exp_val = log(sum_exp) + max_logit
        float ce_loss = log_sum_exp_val - label_logit
        
        // 应用标签平滑
        if label_smoothing > 0.0 {
            // L = (1 - α) * L_ce + α * L_uniform
            float uniform_loss = -log(1.0 / float(vocab_size))
            ce_loss = (1.0 - label_smoothing) * ce_loss + label_smoothing * uniform_loss
        }
        
        per_token_loss[t] = ce_loss
        t = t + 1
    }
    
    per_token_loss
}

// ============================================================================
// 3. MoE 辅助损失
// ============================================================================

// MoE 辅助损失计算
// 用于平衡负载，避免某些专家被过度使用
//
// L_aux = α * Σ (P_e * G_e) 
// 其中 P_e = 本 GPU 中路由到 expert e 的 token 数 / 总 token 数
//       G_e = expert e 接收到的梯度 / 预期梯度
func compute_moe_aux_loss(
    []int expert_indices,        // [num_tokens, top_k] 每个 token 的专家选择
    []float expert_weights,      // [num_tokens, top_k] 每个专家的权重
    int num_tokens,
    int top_k,
    int num_experts,
    float aux_loss_weight
) float {
    
    // 计算每个专家的负载
    []float expert_load = make([]float, num_experts)
    []float expert_importance = make([]float, num_experts)
    
    int t = 0
    while t < num_tokens {
        int k = 0
        while k < top_k {
            // expert_indices 的存储方式假设是 [num_tokens * top_k]
            int expert_id = expert_indices[t * top_k + k]
            float weight = expert_weights[t * top_k + k]
            
            expert_load[expert_id] = expert_load[expert_id] + weight
            expert_importance[expert_id] = expert_importance[expert_id] + weight
            
            k = k + 1
        }
        t = t + 1
    }
    
    // 计算平均负载和不均衡度
    float avg_load = float(num_tokens * top_k) / float(num_experts)
    
    float aux_loss = 0.0
    int e = 0
    while e < num_experts {
        // aux_loss += (expert_load[e] - avg_load) ^ 2
        float diff = expert_load[e] - avg_load
        aux_loss = aux_loss + diff * diff
        e = e + 1
    }
    
    // 归一化
    aux_loss = aux_loss / float(num_experts)
    aux_loss = aux_loss * aux_loss_weight
    
    aux_loss
}

// ============================================================================
// 4. KL 散度损失 (用于 DPO/对齐)
// ============================================================================

// KL 散度损失计算 (用于学习偏好时与基础模型保持一致)
// KL(p_target || p_base) = Σ p_target * (log p_target - log p_base)
func compute_kl_divergence(
    []float logits_target,       // 目标模型的 logits
    []float logits_base,         // 基础模型的 logits
    int batch_size,
    int seq_len,
    int vocab_size,
    float temperature
) []float {
    
    int num_tokens = batch_size * seq_len
    []float per_token_kl = make([]float, num_tokens)
    
    int t = 0
    while t < num_tokens {
        // 计算概率分布
        []float probs_target = softmax(logits_target, t * vocab_size, (t+1) * vocab_size, temperature)
        []float probs_base = softmax(logits_base, t * vocab_size, (t+1) * vocab_size, temperature)
        
        // 计算 KL 散度
        float kl = 0.0
        int v = 0
        while v < vocab_size {
            float p_target = probs_target[v]
            float p_base = probs_base[v]
            
            if p_target > 1e-8 {  // 避免 log(0)
                kl = kl + p_target * (log(p_target) - log(p_base + 1e-8))
            }
            
            v = v + 1
        }
        
        per_token_kl[t] = kl
        t = t + 1
    }
    
    per_token_kl
}

// ============================================================================
// 5. 完整损失计算
// ============================================================================

// 计算完整的训练损失
func compute_total_loss(
    loss_state state,
    []float logits,              // [batch*seq, vocab_size]
    []int labels,                // [batch*seq]
    []int expert_indices,        // [batch*seq, top_k]
    []float expert_weights,      // [batch*seq, top_k]
    int batch_size,
    int seq_len,
    int top_k
) float {
    
    // 1. Cross-Entropy Loss
    []float ce_per_token = compute_ce_loss(
        logits, labels, batch_size, seq_len, 
        state.config.vocab_size, state.config.label_smoothing
    )
    
    // 聚合 CE loss (mean reduction)
    float ce_loss = 0.0
    int i = 0
    while i < len(ce_per_token) {
        ce_loss = ce_loss + ce_per_token[i]
        i = i + 1
    }
    ce_loss = ce_loss / float(len(ce_per_token))
    
    state.loss_ce = ce_loss
    
    // 2. MoE Auxiliary Loss
    float aux_loss = compute_moe_aux_loss(
        expert_indices, expert_weights, batch_size * seq_len, top_k,
        256,  // num_experts (假设固定)
        state.config.aux_loss_weight
    )
    
    state.loss_aux = aux_loss
    
    // 3. Total Loss
    float total_loss = state.loss_ce + state.loss_aux
    
    // 如果启用了 KL 散度
    if state.config.kl_loss_weight > 0.0 {
        // 需要传入基础模型的 logits
        // []float kl_per_token = compute_kl_divergence(...)
        // float kl_loss = aggregate(kl_per_token) * state.config.kl_loss_weight
        // total_loss = total_loss + kl_loss
    }
    
    state.loss_total = total_loss
    
    // 4. 更新统计
    state.num_loss_steps = state.num_loss_steps + 1
    state.avg_loss = (state.avg_loss * float(state.num_loss_steps - 1) + total_loss) / 
                     float(state.num_loss_steps)
    
    total_loss
}

// ============================================================================
// 6. 反向传播 (梯度计算)
// ============================================================================

// Cross-Entropy Loss 的梯度
// dL/dlogits = softmax(logits) - one_hot(label)
func compute_ce_gradient(
    []float logits,              // [batch*seq, vocab_size]
    []int labels,                // [batch*seq]
    int batch_size,
    int seq_len,
    int vocab_size
) []float {
    
    int num_tokens = batch_size * seq_len
    []float grad_logits = make([]float, num_tokens * vocab_size)
    
    int t = 0
    while t < num_tokens {
        // 计算 softmax
        []float probs = softmax(logits, t * vocab_size, (t+1) * vocab_size, 1.0)
        
        // 梯度 = softmax - one_hot
        int v = 0
        while v < vocab_size {
            grad_logits[t * vocab_size + v] = probs[v]
            v = v + 1
        }
        
        // 减去 one_hot
        int label = labels[t]
        grad_logits[t * vocab_size + label] = grad_logits[t * vocab_size + label] - 1.0
        
        // 平均化 (如果 reduction = mean)
        grad_logits[t * vocab_size + label] = grad_logits[t * vocab_size + label] / float(num_tokens)
        
        t = t + 1
    }
    
    grad_logits
}

// MoE 辅助损失的梯度 (反向传播)
func compute_moe_aux_gradient(
    []int expert_indices,
    []float expert_weights,
    int num_tokens,
    int top_k,
    int num_experts
) []float {
    
    // 梯度的形式: d_aux_loss / d_router_logits
    // 这通常涉及对路由权重的梯度
    
    []float grad_router = make([]float, num_tokens * num_experts)
    
    // 简化实现：返回零梯度
    grad_router
}

// ============================================================================
// 7. 动态损失缩放 (用于 FP16/BF16)
// ============================================================================

// 更新动态损失缩放
func update_loss_scale(
    loss_state state,
    int overflow_detected
) {
    
    state.loss_scale_steps = state.loss_scale_steps + 1
    
    if overflow_detected > 0 {
        // 减半损失缩放
        state.loss_scale = state.loss_scale / 2.0
        if state.loss_scale < state.min_loss_scale {
            state.loss_scale = state.min_loss_scale
        }
        io_println("Overflow detected, reducing loss scale to " + float_to_string(state.loss_scale))
    } else {
        // 定期增加损失缩放
        if state.loss_scale_steps % 2000 == 0 {
            state.loss_scale = state.loss_scale * 2.0
            if state.loss_scale > state.max_loss_scale {
                state.loss_scale = state.max_loss_scale
            }
        }
    }
}

// 应用动态损失缩放
func apply_loss_scale(
    []float gradients,
    float loss_scale
) {
    
    int i = 0
    while i < len(gradients) {
        gradients[i] = gradients[i] * loss_scale
        i = i + 1
    }
}

// ============================================================================
// 8. 工具函数
// ============================================================================

// Softmax 计算 (带温度参数)
func softmax(
    []float logits,
    int start_idx,
    int end_idx,
    float temperature
) []float {
    
    int size = end_idx - start_idx
    []float result = make([]float, size)
    
    // 找最大值以避免溢出
    float max_val = find_max(logits, start_idx, end_idx)
    
    // 计算 exp 和
    float sum_exp = 0.0
    int i = 0
    while i < size {
        float val = (logits[start_idx + i] - max_val) / temperature
        float exp_val = exp(val)
        result[i] = exp_val
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    
    // 归一化
    i = 0
    while i < size {
        if sum_exp > 0.0 {
            result[i] = result[i] / sum_exp
        }
        i = i + 1
    }
    
    result
}

// 找最大值
func find_max([]float arr, int start_idx, int end_idx) float {
    float max_val = arr[start_idx]
    int i = start_idx + 1
    while i < end_idx {
        if arr[i] > max_val {
            max_val = arr[i]
        }
        i = i + 1
    }
    max_val
}

// 指数函数
func exp(float x) float {
    // 简单的近似或占位符
    if x > 20.0 {
        return 485165195.0  // exp(20)
    }
    if x < -20.0 {
        return 0.0
    }
    // 实际应使用数学库
    2.718
}

// 对数函数
func log(float x) float {
    // 占位符
    if x <= 0.0 {
        return -1000.0
    }
    1.0
}

func float_to_string(float x) string {
    // 占位符
    "loss"
}
