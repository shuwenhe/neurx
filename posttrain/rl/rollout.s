package neurx.posttrain.rl.rollout

struct rollout_config {
    int max_seq_len
    float temperature
    float top_p
    int top_k
    bool do_sample
    int num_return_sequences
}

struct rollout_sample {
    string prompt
    string response
    []int token_ids
    []float log_probs
    []float values
    float reward
    int length
}

struct rollout_batch {
    []rollout_sample samples
    float avg_length
    float avg_log_prob
    int total_tokens
}

struct rollout_generator {
    rollout_config config
    int vocab_size
}

func new_rollout_generator(rollout_config config, int vocab_size) rollout_generator {
    rollout_generator rg = rollout_generator{}
    rg.config = config
    rg.vocab_size = vocab_size
    return rg
}

func (rollout_generator* rg) generate_single(
    string prompt,
    []int prompt_token_ids
) rollout_sample {
    rollout_sample sample = rollout_sample{}
    sample.prompt = prompt
    sample.token_ids = []int{}
    sample.log_probs = []float{}
    sample.values = []float{}
    int i = 0
    while i < len(prompt_token_ids) {
        sample.token_ids = append(sample.token_ids, prompt_token_ids[i])
        i = i + 1
    }
    int generated_tokens = 0
    bool finished = false
    while !finished && generated_tokens < rg.config.max_seq_len {
        []float logits = get_model_logits_placeholder(sample.token_ids, rg.vocab_size)
        if rg.config.temperature != 1.0 {
            logits = apply_temperature(logits, rg.config.temperature)
        }
        int next_token = 0
        float log_prob = 0.0
        if rg.config.do_sample {
            if rg.config.top_k > 0 {
                logits = apply_top_k_filtering(logits, rg.config.top_k)
            }
            if rg.config.top_p > 0.0 && rg.config.top_p < 1.0 {
                logits = apply_top_p_filtering(logits, rg.config.top_p)
            }
            []float probs = softmax(logits)
            next_token = sample_from_distribution(probs)
            log_prob = log(probs[next_token] + 1e-10)
        } else {
            next_token = argmax(logits)
            []float probs = softmax(logits)
            log_prob = log(probs[next_token] + 1e-10)
        }
        if next_token == 2 {
            finished = true
        }
        sample.token_ids = append(sample.token_ids, next_token)
        sample.log_probs = append(sample.log_probs, log_prob)
        float value = 0.0
        sample.values = append(sample.values, value)
        generated_tokens = generated_tokens + 1
    }
    sample.response = decode_tokens_placeholder(sample.token_ids, len(prompt_token_ids))
    sample.length = len(sample.token_ids) - len(prompt_token_ids)
    return sample
}

func (rollout_generator* rg) generate_batch(
    []string prompts,
    [][]int prompt_token_ids_batch
) rollout_batch {
    rollout_batch batch = rollout_batch{}
    batch.samples = []rollout_sample{}
    int total_length = 0
    float total_log_prob = 0.0
    int total_tokens = 0
    int i = 0
    while i < len(prompts) {
        int j = 0
        while j < rg.config.num_return_sequences {
            rollout_sample sample = rg.generate_single(
                prompts[i],
                prompt_token_ids_batch[i]
            )
            batch.samples = append(batch.samples, sample)
            total_length = total_length + sample.length
            total_tokens = total_tokens + len(sample.token_ids)
            int k = 0
            while k < len(sample.log_probs) {
                total_log_prob = total_log_prob + sample.log_probs[k]
                k = k + 1
            }
            j = j + 1
        }
        i = i + 1
    }
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

func apply_temperature([]float logits, float temperature) []float {
    []float scaled = []float{}
    int i = 0
    while i < len(logits) {
        scaled = append(scaled, logits[i] / temperature)
        i = i + 1
    }
    return scaled
}

func apply_top_k_filtering([]float logits, int k) []float {
    int n = len(logits)
    if k >= n { return logits }
    []float sorted_logits = copy_float_array(logits)
    sort_float_array_desc(sorted_logits)
    float threshold = sorted_logits[k - 1]
    []float filtered = []float{}
    int i = 0
    while i < n {
        if logits[i] >= threshold {
            filtered = append(filtered, logits[i])
        } else {
            filtered = append(filtered, -1e38)
        }
        i = i + 1
    }
    return filtered
}

func apply_top_p_filtering([]float logits, float top_p) []float {
    []float probs = softmax(logits)
    []int sorted_indices = argsort_desc(probs)
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

func softmax([]float logits) []float {
    int n = len(logits)
    if n == 0 { return []float{} }
    float max_logit = logits[0]
    int i = 1
    while i < n {
        if logits[i] > max_logit {
            max_logit = logits[i]
        }
        i = i + 1
    }
    []float exp_logits = []float{}
    float sum_exp = 0.0
    i = 0
    while i < n {
        float exp_val = exp(logits[i] - max_logit)
        exp_logits = append(exp_logits, exp_val)
        sum_exp = sum_exp + exp_val
        i = i + 1
    }
    []float probs = []float{}
    i = 0
    while i < n {
        probs = append(probs, exp_logits[i] / sum_exp)
        i = i + 1
    }
    return probs
}

func sample_from_distribution([]float probs) int {
    []float cumsum = []float{}
    float sum = 0.0
    int i = 0
    while i < len(probs) {
        sum = sum + probs[i]
        cumsum = append(cumsum, sum)
        i = i + 1
    }
    float rand = get_random_float()
    i = 0
    while i < len(cumsum) {
        if cumsum[i] >= rand {
            return i
        }
        i = i + 1
    }
    return len(probs) - 1
}

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

func get_model_logits_placeholder([]int token_ids, int vocab_size) []float {
    []float logits = []float{}
    int i = 0
    while i < vocab_size {
        logits = append(logits, 0.0)
        i = i + 1
    }
    return logits
}

func decode_tokens_placeholder([]int token_ids, int prompt_len) string {
    return "Generated response placeholder"
}

func get_random_float() float {
    return 0.5
}

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

func print_rollout_batch_stats(rollout_batch batch) {
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
