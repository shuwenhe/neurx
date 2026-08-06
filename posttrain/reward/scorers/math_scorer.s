package neurx.posttrain.reward.scorers.math

func compute_math_score(string solution_str, string ground_truth) float {
    string boxed = last_boxed_only_string(solution_str)
    if boxed == "" {
        return 0.0
    }
    string answer = remove_boxed(boxed)
    if is_equiv(answer, ground_truth) {
        return 1.0
    }
    return 0.0
}

func last_boxed_only_string(string s) string {
    int idx = find_last_substring(s, "\\boxed")
    if idx < 0 {
        idx = find_last_substring(s, "\\fbox")
        if idx < 0 {
            return ""
        }
    }
    int i = idx
    int right_brace_idx = -1
    int num_left_braces_open = 0
    int s_len = len(s)
    while i < s_len {
        int c = char_at(s, i)
        if c == 123 {
            num_left_braces_open = num_left_braces_open + 1
        }
        if c == 125 {
            num_left_braces_open = num_left_braces_open - 1
            if num_left_braces_open == 0 {
                right_brace_idx = i
                break
            }
        }
        i = i + 1
    }
    if right_brace_idx < 0 {
        return ""
    }
    return substring(s, idx, right_brace_idx + 1)
}

func remove_boxed(string s) string {
    string boxed_space = "\\boxed "
    if starts_with(s, boxed_space) {
        return substring(s, len(boxed_space), len(s))
    }
    string left = "\\boxed{"
    if starts_with(s, left) {
        return substring(s, len(left), len(s) - 1)
    }
    return s
}

func is_equiv(string str1, string str2) bool {
    string ss1 = strip_string(str1)
    string ss2 = strip_string(str2)
    return ss1 == ss2
}

func strip_string(string input) string {
    string result = input
    result = replace_all(result, "\n", "")
    result = replace_all(result, "\\!", "")
    result = replace_all(result, "\\\\", "\\")
    result = replace_all(result, "tfrac", "frac")
    result = replace_all(result, "dfrac", "frac")
    result = replace_all(result, "\\left", "")
    result = replace_all(result, "\\right", "")
    result = replace_all(result, "^{\\circ}", "")
    result = replace_all(result, "^\\circ", "")
    result = replace_all(result, "\\$", "")
    result = remove_units(result)
    result = replace_all(result, "\\%", "")
    result = replace_all(result, "%", "")
    result = replace_all(result, " .", " 0.")
    result = replace_all(result, "\"", "")
    result = fix_sqrt(result)
    result = replace_all(result, " ", "")
    result = fix_fracs(result)
    if result == "0.5" {
        result = "\\frac{1}{2}"
    }
    return result
}

func remove_units(string s) string {
    int idx = find_substring(s, "\\text{")
    if idx < 0 {
        return s
    }
    return substring(s, 0, idx)
}

func fix_sqrt(string s) string {
    return s
}

func fix_fracs(string s) string {
    return s
}

func find_last_substring(string s, string sub) int {
    int s_len = len(s)
    int sub_len = len(sub)
    int found = -1
    for int i = 0; i <= s_len - sub_len; i = i + 1 {
        if substring(s, i, i + sub_len) == sub {
            found = i
        }
    }
    return found
}

func find_substring(string s, string sub) int {
    int s_len = len(s)
    int sub_len = len(sub)
    for int i = 0; i <= s_len - sub_len; i = i + 1 {
        if substring(s, i, i + sub_len) == sub {
            return i
        }
    }
    return -1
}

func starts_with(string s, string prefix) bool {
    int prefix_len = len(prefix)
    if prefix_len > len(s) {
        return false
    }
    return substring(s, 0, prefix_len) == prefix
}

func replace_all(string s, string old_str, string new_str) string {
    if old_str == "" {
        return s
    }
    string result = ""
    int i = 0
    int s_len = len(s)
    int old_len = len(old_str)
    while i < s_len {
        if i <= s_len - old_len {
            if substring(s, i, i + old_len) == old_str {
                result = result + new_str
                i = i + old_len
                continue
            }
        }
        result = result + char_to_string(char_at(s, i))
        i = i + 1
    }
    return result
}

