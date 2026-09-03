import "./types"
import "std/string"
import "std/vector"
func NormalizeText(string text) string {
    text = trim_whitespace(text)
    text = normalize_unicode(text)
    return text
}

func TokensToString(i32[] tokens, map[i32]string vocab) string {
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

func StringToTokens(string text, map[string]i32 vocab) []i32 {
    tokens := make(i32[], 0)
    parts := split_by_space(text)
    for i := 0; i < len(parts); i += 1 {
        part := parts[i]
        if len(part) > 2 && part[0:1] == "<" && part[len(part)-1:] == ">" {
            part = part[1 : len(part)-1]
        }
        if id, ok := vocab[part]; ok {
            tokens = append(tokens, id)
        }
    }
    return tokens
}

func GetSequenceLength(i32[] tokens) i32 {
    return i32(len(tokens))
}

func GetTokenFrequency(i32[] tokens) map[i32]i32 {
    freq := make(map[i32]i32)
    for i := 0; i < len(tokens); i += 1 {
        freq[tokens[i]] += 1
    }
    return freq
}

func GetMostFrequentTokens(i32[] tokens, i32 top_n) []i32 {
    freq := GetTokenFrequency(tokens)
    token_ids := make(i32[], 0)
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
    if i32(len(token_ids)) > top_n {
        return token_ids[0:top_n]
    }
    return token_ids
}

func GetTokenEntropy(i32[] tokens) f32 {
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

func GetUniqueTokenCount(i32[] tokens) i32 {
    unique := make(map[i32]bool)
    for i := 0; i < len(tokens); i += 1 {
        unique[tokens[i]] = true
    }
    return i32(len(unique))
}

func PadSequence(i32[] tokens, i32 target_length, i32 pad_token_id) []i32 {
    current_len := i32(len(tokens))
    if current_len >= target_length {
        return tokens
    }
    result := make(i32[], target_length)
    for i := 0; i < len(tokens); i += 1 {
        result[i] = tokens[i]
    }
    for i := current_len; i < target_length; i += 1 {
        result[i] = pad_token_id
    }
    return result
}

func TruncateSequence(i32[] tokens, i32 max_length) []i32 {
    if i32(len(tokens)) <= max_length {
        return tokens
    }
    return tokens[0:max_length]
}

func TruncateSequenceFromLeft(i32[] tokens, i32 max_length) []i32 {
    if i32(len(tokens)) <= max_length {
        return tokens
    }
    start := len(tokens) - int(max_length)
    return tokens[start:]
}

func AreTokensEqual(i32[] seq1, i32[] seq2) bool {
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

func FindSubsequence(i32[] haystack, i32[] needle) i32 {
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

func CountOccurrences(i32[] haystack, i32[] needle) i32 {
    count := i32(0)
    pos := i32(0)
    for {
        found_pos := FindSubsequence(haystack, needle)
        if found_pos == -1 {
            break
        }
        count += 1
        pos += found_pos + i32(len(needle))
    }
    return count
}

func GetSequenceStats(i32[] tokens) map[string]f32 {
    stats := make(map[string]f32)
    if len(tokens) == 0 {
        return stats
    }
    stats["length"] = f32(len(tokens))
    stats["unique_tokens"] = f32(GetUniqueTokenCount(tokens))
    stats["diversity_ratio"] = stats["unique_tokens"] / stats["length"]
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
    stats["entropy"] = GetTokenEntropy(tokens)
    return stats
}

func PadBatch(i32[][]] sequences, i32 pad_token_id) i32[][]] {
    max_len := i32(0)
    for i := 0; i < len(sequences); i += 1 {
        if i32(len(sequences[i])) > max_len {
            max_len = i32(len(sequences[i]))
        }
    }
    result := make(i32[][]], len(sequences))
    for i := 0; i < len(sequences); i += 1 {
        result[i] = PadSequence(sequences[i], max_len, pad_token_id)
    }
    return result
}

func GetBatchLengths(i32[][]] sequences) []i32 {
    lengths := make(i32[], len(sequences))
    for i := 0; i < len(sequences); i += 1 {
        lengths[i] = i32(len(sequences[i]))
    }
    return lengths
}

func trim_whitespace(string s) string {
    start := 0
    end := len(s)
    for start < end && is_whitespace(string(s[start])) {
        start += 1
    }
    for end > start && is_whitespace(string(s[end-1])) {
        end -= 1
    }
    return s[start:end]
}

func normalize_unicode(string s) string {
    return s
}

func split_by_space(string s) []string {
    parts := make([]string, 0)
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

func is_whitespace(string char) bool {
    return char == " " || char == "\t" || char == "\n" || char == "\r"
}

func string_from_i32(i32 n) string {
    if n == 0 {
        return "0"
    }
    result := ""
    num := n
    if num < 0 {
        result = "-"
        num = -num
    }
    digits := ""
    for num > 0 {
        digit := num % 10
        digits = string(digit + 48) + digits
        num /= 10
    }
    return result + digits
}

func log2(f32 x) f32 {
    if x <= 0.0 {
        return 0.0
    }
    return x
}
