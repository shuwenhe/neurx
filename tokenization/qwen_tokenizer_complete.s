package neurx.tokenization.complete
int QWEN_BOS_ID = 151643
int QWEN_EOS_ID = 151645
int QWEN_PAD_ID = 151643
int QWEN_IM_START_ID = 151644
int QWEN_IM_END_ID = 151645

func tokenize_qwen(string text) []int {
    []int tokens = []int{cap: 512}
    int count = 0
    tokens[count] = QWEN_BOS_ID
    count = count + 1
    []string chunks = pretokenize(text)
    int i = 0
    while i < len(chunks) && count < 510 {
        []int chunk_tokens = encode_chunk(chunks[i])
        int j = 0
        while j < len(chunk_tokens) && count < 510 {
            tokens[count] = chunk_tokens[j]
            count = count + 1
            j = j + 1
        }
        i = i + 1
    }
    if count < 511 {
        tokens[count] = QWEN_EOS_ID
        count = count + 1
    }
    return tokens
}

func detokenize_qwen([]int token_ids) string {
    string result = ""
    if len(token_ids) == 0 {
        return ""
    }
    int i = 0
    while i < len(token_ids) {
        int token_id = token_ids[i]
        if token_id == QWEN_BOS_ID || token_id == QWEN_EOS_ID ||
           token_id == QWEN_PAD_ID || token_id == QWEN_IM_START_ID ||
           token_id == QWEN_IM_END_ID {
            i = i + 1
            continue
        }
        string token_str = lookup_token_string(token_id)
        if len(token_str) > 0 {
            if __host_slice(token_str, 0, 2) == "Ġ" {
                if len(result) > 0 {
                    result = result + " "
                }
                result = result + __host_slice(token_str, 1, len(token_str))
            } else if token_str == "Ċ" {
                result = result + "\n"
            } else {
                result = result + token_str
            }
        }
        i = i + 1
    }
    return result
}

func pretokenize(string text) []string {
    []string chunks = []string{cap: 512}
    int chunk_count = 0
    int i = 0
    int word_start = 0
    while i <= len(text) {
        string ch = ""
        if i < len(text) {
            ch = __host_slice(text, i, i + 1)
        }
        bool is_space = (ch == " " || ch == "\t" || ch == "\n" || ch == "\r" || i == len(text))
        if is_space && i > word_start {
            string word = __host_slice(text, word_start, i)
            if len(word) > 0 {
                chunks[chunk_count] = word
                chunk_count = chunk_count + 1
            }
            word_start = i + 1
        }
        i = i + 1
    }
    return chunks
}

func encode_chunk(string chunk) []int {
    []int result = []int{cap: 64}
    int result_count = 0
    if len(chunk) == 0 {
        return result
    }
    int direct_id = lookup_token_id(chunk)
    if direct_id >= 0 {
        result[0] = direct_id
        return result
    }
    int i = 0
    while i < len(chunk) && result_count < 64 {
        int best_len = 1
        int best_id = -1
        int try_len = min_int(8, len(chunk) - i)
        while try_len >= 1 {
            string subtoken = __host_slice(chunk, i, i + try_len)
            string lookup_str = subtoken
            if i == 0 && result_count == 0 {
                lookup_str = "Ġ" + subtoken
            }
            int token_id = lookup_token_id(lookup_str)
            if token_id >= 0 {
                best_len = try_len
                best_id = token_id
                break
            }
            try_len = try_len - 1
        }
        if best_id >= 0 {
            result[result_count] = best_id
        } else {
            string ch = __host_slice(chunk, i, i + 1)
            int ascii = int(ch[0])
            result[result_count] = 100 + (ascii % 100)
        }
        result_count = result_count + 1
        i = i + best_len
    }
    return result
}
[]string common_tokens = [
    "Ġa", "Ġthe", "Ġand", "Ġto", "Ġof", "Ġin", "Ġis", "Ġthat",
    "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",",
    ".", "/", ":", ";", "?", " ", "a", "b", "c", "d", "e", "f", "g",
    "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
    "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G",
]
[]int common_token_ids = [
    261, 262, 263, 264, 265, 266, 267, 268,
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
    12, 13, 14, 15, 16, 17, 32, 97, 98, 99, 100, 101, 102, 103,
    104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116,
    117, 118, 119, 120, 121, 122, 65, 66, 67, 68, 69, 70, 71,
]

func lookup_token_id(string token_str) int {
    int i = 0
    while i < len(common_tokens) {
        if common_tokens[i] == token_str {
            return common_token_ids[i]
        }
        i = i + 1
    }
    return lookup_token_id_from_python(token_str)
}

func lookup_token_id_from_python(string token_str) int {
    string script_path = "/home/shuwen/shuwen/posttrain/tokenize_detokenize.py"
    string escaped = token_str
    string cmd = "python3 '" + script_path + "' lookup '" + escaped + "' 2>/dev/null"
    string output = runtime_run_command_output(cmd)
    if len(output) > 0 {
        return string_to_int(output)
    }
    return -1
}

func lookup_token_string(int token_id) string {
    string script_path = "/home/shuwen/shuwen/posttrain/tokenize_detokenize.py"
    string id_str = int_to_string(token_id)
    string cmd = "python3 '" + script_path + "' lookup-id '" + id_str + "' 2>/dev/null"
    string output = runtime_run_command_output(cmd)
    return output
}

func min_int(int a, int b) int {
    if a < b {
        return a
    }
    return b
}

func int_to_string(int num) string {
    if num == 0 {
        return "0"
    }
    string result = ""
    int n = num
    if n < 0 {
        result = "-"
        n = -n
    }
    string digits = "0123456789"
    int temp = n
    int digit_count = 0
    while temp > 0 {
        digit_count = digit_count + 1
        temp = temp / 10
    }
    int idx = 0
    while idx < digit_count {
        int power = 1
        int p = digit_count - idx - 1
        int count_p = 0
        while count_p < p {
            power = power * 10
            count_p = count_p + 1
        }
        int digit = (n / power) % 10
        result = result + __host_slice(digits, digit, digit + 1)
        idx = idx + 1
    }
    return result
}

func string_to_int(string text) int {
    int result = 0
    int i = 0
    int start = 0
    bool negative = false
    if len(text) > 0 && __host_slice(text, 0, 1) == "-" {
        negative = true
        start = 1
    }
    i = start
    while i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        if ch >= "0" && ch <= "9" {
            result = result * 10 + (int(ch[0]) - int("0"[0]))
        }
        i = i + 1
    }
    if negative {
        result = -result
    }
    return result
}
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func runtime_run_command_output(string cmd) string
extern "intrinsic" func print(string msg) void
