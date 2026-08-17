package neurx.tokenization.qwen
use neurx.util.string_utils.{string_split, string_contains, string_index_of}
int VOCAB_SIZE = 151643
int BOS_TOKEN_ID = 151643
int EOS_TOKEN_ID = 151645
int PAD_TOKEN_ID = 151643
int IM_START_ID = 151644
int IM_END_ID = 151645
string SPACE_TOKEN = "Ġ"
string NEWLINE_TOKEN = "Ċ"
struct TokenPair {
    string left
    string right
    int priority
}
struct VocabEntry {
    string token_str
    int token_id
}
[]TokenPair merge_rules = []TokenPair{cap: 50000}
int merge_rules_count = 0
[]VocabEntry vocab_cache = []VocabEntry{cap: 151700}
int vocab_cache_count = 0
bool tokenizer_initialized = false
func init_tokenizer() {
    if tokenizer_initialized {
        return
    }
    tokenizer_initialized = true
    load_merge_rules()
    load_vocabulary()
}
func load_merge_rules() {
    string model_dir = runtime_env_get("NEURX_MODEL_DIR", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    string merges_file = model_dir + "/merges.txt"
    string file_content = runtime_read_file(merges_file)
    if len(file_content) == 0 {
        return
    }
    []string lines = string_split(file_content, "\n")
    int i = 0
    merge_rules_count = 0
    while i < len(lines) && merge_rules_count < 49999 {
        string line = lines[i]
        if len(line) == 0 {
            i = i + 1
            continue
        }
        []string parts = string_split(line, " ")
        if len(parts) >= 2 {
            TokenPair rule = TokenPair{
                left: parts[0],
                right: parts[1],
                priority: i,
            }
            merge_rules[merge_rules_count] = rule
            merge_rules_count = merge_rules_count + 1
        }
        i = i + 1
    }
}
func load_vocabulary() {
    string model_dir = runtime_env_get("NEURX_MODEL_DIR", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    string vocab_file = model_dir + "/vocab.json"
    string json_content = runtime_read_file(vocab_file)
    if len(json_content) == 0 {
        return
    }
    parse_json_vocab(json_content)
}
func parse_json_vocab(string json_str) {
    vocab_cache_count = 0
    string content = json_str
    if len(content) > 2 && __host_slice(content, 0, 1) == "{" {
        content = __host_slice(content, 1, len(content) - 1)
    }
    []string entries = string_split(content, ",")
    int i = 0
    while i < len(entries) && vocab_cache_count < 151642 {
        string entry = entries[i]
        int colon_idx = string_index_of(entry, ":")
        if colon_idx > 0 {
            int first_quote = string_index_of(entry, "\"")
            int last_quote = string_last_index_of(entry, "\"")
            if first_quote >= 0 && last_quote > first_quote {
                string token_str = __host_slice(entry, first_quote + 1, last_quote)
                string id_str = __host_slice(entry, colon_idx + 1, len(entry))
                id_str = string_trim(id_str)
                int token_id = 0
                int j = 0
                while j < len(id_str) {
                    string ch = __host_slice(id_str, j, j + 1)
                    if ch >= "0" && ch <= "9" {
                        token_id = token_id * 10 + (int(ch[0]) - int("0"[0]))
                    }
                    j = j + 1
                }
                VocabEntry entry_obj = VocabEntry{
                    token_str: token_str,
                    token_id: token_id,
                }
                vocab_cache[vocab_cache_count] = entry_obj
                vocab_cache_count = vocab_cache_count + 1
            }
        }
        i = i + 1
    }
}
func string_last_index_of(string text, string ch) int {
    int last_idx = -1
    int i = 0
    while i < len(text) {
        if __host_slice(text, i, i + 1) == ch {
            last_idx = i
        }
        i = i + 1
    }
    return last_idx
}
func string_trim(string text) string {
    int start = 0
    int end = len(text)
    while start < end && (__host_slice(text, start, start + 1) == " " ||
                          __host_slice(text, start, start + 1) == "\t" ||
                          __host_slice(text, start, start + 1) == "\n" ||
                          __host_slice(text, start, start + 1) == "\r") {
        start = start + 1
    }
    while end > start && (__host_slice(text, end - 1, end) == " " ||
                          __host_slice(text, end - 1, end) == "\t" ||
                          __host_slice(text, end - 1, end) == "\n" ||
                          __host_slice(text, end - 1, end) == "\r") {
        end = end - 1
    }
    return __host_slice(text, start, end)
}
func vocab_lookup(string token_str) int {
    int i = 0
    while i < vocab_cache_count {
        if vocab_cache[i].token_str == token_str {
            return vocab_cache[i].token_id
        }
        i = i + 1
    }
    return -1
}
func vocab_reverse_lookup(int token_id) string {
    int i = 0
    while i < vocab_cache_count {
        if vocab_cache[i].token_id == token_id {
            return vocab_cache[i].token_str
        }
        i = i + 1
    }
    return ""
}
func encode_text_bpe(string text) []int {
    init_tokenizer()
    []int token_ids = []int{cap: 512}
    int token_count = 0
    token_ids[token_count] = BOS_TOKEN_ID
    token_count = token_count + 1
    []string word_pieces = tokenize_to_word_pieces(text)
    word_pieces = apply_bpe_merges(word_pieces)
    int i = 0
    while i < len(word_pieces) && token_count < 510 {
        int token_id = vocab_lookup(word_pieces[i])
        if token_id >= 0 {
            token_ids[token_count] = token_id
            token_count = token_count + 1
        }
        i = i + 1
    }
    if token_count < 511 {
        token_ids[token_count] = EOS_TOKEN_ID
        token_count = token_count + 1
    }
    return token_ids
}
func tokenize_to_word_pieces(string text) []string {
    []string pieces = []string{cap: 512}
    int piece_count = 0
    []string words = string_split(text, " ")
    int word_idx = 0
    while word_idx < len(words) && piece_count < 510 {
        string word = words[word_idx]
        if len(word) > 0 {
            if word_idx > 0 {
                pieces[piece_count] = SPACE_TOKEN + __host_slice(word, 0, 1)
                piece_count = piece_count + 1
                int char_idx = 1
                while char_idx < len(word) && piece_count < 510 {
                    pieces[piece_count] = __host_slice(word, char_idx, char_idx + 1)
                    piece_count = piece_count + 1
                    char_idx = char_idx + 1
                }
            } else {
                int char_idx = 0
                while char_idx < len(word) && piece_count < 510 {
                    pieces[piece_count] = __host_slice(word, char_idx, char_idx + 1)
                    piece_count = piece_count + 1
                    char_idx = char_idx + 1
                }
            }
        }
        word_idx = word_idx + 1
    }
    return pieces
}
func apply_bpe_merges([]string pieces) []string {
    []string result = pieces
    int merge_idx = 0
    while merge_idx < merge_rules_count {
        TokenPair rule = merge_rules[merge_idx]
        result = apply_single_merge(result, rule.left, rule.right)
        merge_idx = merge_idx + 1
    }
    return result
}
func apply_single_merge([]string pieces, string left, string right) []string {
    []string result = []string{cap: 512}
    int result_count = 0
    int i = 0
    while i < len(pieces) {
        if i < len(pieces) - 1 && pieces[i] == left && pieces[i + 1] == right {
            result[result_count] = left + right
            result_count = result_count + 1
            i = i + 2
        } else {
            result[result_count] = pieces[i]
            result_count = result_count + 1
            i = i + 1
        }
    }
    return result
}
func decode_tokens_bpe([]int token_ids) string {
    init_tokenizer()
    string result = ""
    if len(token_ids) == 0 {
        return ""
    }
    int i = 0
    while i < len(token_ids) {
        int token_id = token_ids[i]
        if token_id == BOS_TOKEN_ID || token_id == EOS_TOKEN_ID ||
           token_id == PAD_TOKEN_ID {
            i = i + 1
            continue
        }
        string token_str = vocab_reverse_lookup(token_id)
        if len(token_str) > 0 {
            if __host_slice(token_str, 0, 1) == SPACE_TOKEN {
                result = result + " "
                result = result + __host_slice(token_str, 1, len(token_str))
            } else if token_str == NEWLINE_TOKEN {
                result = result + "\n"
            } else {
                result = result + token_str
            }
        }
        i = i + 1
    }
    return result
}
extern "intrinsic" func __host_slice(string text, int start, int end) string
extern "intrinsic" func runtime_env_get(string key, string default_val) string
extern "intrinsic" func runtime_read_file(string path) string
extern "intrinsic" func print(string text) void
func test_qwen_tokenizer() {
    print("=== Qwen Tokenizer Test ===\n")
    string test_text = "你是"
    print("Input: " + test_text + "\n")
    []int tokens = encode_text_bpe(test_text)
    print("Tokens: [")
    int i = 0
    while i < len(tokens) && i < 20 {
        if i > 0 {
            print(", ")
        }
        print(int_to_string(tokens[i]))
        i = i + 1
    }
    print("]\n")
    string decoded = decode_tokens_bpe(tokens)
    print("Decoded: " + decoded + "\n")
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
