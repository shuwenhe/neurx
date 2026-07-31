// Rollout 生成器 - 从 verl 借鉴的 RL 核心模块
package neurx.posttrain.rl.rollout

// 对应 verl: verl/workers/rollout/

// Rollout 配置
struct RolloutConfig {
    int max_seq_len         // 最大序列长度
    float temperature       // 采样温度
    float top_p             // nucleus 采样参数
    int top_k               // top-k 采样参数
    bool do_sample          // 是否采样（vs 贪婪）
    int num_return_sequences // 每个 prompt 生成多少个响应
}

// 单个 Rollout 样本
struct RolloutSample {
    string prompt           // 输入提示
    string response         // 生成的响应
    []int token_ids         // 生成的 token ID
    []float log_probs       // 每个 token 的 log 概率
    []float values          // Value function 估计（如果使用 PPO）
    float reward            // 该样本的奖励
    int length              // 响应长度
}

// Rollout 批次结果
struct RolloutBatch {
    []RolloutSample samples // 所有样本
    float avg_length        // 平均长度
    float avg_log_prob      // 平均 log 概率
    int total_tokens        // 总 token 数
}

// Rollout 生成器
struct RolloutGenerator {
    RolloutConfig config
    int vocab_size          // 词汇表大小
}

func new_rollout_generator(RolloutConfig config, int vocab_size) RolloutGenerator {
    RolloutGenerator rg = RolloutGenerator{}
    rg.config = config
    rg.vocab_size = vocab_size
    return rg
}

// 生成单个样本的 rollout
// logits_fn: 函数指针，输入 token IDs，返回 logits
func (rg *RolloutGenerator) generate_single(
    string prompt,
    []int prompt_token_ids
) RolloutSample {
    RolloutSample sample = RolloutSample{}
    sample.prompt = prompt
    sample.token_ids = []int{}
    sample.log_probs = []float{}
    sample.values = []float{}
    
    // 复制 prompt tokens
    int i = 0
    while i < len(prompt_token_ids) {
        sample.token_ids = append(sample.token_ids, prompt_token_ids[i])
        i = i + 1
    }
    
    // 生成循环
    int generated_tokens = 0
    bool finished = false
    
    while !finished && generated_tokens < rg.config.max_seq_len {
        // 1. 获取当前序列的 logits
        // 实际应该调用模型的 forward，这里用占位符
        []float logits = get_model_logits_placeholder(sample.token_ids, rg.vocab_size)
        
        // 2. 应用温度
        if rg.config.temperature != 1.0 {
            logits = apply_temperature(logits, rg.config.temperature)
        }
        
        // 3. 采样或贪婪选择
        int next_token = 0
        float log_prob = 0.0
        
        if rg.config.do_sample {
            // 采样
            if rg.config.top_k > 0 {
                logits = apply_top_k_filtering(logits, rg.config.top_k)
            }
            if rg.config.top_p > 0.0 && rg.config.top_p < 1.0 {
                logits = apply_top_p_filtering(logits, rg.config.top_p)
            }
            
            // Softmax + 采样
            []float probs = softmax(logits)
            next_token = sample_from_distribution(probs)
            log_prob = log(probs[next_token] + 1e-10)
        } else {
            // 贪婪选择
            next_token = argmax(logits)
            []float probs = softmax(logits)
            log_prob = log(probs[next_token] + 1e-10)
        }
        
        // 4. 检查 EOS token (假设 EOS = 2)
        if next_token == 2 {
            finished = true
        }
        
        // 5. 添加到序列
        sample.token_ids = append(sample.token_ids, next_token)
        sample.log_probs = append(sample.log_probs, log_prob)
        
        // 6. 计算 value（如果使用 PPO）
        // 实际应该调用 critic 网络
        float value = 0.0  // 占位符
        sample.values = append(sample.values, value)
        
        generated_tokens = generated_tokens + 1
    }
    
    // 7. 解码为字符串（简化）
    sample.response = decode_tokens_placeholder(sample.token_ids, len(prompt_token_ids))
    sample.length = len(sample.token_ids) - len(prompt_token_ids)
    
    return sample
}

