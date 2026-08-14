// NeurX Tokenizers - Utility Functions
// Helper functions for tokenization operations

import "./types"
import "std/string"
import "std/vector"

// ============================================================================
// Text Processing Utilities
// ============================================================================

// NormalizeText - Normalize text for tokenization
func NormalizeText(text: string) string {
    // Remove leading/trailing whitespace
    text = trim_whitespace(text)
    
    // Normalize unicode
    text = normalize_unicode(text)
    
    return text
}

// TokensToString - Convert token IDs to readable string
func TokensToString(tokens: vec[i32], vocab: map[i32]string) string {
    result := ""
    
    for i := 0; i < len(tokens); i += 1 {
        if i > 0 {
            result = result + " "
        }
        
        if text, ok := vocab[tokens[i]]; ok {
            result = result + text
        } else {
            result = result + "<" + string_from_i32(tokens[i]) + ">"
        }
    }
    
    return result
}

// StringToTokens - Parse string to token IDs
func StringToTokens(text: string, vocab: map[string]i32) vec[i32] {
    tokens := make(vec[i32], 0)
    
    // Split by spaces
    parts := split_by_space(text)
    
    for i := 0; i < len(parts); i += 1 {
        part := parts[i]
        
        // Remove angle brackets if present
        if len(part) > 2 && part[0:1] == "<" && part[len(part)-1:] == ">" {
            part = part[1 : len(part)-1]
        }
        
        if id, ok := vocab[part]; ok {
            tokens = append(tokens, id)
        }
    }
    
    return tokens
}

// ============================================================================
// Token Sequence Analysis
// ============================================================================

// GetSequenceLength - Get length of token sequence
func GetSequenceLength(tokens: vec[i32]) i32 {
    return i32(len(tokens))
}

// GetTokenFrequency - Count frequency of each token
func GetTokenFrequency(tokens: vec[i32]) map[i32]i32 {
    freq := make(map[i32]i32)
    
    for i := 0; i < len(tokens); i += 1 {
        freq[tokens[i]] += 1
    }
    
    return freq
}

// GetMostFrequentTokens - Get N most frequent tokens
func GetMostFrequentTokens(tokens: vec[i32], top_n: i32) vec[i32] {
    freq := GetTokenFrequency(tokens)
    
    // Sort by frequency (simplified bubble sort)
    token_ids := make(vec[i32], 0)
    for id := range freq {
        token_ids = append(token_ids, id)
    }
    
    for i := 0; i < len(token_ids); i += 1 {
        for j := 0; j < len(token_ids)-1; j += 1 {
            if freq[token_ids[j]] < freq[token_ids[j+1]] {
                temp := token_ids[j]
                token_ids[j] = token_ids[j+1]
                token_ids[j+1] = temp
            }
        }
    }
    
    // Return top N
    if i32(len(token_ids)) > top_n {
        return token_ids[0:top_n]
    }
    
    return token_ids
}

// GetTokenEntropy - Calculate entropy of token distribution
func GetTokenEntropy(tokens: vec[i32]) f32 {
    if len(tokens) == 0 {
        return 0.0
    }
    
    freq := GetTokenFrequency(tokens)
    total := i32(len(tokens))
    entropy := f32(0.0)
    
    for _, count := range freq {
        p := f32(count) / f32(total)
        if p > 0.0 {
            entropy -= p * log2(p)
        }
    }
    
    return entropy
}

// GetUniqueTokenCount - Count unique tokens in sequence
func GetUniqueTokenCount(tokens: vec[i32]) i32 {
    unique := make(map[i32]bool)
    
    for i := 0; i < len(tokens); i += 1 {
        unique[tokens[i]] = true
    }
    
    return i32(len(unique))
}

// ============================================================================
// Padding and Truncation
// ============================================================================

// PadSequence - Pad sequence to length
func PadSequence(tokens: vec[i32], target_length: i32, pad_token_id: i32) vec[i32] {
    current_len := i32(len(tokens))
    
    if current_len >= target_length {
        return tokens
    }
    
    result := make(vec[i32], target_length)
    
    // Copy original tokens
    for i := 0; i < len(tokens); i += 1 {
        result[i] = tokens[i]
    }
    
    // Pad with pad_token_id
    for i := current_len; i < target_length; i += 1 {
        result[i] = pad_token_id
    }
    
    return result
}

// TruncateSequence - Truncate sequence to length
func TruncateSequence(tokens: vec[i32], max_length: i32) vec[i32] {
    if i32(len(tokens)) <= max_length {
        return tokens
    }
    
    return tokens[0:max_length]
}

// TruncateSequenceFromLeft - Truncate from left side
func TruncateSequenceFromLeft(tokens: vec[i32], max_length: i32) vec[i32] {
    if i32(len(tokens)) <= max_length {
        return tokens
    }
    
    start := len(tokens) - int(max_length)
    return tokens[start:]
}

// ============================================================================
// Token Comparison and Matching
// ============================================================================

