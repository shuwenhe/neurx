package neurx.parser.error_recovery

use neurx.parser.types
use neurx.parser.text_parser

func attempt_recovery(string error_msg, string text, int strategy) ParseResult {
    result := create_parse_result()
    result.raw_output = text
    result.error_msg = error_msg

    match strategy {
        0 => return result
        1 => return skip_invalid(text)
        2 => return attempt_fix(text)
        3 => return truncate_at_error(text, error_msg)
        4 => return fallback_to_text(text)
        _ => return result
    }
}

func skip_invalid(string text) ParseResult {
    result := create_parse_result()
    result.raw_output = text
    result.recovery_applied = true
    result.recovery_method = "skip_invalid"

    recovered := ""
    i := 0
    valid_count := 0

    for i < len(text) {
        ch := text[i]

        if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
           (ch >= '0' && ch <= '9') || ch == ' ' || ch == '\n' ||
           ch == '\t' || ch == '-' || ch == '_' {
            recovered = recovered + string(ch)
            valid_count = valid_count + 1
        } else if ch == '"' || ch == '{' || ch == '}' ||
                  ch == '[' || ch == ']' || ch == ':' ||
                  ch == ',' || ch == '.' {
            recovered = recovered + string(ch)
            valid_count = valid_count + 1
        }

        i = i + 1
    }

    result.parsed_output = recovered
    result.status = if valid_count > 0 { 4 } else { 3 }
    result.confidence = float(valid_count) / float(len(text))

    return result
}

func attempt_fix(string text) ParseResult {
    result := create_parse_result()
    result.raw_output = text
    result.recovery_applied = true

    trimmed := trim_string(text)

    if trimmed[0] == '{' || trimmed[0] == '[' {
        return fix_json(text)
    }

    if trimmed[0] == '<' {
        return fix_xml(text)
    }

    return fix_common_issues(text)
}

func fix_json(string text) ParseResult {
    result := create_parse_result()
    result.recovery_method = "fix_json"
    result.raw_output = text

    trimmed := trim_string(text)
    fixed := ""

    if trimmed[0] != '{' && trimmed[0] != '[' {
        if contains_json_content(trimmed) {
            fixed = "{" + trimmed + "}"
        }
    } else {
        fixed = trimmed
    }

    if len(fixed) > 0 {
        if fixed[len(fixed) - 1] != '}' && fixed[len(fixed) - 1] != ']' {
            if fixed[0] == '{' {
                fixed = fixed + "}"
            } else if fixed[0] == '[' {
                fixed = fixed + "]"
            }
        }
    }

    quote_count := 0
    i := 0
    for i < len(fixed) {
        if fixed[i] == '"' {
            quote_count = quote_count + 1
        }
        i = i + 1
    }

    if quote_count % 2 == 1 {
        fixed = fixed + "\""
    }

    result.parsed_output = fixed
    result.status = 4
    result.confidence = 0.7

    return result
}

func contains_json_content(string text) bool {
    has_colon := find_substring(text, ":", 0) >= 0
    has_comma := find_substring(text, ",", 0) >= 0
    has_quotes := find_substring(text, "\"", 0) >= 0

    return has_colon || (has_comma && has_quotes)
}

func fix_xml(string text) ParseResult {
    result := create_parse_result()
    result.recovery_method = "fix_xml"
    result.raw_output = text

    trimmed := trim_string(text)
    fixed := trimmed

    open_tags := count_occurrences(fixed, "<")
    close_tags := count_occurrences(fixed, ">")

    if close_tags < open_tags {
        i := 0
        for i < len(fixed) - open_tags + close_tags {
            fixed = fixed + ">"
            i = i + 1
        }
    }

    closing_slashes := count_occurrences(fixed, "</")
    opening_tags := count_occurrences(fixed, "<") - count_occurrences(fixed, "</")

    if opening_tags > closing_slashes {

        last_tag := extract_last_tag(fixed)
        if len(last_tag) > 0 {
            fixed = fixed + "</" + last_tag + ">"
        }
    }

    result.parsed_output = fixed
    result.status = 4
    result.confidence = 0.65

    return result
}

