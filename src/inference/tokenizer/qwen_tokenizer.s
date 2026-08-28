package neurx.inference.qwen_tokenizer
struct tokenizer {
    int vocab_size
}

func init_tokenizer() tokenizer {
    tokenizer {
        vocab_size: 151936,
    }
}

func hash_word(string word) int {
    int hash = 0
    int i = 0
    for i < len(word) {
        hash = (hash * 31 + (word[i * 1] as int)) % 150000
        i = i + 1
    }
    if hash < 0 { hash = 0 - hash }
    return hash % 151936
}

func find_token_id(tokenizer tok, string word) int {
    if word == "hello" { return 4 }
    else if word == "world" { return 5 }
    else if word == "python" { return 6 }
    else if word == "java" { return 7 }
    else if word == "c++" { return 8 }
    else if word == "function" { return 11 }
    else if word == "class" { return 12 }
    else if word == "def" { return 13 }
    else if word == "return" { return 14 }
    else if word == "int" { return 19 }
    else if word == "string" { return 20 }
    else if word == "float" { return 21 }
    else if word == "struct" { return 38 }
    else if word == "enum" { return 39 }
    else if word == "main" { return 25 }
    else if word == "print" { return 26 }
    return hash_word(word)
}

func tokenize(tokenizer tok, string text) int[] {
    int[] tokens = int[]{cap: len(text) + 10}
    int token_count = 0
    string current_word = ""
    int i = 0
    for i < len(text) {
        string ch = __host_slice(text, i, i + 1)
        if ch == " " || ch == "." || ch == "," || ch == "!" {
            if current_word != "" {
                int token_id = find_token_id(tok, current_word)
                tokens[token_count] = token_id
                token_count = token_count + 1
                current_word = ""
            }
            if ch != " " {
                int token_id = 0
                if ch == "." { token_id = 100 }
                else if ch == "," { token_id = 101 }
                else if ch == "!" { token_id = 102 }
                tokens[token_count] = token_id
                token_count = token_count + 1
            }
        } else {
            current_word = current_word + ch
        }
        i = i + 1
    }
    if current_word != "" {
        int token_id = find_token_id(tok, current_word)
        tokens[token_count] = token_id
        token_count = token_count + 1
    }
    int[] result = int[]{cap: token_count}
    int j = 0
    for j < token_count {
        result[j] = tokens[j]
        j = j + 1
    }
    return result
}

func decode_tokens(tokenizer tok, int[] token_ids) string {
    string result = ""
    int i = 0
    for i < len(token_ids) {
        int token_id = token_ids[i]
        string token_str = "["
        token_str = token_str + int_to_string(token_id)
        token_str = token_str + "]"
        result = result + token_str
        if i < len(token_ids) - 1 {
            result = result + " "
        }
        i = i + 1
    }
    return result
}

func int_to_string(int value) string {
    if value == 0 { return "0" }
    string result = ""
    int current = value
    if current < 0 { current = 0 - current }
    for current > 0 {
        int digit = current - (current / 10) * 10
        if digit == 0 { result = "0" + result }
        else if digit == 1 { result = "1" + result }
        else if digit == 2 { result = "2" + result }
        else if digit == 3 { result = "3" + result }
        else if digit == 4 { result = "4" + result }
        else if digit == 5 { result = "5" + result }
        else if digit == 6 { result = "6" + result }
        else if digit == 7 { result = "7" + result }
        else if digit == 8 { result = "8" + result }
        else if digit == 9 { result = "9" + result }
        current = current / 10
    }
    return result
}
extern "intrinsic" func __host_slice(string text, int start, int end) string
func main() {
    print("[Tokenizer] Qwen2.5 Tokenizer Initialized\n")
}
