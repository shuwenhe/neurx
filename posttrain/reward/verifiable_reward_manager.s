package neurx.posttrain.reward.verifiable_reward_manager
use std.io.eprintln
enum reward_type {
    MODEL_BASED,
    FUNCTION_BASED,
    HUMAN_FEEDBACK,
    VERIFIABLE,
}

struct verification_result {
    bool is_valid
    bool is_correct
    string error_message
    float confidence
}

struct reward_function_config {
    string function_name
    reward_type type
    string description
    bool is_verifiable
    float max_reward
    float min_reward
}

struct reward_sample {
    int sample_id
    string input_text
    string output_text
    float reward_value
    reward_type reward_type
    verification_result verification
    int step
}

struct verifiable_reward_manager_state {
    []reward_function_config reward_functions
    []reward_sample history
    int sample_count
    float avg_reward
    float reward_variance
    map string = int function_call_count
    bool enable_verification
}

func new_verifiable_reward_manager() verifiable_reward_manager_state {
    verifiable_reward_manager_state {
        reward_functions: []reward_function_config{cap: 50},
        history: []reward_sample{cap: 100000},
        sample_count: 0,
        avg_reward: 0.0,
        reward_variance: 0.0,
        function_call_count: map string = int{cap: 50},
        enable_verification: true,
    }
}

func reward_register_function(verifiable_reward_manager_state state, string func_name, reward_type reward_t, string description, bool is_verifiable, float max_reward) verifiable_reward_manager_state {
    reward_function_config config = reward_function_config {
        function_name: func_name,
        type: reward_t,
        description: description,
        is_verifiable: is_verifiable,
        max_reward: max_reward,
        min_reward: -max_reward,
    }
    state.reward_functions += []reward_function_config{config}
    state.function_call_count[func_name] = 0
    eprintln("[RewardManager] Registered reward function: " + func_name + " (type: " + reward_type_to_string(reward_t) + ")")
    state
}

func reward_verify_math(string expected_output, string model_output) verification_result {
    bool is_correct = expected_output == model_output
    verification_result {
        is_valid: true,
        is_correct: is_correct,
        error_message: (if is_correct then "correct" else "incorrect answer"),
        confidence: (if is_correct then 1.0 else 0.0),
    }
}

func reward_verify_code(string code_output, string expected_output) verification_result {
    bool is_valid = len(code_output) > 0
    bool is_correct = code_output == expected_output
    verification_result {
        is_valid: is_valid,
        is_correct: is_correct,
        error_message: (if is_correct then "code correct" else "code output mismatch"),
        confidence: (if is_correct then 0.95 else 0.1),
    }
}

func reward_compute_math_reward(verifiable_reward_manager_state state, int step, string input_text, string output_text, string expected_output) verifiable_reward_manager_state {
    verification_result verification = reward_verify_math(expected_output, output_text)
    float reward_value = 0.0
    if verification.is_correct {
        reward_value = 1.0
    } else {
        reward_value = -0.5
    }
    reward_sample sample = reward_sample {
        sample_id: state.sample_count,
        input_text: input_text,
        output_text: output_text,
        reward_value: reward_value,
        reward_type: VERIFIABLE,
        verification: verification,
        step: step,
    }
    state.history += []reward_sample{sample}
    state.sample_count = state.sample_count + 1
    int count = state.function_call_count["math"]
    state.function_call_count["math"] = count + 1
    state = reward_update_statistics(state)
    eprintln("[RewardManager] Math reward: " + reward_to_string(reward_value) + " (correct: " + (if verification.is_correct then "yes" else "no") + ")")
    state
}

func reward_compute_code_reward(verifiable_reward_manager_state state, int step, string input_text, string output_text, string expected_output) verifiable_reward_manager_state {
    verification_result verification = reward_verify_code(output_text, expected_output)
    float reward_value = 0.0
    if verification.is_correct {
        reward_value = 1.0
    } else if verification.is_valid {
        reward_value = 0.3
    } else {
        reward_value = -1.0
    }
    reward_sample sample = reward_sample {
        sample_id: state.sample_count,
        input_text: input_text,
        output_text: output_text,
        reward_value: reward_value,
        reward_type: VERIFIABLE,
        verification: verification,
        step: step,
    }
    state.history += []reward_sample{sample}
    state.sample_count = state.sample_count + 1
    int count = state.function_call_count["code"]
    state.function_call_count["code"] = count + 1
    state = reward_update_statistics(state)
    eprintln("[RewardManager] Code reward: " + reward_to_string(reward_value) + " (valid: " + (if verification.is_valid then "yes" else "no") + ")")
    state
}

