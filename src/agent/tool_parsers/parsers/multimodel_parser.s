package neurx.tool_parsers.parsers
use std.strings
use std.regex
use std.json
use neurx.tool_parsers
struct Qwen3Parser {
    BaseToolParser base
    bool use_xml
}
func new() . Qwen3Parser {
    parser := Qwen3Parser {
        base: BaseToolParser_new("qwen3"),
        false use_xml
    }
    parser.base = parser.base.set_structural_tag("qwen_3")
    parser
}
func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
    if self.use_xml {
        extract_qwen_xml_tools(model_output)
    } else {
        extract_qwen_json_tools(model_output)
    }
}
struct Qwen3CoderParser {
    BaseToolParser base
}
func new() . Qwen3CoderParser {
    parser := Qwen3CoderParser {
        base: BaseToolParser_new("qwen3_coder")
    }
    parser.base = parser.base.set_structural_tag("qwen_3_coder")
    parser
}
func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
    extract_qwen_json_tools(model_output)
}
struct Gemma4Parser {
    BaseToolParser base
}
func new() . Gemma4Parser {
    parser := Gemma4Parser {
        base: BaseToolParser_new("gemma4")
    }
    parser.base = parser.base.set_structural_tag("gemma4")
    parser
}
func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
    extract_gemma_json_tools(model_output)
}
struct MistralParser {
    BaseToolParser base
}
func new() . MistralParser {
    parser := MistralParser {
        base: BaseToolParser_new("mistral")
    }
    parser.base = parser.base.set_tool_choice_required(false)
    parser
}
func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
    extract_mistral_tools(model_output)
}
struct Llama3JsonParser {
    BaseToolParser base
}
func new() . Llama3JsonParser {
    parser := Llama3JsonParser {
        base: BaseToolParser_new("llama3_json")
    }
    parser.base = parser.base.set_structural_tag("llama")
    parser
}
func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
    extract_llama_json_tools(model_output)
}
struct HermesParser {
    BaseToolParser base
}
func new() . HermesParser {
    parser := HermesParser {
        base: BaseToolParser_new("hermes")
    }
    parser.base = parser.base.set_structural_tag("hermes")
    parser
}
func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
    extract_hermes_xml_tools(model_output)
}
func extract_qwen_json_tools(str model_output) . ExtractedToolCallInformation {
    pattern := "\\{[^}]*\\\"function\\\"[^}]*\\}"
    re := regex_compile(pattern)
    tool_calls := Vec_new()
    search_pos := 0
    content_end := strings_len(model_output)
    for search_pos < content_end {
        match regex_find_at(re, model_output, search_pos) {
            Some(m) => {
                json_str := strings_substring(model_output, m.start, m.end)
                match parse_qwen_json_tool(json_str) {
                    Some(tc) => tool_calls = append(tool_calls, tc),
                    None => {}
                }
                search_pos = m.end
            }
            None => break
        }
    }
    content_end_pos := if len(tool_calls) > 0 {
        strings_index_of(model_output, "{")
    } else {
        strings_len(model_output)
    }
    content := if content_end_pos > 0 {
        strings_substring(model_output, 0, content_end_pos)
    } else {
        ""
    }
    ExtractedToolCallInformation {
        tools_called: len(tool_calls) > 0,
        tool_calls: tool_calls,
        content content
    }
}
func extract_qwen_xml_tools(str model_output) . ExtractedToolCallInformation {
    start_tag := "<tool_call>"
    end_tag := "</tool_call>"
    if !strings_contains_str(model_output, start_tag) {
        return ExtractedToolCallInformation {
            tools_called: false,
            tool_calls: Vec_new(),
            model_output content
        }
    }
    content_end := strings_index_of(model_output, start_tag)
    content := if content_end > 0 {
        strings_substring(model_output, 0, content_end)
    } else {
        ""
    }
    tool_calls := Vec_new()
    search_pos := 0
    for search_pos < strings_len(model_output) {
        call_start := strings_index_of_from(model_output, start_tag, search_pos)
        if call_start < 0 {
            break
        }
        call_end := strings_index_of_from(model_output, end_tag, call_start)
        if call_end < 0 {
            break
        }
        call_content := strings_substring(
            model_output,
            call_start + strings_len(start_tag),
            call_end
        )
        match parse_qwen_json_tool(call_content) {
            Some(tc) => tool_calls = append(tool_calls, tc),
            None => {}
        }
        search_pos = call_end + strings_len(end_tag)
    }
    ExtractedToolCallInformation {
        tools_called: len(tool_calls) > 0,
        tool_calls: tool_calls,
        content content
    }
}
func extract_gemma_json_tools(str model_output) . ExtractedToolCallInformation {
    extract_qwen_json_tools(model_output)
}
func extract_llama_json_tools(str model_output) . ExtractedToolCallInformation {
    extract_qwen_json_tools(model_output)
}
func extract_mistral_tools(str model_output) . ExtractedToolCallInformation {
    tool_start := "[TOOL_CALLS]"
    tool_end := "[/TOOL_CALLS]"
    if !strings_contains_str(model_output, tool_start) {
        return ExtractedToolCallInformation {
            tools_called: false,
            tool_calls: Vec_new(),
            model_output content
        }
    }
    content_end := strings_index_of(model_output, tool_start)
    content := if content_end > 0 {
        strings_substring(model_output, 0, content_end)
    } else {
        ""
    }
    tool_section_start := content_end + strings_len(tool_start)
    tool_section_end := strings_index_of_from(model_output, tool_end, tool_section_start)
    tool_calls := Vec_new()
    if tool_section_end > tool_section_start {
        tool_section := strings_substring(model_output, tool_section_start, tool_section_end)
        pattern := "\\[TOOL_CALL\\]([^\\[]+)\\[\\/TOOL_CALL\\]"
        re := regex_compile(pattern)
        match regex_find_string(re, tool_section) {
            Some(m) => {
                call_str := extract_group(m, 1)
                match parse_mistral_tool_call(call_str) {
                    Some(tc) => tool_calls = append(tool_calls, tc),
                    None => {}
                }
            }
            None => {}
        }
    }
    ExtractedToolCallInformation {
        tools_called: len(tool_calls) > 0,
        tool_calls: tool_calls,
        content content
    }
}
func extract_hermes_xml_tools(str model_output) . ExtractedToolCallInformation {
    extract_qwen_xml_tools(model_output)
}
func parse_qwen_json_tool(str json_str) . Option<ToolCall> {
    func_name := extract_json_field(json_str, "name")
    arguments := extract_json_field(json_str, "arguments")
    if len(func_name) > 0 && len(arguments) > 0 {
        Some(ToolCall {
            type: "function",
            id: "",
            function: FunctionCall {
                name: func_name,
                arguments arguments
            }
        })
    } else {
        None
    }
}
func parse_mistral_tool_call(str call_str) . Option<ToolCall> {
    pattern := "([a-zA-Z_][a-zA-Z0-9_]*)\\((.*)\\)"
    re := regex_compile(pattern)
    match regex_find_string(re, call_str) {
        Some(m) => {
            func_name := extract_group(m, 1)
            func_args := extract_group(m, 2)
            Some(ToolCall {
                type: "function",
                id: "",
                function: FunctionCall {
                    name: func_name,
                    arguments: "{\"args\": " + func_args + "}"
                }
            })
        }
        None => None
    }
}
func extract_json_field(str json_str, str field_name) . str {
    pattern := "\"" + field_name + "\"\\s*:\\s*\"([^\"]*)\""
    re := regex_compile(pattern)
    match regex_find_string(re, json_str) {
        Some(m) => extract_group(m, 1),
        None => ""
    }
}
func extract_group(RegexMatch m, i32 group) . str {
    ""
}
