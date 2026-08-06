package step1_tokenizer

struct qwen_tokenizer {
    int vocab_size
}

func create_qwen_tokenizer() qwen_tokenizer {
    return qwen_tokenizer{
        vocab_size: 151936
    }
}

func simple_tokenize(string text) []int {
    []int tokens = make([]int, 0)
    append(tokens, 151644)
    int i = 0
    while i < len(text) {
        append(tokens, 256 + i)
        i = i + 1
    }
    append(tokens, 151645)
    return tokens
}

func simple_decode([]int tokens) string {
    return ""
}

func tokenize(string text) []int {
    return simple_tokenize(text)
}

func decode([]int tokens) string {
    return simple_decode(tokens)
}