func reward_compute_model_based(verifiable_reward_manager_state state, int step, string input_text, string output_text, float model_score) verifiable_reward_manager_state {
    reward_sample sample = reward_sample {
        sample_id: state.sample_count,
        input_text: input_text,
        output_text: output_text,
        reward_value: model_score,
        reward_type: MODEL_BASED,
        verification: verification_result{
            is_valid: true,
            is_correct: false,
            error_message: "model-based score",
            confidence: 0.8,
        },
        step: step,
    }
    state.history += []reward_sample{sample}
    state.sample_count = state.sample_count + 1
    int count = state.function_call_count["model_based"]
    state.function_call_count["model_based"] = count + 1
    state = reward_update_statistics(state)
    eprintln("[RewardManager] Model-based reward: " + reward_to_string(model_score))
    state
}

func reward_update_statistics(verifiable_reward_manager_state state) verifiable_reward_manager_state {
    if state.sample_count == 0 {
        return state
    }
    float sum_reward = 0.0
    for i in range(len(state.history)) {
        reward_sample sample = state.history[i]
        sum_reward = sum_reward + sample.reward_value
    }
    state.avg_reward = sum_reward / float(state.sample_count)
    float sum_sq_diff = 0.0
    for i in range(len(state.history)) {
        reward_sample sample = state.history[i]
        float diff = sample.reward_value - state.avg_reward
        sum_sq_diff = sum_sq_diff + (diff * diff)
    }
    if state.sample_count > 1 {
        state.reward_variance = sum_sq_diff / float(state.sample_count - 1)
    }
    state
}

func reward_get_verification_ratio(verifiable_reward_manager_state state) float {
    if state.sample_count == 0 {
        return 0.0
    }
    int verifiable_count = 0
    for i in range(len(state.history)) {
        reward_sample sample = state.history[i]
        if sample.reward_type == VERIFIABLE && sample.verification.is_valid {
            verifiable_count = verifiable_count + 1
        }
    }
    float(verifiable_count) / float(state.sample_count)
}

func reward_get_accuracy(verifiable_reward_manager_state state) float {
    if state.sample_count == 0 {
        return 0.0
    }
    int correct_count = 0
    int verifiable_count = 0
    for i in range(len(state.history)) {
        reward_sample sample = state.history[i]
        if sample.reward_type == VERIFIABLE {
            verifiable_count = verifiable_count + 1
            if sample.verification.is_correct {
                correct_count = correct_count + 1
            }
        }
    }
    if verifiable_count == 0 {
        return 0.0
    }
    float(correct_count) / float(verifiable_count)
}

func reward_get_report(verifiable_reward_manager_state state) string {
    string report = "[RewardManager] Report\n"
    report = report + "Total Samples: " + int_to_str_func(state.sample_count) + "\n"
    report = report + "Average Reward: " + float_to_str_func(state.avg_reward) + "\n"
    report = report + "Reward Variance: " + float_to_str_func(state.reward_variance) + "\n"
    report = report + "Verification Ratio: " + float_to_str_func(reward_get_verification_ratio(state)) + "\n"
    report = report + "Accuracy (Verifiable): " + float_to_str_func(reward_get_accuracy(state)) + "\n"
    report = report + "Function Calls:\n"
    []string keys = map_keys_func(state.function_call_count)
    for i in range(len(keys)) {
        string key = keys[i]
        int count = state.function_call_count[key]
        report = report + "  " + key + ": " + int_to_str_func(count) + "\n"
    }
    report
}

func reward_type_to_string(reward_type rt) string {
    if rt == MODEL_BASED {
        return "model-based"
    } else if rt == FUNCTION_BASED {
        return "function-based"
    } else if rt == VERIFIABLE {
        return "verifiable"
    }
    return "human-feedback"
}

func reward_to_string(float r) string {
    if r > 0.5 {
        return "high"
    } else if r > 0.0 {
        return "positive"
    } else if r < -0.5 {
        return "very-negative"
    } else if r < 0.0 {
        return "negative"
    }
    return "neutral"
}

func int_to_str_func(int n) string {
    ""
}

func float_to_str_func(float f) string {
    ""
}

func map_keys_func(map string = int m) []string {
    []string keys = []string{cap: 100}
    keys
}
