// Token 准确率计算 - 从 verl 借鉴
package neurx.posttrain.training.token_accuracy

// 对应 verl: verl/trainer/ppo/metric_utils.py 中的 token-level accuracy

// Token 级准确率统计
struct TokenAccuracyStats {
    int correct_tokens      // 正确预测的 token 数
    int total_tokens        // 总 token 数（不含 padding）
    float accuracy          // 准确率
    int exact_matches       // 完全匹配的序列数
    int total_sequences     // 总序列数
    float sequence_accuracy // 序列级准确率
}

// 计算 Token 级准确率
// logits: [batch_size, seq_len, vocab_size]
// targets: [batch_size, seq_len]
// mask: [batch_size, seq_len] (1 = valid token, 0 = padding)
func compute_token_accuracy(
    [][][]float logits,
    [][]int targets,
    [][]bool mask
) TokenAccuracyStats {
    TokenAccuracyStats stats = TokenAccuracyStats{}
    stats.correct_tokens = 0
    stats.total_tokens = 0
    stats.exact_matches = 0
    stats.total_sequences = 0
    
    int batch_size = len(logits)
    if batch_size == 0 {
        return stats
    }
    
    // 遍历 batch
    int b = 0
    while b < batch_size {
        int seq_len = len(logits[b])
        bool sequence_correct = true
        int sequence_tokens = 0
        
        // 遍历序列中的每个 token
        int t = 0
        while t < seq_len {
            // 跳过 padding token
            if !mask[b][t] {
                t = t + 1
                continue
            }
            
            sequence_tokens = sequence_tokens + 1
            stats.total_tokens = stats.total_tokens + 1
            
            // 找到 logits 中最大值的索引（预测的 token）
            int predicted_token = argmax(logits[b][t])
            int target_token = targets[b][t]
            
            // 检查是否预测正确
            if predicted_token == target_token {
                stats.correct_tokens = stats.correct_tokens + 1
            } else {
                sequence_correct = false
            }
            
            t = t + 1
        }
        
        // 统计完全匹配的序列
        if sequence_tokens > 0 {
            stats.total_sequences = stats.total_sequences + 1
            if sequence_correct {
                stats.exact_matches = stats.exact_matches + 1
            }
        }
        
        b = b + 1
    }
    
    // 计算准确率
    if stats.total_tokens > 0 {
        stats.accuracy = ((stats.correct_tokens as float)) / ((stats.total_tokens as float))
    } else {
        stats.accuracy = 0.0
    }
    
    if stats.total_sequences > 0 {
        stats.sequence_accuracy = ((stats.exact_matches as float)) / ((stats.total_sequences as float))
    } else {
        stats.sequence_accuracy = 0.0
    }
    
    return stats
}

// 简化版：从 logits 和 targets 直接计算（假设所有 token 有效）
func compute_token_accuracy_simple(
    [][][]float logits,
    [][]int targets
) float {
    int correct = 0
    int total = 0
    
    int batch_size = len(logits)
    int b = 0
    while b < batch_size {
        int seq_len = len(logits[b])
        int t = 0
        while t < seq_len {
            int predicted = argmax(logits[b][t])
            int target = targets[b][t]
            
            if predicted == target {
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

// Top-K 准确率计算
// 检查目标 token 是否在预测的 top-K 中
func compute_topk_accuracy(
    [][][]float logits,
    [][]int targets,
    [][]bool mask,
    int k
) float {
    int correct = 0
    int total = 0
    
    int batch_size = len(logits)
    int b = 0
    while b < batch_size {
        int seq_len = len(logits[b])
        int t = 0
        while t < seq_len {
            // 跳过 padding
            if !mask[b][t] {
                t = t + 1
                continue
            }
            
            total = total + 1
            
            // 获取 top-k 预测
            []int topk_indices = get_topk_indices(logits[b][t], k)
            int target = targets[b][t]
            
            // 检查 target 是否在 top-k 中
            bool in_topk = false
            int i = 0
            while i < len(topk_indices) {
                if topk_indices[i] == target {
                    in_topk = true
                    break
                }
                i = i + 1
            }
            
            if in_topk {
                correct = correct + 1
            }
            
            t = t + 1
        }
        b = b + 1
    }
    
    if total == 0 { return 0.0 }
    return ((correct as float)) / ((total as float))
}


// ========== 辅助函数 ==========

// 找到向量中最大值的索引
func argmax([]float vector) int {
    if len(vector) == 0 { return -1 }
    
    int max_idx = 0
    float max_val = vector[0]
    
    int i = 1
    while i < len(vector) {
        if vector[i] > max_val {
            max_val = vector[i]
            max_idx = i
        }
        i = i + 1
    }
    
    return max_idx
}

// 获取 top-k 最大值的索引
func get_topk_indices([]float vector, int k) []int {
    int n = len(vector)
    if n == 0 { return []int{} }
    if k > n { k = n }
    
    // 创建索引-值对
    []int indices = []int{}
    []float values = []float{}
    
    int i = 0
    while i < n {
        indices = append(indices, i)
        values = append(values, vector[i])
        i = i + 1
    }
    
    // 选择排序 top-k（简单实现）
    []int topk = []int{}
    int selected = 0
    while selected < k {
        // 找到剩余中最大的
        int max_idx = 0
        float max_val = values[0]
        
        int j = 1
        while j < len(values) {
            if values[j] > max_val {
                max_val = values[j]
                max_idx = j
            }
            j = j + 1
        }
        
        // 添加到 top-k
        topk = append(topk, indices[max_idx])
        
        // 移除已选择的（设置为负无穷）
        values[max_idx] = -1e38
        
        selected = selected + 1
    }
    
    return topk
}

// 打印 Token 准确率统计
func print_token_accuracy_stats(TokenAccuracyStats stats) {
    println("[Token Accuracy]")
    print("  Correct Tokens:  ")
    print(int_to_str(stats.correct_tokens))
    print(" / ")
    println(int_to_str(stats.total_tokens))
    print("  Token Accuracy:  ")
    println(float_to_str_4(stats.accuracy * 100.0) + "%")
    print("  Exact Matches:   ")
    print(int_to_str(stats.exact_matches))
    print(" / ")
    println(int_to_str(stats.total_sequences))
    print("  Seq Accuracy:    ")
    println(float_to_str_4(stats.sequence_accuracy * 100.0) + "%")
}


// ========== 格式化函数 ==========

func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool negative = false
    if value < 0 {
        negative = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value - (value / 10) * 10
        if digit == 0 { out = "0" + out }
        else if digit == 1 { out = "1" + out }
        else if digit == 2 { out = "2" + out }
        else if digit == 3 { out = "3" + out }
        else if digit == 4 { out = "4" + out }
        else if digit == 5 { out = "5" + out }
        else if digit == 6 { out = "6" + out }
        else if digit == 7 { out = "7" + out }
        else if digit == 8 { out = "8" + out }
        else { out = "9" + out }
        value = value / 10
    }
    if negative { out = "-" + out }
    return out
}

func float_to_str_4(float value) string {
    float current = value
    bool negative = current < 0.0
    if negative { current = 0.0 - current }
    
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    
    string result = int_to_str(whole) + "."
    
    int i = 0
    while i < 4 {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        result = result + int_to_str(digit)
        i = i + 1
    }
    
    if negative { result = "-" + result }
    return result
}
