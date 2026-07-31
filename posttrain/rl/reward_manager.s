// 奖励管理器 - 从 verl 借鉴的 RL 核心模块
package neurx.posttrain.rl.reward_manager

// 对应 verl: verl/workers/reward_manager/

// 奖励类型
struct RewardConfig {
    string reward_type      // "rule", "model", "mixed"
    float reward_scale      // 奖励缩放因子
    bool normalize          // 是否归一化
}

// 奖励计算结果
struct RewardResult {
    []float rewards         // 每个样本的奖励
    float mean_reward       // 平均奖励
    float std_reward        // 标准差
    float min_reward        // 最小值
    float max_reward        // 最大值
}

// 规则奖励管理器（NaiveRewardManager 的 S 语言实现）
struct RuleRewardManager {
    RewardConfig config
}

func new_rule_reward_manager(RewardConfig config) RuleRewardManager {
    RuleRewardManager rm = RuleRewardManager{}
    rm.config = config
    return rm
}

// 基于规则的奖励计算
// prompts: 输入提示
// responses: 模型生成的响应
func (rm *RuleRewardManager) compute_rewards(
    []string prompts,
    []string responses
) RewardResult {
    int batch_size = len(responses)
    []float rewards = []float{}
    
    int i = 0
    while i < batch_size {
        string response = responses[i]
        
        // 规则 1: 长度奖励（鼓励适中长度）
        int response_len = string_length(response)
        float length_reward = compute_length_reward(response_len)
        
        // 规则 2: 完整性奖励（包含句号）
        float completeness_reward = 0.0
        if string_contains(response, ".") || string_contains(response, "。") {
            completeness_reward = 0.5
        }
        
        // 规则 3: 质量启发式（避免重复）
        float quality_reward = compute_quality_reward(response)
        
        // 组合奖励
        float total_reward = (length_reward + completeness_reward + quality_reward) / 3.0
        total_reward = total_reward * rm.config.reward_scale
        
        rewards = append(rewards, total_reward)
        i = i + 1
    }
    
    // 归一化（可选）
    if rm.config.normalize && len(rewards) > 1 {
        rewards = normalize_rewards(rewards)
    }
    
    // 计算统计信息
    return compute_reward_statistics(rewards)
}

// 长度奖励：鼓励 50-200 字符的响应
func compute_length_reward(int length) float {
    if length < 10 {
        return 0.1  // 太短
    }
    if length >= 10 && length <= 200 {
        return 1.0  // 理想长度
    }
    if length > 200 && length <= 500 {
        return 0.7  // 略长
    }
    return 0.3  // 太长
}

// 质量奖励：检测重复和多样性
func compute_quality_reward(string response) float {
    int len = string_length(response)
    if len < 10 { return 0.0 }
    
    // 简单启发式：检查是否有过多重复字符
    bool has_repetition = check_repetition(response)
    
    if has_repetition {
        return 0.2  // 检测到重复，低分
    }
    
    return 0.8  // 看起来不错
}

// 检查字符串是否有连续重复
func check_repetition(string s) bool {
    int len = string_length(s)
    if len < 6 { return false }
    
    // 检查是否有 3 个连续相同的字符
    int i = 0
    while i < len - 2 {
        // 简化版：假设单字节字符
        // 生产环境应使用更复杂的重复检测
        i = i + 1
    }
    
    return false  // 简化实现，总是返回 false
}


// ========== 批量奖励管理器 (BatchRewardManager) ==========

// 批量奖励管理器（用于大规模并行计算）
struct BatchRewardManager {
    RewardConfig config
    int batch_size
}

func new_batch_reward_manager(RewardConfig config, int batch_size) BatchRewardManager {
    BatchRewardManager brm = BatchRewardManager{}
    brm.config = config
    brm.batch_size = batch_size
    return brm
}

// 批量计算奖励（分批处理）
func (brm *BatchRewardManager) compute_rewards_batched(
    []string prompts,
    []string responses
) RewardResult {
    int total_samples = len(responses)
    []float all_rewards = []float{}
    
    int start = 0
    while start < total_samples {
        int end = start + brm.batch_size
        if end > total_samples {
            end = total_samples
        }
        
        // 提取当前批次
        []string batch_prompts = slice_strings(prompts, start, end)
        []string batch_responses = slice_strings(responses, start, end)
        
        // 计算批次奖励
        RuleRewardManager rm = new_rule_reward_manager(brm.config)
        RewardResult batch_result = rm.compute_rewards(batch_prompts, batch_responses)
        
        // 累积结果
        int i = 0
        while i < len(batch_result.rewards) {
            all_rewards = append(all_rewards, batch_result.rewards[i])
            i = i + 1
        }
        
        start = end
    }
    
    return compute_reward_statistics(all_rewards)
}


// ========== 混合奖励管理器 (MixedRewardManager) ==========

// 混合奖励：结合规则奖励和模型奖励
struct MixedRewardManager {
    RewardConfig config
    float rule_weight       // 规则奖励权重
    float model_weight      // 模型奖励权重
}

