#!/usr/bin/env s

// ============================================
// NeurX tokenizer Framework
// Purpose: Tokenize training data for NeurX-level LLM training
// Language: S
// ============================================

package main

import (
    "io"
    "encoding/json"
    "math"
)

// tokenizer implements BPE-style tokenization
type tokenizer struct {
    vocab: map[string]int
    inv_vocab: map[int]string
    vocab_size: int
    special_tokens: map[string]int
}

// Initialize tokenizer with vocabulary
func (t *tokenizer) init(vocab_size: int) {
    t.vocab_size = vocab_size
    t.vocab = make(map[string]int)
    t.inv_vocab = make(map[int]string)
    
    // Initialize with special tokens
    t.special_tokens = map[string]int{
        "[PAD]": 0,
        "[UNK]": 1,
        "[BOS]": 2,
        "[EOS]": 3,
        "[CLS]": 4,
        "[SEP]": 5,
        "[MASK]": 6,
    }
    
    // Add special tokens to vocabulary
    idx := 0
    for token, id := range t.special_tokens {
        t.vocab[token] = id
        t.inv_vocab[id] = token
        idx = id + 1
    }
}

// Tokenize text into tokens
func (t *tokenizer) encode(text: string): []int {
    tokens := make([]int, 0)
    
    // Split into words
    words := split_whitespace(text)
    
    for _, word := range words {
        // Add BOS token at start
        if len(tokens) == 0 {
            tokens = append(tokens, t.special_tokens["[BOS]"])
        }
        
        // Convert word to sub-word tokens
        for _, ch := range word {
            if id, exists := t.vocab[string(ch)]; exists {
                tokens = append(tokens, id)
            } else {
                // Unknown character
                tokens = append(tokens, t.special_tokens["[UNK]"])
            }
        }
        
        // Add space token between words
        if id, exists := t.vocab[" "]; exists {
            tokens = append(tokens, id)
        }
    }
    
    // Add EOS token at end
    if len(tokens) > 0 {
        tokens = append(tokens, t.special_tokens["[EOS]"])
    }
    
    return tokens
}

// Decode tokens back to text
func (t *tokenizer) decode(tokens: []int): string {
    text := ""
    for _, token_id := range tokens {
        if token, exists := t.inv_vocab[token_id]; exists {
            text += token
        }
    }
    return text
}

// Calculate vocabulary statistics
func (t *tokenizer) vocab_stats(): map[string]interface{} {
    return map[string]interface{}{
        "vocab_size": t.vocab_size,
        "actual_vocab": len(t.vocab),
        "special_tokens": len(t.special_tokens),
        "coverage": float64(len(t.vocab)) / float64(t.vocab_size) * 100,
    }
}

// Tokenize batch of texts
func (t *tokenizer) encode_batch(texts: []string, max_length: int, padding: bool): [][]int {
    batch := make([][]int, len(texts))
    
    for i, text := range texts {
        tokens := t.encode(text)
        
        // Truncate if too long
        if len(tokens) > max_length {
            tokens = tokens[:max_length]
        }
        
        // Pad if requested
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

// Helper functions
func split_whitespace(s: string): []string {
    // Split string by whitespace
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

// Main execution
func main() {
    // Initialize tokenizer
    tokenizer := &tokenizer{}
    tokenizer.init(128000)  // Match NeurX vocab size
    
    // Example: Tokenize training data
    training_texts := []string{
        "Transformers have revolutionized natural language processing.",
        "Large language models require significant computational resources.",
    }
    
    // Encode batch
    batch := tokenizer.encode_batch(training_texts, 4096, true)
    
    // Print results
    for i, tokens := range batch {
        stats := map[string]interface{}{
            "text": training_texts[i],
            "token_count": len(tokens),
            "first_10_tokens": tokens[:min(10, len(tokens))],
        }
        
        json_data, _ := json.Marshal(stats)
        println(string(json_data))
    }
    
    // Print tokenizer statistics
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
