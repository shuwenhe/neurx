package neurx.posttrain.reward.scorers.gsm8k
use neurx.tensor
struct gsm8k_score_config {
    string method
    float format_score
    float correct_score
    int solution_clip_chars
}

func default_gsm8k_config() gsm8k_score_config {
    gsm8k_score_config {
        method: "strict",
        format_score: 0.0,
        correct_score: 1.0,
        solution_clip_chars: 300,
    }
}

func extract_gsm8k_solution(string solution_str, string method) string {
    string clipped = solution_str
    int slen = len(solution_str)
    if slen > 300 {
        clipped = substring(solution_str, slen - 300, slen)
    }
    if method == "strict" {
        return extract_strict_answer(clipped)
    }
    return extract_flexible_answer(clipped)
}

func extract_strict_answer(string text) string {
    int marker_pos = find_last_marker(text, "#### ")
    if marker_pos < 0 {
        return ""
    }
    string after_marker = substring(text, marker_pos + 5, len(text))
    string number = extract_leading_number(after_marker)
    return remove_commas_and_dollars(number)
}

func extract_flexible_answer(string text) string {
    string[] numbers = extract_all_numbers(text)
    for int i = len(numbers) - 1; i >= 0; i = i - 1 {
        string candidate = numbers[i]
        if candidate != "" && candidate != "." {
            return candidate
        }
    }
    return ""
}

func compute_gsm8k_score(
    string solution_str,
    string ground_truth,
    gsm8k_score_config config
) float {
    string answer = extract_gsm8k_solution(solution_str, config.method)
    if answer == "" {
        return 0.0
    }
    if answer == ground_truth {
        return config.correct_score
    }
    return config.format_score
}

func find_last_marker(string text, string marker) int {
    int text_len = len(text)
    int marker_len = len(marker)
    int last_pos = -1
    for int i = 0; i <= text_len - marker_len; i = i + 1 {
        if substring(text, i, i + marker_len) == marker {
            last_pos = i
        }
    }
    return last_pos
}

func extract_leading_number(string text) string {
    string result = ""
    int text_len = len(text)
    for int i = 0; i < text_len; i = i + 1 {
        string ch = substring(text, i, i + 1)
        if is_number_char(ch) {
            result = string_concat(result, ch)
        } else {
            break
        }
    }
    return result
}

func extract_all_numbers(string text) []string {
    string[] numbers = make(string[], 0)
    int text_len = len(text)
    string current = ""
    for int i = 0; i < text_len; i = i + 1 {
        string ch = substring(text, i, i + 1)
        if is_number_char(ch) {
            current = string_concat(current, ch)
        } else {
            if current != "" {
                numbers = append(numbers, remove_commas_and_dollars(current))
                current = ""
            }
        }
    }
    if current != "" {
        numbers = append(numbers, remove_commas_and_dollars(current))
    }
    return numbers
}

func is_number_char(string ch) bool {
    return ch == "0" || ch == "1" || ch == "2" || ch == "3" || ch == "4" || ch == "5" || ch == "6" || ch == "7" || ch == "8" || ch == "9" || ch == "." || ch == "," || ch == "-"
}

func remove_commas_and_dollars(string s) string {
    string result = ""
    int slen = len(s)
    for int i = 0; i < slen; i = i + 1 {
        string ch = substring(s, i, i + 1)
        if ch != "," && ch != "$" {
            result = string_concat(result, ch)
        }
    }
    return result
}

func string_concat(string a, string b) string {
    return a + b
}
