package neurx.tokenization
use neurx.runtime.io.{runtime_run_command_output, runtime_file_exists, runtime_env_get}

struct TokenizerConfig {
    int vocab_size
    string vocab_path
    string model_dir
}
[]string cached_vocab_items = []string{cap: 151700}
[]int cached_vocab_ids = []int{cap: 151700}
int cached_vocab_count = 0
bool vocab_loaded = false

func init_tokenizer_config() TokenizerConfig {
    string model_dir = runtime_env_get("NEURX_MODEL_DIR", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    TokenizerConfig config = TokenizerConfig{
        vocab_size: 151643,
        vocab_path: model_dir + "/vocab.json",
        model_dir: model_dir,
    }
    return config
}

func encode_text(string text) []int {
    string model_dir = runtime_env_get("NEURX_MODEL_DIR", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    string script_path = "/home/shuwen/shuwen/posttrain/tokenize_detokenize.py"
    string escaped_text = text
    string cmd = "python3 '" + script_path + "' encode '" + escaped_text + "' 2>/dev/null"
    string output = runtime_run_command_output(cmd)
    []int tokens = []int{cap: 512}
    if len(output) == 0 {
        tokens[0] = 1
        return tokens
    }
    int count = 0
    int i = 0
    int token_start = 0
    int output_len = len(output)
    while i <= output_len && count < 512 {
        string ch = " "
        if i < output_len {
            ch = __host_slice(output, i, i + 1)
        }
        if (ch == " " || i == output_len) && i > token_start {
            string num_str = __host_slice(output, token_start, i)
            int token_id = 0
            int j = 0
            while j < len(num_str) {
                string digit = __host_slice(num_str, j, j + 1)
                if digit >= "0" && digit <= "9" {
                    token_id = token_id * 10 + (int(digit[0]) - int("0"[0]))
                }
                j = j + 1
            }
            if token_id >= 0 && token_id < 151644 && count < 512 {
                tokens[count] = token_id
                count = count + 1
            }
            token_start = i + 1
        }
        i = i + 1
    }
    if count == 0 {
        tokens[0] = 1
    }
    return tokens
}

func decode_tokens([]int token_ids) string {
    string model_dir = runtime_env_get("NEURX_MODEL_DIR", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    string script_path = "/home/shuwen/shuwen/posttrain/tokenize_detokenize.py"
    if len(token_ids) == 0 {
        return ""
    }
    string token_list = ""
    int i = 0
    while i < len(token_ids) && i < 512 {
        if i > 0 {
            token_list = token_list + " "
        }
        token_list = token_list + int_to_string(token_ids[i])
        i = i + 1
    }
    string cmd = "python3 '" + script_path + "' decode '" + token_list + "' 2>/dev/null"
    string output = runtime_run_command_output(cmd)
    if len(output) > 0 {
        return output
    }
    return "[Decode failed]"
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

func test_tokenizer() {
    string test_input = "你是"
    print("[Tokenizer] Input: " + test_input + "\n")
    []int tokens = encode_text(test_input)
    print("[Tokenizer] Tokens: [")
    int i = 0
    while i < len(tokens) && tokens[i] > 0 {
        if i > 0 {
            print(", ")
        }
        print(int_to_string(tokens[i]))
        i = i + 1
    }
    print("]\n")
    string decoded = decode_tokens(tokens)
    print("[Tokenizer] Decoded: " + decoded + "\n")
}
