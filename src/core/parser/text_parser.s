package neurx.parser.text_parser
use neurx.parser.types
use std.slices
func tokenize(string input) string[] {
    tokens := string[]{}
    current_token := ""
    i := 0
    for i < len(input) {
        ch := input[i]
        if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
            if len(current_token) > 0 {
                tokens = append(tokens, current_token)
                current_token = ""
            }
            i = i + 1
        }
        else if ch == '.' || ch == ',' || ch == '!' || ch == '' ||
                ch == ';' || ch == ':' || ch == '"' || ch == '\'' {
            if len(current_token) > 0 {
                tokens = append(tokens, current_token)
                current_token = ""
            }
            tokens = append(tokens, string(ch))
            i = i + 1
        }
        else if ch == '(' || ch == ')' || ch == '[' || ch == ']' ||
                ch == '{' || ch == '}' {
            if len(current_token) > 0 {
                tokens = append(tokens, current_token)
                current_token = ""
            }
            tokens = append(tokens, string(ch))
            i = i + 1
        }
        else {
            current_token = current_token + string(ch)
            i = i + 1
        }
    }
    if len(current_token) > 0 {
        tokens = append(tokens, current_token)
    }
    return tokens
}
func split_lines(string text) string[] {
    lines := string[]{}
    current_line := ""
    i := 0
    for i < len(text) {
        ch := text[i]
        if ch == '\n' {
            lines = append(lines, current_line)
            current_line = ""
            i = i + 1
        } else if ch == '\r' && i + 1 < len(text) && text[i + 1] == '\n' {
            lines = append(lines, current_line)
            current_line = ""
            i = i + 2
        } else if ch == '\r' {
            lines = append(lines, current_line)
            current_line = ""
            i = i + 1
        } else {
            current_line = current_line + string(ch)
            i = i + 1
        }
    }
    if len(current_line) > 0 {
        lines = append(lines, current_line)
    }
    return lines
}
func split_paragraphs(string text) string[] {
    lines := split_lines(text)
    paragraphs := string[]{}
    current_para := ""
    i := 0
    for i < len(lines) {
        line := lines[i]
        if trim_string(line) == "" {
            if len(trim_string(current_para)) > 0 {
                paragraphs = append(paragraphs, current_para)
                current_para = ""
            }
        } else {
            if len(current_para) > 0 {
                current_para = current_para + "\n"
            }
            current_para = current_para + line
        }
        i = i + 1
    }
    if len(trim_string(current_para)) > 0 {
        paragraphs = append(paragraphs, current_para)
    }
    return paragraphs
}
func trim_string(string s) string {
    start := 0
    end := len(s) - 1
    for start <= end && (s[start] == ' ' || s[start] == '\t' ||
                          s[start] == '\n' || s[start] == '\r') {
        start = start + 1
    }
    for end >= start && (s[end] == ' ' || s[end] == '\t' ||
                          s[end] == '\n' || s[end] == '\r') {
        end = end - 1
    }
    if start > end {
        return ""
    }
    return s[start:end + 1]
}
func extract_between(string text, string open_delim, string close_delim) string {
    open_pos := find_substring(text, open_delim, 0)
    if open_pos < 0 {
        return ""
    }
    open_pos = open_pos + len(open_delim)
    close_pos := find_substring(text, close_delim, open_pos)
    if close_pos < 0 {
        return text[open_pos:]
    }
    return text[open_pos:close_pos]
}
func find_all_substring(string text, string pattern) int[] {
    positions := int[]{}
    pos := 0
    for pos < len(text) {
        found_pos := find_substring(text, pattern, pos)
        if found_pos < 0 {
            break
        }
        positions = append(positions, found_pos)
        pos = found_pos + 1
    }
    return positions
}
func find_substring(string text, string substring, int start_pos) int {
    if len(substring) == 0 || len(text) == 0 {
        return -1
    }
    i := start_pos
    for i <= len(text) - len(substring) {
        j := 0
        for j < len(substring) && text[i + j] == substring[j] {
            j = j + 1
        }
        if j == len(substring) {
            return i
        }
        i = i + 1
    }
    return -1
}
func replace_all(string text, string pattern, string replacement) string {
    positions := find_all_substring(text, pattern)
    result := ""
    last_pos := 0
    i := 0
    for i < len(positions) {
        pos := positions[i]
        result = result + text[last_pos:pos] + replacement
        last_pos = pos + len(pattern)
        i = i + 1
    }
    result = result + text[last_pos:]
    return result
}
func starts_with(string text, string prefix) bool {
    if len(prefix) > len(text) {
        return false
    }
    return text[0:len(prefix)] == prefix
}
func ends_with(string text, string suffix) bool {
    if len(suffix) > len(text) {
        return false
    }
    return text[len(text) - len(suffix):] == suffix
}
func normalize_whitespace(string text) string {
    text = trim_string(text)
    result := ""
    last_was_space := false
    i := 0
    for i < len(text) {
        ch := text[i]
        if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
            if !last_was_space {
                result = result + " "
                last_was_space = true
            }
        } else {
            result = result + string(ch)
            last_was_space = false
        }
        i = i + 1
    }
    return result
}
func to_lowercase(string text) string {
    result := ""
    i := 0
    for i < len(text) {
        ch := text[i]
        if ch >= 'A' && ch <= 'Z' {
            result = result + string(ch + 32)
        } else {
            result = result + string(ch)
        }
        i = i + 1
    }
    return result
}
func to_uppercase(string text) string {
    result := ""
    i := 0
    for i < len(text) {
        ch := text[i]
        if ch >= 'a' && ch <= 'z' {
            result = result + string(ch - 32)
        } else {
            result = result + string(ch)
        }
        i = i + 1
    }
    return result
}
func is_alphanumeric(string ch) bool {
    if len(ch) != 1 {
        return false
    }
    c := ch[0]
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
}
func is_digit(string ch) bool {
    if len(ch) != 1 {
        return false
    }
    c := ch[0]
    return c >= '0' && c <= '9'
}
func is_whitespace(string ch) bool {
    if len(ch) != 1 {
        return false
    }
    c := ch[0]
    return c == ' ' || c == '\t' || c == '\n' || c == '\r'
}
func extract_words(string text) string[] {
    words := string[]{}
    current_word := ""
    i := 0
    for i < len(text) {
        ch := text[i]
        if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') {
            current_word = current_word + string(ch)
        } else {
            if len(current_word) > 0 {
                words = append(words, current_word)
                current_word = ""
            }
        }
        i = i + 1
    }
    if len(current_word) > 0 {
        words = append(words, current_word)
    }
    return words
}
func count_occurrences(string text, string substring) int {
    positions := find_all_substring(text, substring)
    return len(positions)
}
func substring(string text, int start, int length) string {
    if start < 0 || start >= len(text) || length <= 0 {
        return ""
    }
    end := start + length
    if end > len(text) {
        end = len(text)
    }
    return text[start:end]
}
func split_string(string text, string delimiter) string[] {
    if len(delimiter) == 0 {
        chars := string[]{}
        i := 0
        for i < len(text) {
            chars = append(chars, string(text[i]))
            i = i + 1
        }
        return chars
    }
    parts := string[]{}
    current_part := ""
    i := 0
    for i < len(text) {
        if i + len(delimiter) <= len(text) && text[i:i + len(delimiter)] == delimiter {
            parts = append(parts, current_part)
            current_part = ""
            i = i + len(delimiter)
        } else {
            current_part = current_part + string(text[i])
            i = i + 1
        }
    }
    parts = append(parts, current_part)
    return parts
}
func join_strings(string[] strings, string separator) string {
    result := ""
    i := 0
    for i < len(strings) {
        if i > 0 {
            result = result + separator
        }
        result = result + strings[i]
        i = i + 1
    }
    return result
}