func fix_common_issues(string text) ParseResult {
    result := create_parse_result()
    result.recovery_method = "fix_common_issues"
    result.raw_output = text

    fixed := text

    fixed = replace_all(fixed, """, "\"")
    fixed = replace_all(fixed, """, "\"")
    fixed = replace_all(fixed, "'", "'")

    fixed = replace_all(fixed, "–", "-")
    fixed = replace_all(fixed, "—", "-")

    fixed = replace_all(fixed, "…", "...")

    fixed = replace_all(fixed, "  ", " ")

    result.parsed_output = fixed
    result.status = 4
    result.confidence = 0.6

    return result
}

func truncate_at_error(string text, string error_msg) ParseResult {
    result := create_parse_result()
    result.recovery_method = "truncate"
    result.raw_output = text

    error_pos := 0

    pos_patterns := string[]{"position ", "at ", "line "}
    i := 0

    for i < len(pos_patterns) {
        pos := find_substring(error_msg, pos_patterns[i], 0)
        if pos >= 0 {

            num_start := pos + len(pos_patterns[i])
            num_str := ""
            j := num_start

            for j < len(error_msg) && error_msg[j] >= '0' && error_msg[j] <= '9' {
                num_str = num_str + string(error_msg[j])
                j = j + 1
            }

            if len(num_str) > 0 {
                error_pos = parse_int(num_str)
                break
            }
        }

        i = i + 1
    }

    if error_pos > 0 && error_pos < len(text) {
        result.parsed_output = trim_string(text[0:error_pos])
    } else {

        result.parsed_output = truncate_at_last_token(text)
    }

    result.status = 4
    result.confidence = 0.5

    return result
}

func truncate_at_last_token(string text) string {

    last_space := -1
    last_newline := -1
    i := 0

    for i < len(text) {
        if text[i] == ' ' {
            last_space = i
        } else if text[i] == '\n' {
            last_newline = i
        }
        i = i + 1
    }

    if last_newline > last_space {
        return trim_string(text[0:last_newline])
    } else if last_space > 0 {
        return trim_string(text[0:last_space])
    }

    return text
}

func fallback_to_text(string text) ParseResult {
    result := create_parse_result()
    result.recovery_method = "fallback_to_text"
    result.raw_output = text
    result.format = 0

    paragraphs := split_paragraphs(text)

    result.parsed_output = text
    result.status = 4
    result.confidence = 0.4

    return result
}

func extract_last_tag(string xml) string {
    last_tag_start := -1
    last_tag_end := -1
    i := 0

    for i < len(xml) {
        if xml[i] == '<' && (i == 0 || xml[i - 1] != '<') {
            last_tag_start = i
        } else if xml[i] == '>' {
            last_tag_end = i
        }
        i = i + 1
    }

    if last_tag_start >= 0 && last_tag_end > last_tag_start {
        tag_content := xml[last_tag_start + 1:last_tag_end]

        space_pos := find_substring(tag_content, " ", 0)
        if space_pos > 0 {
            return tag_content[0:space_pos]
        } else {
            return tag_content
        }
    }

    return ""
}

func parse_int(string s) int {
    result := 0
    i := 0

    for i < len(s) && s[i] >= '0' && s[i] <= '9' {
        result = result * 10 + int(s[i] - '0')
        i = i + 1
    }

    return result
}

func suggest_recovery_strategy(string error_msg, string text) int {
    if find_substring(error_msg, "brace", 0) >= 0 ||
       find_substring(error_msg, "bracket", 0) >= 0 {
        return 2
    }

    if find_substring(error_msg, "quote", 0) >= 0 {
        return 2
    }

    if find_substring(error_msg, "invalid", 0) >= 0 {
        return 1
    }

    if find_substring(error_msg, "incomplete", 0) >= 0 ||
       find_substring(error_msg, "truncate", 0) >= 0 {
        return 3
    }

    return 4
}

func validate_recovery(string original, string recovered) bool {

    if len(recovered) < len(original) / 2 {
        return false
    }

    if len(recovered) > 0 && (recovered[0] == ' ' || recovered[0] == '\n') {
        return false
    }

    return true
}

struct RepairStrategy {
    int strategy_type
    int max_attempts
    float preserve_ratio
    bool strict
}

func create_default_repair_strategy() RepairStrategy {
    return RepairStrategy{
        strategy_type: 2,
        max_attempts: 3,
        preserve_ratio: 0.5,
        strict: false,
    }
}
