package neurx.posttrain.rl.reward_manager
struct reward_config {
    string reward_type
    float reward_scale
    bool normalize
}

struct reward_result {
    []float rewards
    float mean_reward
    float std_reward
    float min_reward
    float max_reward
}

struct rule_reward_manager {
    reward_config config
}

func new_rule_reward_manager(reward_config config) rule_reward_manager {
    rule_reward_manager rm = rule_reward_manager{}
    rm.config = config
    return rm
}

func (rule_reward_manager* rm) compute_rewards(
    []string prompts,
    []string responses
) reward_result {
    int batch_size = len(responses)
    []float rewards = []float{}
    int i = 0
    while i < batch_size {
        string response = responses[i]
        int response_len = string_length(response)
        float length_reward = compute_length_reward(response_len)
        float completeness_reward = 0.0
        if string_contains(response, ".") || string_contains(response, "。") {
            completeness_reward = 0.5
        }
        float quality_reward = compute_quality_reward(response)
        float total_reward = (length_reward + completeness_reward + quality_reward) / 3.0
        total_reward = total_reward * rm.config.reward_scale
        rewards = append(rewards, total_reward)
        i = i + 1
    }
    if rm.config.normalize && len(rewards) > 1 {
        rewards = normalize_rewards(rewards)
    }
    return compute_reward_statistics(rewards)
}

func compute_length_reward(int length) float {
    if length < 10 {
        return 0.1
    }
    if length >= 10 && length <= 200 {
        return 1.0
    }
    if length > 200 && length <= 500 {
        return 0.7
    }
    return 0.3
}

func compute_quality_reward(string response) float {
    int len = string_length(response)
    if len < 10 { return 0.0 }
    bool has_repetition = check_repetition(response)
    if has_repetition {
        return 0.2
    }
    return 0.8
}

func check_repetition(string s) bool {
    int len = string_length(s)
    if len < 6 { return false }
    int i = 0
    while i < len - 2 {
        i = i + 1
    }
    return false
}

struct batch_reward_manager {
    reward_config config
    int batch_size
}

func new_batch_reward_manager(reward_config config, int batch_size) batch_reward_manager {
    batch_reward_manager brm = batch_reward_manager{}
    brm.config = config
    brm.batch_size = batch_size
    return brm
}

func (batch_reward_manager* brm) compute_rewards_batched(
    []string prompts,
    []string responses
) reward_result {
    int total_samples = len(responses)
    []float all_rewards = []float{}
    int start = 0
    while start < total_samples {
        int end = start + brm.batch_size
        if end > total_samples {
            end = total_samples
        }
        []string batch_prompts = slice_strings(prompts, start, end)
        []string batch_responses = slice_strings(responses, start, end)
        rule_reward_manager rm = new_rule_reward_manager(brm.config)
        reward_result batch_result = rm.compute_rewards(batch_prompts, batch_responses)
        int i = 0
        while i < len(batch_result.rewards) {
            all_rewards = append(all_rewards, batch_result.rewards[i])
            i = i + 1
        }
        start = end
    }
    return compute_reward_statistics(all_rewards)
}

struct mixed_reward_manager {
    reward_config config
    float rule_weight
    float model_weight
}

func new_mixed_reward_manager(
    reward_config config,
    float rule_weight,
    float model_weight
) mixed_reward_manager {
    mixed_reward_manager mrm = mixed_reward_manager{}
    mrm.config = config
    mrm.rule_weight = rule_weight
    mrm.model_weight = model_weight
    return mrm
}

func (mixed_reward_manager* mrm) compute_rewards(
    []string prompts,
    []string responses
) reward_result {
    rule_reward_manager rm = new_rule_reward_manager(mrm.config)
    reward_result rule_result = rm.compute_rewards(prompts, responses)
    []float model_rewards = simulate_model_rewards(responses)
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

func simulate_model_rewards([]string responses) []float {
    []float rewards = []float{}
    int i = 0
    while i < len(responses) {
        int len = string_length(responses[i])
        float reward = ((len as float)) / 100.0
        if reward > 1.0 { reward = 1.0 }
        rewards = append(rewards, reward)
        i = i + 1
    }
    return rewards
}

func compute_reward_statistics([]float rewards) reward_result {
    reward_result result = reward_result{}
    result.rewards = rewards
    int n = len(rewards)
    if n == 0 {
        result.mean_reward = 0.0
        result.std_reward = 0.0
        result.min_reward = 0.0
        result.max_reward = 0.0
        return result
    }
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

func normalize_rewards([]float rewards) []float {
    int n = len(rewards)
    if n == 0 { return rewards }
    float sum = 0.0
    int i = 0
    while i < n {
        sum = sum + rewards[i]
        i = i + 1
    }
    float mean = sum / ((n as float))
    float var_sum = 0.0
    i = 0
    while i < n {
        float diff = rewards[i] - mean
        var_sum = var_sum + diff * diff
        i = i + 1
    }
    float std = sqrt(var_sum / ((n as float)))
    []float normalized = []float{}
    i = 0
    while i < n {
        float norm_val = (rewards[i] - mean) / (std + 1e-8)
        normalized = append(normalized, norm_val)
        i = i + 1
    }
    return normalized
}

func print_reward_stats(reward_result result) {
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

func string_length(string s) int {
    int len = 0
    int i = 0
    return 50
}

func string_contains(string haystack, string needle) bool {
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
