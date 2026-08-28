package neurx.parser.format_parser
use neurx.parser.types
use neurx.parser.text_parser
func detect_format(string text) FormatDetectionResult {
    trimmed := trim_string(text)
    if len(trimmed) == 0 {
        return FormatDetectionResult{
            detected_format: 0,
            confidence: 1.0,
            indicators: string[]{},
            metadata: map[string]string{},
        }
    }
    first_char := trimmed[0]
    indicators := string[]{}
    if first_char == '{' || first_char == '[' {
        if is_valid_json_structure(trimmed) {
            return FormatDetectionResult{
                detected_format: 1,
                confidence: 0.95,
                indicators: string[]{"starts_with_brace", "valid_json_structure"},
                metadata: map[string]string{},
            }
        }
    }
    if first_char == '<' {
        if is_valid_xml_structure(trimmed) {
            return FormatDetectionResult{
                detected_format: 2,
                confidence: 0.95,
                indicators: string[]{"starts_with_tag", "valid_xml_structure"},
                metadata: map[string]string{},
            }
        }
    }
    if has_markdown_markers(trimmed) {
        return FormatDetectionResult{
            detected_format: 3,
            confidence: 0.8,
            indicators: string[]{"has_markdown_markers"},
            metadata: map[string]string{},
        }
    }
    if is_yaml_like(trimmed) {
        return FormatDetectionResult{
            detected_format: 4,
            confidence: 0.7,
            indicators: string[]{"yaml_like_structure"},
            metadata: map[string]string{},
        }
    }
    if is_csv_like(trimmed) {
        return FormatDetectionResult{
            detected_format: 5,
            confidence: 0.7,
            indicators: string[]{"csv_like_structure"},
            metadata: map[string]string{},
        }
    }
    if has_html_tags(trimmed) {
        return FormatDetectionResult{
            detected_format: 6,
            confidence: 0.75,
            indicators: string[]{"has_html_tags"},
            metadata: map[string]string{},
        }
    }
    return FormatDetectionResult{
        detected_format: 0,
        confidence: 1.0,
        indicators: string[]{"no_format_markers"},
        metadata: map[string]string{},
    }
}
func is_valid_json_structure(string text) bool {
    trimmed := trim_string(text)
    if len(trimmed) < 2 {
        return false
    }
    first := trimmed[0]
    last := trimmed[len(trimmed) - 1]
    if (first == '{' && last == '}') || (first == '[' && last == ']') {
        brace_count := 0
        bracket_count := 0
        i := 0
        in_string := false
        for i < len(trimmed) {
            ch := trimmed[i]
            if ch == '"' && (i == 0 || trimmed[i - 1] != '\\') {
                in_string = !in_string
            } else if !in_string {
                if ch == '{' {
                    brace_count = brace_count + 1
                } else if ch == '}' {
                    brace_count = brace_count - 1
                } else if ch == '[' {
                    bracket_count = bracket_count + 1
                } else if ch == ']' {
                    bracket_count = bracket_count - 1
                }
            }
            i = i + 1
        }
        return brace_count == 0 && bracket_count == 0
    }
    return false
}
func is_valid_xml_structure(string text) bool {
    trimmed := trim_string(text)
    if len(trimmed) < 3 || trimmed[0] != '<' {
        return false
    }
    tag_start := 0
    tag_end := find_substring(trimmed, ">", tag_start)
    if tag_end < 0 {
        return false
    }
    closing_pattern := "</"
    if find_substring(trimmed, closing_pattern, tag_end) >= 0 {
        return true
    }
    if find_substring(trimmed, "/>", tag_end) >= 0 {
        return true
    }
    return false
}
func has_markdown_markers(string text) bool {
    if starts_with(trim_string(text), "#") {
        return true
    }
    if find_substring(text, "**", 0) >= 0 || find_substring(text, "__", 0) >= 0 {
        return true
    }
    if find_substring(text, "*", 0) >= 0 || find_substring(text, "_", 0) >= 0 {
        return true
    }
    if starts_with(trim_string(text), "-") || starts_with(trim_string(text), "*") {
        return true
    }
    if find_substring(text, "```", 0) >= 0 {
        return true
    }
    if find_substring(text, "[", 0) >= 0 && find_substring(text, "](", 0) >= 0 {
        return true
    }
    return false
}
func is_yaml_like(string text) bool {
    lines := split_lines(text)
    if len(lines) == 0 {
        return false
    }
    yaml_count := 0
    i := 0
    for i < len(lines) && i < 10 {
        line := trim_string(lines[i])
        if len(line) > 0 && line[0] != '#' {
            colon_pos := find_substring(line, ":", 0)
            if colon_pos > 0 && colon_pos < len(line) - 1 {
                if colon_pos < 5 || (line[colon_pos - 1] != '/' && line[colon_pos - 2] != '/') {
                    yaml_count = yaml_count + 1
                }
            }
        }
        i = i + 1
    }
    return yaml_count >= 2
}
func is_csv_like(string text) bool {
    lines := split_lines(text)
    if len(lines) < 2 {
        return false
    }
    first_line := lines[0]
    comma_count := count_occurrences(first_line, ",")
    if comma_count < 1 {
        return false
    }
    if len(lines) > 1 {
        second_line := lines[1]
        second_comma_count := count_occurrences(second_line, ",")
        if second_comma_count >= comma_count - 1 && second_comma_count <= comma_count + 1 {
            return true
        }
    }
    return false
}
func has_html_tags(string text) bool {
    html_tags := string[]{"<html", "<div", "<span", "<p>", "<h1", "<h2", "<table", "<body"}
    i := 0
    for i < len(html_tags) {
        if find_substring(to_lowercase(text), html_tags[i], 0) >= 0 {
            return true
        }
        i = i + 1
    }
    if find_substring(text, "</", 0) >= 0 {
        return true
    }
    return false
}
func parse_json_output(string text) ParseResult {
    result := create_parse_result()
    result.format = 1
    result.raw_output = text
    trimmed := trim_string(text)
    if len(trimmed) == 0 {
        result.status = 3
        result.error_msg = "Empty input"
        return result
    }
    if trimmed[0] == '{' {
        result.value = create_object_value(string[]{}, []ParsedValue{})
    } else if trimmed[0] == '[' {
        result.value = create_array_value([]ParsedValue{})
    } else if trimmed[0] == '"' {
        result.value = create_string_value(extract_string_value(trimmed))
    } else {
        result.value = create_string_value(trimmed)
    }
    result.status = 0
    result.parsed_output = trimmed
    result.confidence = 0.8
    return result
}
func parse_xml_output(string text) ParseResult {
    result := create_parse_result()
    result.format = 2
    result.raw_output = text
    trimmed := trim_string(text)
    root_name := extract_tag_name(trimmed)
    if len(root_name) > 0 {
        result.value = create_object_value(string[]{root_name}, []ParsedValue{})
        result.status = 0
        result.confidence = 0.8
    } else {
        result.status = 3
        result.error_msg = "No valid XML tag found"
    }
    result.parsed_output = trimmed
    return result
}
func parse_markdown_output(string text) ParseResult {
    result := create_parse_result()
    result.format = 3
    result.raw_output = text
    lines := split_lines(text)
    result.value = create_array_value([]ParsedValue{})
    result.status = 0
    result.parsed_output = text
    result.confidence = 0.7
    return result
}
func parse_csv_output(string text) ParseResult {
    result := create_parse_result()
    result.format = 5
    result.raw_output = text
    lines := split_lines(text)
    if len(lines) > 0 {
        result.value = create_array_value([]ParsedValue{})
        result.status = 0
        result.confidence = 0.75
    } else {
        result.status = 3
        result.error_msg = "Empty CSV"
    }
    result.parsed_output = text
    return result
}
func extract_tag_name(string xml) string {
    if len(xml) < 2 || xml[0] != '<' {
        return ""
    }
    i := 1
    tag_name := ""
    for i < len(xml) && xml[i] != '>' && xml[i] != ' ' && xml[i] != '\t' {
        tag_name = tag_name + string(xml[i])
        i = i + 1
    }
    return tag_name
}
func extract_string_value(string quoted) string {
    if len(quoted) < 2 {
        return ""
    }
    if quoted[0] != '"' {
        return quoted
    }
    result := ""
    i := 1
    for i < len(quoted) && quoted[i] != '"' {
        if quoted[i] == '\\' && i + 1 < len(quoted) {
            next_char := quoted[i + 1]
            if next_char == '"' {
                result = result + "\""
                i = i + 2
            } else if next_char == '\\' {
                result = result + "\\"
                i = i + 2
            } else if next_char == 'n' {
                result = result + "\n"
                i = i + 2
            } else if next_char == 't' {
                result = result + "\t"
                i = i + 2
            } else {
                result = result + string(quoted[i])
                i = i + 1
            }
        } else {
            result = result + string(quoted[i])
            i = i + 1
        }
    }
    return result
}
func normalize_format(string text, int format) string {
    match format {
        0 => return normalize_text(text)
        1 => return normalize_json(text)
        2 => return normalize_xml(text)
        3 => return normalize_markdown(text)
        4 => return normalize_yaml(text)
        5 => return normalize_csv(text)
        6 => return normalize_html(text)
        _ => return text
    }
}
func normalize_text(string text) string {
    return normalize_whitespace(text)
}
func normalize_json(string text) string {
    return normalize_whitespace(text)
}
func normalize_xml(string text) string {
    return normalize_whitespace(text)
}
func normalize_markdown(string text) string {
    return normalize_whitespace(text)
}
func normalize_yaml(string text) string {
    return normalize_whitespace(text)
}
func normalize_csv(string text) string {
    return text
}
func normalize_html(string text) string {
    return normalize_whitespace(text)
}
func convert_format(string text, int from_format, int to_format) string {
    if from_format == to_format {
        return text
    }
    return normalize_format(text, to_format)
}
func validate_format(string text, int format) bool {
    match format {
        0 => return true
        1 => return is_valid_json_structure(text)
        2 => return is_valid_xml_structure(text)
        3 => return true
        4 => return is_yaml_like(text)
        5 => return is_csv_like(text)
        6 => return has_html_tags(text)
        _ => return false
    }
}