// 批量生成 rollouts
func (rg *RolloutGenerator) generate_batch(
    []string prompts,
    [][]int prompt_token_ids_batch
) RolloutBatch {
    RolloutBatch batch = RolloutBatch{}
    batch.samples = []RolloutSample{}
    
    int total_length = 0
    float total_log_prob = 0.0
    int total_tokens = 0
    
    // 遍历每个 prompt
    int i = 0
    while i < len(prompts) {
        // 为每个 prompt 生成 num_return_sequences 个样本
        int j = 0
        while j < rg.config.num_return_sequences {
            RolloutSample sample = rg.generate_single(
                prompts[i],
                prompt_token_ids_batch[i]
            )
            
            batch.samples = append(batch.samples, sample)
            
            total_length = total_length + sample.length
            total_tokens = total_tokens + len(sample.token_ids)
            
            // 累积平均 log 概率
            int k = 0
            while k < len(sample.log_probs) {
                total_log_prob = total_log_prob + sample.log_probs[k]
                k = k + 1
            }
            
            j = j + 1
        }
        i = i + 1
    }
    
    // 计算统计信息
    int num_samples = len(batch.samples)
    if num_samples > 0 {
        batch.avg_length = ((total_length as float)) / ((num_samples as float))
        
        int total_generated_tokens = 0
        int idx = 0
        while idx < num_samples {
            total_generated_tokens = total_generated_tokens + len(batch.samples[idx].log_probs)
            idx = idx + 1
        }
        
        if total_generated_tokens > 0 {
            batch.avg_log_prob = total_log_prob / ((total_generated_tokens as float))
        }
    }
    
    batch.total_tokens = total_tokens
    
    return batch
}


// ========== 采样辅助函数 ==========

// 应用温度缩放
func apply_temperature([]float logits, float temperature) []float {
    []float scaled = []float{}
    int i = 0
    while i < len(logits) {
        scaled = append(scaled, logits[i] / temperature)
        i = i + 1
    }
    return scaled
}

// Top-K 过滤（保留 top-k，其余设为负无穷）
func apply_top_k_filtering([]float logits, int k) []float {
    int n = len(logits)
    if k >= n { return logits }
    
    // 找到第 k 大的值
    []float sorted_logits = copy_float_array(logits)
    sort_float_array_desc(sorted_logits)
    
    float threshold = sorted_logits[k - 1]
    
    // 过滤
    []float filtered = []float{}
    int i = 0
    while i < n {
        if logits[i] >= threshold {
            filtered = append(filtered, logits[i])
        } else {
            filtered = append(filtered, -1e38)  // 负无穷
        }
        i = i + 1
    }
    
    return filtered
}

// Top-P (nucleus) 过滤
func apply_top_p_filtering([]float logits, float top_p) []float {
    // 1. 计算概率分布
    []float probs = softmax(logits)
    
    // 2. 按概率降序排序（保持索引）
    []int sorted_indices = argsort_desc(probs)
    
    // 3. 累积概率
    float cumsum = 0.0
    []bool keep_mask = make_bool_array(len(probs), false)
    
    int i = 0
    while i < len(sorted_indices) {
        int idx = sorted_indices[i]
        cumsum = cumsum + probs[idx]
        keep_mask[idx] = true
        
        if cumsum >= top_p {
            break
        }
        i = i + 1
    }
    
    // 4. 过滤
    []float filtered = []float{}
    int j = 0
    while j < len(logits) {
        if keep_mask[j] {
            filtered = append(filtered, logits[j])
        } else {
            filtered = append(filtered, -1e38)
        }
        j = j + 1
    }
    
    return filtered
}

