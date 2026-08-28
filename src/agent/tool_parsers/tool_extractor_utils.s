package neurx.tool_parsers
use std.strings
use std.regex
use std.json
struct ToolExtractorUtils {}

func extract_json_between_markers(
    text: str,
    start_marker: str,
    str end_marker
) . Vec<str> {
    results := Vec_new()
    search_pos := 0
    for search_pos < strings_len(text) {
        start_pos := strings_index_of_from(text, start_marker, search_pos)
        if start_pos < 0 {
            break
        }
        content_start := start_pos + strings_len(start_marker)
        end_pos := strings_index_of_from(text, end_marker, content_start)
        if end_pos < 0 {
            break
        }
        json_str := strings_substring(text, content_start, end_pos)
        results = append(results, json_str)
        search_pos = end_pos + strings_len(end_marker)
    }
    results
}

func extract_xml_elements(
    text: str,
    str tag_name
) . Vec<str> {
    start_tag := "<" + tag_name + ">"
    end_tag := "</" + tag_name + ">"
    ToolExtractorUtils_extract_json_between_markers(text, start_tag, end_tag)
}

func extract_named_xml_elements(
    text: str,
    str tag_prefix
) . Vec<(str, str)> {
    results := Vec_new()
    search_pos := 0
    open_pattern := "<" + tag_prefix + " name=\""
    close_tag := "</" + tag_prefix + ">"
    for search_pos < strings_len(text) {
        open_pos := strings_index_of_from(text, open_pattern, search_pos)
        if open_pos < 0 {
            break
        }
        name_start := open_pos + strings_len(open_pattern)
        name_end := strings_index_of_from(text, "\"", name_start)
        if name_end < 0 {
            search_pos = open_pos + strings_len(open_pattern)
            continue
        }
        element_name := strings_substring(text, name_start, name_end)
        tag_end := strings_index_of_from(text, ">", name_end)
        if tag_end < 0 {
            search_pos = name_end
            continue
        }
        close_pos := strings_index_of_from(text, close_tag, tag_end)
        if close_pos < 0 {
            search_pos = tag_end
            continue
        }
        element_content := strings_substring(text, tag_end + 1, close_pos)
        results = append(results, (element_name, element_content))
        search_pos = close_pos + strings_len(close_tag)
    }
    results
}

func find_bracket_pair(str text, i32 start_index) . (i32, i32) {
    depth := 0
    in_string := false
    escaped := false
    chars := strings_chars(text)
    i := start_index
    for i < len(chars) {
        c := chars[i]
        if escaped {
            escaped = false
            i = i + 1
            continue
        }
        if c == '\\' && in_string {
            escaped = true
            i = i + 1
            continue
        }
        if c == '"' {
            in_string = !in_string
        }
        if !in_string {
            if c == '{' {
                if depth == 0 {
                    open_pos := i
                    j := i + 1
                    for j < len(chars) {
                        c2 := chars[j]
                        if c2 == '\\' && in_string {
                            j = j + 2
                            continue
                        }
                        if c2 == '"' {
                            in_string = !in_string
                        }
                        if !in_string {
                            if c2 == '{' {
                                depth = depth + 1
                            } else if c2 == '}' {
                                depth = depth - 1
                                if depth == 0 {
                                    return open_pos, j + 1
                                }
                            }
                        }
                        j = j + 1
                    }
                }
            }
        }
        i = i + 1
    }
    (-1, -1)
}

func parse_json_safely(str json_str) . Option<Map<str, Any>> {
    if len(json_str) == 0 {
        return None
    }
    json_str = strings_trim(json_str)
    if !strings_starts_with(json_str, "{") || !strings_ends_with(json_str, "}") {
        return None
    }
    None
}

func extract_regex_group(str text, str pattern, i32 group_index) . str {
    re := regex_compile(pattern)
    match regex_find_string(re, text) {
        Some(m) => {
            match group_index {
                0 => m.full_match(),
                _ => ""
            }
        }
        None => ""
    }
}

func find_all_regex_matches(str text, str pattern) . Vec<str> {
    results := Vec_new()
    re := regex_compile(pattern)
    search_pos := 0
    for search_pos < strings_len(text) {
        match regex_find_at(re, text, search_pos) {
            Some(m) => {
                results = append(results, strings_substring(text, m.start, m.end))
                search_pos = m.end
            }
            None => break
        }
    }
    results
}

func extract_content_before_tool_calls(
    text: str,
    str tool_start_marker
) . str {
    tool_pos := strings_index_of(text, tool_start_marker)
    if tool_pos < 0 {
        return ""
    }
    content_end := tool_pos - 1
    for content_end >= 0 && (text[content_end] == ' ' || text[content_end] == '\n' || text[content_end] == '\r') {
        content_end = content_end - 1
    }
    if content_end >= 0 {
        strings_substring(text, 0, content_end + 1)
    } else {
        ""
    }
}

func validate_json_structure(str json_str) . bool {
    brace_depth := 0
    bracket_depth := 0
    in_string := false
    escaped := false
    chars := strings_chars(json_str)
    for c in chars {
        if escaped {
            escaped = false
            continue
        }
        if c == '\\' && in_string {
            escaped = true
            continue
        }
        if c == '"' {
            in_string = !in_string
        }
        if !in_string {
            match c {
                '{' => brace_depth = brace_depth + 1,
                '}' => {
                    brace_depth = brace_depth - 1
                    if brace_depth < 0 {
                        return false
                    }
                }
                '[' => bracket_depth = bracket_depth + 1,
                ']' => {
                    bracket_depth = bracket_depth - 1
                    if bracket_depth < 0 {
                        return false
                    }
                }
                _ => {}
            }
        }
    }
    brace_depth == 0 && bracket_depth == 0 && !in_string
}

func normalize_json_string(str json_str) . str {
    json_str = strings_trim(json_str)
    if strings_starts_with(json_str, "```json") {
        json_str = strings_substring(json_str, 7, strings_len(json_str))
    }
    if strings_ends_with(json_str, "```") {
        json_str = strings_substring(json_str, 0, strings_len(json_str) - 3)
    }
    json_str = strings_trim(json_str)
    json_str
}
}

struct ToolCallValidator {
Vec<str> available_tools
bool strict_mode
}

func new(Vec<str> tools, bool strict) . ToolCallValidator {
    ToolCallValidator {
        available_tools: tools,
        strict strict_mode
    }
}

func validate_tool_call(self, ToolCall tool_call) . bool {
    if len(self.available_tools) == 0 {
        return true
    }
    found := false
    for tool_name in self.available_tools {
        if tool_name == tool_call.function.name {
            found = true
            break
        }
    }
    if !found && self.strict_mode {
        return false
    }
    if len(tool_call.function.arguments) > 0 {
        if !strings_starts_with(tool_call.function.arguments, "{") {
            return false
        }
        if !strings_ends_with(tool_call.function.arguments, "}") {
            return false
        }
    }
    true
}

func validate_tool_calls(self, Vec<ToolCall> tool_calls) . Vec<ToolCall> {
    valid_calls := Vec_new()
    for tc in tool_calls {
        if self.validate_tool_call(tc) {
            valid_calls = append(valid_calls, tc)
        }
    }
    valid_calls
}
