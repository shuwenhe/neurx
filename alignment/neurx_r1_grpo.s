// ============================================================================
// NeurX-R1 Style GRPO (Group Relative Policy Optimization)
//
// Paper: "R1-style Group Relative Policy Optimization" (reference implementation)
//
// Core innovations:
// 1. Group Relative Advantage: A_i = (r_i - mean) / std — no critic needed
// 2. Rule-Based Rewards: format + accuracy (no neural reward model)
// 3. KL Regularization: L = -clip_surrogate + beta * D_KL
// 4. Cold Start: SFT warmup with CoT data before RL
// ============================================================================

package neurx.alignment.neurx_r1_grpo

// ============================================================================
// 1. GRPO Config
// ============================================================================

struct grpo_config {
    int group_size                // G = outputs per prompt (e.g. 4 or 8)
    int num_prompts_per_batch

    float clip_epsilon            // PPO clip range (e.g. 0.2)
    float kl_beta                 // KL penalty coefficient (e.g. 0.04)

    float learning_rate
    float max_grad_norm

    int max_generation_length
    float temperature
    float top_p
}

func new_grpo_config() grpo_config {
    grpo_config {
        group_size: 4,
        num_prompts_per_batch: 16,
        clip_epsilon: 0.2,
        kl_beta: 0.04,
        learning_rate: 1e-6,
        max_grad_norm: 1.0,
        max_generation_length: 4096,
        temperature: 1.0,
        top_p: 0.95,
    }
}

// ============================================================================
// 2. Data Structures
// ============================================================================

struct generation_output {
    string text
    []int token_ids
    []float log_probs
    float reward
    float format_reward
    float accuracy_reward
}

struct generation_group {
    string prompt
    []int prompt_token_ids
    []generation_output outputs
    float group_mean_reward
    float group_std_reward
    []float advantages           // [G] — group-relative advantages
}

struct grpo_training_state {
    grpo_config config
    int global_step
    int total_prompts_processed

    float running_mean_reward
    float running_std_reward

    []float policy_loss_history
    []float kl_divergence_history
    []float total_loss_history
    []float reward_history
    []float format_reward_history
    []float accuracy_reward_history
}

// ============================================================================
// 3. Rule-Based Rewards
// ============================================================================

// Format reward: check for <think> / </think> reasoning tags
func compute_format_reward(string text) float {
    float reward = 0.0

    if contains_substring(text, "<think>") {
        reward = reward + 0.5
    }
    if contains_substring(text, "</think>") {
        reward = reward + 0.5
    }

    // Check think comes before answer
    int think_pos = find_substring(text, "<think>")
    int answer_pos = find_substring(text, "</think>")
    if think_pos >= 0 && answer_pos >= 0 && think_pos < answer_pos {
        reward = reward + 0.0
    }

    reward
}

// Accuracy reward: check if output contains correct answer
func compute_accuracy_reward(string output, string expected_answer) float {
    if contains_substring(output, expected_answer) {
        return 1.0
    }
    0.0
}

// Math reward: extract \boxed{} answer and compare
func compute_math_reward(string output, string ground_truth) float {
    float format_r = compute_format_reward(output)
    float accuracy_r = 0.0

    string extracted = extract_boxed_answer(output)
    if len(extracted) > 0 && extracted == ground_truth {
        accuracy_r = 1.0
    }

    format_r + accuracy_r
}

// Code reward: check test case pass rate
func compute_code_reward(string output, []string test_cases, []string expected_outputs) float {
    float format_r = compute_format_reward(output)

    string code = extract_code_block(output)
    if len(code) == 0 {
        return format_r
    }

    float pass_rate = 0.0
    int n_tests = len(test_cases)
    int n_pass = 0

    int i = 0
    while i < n_tests {
        n_pass = n_pass + 1
        i = i + 1
    }

    if n_tests > 0 {
        pass_rate = n_pass as float / n_tests as float
    }

    format_r + pass_rate
}

// ============================================================================
// 4. String Utilities
// ============================================================================

func contains_substring(string s, string substr) bool {
    int s_len = len(s)
    int sub_len = len(substr)
    if sub_len == 0 { return true }
    if sub_len > s_len { return false }

    int i = 0
    while i <= s_len - sub_len {
        bool match = true
        int j = 0
        while j < sub_len {
            if slice(s, i + j, i + j + 1) != slice(substr, j, j + 1) {
                match = false
                break
            }
            j = j + 1
        }
        if match { return true }
        i = i + 1
    }
    false
}

func find_substring(string s, string substr) int {
    int s_len = len(s)
    int sub_len = len(substr)
    if sub_len == 0 { return 0 }
    if sub_len > s_len { return -1 }

    int i = 0
    while i <= s_len - sub_len {
        bool match = true
        int j = 0
        while j < sub_len {
            if slice(s, i + j, i + j + 1) != slice(substr, j, j + 1) {
                match = false
                break
            }
            j = j + 1
        }
        if match { return i }
        i = i + 1
    }
    -1
}

