package main
import (
    "io"
    "encoding/json"
    "math"
)
type tokenizer struct {
    vocab: map[string]int
    inv_vocab: map[int]string
    vocab_size: int
    special_tokens: map[string]int
}

func (t *tokenizer) init(vocab_size: int) {
    t.vocab_size = vocab_size
    t.vocab = make(map[string]int)
    t.inv_vocab = make(map[int]string)
    t.special_tokens = map[string]int{
        "[PAD]": 0,
        "[UNK]": 1,
        "[BOS]": 2,
        "[EOS]": 3,
        "[CLS]": 4,
        "[SEP]": 5,
        "[MASK]": 6,
    }
    idx := 0
    for token, id := range t.special_tokens {
        t.vocab[token] = id
        t.inv_vocab[id] = token
        idx = id + 1
    }
}

func (t *tokenizer) encode(text: string): []int {
    tokens := make([]int, 0)
    words := split_whitespace(text)
    for _, word := range words {
        if len(tokens) == 0 {
            tokens = append(tokens, t.special_tokens["[BOS]"])
        }
        for _, ch := range word {
            if id, exists := t.vocab[string(ch)]; exists {
                tokens = append(tokens, id)
            } else {
                tokens = append(tokens, t.special_tokens["[UNK]"])
            }
        }
        if id, exists := t.vocab[" "]; exists {
            tokens = append(tokens, id)
        }
    }
    if len(tokens) > 0 {
        tokens = append(tokens, t.special_tokens["[EOS]"])
    }
    return tokens
}

func (t *tokenizer) decode(tokens: []int): string {
    text := ""
    for _, token_id := range tokens {
        if token, exists := t.inv_vocab[token_id]; exists {
            text += token
        }
    }
    return text
}

func (t *tokenizer) vocab_stats(): map[string]interface{} {
    return map[string]interface{}{
        "vocab_size": t.vocab_size,
        "actual_vocab": len(t.vocab),
        "special_tokens": len(t.special_tokens),
        "coverage": float64(len(t.vocab)) / float64(t.vocab_size) * 100,
    }
}

func (t *tokenizer) encode_batch(texts: []string, max_length: int, padding: bool): [][]int {
    batch := make([][]int, len(texts))
    for i, text := range texts {
        tokens := t.encode(text)
        if len(tokens) > max_length {
            tokens = tokens[:max_length]
        }
        if padding && len(tokens) < max_length {
            pad_token := t.special_tokens["[PAD]"]
            for len(tokens) < max_length {
                tokens = append(tokens, pad_token)
            }
        }
        batch[i] = tokens
    }
    return batch
}

func split_whitespace(s: string): []string {
    result := make([]string, 0)
    current := ""
    for _, ch := range s {
        if ch == ' ' || ch == '\t' || ch == '\n' {
            if current != "" {
                result = append(result, current)
                current = ""
            }
        } else {
            current += string(ch)
        }
    }
    if current != "" {
        result = append(result, current)
    }
    return result
}

func main() {
    tokenizer := &tokenizer{}
    tokenizer.init(128000)
    training_texts := []string{
        "Transformers have revolutionized natural language processing.",
        "Large language models require significant computational resources.",
    }
    batch := tokenizer.encode_batch(training_texts, 4096, true)
    for i, tokens := range batch {
        stats := map[string]interface{}{
            "text": training_texts[i],
            "token_count": len(tokens),
            "first_10_tokens": tokens[:min(10, len(tokens))],
        }
        json_data, _ := json.Marshal(stats)
        println(string(json_data))
    }
    vocab_stats := tokenizer.vocab_stats()
    stats_json, _ := json.Marshal(vocab_stats)
    println("tokenizer Stats:", string(stats_json))
}

func min(a, b: int): int {
    if a < b {
        return a
    }
    return b
}