func new_mixed_reward_manager(
    RewardConfig config,
    float rule_weight,
    float model_weight
) MixedRewardManager {
    MixedRewardManager mrm = MixedRewardManager{}
    mrm.config = config
    mrm.rule_weight = rule_weight
    mrm.model_weight = model_weight
    return mrm
}

// 混合奖励计算
func (mrm *MixedRewardManager) compute_rewards(
    []string prompts,
    []string responses
) RewardResult {
    // 1. 计算规则奖励
    RuleRewardManager rm = new_rule_reward_manager(mrm.config)
    RewardResult rule_result = rm.compute_rewards(prompts, responses)
    
    // 2. 计算模型奖励（模拟）
    // 实际应该调用奖励模型，这里用简化版
    []float model_rewards = simulate_model_rewards(responses)
    
    // 3. 加权组合
    []float mixed_rewards = []float{}
    int i = 0
    while i < len(rule_result.rewards) {
        float mixed = mrm.rule_weight * rule_result.rewards[i] + 
                     mrm.model_weight * model_rewards[i]
        mixed_rewards = append(mixed_rewards, mixed)
        i = i + 1
    }
    
    return compute_reward_statistics(mixed_rewards)
}

// 模拟模型奖励（占位符）
func simulate_model_rewards([]string responses) []float {
    []float rewards = []float{}
    int i = 0
    while i < len(responses) {
        // 简化：基于长度的模拟奖励
        int len = string_length(responses[i])
        float reward = ((len as float)) / 100.0
        if reward > 1.0 { reward = 1.0 }
        rewards = append(rewards, reward)
        i = i + 1
    }
    return rewards
}


// ========== 奖励统计和工具函数 ==========

// 计算奖励统计信息
func compute_reward_statistics([]float rewards) RewardResult {
    RewardResult result = RewardResult{}
    result.rewards = rewards
    
    int n = len(rewards)
    if n == 0 {
        result.mean_reward = 0.0
        result.std_reward = 0.0
        result.min_reward = 0.0
        result.max_reward = 0.0
        return result
    }
    
    // 计算均值、最小值、最大值
    float sum = 0.0
    float min_val = rewards[0]
    float max_val = rewards[0]
    
    int i = 0
    while i < n {
        float r = rewards[i]
        sum = sum + r
        if r < min_val { min_val = r }
        if r > max_val { max_val = r }
        i = i + 1
    }
    
    float mean = sum / ((n as float))
    
    // 计算标准差
    float var_sum = 0.0
    i = 0
    while i < n {
        float diff = rewards[i] - mean
        var_sum = var_sum + diff * diff
        i = i + 1
    }
    
    float variance = var_sum / ((n as float))
    float std = sqrt(variance)
    
    result.mean_reward = mean
    result.std_reward = std
    result.min_reward = min_val
    result.max_reward = max_val
    
    return result
}

// 归一化奖励 (zero mean, unit variance)
func normalize_rewards([]float rewards) []float {
    int n = len(rewards)
    if n == 0 { return rewards }
    
    // 计算均值
    float sum = 0.0
    int i = 0
    while i < n {
        sum = sum + rewards[i]
        i = i + 1
    }
    float mean = sum / ((n as float))
    
    // 计算标准差
    float var_sum = 0.0
    i = 0
    while i < n {
        float diff = rewards[i] - mean
        var_sum = var_sum + diff * diff
        i = i + 1
    }
    float std = sqrt(var_sum / ((n as float)))
    
    // 归一化
    []float normalized = []float{}
    i = 0
    while i < n {
        float norm_val = (rewards[i] - mean) / (std + 1e-8)
        normalized = append(normalized, norm_val)
        i = i + 1
    }
    
    return normalized
}

// 打印奖励统计
func print_reward_stats(RewardResult result) {
    println("[Reward Statistics]")
    print("  Mean:   ")
    println(float_to_str_4(result.mean_reward))
    print("  Std:    ")
    println(float_to_str_4(result.std_reward))
    print("  Min:    ")
    println(float_to_str_4(result.min_reward))
    print("  Max:    ")
    println(float_to_str_4(result.max_reward))
    print("  Samples: ")
    println(int_to_str(len(result.rewards)))
}


// ========== 字符串工具 ==========

func string_length(string s) int {
    // 简化实现：假设每个字符 1 字节
    // 实际应该使用 UTF-8 长度
    int len = 0
    int i = 0
    // S 语言可能没有直接的字符串长度函数，这里用占位符
    // 实际应该调用 runtime 函数
    return 50  // 占位符：返回固定值
}

func string_contains(string haystack, string needle) bool {
    // 占位符：简化实现
    // 实际应该实现子串查找
    return false
}

func slice_strings([]string arr, int start, int end) []string {
    []string result = []string{}
    int i = start
    while i < end && i < len(arr) {
        result = append(result, arr[i])
        i = i + 1
    }
    return result
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
