package neurx.posttrain.reward.verifiable
use neurx.tensor.{tensor}
struct math_problem {
    string question
    string answer
    string problem_type
}
struct code_problem {
    string description
    string test_cases
    string expected_output
    string language
}
struct verification_result {
    bool correct
    float reward
    string error_message
    []string intermediate_steps
}
func verify_math_solution(
    math_problem problem,
    string solution
) verification_result {
    string cleaned_solution = trim_whitespace(solution)
    string extracted_answer = extract_final_answer(cleaned_solution)
    bool is_correct = compare_math_answers(
        extracted_answer,
        problem.answer
    )
    float reward = 0.0
    if is_correct {
        reward = 1.0
    }
    []string steps = extract_reasoning_steps(cleaned_solution)
    float step_reward = evaluate_reasoning_steps(steps, problem)
    float total_reward = 0.5 * reward + 0.5 * step_reward
    verification_result {
        correct: is_correct,
        reward: total_reward,
        error_message: "",
        intermediate_steps: steps,
    }
}
func verify_code_solution(
    code_problem problem,
    string code
) verification_result {
    (bool success, string output, string error) = run_code_sandbox(
        code,
        problem.language,
        problem.test_cases
    )
    if !success {
        return verification_result {
            correct: false,
            reward: 0.0,
            error_message: error,
            intermediate_steps: []string{},
        }
    }
    bool correct = output == problem.expected_output
    float reward = 0.0
    if correct {
        reward = 1.0
    } else {
        reward = compute_output_similarity(output, problem.expected_output)
    }
    verification_result {
        correct: correct,
        reward: reward,
        error_message: "",
        intermediate_steps: []string{},
    }
}
func extract_final_answer(string solution) string {
    string answer = ""
    if contains(solution, "\\boxed{") {
        int start = index_of(solution, "\\boxed{") + 7
        int end = index_of_from(solution, "}", start)
        answer = substring(solution, start, end)
        return answer
    }
    if contains(solution, "answer is") {
        int start = index_of(solution, "answer is") + 10
        answer = extract_next_value(solution, start)
        return answer
    }
    if contains(solution, "=") {
        int last_eq = last_index_of(solution, "=")
        answer = extract_next_value(solution, last_eq + 1)
        return answer
    }
    answer
}
func compare_math_answers(string answer1, string answer2) bool {
    string norm1 = normalize_math_expression(answer1)
    string norm2 = normalize_math_expression(answer2)
    if norm1 == norm2 {
        return true
    }
    (bool is_num1, float val1) = try_parse_number(norm1)
    (bool is_num2, float val2) = try_parse_number(norm2)
    if is_num1 && is_num2 {
        float diff = val1 - val2
        if diff < 0.0 {
            diff = -diff
        }
        return diff < 0.001
    }
    false
}
func normalize_math_expression(string expr) string {
    string result = expr
    result = remove_all(result, " ")
    result = remove_all(result, "\t")
    result = remove_all(result, "\n")
    result = to_lower(result)
    result = replace_all(result, "\\frac", "")
    result = replace_all(result, "\\sqrt", "sqrt")
    result
}
func extract_reasoning_steps(string solution) []string {
    []string steps = []string{}
    []string lines = split(solution, "\n")
    int i = 0
    while i < lines.len {
        string line = trim_whitespace(lines[i])
        if len(line) > 10 {
            steps[steps.len] = line
        }
        i = i + 1
    }
    steps
}
func evaluate_reasoning_steps(
    []string steps,
    math_problem problem
) float {
    if steps.len == 0 {
        return 0.0
    }
    int valid_steps = 0
    int i = 0
    while i < steps.len {
        bool has_math = contains(steps[i], "=") ||
                       contains(steps[i], "+") ||
                       contains(steps[i], "-") ||
                       contains(steps[i], "*") ||
                       contains(steps[i], "/")
        if has_math {
            valid_steps = valid_steps + 1
        }
        i = i + 1
    }
    float score = (valid_steps * 1.0) / (steps.len * 1.0)
    score
}
func run_code_sandbox(
    string code,
    string language,
    string test_cases
) (bool, string, string) {
    (true, "", "")
}
func compute_output_similarity(string output, string expected) float {
    if output == expected {
        return 1.0
    }
    int matches = 0
    int total = expected.len
    int i = 0
    while i < expected.len && i < output.len {
        if expected[i] == output[i] {
            matches = matches + 1
        }
        i = i + 1
    }
    (matches * 1.0) / (total * 1.0)
}
func trim_whitespace(string s) string { s }

func contains(string s, string sub) bool { false }

func index_of(string s, string sub) int { 0 }

func index_of_from(string s, string sub, int from) int { 0 }

func last_index_of(string s, string sub) int { 0 }

func substring(string s, int start, int end) string { s }

func extract_next_value(string s, int pos) string { "" }

func remove_all(string s, string sub) string { s }

func to_lower(string s) string { s }

func replace_all(string s, string old, string new) string { s }

func split(string s, string delim) []string { []string{} }

func len(string s) int { 0 }

func try_parse_number(string s) (bool, float) { (false, 0.0) }