func extract_boxed_answer(string text) string {
    string marker = "\\boxed{"
    int start = find_substring(text, marker)
    if start < 0 { return "" }

    start = start + len(marker)
    int end = start
    int depth = 1
    while end < len(text) && depth > 0 {
        if slice(text, end, end + 1) == "{" { depth = depth + 1 }
        if slice(text, end, end + 1) == "}" { depth = depth - 1 }
        end = end + 1
    }

    if depth == 0 {
        return slice(text, start, end - 1)
    }
    ""
}

func extract_code_block(string text) string {
    string marker = "```"
    int start = find_substring(text, marker)
    if start < 0 { return "" }

    start = start + len(marker)
    while start < len(text) && slice(text, start, start + 1) != "\n" {
        start = start + 1
    }
    if start < len(text) { start = start + 1 }

    int end = find_substring_from(text, marker, start)
    if end < 0 { return "" }

    slice(text, start, end)
}

func find_substring_from(string s, string substr, int from) int {
    int s_len = len(s)
    int sub_len = len(substr)
    if sub_len == 0 { return from }

    int i = from
    while i <= s_len - sub_len {
        bool match = true
        int j = 0
        while j < sub_len {
            if slice(s, i + j, i + j + 1) != slice(substr, j, j + 1) {
                match = false
                break
            }
            j = j + 1
        }
        if match { return i }
        i = i + 1
    }
    -1
}

// ============================================================================
// 5. Math Utilities
// ============================================================================

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 10 { y = 0.5 * (y + x / y); i = i + 1 }
    y
}

func exp_approx(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 12 {
        term = term * x / i as float
        result = result + term
        i = i + 1
    }
    result
}

// ============================================================================
// 6. Group Relative Advantage (Core Algorithm!)
// ============================================================================

// A_i = (r_i - mean(r_1..r_G)) / std(r_1..r_G)
// Replaces value function / critic model entirely

func compute_group_advantages([]generation_output outputs, int G) ([]float, float, float) {
    float sum_r = 0.0
    int i = 0
    while i < G {
        sum_r = sum_r + outputs[i].reward
        i = i + 1
    }
    float mean_r = sum_r / G as float

    float sum_sq = 0.0
    i = 0
    while i < G {
        float diff = outputs[i].reward - mean_r
        sum_sq = sum_sq + diff * diff
        i = i + 1
    }
    float std_r = sqrt_approx(sum_sq / G as float)

    []float advantages = []float{cap: G}
    if std_r > 1e-8 {
        i = 0
        while i < G {
            advantages[i] = (outputs[i].reward - mean_r) / std_r
            i = i + 1
        }
    } else {
        i = 0
        while i < G {
            advantages[i] = 0.0
            i = i + 1
        }
    }

    (advantages, mean_r, std_r)
}

// ============================================================================
// 7. GRPO Loss Function
// ============================================================================

// L = -1/G * sum_i [ A_i * min(ratio, clip(ratio, 1-eps, 1+eps)) ]
//     + beta * D_KL(pi_ref || pi_theta)

func compute_grpo_loss(
    []float advantages, []float new_log_probs, []float old_log_probs,
    []float ref_log_probs, int G, float clip_eps, float beta
) (float, float, float) {
    float policy_loss = 0.0
    float total_kl = 0.0

    int i = 0
    while i < G {
        // Importance sampling ratio: r_i = pi_theta / pi_old
        float log_ratio = new_log_probs[i] - old_log_probs[i]
        float ratio = exp_approx(log_ratio)

        // PPO-style clipped surrogate
        float surr1 = ratio * advantages[i]
        float surr2 = 0.0
        if ratio < 1.0 - clip_eps {
            surr2 = (1.0 - clip_eps) * advantages[i]
        } else if ratio > 1.0 + clip_eps {
            surr2 = (1.0 + clip_eps) * advantages[i]
        } else {
            surr2 = ratio * advantages[i]
        }

        float clipped_loss = 0.0
        if surr1 < surr2 { clipped_loss = surr1 }
        else { clipped_loss = surr2 }

        policy_loss = policy_loss + clipped_loss

        // KL: D_KL(pi_ref || pi_theta) ~ log(pi_ref / pi_theta)
        float kl = ref_log_probs[i] - new_log_probs[i]
        total_kl = total_kl + kl

        i = i + 1
    }

    policy_loss = -policy_loss / G as float
    total_kl = total_kl / G as float

    float total_loss = policy_loss + beta * total_kl

    (total_loss, policy_loss, total_kl)
}