// Softmax
func softmax([]float logits) []float {
    int n = len(logits)
    if n == 0 { return []float{} }
    
    // 找到最大值（数值稳定性）
    float max_logit = logits[0]
    int i = 1
    while i < n {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }
    
    // 计算 exp(x - max) 和归一化常数
    []float exp_logits = []float{}
    float sum_exp = 0.0
    
    i = 0
    while i < n {
        float exp_val = exp(logits[i] - max_logit)
        exp_logits = append(exp_logits, exp_val)
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    
    // 归一化
    []float probs = []float{}
    i = 0
    while i < n {
        probs = append(probs, exp_logits[i] / sum_exp)
        i = i + 1
    }
    
    return probs
}

// 从概率分布中采样
func sample_from_distribution([]float probs) int {
    // 简化实现：使用累积分布函数 + 随机数
    // 实际应该调用 runtime 的随机数生成器
    
    // 计算累积分布
    []float cumsum = []float{}
    float sum = 0.0
    int i = 0
    while i < len(probs) {
        sum = sum + probs[i]
        cumsum = append(cumsum, sum)
        i = i + 1
    }
    
    // 生成随机数 [0, 1)
    float rand = get_random_float()  // 占位符
    
    // 找到第一个累积概率 >= rand 的索引
    i = 0
    while i < len(cumsum) {
        if cumsum[i] >= rand {
            return i
        }
        i = i + 1
    }
    
    return len(probs) - 1  // 回退
}

// 找到最大值的索引
func argmax([]float arr) int {
    if len(arr) == 0 { return -1 }
    int max_idx = 0
    float max_val = arr[0]
    int i = 1
    while i < len(arr) {
        if arr[i] > max_val {
            max_val = arr[i]
            max_idx = i
        }
        i = i + 1
    }
    return max_idx
}


// ========== 占位符函数（需要实际实现） ==========

// 获取模型 logits（占位符）
func get_model_logits_placeholder([]int token_ids, int vocab_size) []float {
    // 实际应该调用模型的 forward pass
    []float logits = []float{}
    int i = 0
    while i < vocab_size {
        logits = append(logits, 0.0)
        i = i + 1
    }
    return logits
}

// 解码 tokens 为字符串（占位符）
func decode_tokens_placeholder([]int token_ids, int prompt_len) string {
    // 实际应该调用 tokenizer.decode()
    return "Generated response placeholder"
}

// 随机浮点数生成器（占位符）
func get_random_float() float {
    // 实际应该调用 runtime 的 RNG
    return 0.5  // 占位符
}


// ========== 工具函数 ==========

func copy_float_array([]float arr) []float {
    []float copy = []float{}
    int i = 0
    while i < len(arr) {
        copy = append(copy, arr[i])
        i = i + 1
    }
    return copy
}

func sort_float_array_desc([]float arr) {
    // 简单冒泡排序（降序）
    int n = len(arr)
    int i = 0
    while i < n - 1 {
        int j = 0
        while j < n - i - 1 {
            if arr[j] < arr[j + 1] {
                float temp = arr[j]
                arr[j] = arr[j + 1]
                arr[j + 1] = temp
            }
            j = j + 1
        }
        i = i + 1
    }
}

func argsort_desc([]float arr) []int {
    int n = len(arr)
    []int indices = []int{}
    int i = 0
    while i < n {
        indices = append(indices, i)
        i = i + 1
    }
    
    // 冒泡排序索引（降序）
    i = 0
    while i < n - 1 {
        int j = 0
        while j < n - i - 1 {
            if arr[indices[j]] < arr[indices[j + 1]] {
                int temp = indices[j]
                indices[j] = indices[j + 1]
                indices[j + 1] = temp
            }
            j = j + 1
        }
        i = i + 1
    }
    
    return indices
}

func make_bool_array(int size, bool default_val) []bool {
    []bool arr = []bool{}
    int i = 0
    while i < size {
        arr = append(arr, default_val)
        i = i + 1
    }
    return arr
}


// ========== 打印函数 ==========

func print_rollout_batch_stats(RolloutBatch batch) {
    println("[Rollout Batch Stats]")
    print("  Total Samples:    ")
    println(int_to_str(len(batch.samples)))
    print("  Avg Length:       ")
    println(float_to_str_2(batch.avg_length))
    print("  Avg Log Prob:     ")
    println(float_to_str_4(batch.avg_log_prob))
    print("  Total Tokens:     ")
    println(int_to_str(batch.total_tokens))
}

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

func float_to_str_2(float value) string {
    return float_to_str_n(value, 2)
}

func float_to_str_4(float value) string {
    return float_to_str_n(value, 4)
}

func float_to_str_n(float value, int decimals) string {
    float current = value
    bool negative = current < 0.0
    if negative { current = 0.0 - current }
    
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    
    string result = int_to_str(whole)
    
    if decimals > 0 {
        result = result + "."
        int i = 0
        while i < decimals {
            current = current * 10.0
            int digit = 0
            while current >= 1.0 {
                current = current - 1.0
                digit = digit + 1
            }
            result = result + int_to_str(digit)
            i = i + 1
        }
    }
    
    if negative { result = "-" + result }
    return result
}
