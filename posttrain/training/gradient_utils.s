// 梯度工具 - 从 verl 借鉴的全局梯度裁剪和 NaN 检测
package neurx.posttrain.training.gradient_utils

// 全局梯度裁剪 (跨所有参数层)
// 对应 verl: verl/utils/torch_functional.py::clip_grad_norm_
struct GlobalGradientStats {
    float total_norm        // 全局梯度范数
    float clip_coefficient  // 裁剪系数
    bool clipped            // 是否被裁剪
    int total_params        // 总参数数量
}

// 计算所有层梯度的全局 L2 范数
func compute_global_grad_norm([][]float all_layer_grads) float {
    float total_norm_squared = 0.0
    
    // 遍历所有层
    int layer_idx = 0
    while layer_idx < len(all_layer_grads) {
        []float layer_grad = all_layer_grads[layer_idx]
        
        // 累积该层梯度的平方和
        int i = 0
        while i < len(layer_grad) {
            float g = layer_grad[i]
            total_norm_squared = total_norm_squared + g * g
            i = i + 1
        }
        
        layer_idx = layer_idx + 1
    }
    
    return sqrt(total_norm_squared)
}

// 全局梯度裁剪 (修改输入的梯度数组)
// 返回裁剪统计信息
func clip_gradients_global([][]float all_layer_grads, float max_norm) GlobalGradientStats {
    // 1. 计算全局梯度范数
    float global_norm = compute_global_grad_norm(all_layer_grads)
    
    // 2. 计算裁剪系数
    float clip_coef = max_norm / (global_norm + 1e-6)
    
    bool was_clipped = false
    
    // 3. 如果范数超过阈值，裁剪所有层的梯度
    if clip_coef < 1.0 {
        was_clipped = true
        
        int layer_idx = 0
        while layer_idx < len(all_layer_grads) {
            []float layer_grad = all_layer_grads[layer_idx]
            
            int i = 0
            while i < len(layer_grad) {
                layer_grad[i] = layer_grad[i] * clip_coef
                i = i + 1
            }
            
            layer_idx = layer_idx + 1
        }
    }
    
    // 4. 统计总参数数量
    int total_params = 0
    int idx = 0
    while idx < len(all_layer_grads) {
        total_params = total_params + len(all_layer_grads[idx])
        idx = idx + 1
    }
    
    // 5. 返回统计信息
    GlobalGradientStats stats = GlobalGradientStats{}
    stats.total_norm = global_norm
    stats.clip_coefficient = clip_coef
    stats.clipped = was_clipped
    stats.total_params = total_params
    
    return stats
}


// ========== NaN/Inf 检测 ==========
// 对应 verl: verl/trainer/ppo/ray_trainer.py 中的 NaN 检测

struct NaNInfStats {
    bool has_nan            // 是否包含 NaN
    bool has_inf            // 是否包含 Inf
    int nan_count           // NaN 数量
    int inf_count           // Inf 数量
    int total_checked       // 检查的总数
    string first_nan_layer  // 第一个 NaN 所在层
    string first_inf_layer  // 第一个 Inf 所在层
}

// 检查单个浮点数是否为 NaN
func is_nan(float x) bool {
    // NaN 的特性：NaN != NaN
    return x != x
}

// 检查单个浮点数是否为 Inf
func is_inf(float x) bool {
    // 简化判断：超过浮点数最大值
    float max_float = 3.4e38
    if x > max_float { return true }
    if x < (0.0 - max_float) { return true }
    return false
}

// 检查所有层的梯度是否包含 NaN 或 Inf
func check_gradients_nan_inf([][]float all_layer_grads, []string layer_names) NaNInfStats {
    NaNInfStats stats = NaNInfStats{}
    stats.has_nan = false
    stats.has_inf = false
    stats.nan_count = 0
    stats.inf_count = 0
    stats.total_checked = 0
    stats.first_nan_layer = ""
    stats.first_inf_layer = ""
    
    int layer_idx = 0
    while layer_idx < len(all_layer_grads) {
        []float layer_grad = all_layer_grads[layer_idx]
        string layer_name = ""
        if layer_idx < len(layer_names) {
            layer_name = layer_names[layer_idx]
        }
        
        int i = 0
        while i < len(layer_grad) {
            float g = layer_grad[i]
            stats.total_checked = stats.total_checked + 1
            
            // 检查 NaN
            if is_nan(g) {
                stats.nan_count = stats.nan_count + 1
                if !stats.has_nan {
                    stats.has_nan = true
                    stats.first_nan_layer = layer_name
                }
            }
            
            // 检查 Inf
            if is_inf(g) {
                stats.inf_count = stats.inf_count + 1
                if !stats.has_inf {
                    stats.has_inf = true
                    stats.first_inf_layer = layer_name
                }
            }
            
            i = i + 1
        }
        
        layer_idx = layer_idx + 1
    }
    
    return stats
}