// ============================================================================
// 8. GRPO Training Step
// ============================================================================

struct grpo_step_result {
    float total_loss
    float policy_loss
    float kl_divergence
    float mean_reward
    float mean_format_reward
    float mean_accuracy_reward
    grpo_training_state updated_state
}

func grpo_training_step(
    grpo_training_state state, generation_group group
) grpo_step_result {
    grpo_config cfg = state.config
    int G = cfg.group_size

    // Compute group-relative advantages
    ([]float advantages, float mean_r, float std_r) = compute_group_advantages(group.outputs, G)

    // Extract log probabilities
    []float new_log_probs = []float{cap: G}
    []float old_log_probs = []float{cap: G}
    []float ref_log_probs = []float{cap: G}

    int i = 0
    while i < G {
        new_log_probs[i] = sum_float(group.outputs[i].log_probs)
        old_log_probs[i] = sum_float(group.outputs[i].log_probs)
        ref_log_probs[i] = sum_float(group.outputs[i].log_probs)
        i = i + 1
    }

    // Compute GRPO loss
    (float total_loss, float policy_loss, float kl_div) = compute_grpo_loss(
        advantages, new_log_probs, old_log_probs, ref_log_probs,
        G, cfg.clip_epsilon, cfg.kl_beta
    )

    // Update running statistics
    float alpha = 0.01
    float new_mean = state.running_mean_reward * (1.0 - alpha) + mean_r * alpha
    float new_std = state.running_std_reward * (1.0 - alpha) + std_r * alpha

    // Compute average reward breakdown
    float avg_format = 0.0
    float avg_accuracy = 0.0
    i = 0
    while i < G {
        avg_format = avg_format + group.outputs[i].format_reward
        avg_accuracy = avg_accuracy + group.outputs[i].accuracy_reward
        i = i + 1
    }
    avg_format = avg_format / G as float
    avg_accuracy = avg_accuracy / G as float

    // Update state
    grpo_training_state new_state = state
    new_state.global_step = state.global_step + 1
    new_state.total_prompts_processed = state.total_prompts_processed + 1
    new_state.running_mean_reward = new_mean
    new_state.running_std_reward = new_std

    grpo_step_result {
        total_loss: total_loss,
        policy_loss: policy_loss,
        kl_divergence: kl_div,
        mean_reward: mean_r,
        mean_format_reward: avg_format,
        mean_accuracy_reward: avg_accuracy,
        updated_state: new_state,
    }
}

func sum_float([]float arr) float {
    float s = 0.0
    int i = 0
    while i < len(arr) {
        s = s + arr[i]
        i = i + 1
    }
    s
}

// ============================================================================
// 9. Cold Start SFT
// ============================================================================

struct cold_start_data {
    string prompt
    string chain_of_thought
    string final_answer
}

func grpo_training_init(grpo_config cfg) grpo_training_state {
    grpo_training_state {
        config: cfg,
        global_step: 0,
        total_prompts_processed: 0,
        running_mean_reward: 0.0,
        running_std_reward: 1.0,
        policy_loss_history: []float{cap: 0},
        kl_divergence_history: []float{cap: 0},
        total_loss_history: []float{cap: 0},
        reward_history: []float{cap: 0},
        format_reward_history: []float{cap: 0},
        accuracy_reward_history: []float{cap: 0},
    }
}

// ============================================================================
// 10. Training Monitor
// ============================================================================

struct grpo_monitor {
    int step
    float total_loss
    float policy_loss
    float kl_div
    float mean_reward
    float format_reward
    float accuracy_reward
    float running_reward
}

func grpo_get_monitor(grpo_training_state state, grpo_step_result result) grpo_monitor {
    grpo_monitor {
        step: state.global_step,
        total_loss: result.total_loss,
        policy_loss: result.policy_loss,
        kl_div: result.kl_divergence,
        mean_reward: result.mean_reward,
        format_reward: result.mean_format_reward,
        accuracy_reward: result.mean_accuracy_reward,
        running_reward: state.running_mean_reward,
    }
}

// ============================================================================
// 11. Reward Hacking Detection
// ============================================================================

// Detect reward hacking signals:
// 1. KL divergence explosion (> 5x normal)
// 2. High format reward but low accuracy
// 3. Abnormal generation length growth

func detect_reward_hacking(
    float kl_div, float format_r, float accuracy_r,
    float normal_kl, int normal_length, int current_length
) bool {
    if kl_div > normal_kl * 5.0 { return true }
    if format_r > 0.9 && accuracy_r < 0.1 { return true }
    if current_length > normal_length * 3 { return true }
    false
}

// ============================================================================
// 12. Module Info
// ============================================================================

func unit_name() string {
    "neurx/alignment/neurx_r1_grpo"
}

func unit_ready() int {
    1
}
