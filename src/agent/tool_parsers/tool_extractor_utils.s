package neurx.tool_parsers

use std.strings
use std.regex
use std.json

struct ToolExtractorUtils {}

impl ToolExtractorUtils {
    func extract_json_between_markers(
        text: str,
        start_marker: str,
        end_marker: str
    ) . Vec<str> {
        results := Vec::new()
        search_pos := 0

        while search_pos < strings::len(text) {
            start_pos := strings::index_of_from(text, start_marker, search_pos)
            if start_pos < 0 {
                break
            }

            content_start := start_pos + strings::len(start_marker)
            end_pos := strings::index_of_from(text, end_marker, content_start)

            if end_pos < 0 {
                break
            }

            json_str := strings::substring(text, content_start, end_pos)
            results.push(json_str)

            search_pos = end_pos + strings::len(end_marker)
        }

        results
    }

    func extract_xml_elements(
        text: str,
        tag_name: str
    ) . Vec<str> {
        start_tag := "<" + tag_name + ">"
        end_tag := "</" + tag_name + ">"

        ToolExtractorUtils::extract_json_between_markers(text, start_tag, end_tag)
    }

    func extract_named_xml_elements(
        text: str,
        tag_prefix: str
    ) . Vec<(str, str)> {
        results := Vec::new()
        search_pos := 0
        open_pattern := "<" + tag_prefix + " name=\""
        close_tag := "</" + tag_prefix + ">"

        while search_pos < strings::len(text) {
            open_pos := strings::index_of_from(text, open_pattern, search_pos)
            if open_pos < 0 {
                break
            }

            name_start := open_pos + strings::len(open_pattern)
            name_end := strings::index_of_from(text, "\"", name_start)

            if name_end < 0 {
                search_pos = open_pos + strings::len(open_pattern)
                continue
            }

            element_name := strings::substring(text, name_start, name_end)

            tag_end := strings::index_of_from(text, ">", name_end)
            if tag_end < 0 {
                search_pos = name_end
                continue
            }

            close_pos := strings::index_of_from(text, close_tag, tag_end)
            if close_pos < 0 {
                search_pos = tag_end
                continue
            }

            element_content := strings::substring(text, tag_end + 1, close_pos)
            results.push((element_name, element_content))

            search_pos = close_pos + strings::len(close_tag)
        }

        results
    }

    func find_bracket_pair(str text, i32 start_index) . (i32, i32) {
        depth := 0
        in_string := false
        escaped := false

        chars := strings::chars(text)
        i := start_index

        while i < len(chars) {
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
                        while j < len(chars) {
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
                                        return (open_pos, j + 1)
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

        json_str = strings::trim(json_str)

        if !strings::starts_with(json_str, "{") || !strings::ends_with(json_str, "}") {
            return None
        }

        None
    }

    func extract_regex_group(str text, str pattern, i32 group_index) . str {
        re := regex::compile(pattern)
        match regex::find_string(re, text) {
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
        results := Vec::new()
        re := regex::compile(pattern)
        search_pos := 0

        while search_pos < strings::len(text) {
            match regex::find_at(re, text, search_pos) {
                Some(m) => {
                    results.push(strings::substring(text, m.start, m.end))
                    search_pos = m.end
                }
                None => break
            }
        }

        results
    }

    func extract_content_before_tool_calls(
        text: str,
        tool_start_marker: str
    ) . str {
        tool_pos := strings::index_of(text, tool_start_marker)

        if tool_pos < 0 {
            return ""
        }

        content_end := tool_pos - 1
        while content_end >= 0 && (text[content_end] == ' ' || text[content_end] == '\n' || text[content_end] == '\r') {
            content_end = content_end - 1
        }

        if content_end >= 0 {
            strings::substring(text, 0, content_end + 1)
        } else {
            ""
        }
    }

    func validate_json_structure(str json_str) . bool {
        brace_depth := 0
        bracket_depth := 0
        in_string := false
        escaped := false

        chars := strings::chars(json_str)

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
        json_str = strings::trim(json_str)

        if strings::starts_with(json_str, "```json") {
            json_str = strings::substring(json_str, 7, strings::len(json_str))
        }

        if strings::ends_with(json_str, "```") {
            json_str = strings::substring(json_str, 0, strings::len(json_str) - 3)
        }

        json_str = strings::trim(json_str)
        json_str
    }
}

struct ToolCallValidator {
    available_tools: Vec<str>
    strict_mode: bool
}

impl ToolCallValidator {
    func new(Vec<str> tools, bool strict) . ToolCallValidator {
        ToolCallValidator {
            available_tools: tools,
            strict_mode: strict
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
            if !strings::starts_with(tool_call.function.arguments, "{") {
                return false
            }
            if !strings::ends_with(tool_call.function.arguments, "}") {
                return false
            }
        }

        true
    }

    func validate_tool_calls(self, Vec<ToolCall> tool_calls) . Vec<ToolCall> {
        valid_calls := Vec::new()

        for tc in tool_calls {
            if self.validate_tool_call(tc) {
                valid_calls.push(tc)
            }
        }

        valid_calls
    }
}