// AreTokensEqual - Check if two sequences are equal
func AreTokensEqual(seq1: vec[i32], seq2: vec[i32]) bool {
    if len(seq1) != len(seq2) {
        return false
    }
    
    for i := 0; i < len(seq1); i += 1 {
        if seq1[i] != seq2[i] {
            return false
        }
    }
    
    return true
}

// FindSubsequence - Find position of subsequence in sequence
func FindSubsequence(haystack: vec[i32], needle: vec[i32]) i32 {
    if len(needle) == 0 || len(needle) > len(haystack) {
        return -1
    }
    
    for i := 0; i <= len(haystack)-len(needle); i += 1 {
        match := true
        for j := 0; j < len(needle); j += 1 {
            if haystack[i+j] != needle[j] {
                match = false
                break
            }
        }
        if match {
            return i32(i)
        }
    }
    
    return -1
}

// CountOccurrences - Count occurrences of subsequence
func CountOccurrences(haystack: vec[i32], needle: vec[i32]) i32 {
    count := i32(0)
    pos := i32(0)
    
    for {
        found_pos := FindSubsequence(haystack, needle)
        if found_pos == -1 {
            break
        }
        count += 1
        pos += found_pos + i32(len(needle))
        // Note: simplified, would need to search in remaining portion
    }
    
    return count
}

// ============================================================================
// Token Statistics
// ============================================================================

// GetSequenceStats - Get comprehensive statistics
func GetSequenceStats(tokens: vec[i32]) map[string]f32 {
    stats := make(map[string]f32)
    
    if len(tokens) == 0 {
        return stats
    }
    
    // Length stats
    stats["length"] = f32(len(tokens))
    stats["unique_tokens"] = f32(GetUniqueTokenCount(tokens))
    stats["diversity_ratio"] = stats["unique_tokens"] / stats["length"]
    
    // Token value stats
    min_token := tokens[0]
    max_token := tokens[0]
    sum_token := tokens[0]
    
    for i := 1; i < len(tokens); i += 1 {
        if tokens[i] < min_token {
            min_token = tokens[i]
        }
        if tokens[i] > max_token {
            max_token = tokens[i]
        }
        sum_token += tokens[i]
    }
    
    stats["min_token"] = f32(min_token)
    stats["max_token"] = f32(max_token)
    stats["avg_token_value"] = f32(sum_token) / f32(len(tokens))
    
    // Entropy
    stats["entropy"] = GetTokenEntropy(tokens)
    
    return stats
}

// ============================================================================
// Batch Operations
// ============================================================================

// PadBatch - Pad all sequences in batch to same length
func PadBatch(sequences: vec[vec[i32]], pad_token_id: i32) vec[vec[i32]] {
    // Find max length
    max_len := i32(0)
    for i := 0; i < len(sequences); i += 1 {
        if i32(len(sequences[i])) > max_len {
            max_len = i32(len(sequences[i]))
        }
    }
    
    // Pad all to max length
    result := make(vec[vec[i32]], len(sequences))
    for i := 0; i < len(sequences); i += 1 {
        result[i] = PadSequence(sequences[i], max_len, pad_token_id)
    }
    
    return result
}

// GetBatchLengths - Get lengths of all sequences
func GetBatchLengths(sequences: vec[vec[i32]]) vec[i32] {
    lengths := make(vec[i32], len(sequences))
    for i := 0; i < len(sequences); i += 1 {
        lengths[i] = i32(len(sequences[i]))
    }
    return lengths
}

// ============================================================================
// String Utilities
// ============================================================================

func trim_whitespace(s: string) string {
    start := 0
    end := len(s)
    
    // Trim from start
    for start < end && is_whitespace(string(s[start])) {
        start += 1
    }
    
    // Trim from end
    for end > start && is_whitespace(string(s[end-1])) {
        end -= 1
    }
    
    return s[start:end]
}

func normalize_unicode(s: string) string {
    // Simplified: just return as-is
    // Real implementation would do NFD/NFC normalization
    return s
}

func split_by_space(s: string) vec[string] {
    parts := make(vec[string], 0)
    current := ""
    
    for i := 0; i < len(s); i += 1 {
        if is_whitespace(string(s[i])) {
            if len(current) > 0 {
                parts = append(parts, current)
                current = ""
            }
        } else {
            current = current + string(s[i])
        }
    }
    
    if len(current) > 0 {
        parts = append(parts, current)
    }
    
    return parts
}

func is_whitespace(char: string) bool {
    return char == " " || char == "\t" || char == "\n" || char == "\r"
}

func string_from_i32(n: i32) string {
    if n == 0 {
        return "0"
    }
    
    result := ""
    num := n
    
    if num < 0 {
        result = "-"
        num = -num
    }
    
    // Simple number to string conversion
    digits := ""
    for num > 0 {
        digit := num % 10
        digits = string(digit + 48) + digits  // 48 is ASCII '0'
        num /= 10
    }
    
    return result + digits
}

func log2(x: f32) f32 {
    // Simplified log2 implementation
    // In real code would use math library
    if x <= 0.0 {
        return 0.0
    }
    return x  // Placeholder
}
