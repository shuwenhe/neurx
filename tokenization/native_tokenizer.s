package neurx.tokenization.native

struct UnicodeMap {
    int from_byte1
    int from_byte2
    int from_byte3
    int token_id
}
[]UnicodeMap unicode_table = []UnicodeMap{cap: 1000}
int unicode_table_size = 0

func init_unicode_table() {
    unicode_table_size = 0
}

func simple_tokenize(string text) []int {
    []int tokens = []int{cap: 512}
    int token_count = 0
    tokens[token_count] = 1
    token_count = token_count + 1
    int i = 0
    int text_len = len(text)
    while i < text_len && token_count < 510 {
        string byte_char = __host_slice(text, i, i + 1)
        int ascii_val = int(byte_char[0])
        if ascii_val >= 32 && ascii_val <= 126 {
            tokens[token_count] = ascii_val + 10
        } else if ascii_val > 127 {
            tokens[token_count] = 1000 + (ascii_val % 256)
        } else {
            i = i + 1
            continue
        }
        token_count = token_count + 1
        i = i + 1
    }
    if token_count < 510 {
        tokens[token_count] = 2
        token_count = token_count + 1
    }
    return tokens
}

func simple_detokenize([]int token_ids) string {
    string result = ""
    if len(token_ids) == 0 {
        return ""
    }
    int i = 0
    while i < len(token_ids) {
        int token_id = token_ids[i]
        if token_id == 1 || token_id == 2 {
            i = i + 1
            continue
        }
        if token_id >= 10 && token_id < 137 {
            int ascii_val = token_id - 10
            string ch = ""
            if ascii_val == 32 {
                ch = " "
            } else if ascii_val >= 48 && ascii_val <= 57 {
                ch = __host_slice("0123456789", ascii_val - 48, ascii_val - 47)
            } else if ascii_val >= 65 && ascii_val <= 90 {
                ch = __host_slice("ABCDEFGHIJKLMNOPQRSTUVWXYZ", ascii_val - 65, ascii_val - 64)
            } else if ascii_val >= 97 && ascii_val <= 122 {
                ch = __host_slice("abcdefghijklmnopqrstuvwxyz", ascii_val - 97, ascii_val - 96)
            }
            result = result + ch
        } else if token_id >= 1000 && token_id < 1256 {
            result = result + "[T" + int_to_string(token_id) + "]"
        }
        i = i + 1
    }
    return result
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

func load_vocab_from_python(string vocab_path) []string {
    string cmd = "python3 -c \"import json; v = json.load(open('" + vocab_path + "')); print(' '.join(v.keys()))\" 2>/dev/null"
    string output = runtime_run_command_output(cmd)
    []string vocab = []string{cap: 151700}
    return vocab
}
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func runtime_run_command_output(string cmd) string
