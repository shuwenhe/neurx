// 核心训练稳定性工具 - 简化版（零依赖，直接集成）
package neurx.posttrain.training.stability

// 全局梯度裁剪（跨所有层）
func clip_all_gradients([][]float all_grads, float max_norm) float {
    // 1. 计算全局范数
    float total = 0.0
    int layer = 0
    while layer < len(all_grads) {
        int i = 0
        while i < len(all_grads[layer]) {
            float g = all_grads[layer][i]
            total = total + g * g
            i = i + 1
        }
        layer = layer + 1
    }
    float global_norm = sqrt(total)
    
    // 2. 裁剪
    if global_norm > max_norm {
        float scale = max_norm / global_norm
        layer = 0
        while layer < len(all_grads) {
            int i = 0
            while i < len(all_grads[layer]) {
                all_grads[layer][i] = all_grads[layer][i] * scale
                i = i + 1
            }
            layer = layer + 1
        }
    }
    
    return global_norm
}

// 检测 NaN（NaN != NaN）
func has_nan(float x) bool {
    return x != x
}

// 检测 Inf（超过浮点数最大值）
func has_inf(float x) bool {
    if x > 1e38 { return true }
    if x < -1e38 { return true }
    return false
}

// 检查梯度是否包含 NaN/Inf
func check_grads_healthy([][]float all_grads) bool {
    int layer = 0
    while layer < len(all_grads) {
        int i = 0
        while i < len(all_grads[layer]) {
            float g = all_grads[layer][i]
            if has_nan(g) {
                println("[ERROR] NaN detected in gradients!")
                return false
            }
            if has_inf(g) {
                println("[ERROR] Inf detected in gradients!")
                return false
            }
            i = i + 1
        }
        layer = layer + 1
    }
    return true
}

// Token 准确率计算（简化版）
func compute_accuracy([][][]float logits, [][]int targets) float {
    int correct = 0
    int total = 0
    
    int b = 0
    while b < len(logits) {
        int t = 0
        while t < len(logits[b]) {
            // 找到最大 logit 的索引
            int pred = 0
            float max_val = logits[b][t][0]
            int v = 1
            while v < len(logits[b][t]) {
                if logits[b][t][v] > max_val {
                    max_val = logits[b][t][v]
                    pred = v
                }
                v = v + 1
            }
            
            if pred == targets[b][t] {
                correct = correct + 1
            }
            total = total + 1
            t = t + 1
        }
        b = b + 1
    }
    
    if total == 0 { return 0.0 }
    return ((correct as float)) / ((total as float))
}