// 检查参数是否包含 NaN 或 Inf
func check_parameters_nan_inf([][]float all_layer_params, []string layer_names) NaNInfStats {
    // 复用梯度检查逻辑
    return check_gradients_nan_inf(all_layer_params, layer_names)
}


// ========== 梯度统计 ==========
// 对应 verl: verl/trainer/ppo/metric_utils.py 中的梯度统计

struct GradientStatistics {
    float mean              // 平均值
    float std               // 标准差
    float min               // 最小值
    float max               // 最大值
    float l2_norm           // L2 范数
    int zero_count          // 零梯度数量
    float sparsity          // 稀疏度
}

// 计算单层梯度的统计信息
func compute_gradient_statistics([]float gradients) GradientStatistics {
    GradientStatistics stats = GradientStatistics{}
    
    int n = len(gradients)
    if n == 0 {
        return stats
    }
    
    // 1. 计算均值、最小值、最大值
    float sum = 0.0
    float min_val = gradients[0]
    float max_val = gradients[0]
    int zero_cnt = 0
    
    int i = 0
    while i < n {
        float g = gradients[i]
        sum = sum + g
        
        if g < min_val { min_val = g }
        if g > max_val { max_val = g }
        
        // 检查零梯度 (绝对值小于 1e-8)
        if g > -1e-8 && g < 1e-8 {
            zero_cnt = zero_cnt + 1
        }
        
        i = i + 1
    }
    
    float mean = sum / ((n as float))
    
    // 2. 计算标准差和 L2 范数
    float var_sum = 0.0
    float l2_sum = 0.0
    
    i = 0
    while i < n {
        float g = gradients[i]
        float diff = g - mean
        var_sum = var_sum + diff * diff
        l2_sum = l2_sum + g * g
        i = i + 1
    }
    
    float variance = var_sum / ((n as float))
    float std_dev = sqrt(variance)
    float l2_norm = sqrt(l2_sum)
    
    // 3. 计算稀疏度
    float sparsity = ((zero_cnt as float)) / ((n as float))
    
    // 4. 填充统计结构
    stats.mean = mean
    stats.std = std_dev
    stats.min = min_val
    stats.max = max_val
    stats.l2_norm = l2_norm
    stats.zero_count = zero_cnt
    stats.sparsity = sparsity
    
    return stats
}


// ========== 辅助函数 ==========

// 打印全局梯度裁剪统计
func print_gradient_clip_stats(GlobalGradientStats stats) {
    println("[Gradient Clip]")
    print("  Total Norm: ")
    println(float_to_str_4(stats.total_norm))
    print("  Clipped: ")
    if stats.clipped {
        println("Yes")
        print("  Clip Coef: ")
        println(float_to_str_4(stats.clip_coefficient))
    } else {
        println("No")
    }
    print("  Total Params: ")
    println(int_to_str(stats.total_params))
}

// 打印 NaN/Inf 检测结果
func print_nan_inf_stats(NaNInfStats stats) {
    if stats.has_nan || stats.has_inf {
        println("[ERROR] Detected NaN/Inf in gradients!")
        
        if stats.has_nan {
            print("  NaN Count: ")
            println(int_to_str(stats.nan_count))
            print("  First NaN Layer: ")
            println(stats.first_nan_layer)
        }
        
        if stats.has_inf {
            print("  Inf Count: ")
            println(int_to_str(stats.inf_count))
            print("  First Inf Layer: ")
            println(stats.first_inf_layer)
        }
        
        println("  Training should be stopped or checkpointed!")
    }
}

// 打印梯度统计
func print_gradient_stats(GradientStatistics stats, string layer_name) {
    print("[Gradient Stats] ")
    println(layer_name)
    print("  Mean: ")
    println(float_to_str_4(stats.mean))
    print("  Std: ")
    println(float_to_str_4(stats.std))
    print("  L2 Norm: ")
    println(float_to_str_4(stats.l2_norm))
    print("  Sparsity: ")
    println(float_to_str_4(stats.sparsity))
}


// ========== 格式化辅助函数 ==========

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
