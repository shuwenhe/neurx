package neurx.tool_parsers
use std.json
use std.regex
use std.strings
struct ToolCall {
    str type
    str id
    FunctionCall function
}
struct FunctionCall {
    str name
    str arguments
}
struct ExtractedToolCallInformation {
    bool tools_called
    Vec<ToolCall> tool_calls
    str content
}
struct DeltaToolCall {
    i32 index
    str type
    DeltaFunctionCall function
}
struct DeltaFunctionCall {
    str name
    str arguments
}
struct ParserRequest {
    Vec<str> messages
    Vec<str> tools
    str tool_choice
    str model
}
struct ParserResponse {
    bool tools_called
    Vec<ToolCall> tool_calls
    str content
    bool is_streaming
}
trait ToolParser {
    fn extract_tool_calls(model_output: str, request: ParserRequest) . ExtractedToolCallInformation
    fn extract_tool_calls_streaming(
        previous_text: str,
        current_text: str,
        delta_text: str,
        ParserRequest request
    ) . DeltaToolCall
    fn adjust_request(request: ParserRequest) . ParserRequest {
        request
    }
    fn get_parser_name() . str
    fn supports_streaming() . bool {
        true
    }
    fn supports_tool_choice_required() . bool {
        true
    }
    fn get_structural_tag_model() . str {
        ""
    }
}
struct BaseToolParser {
    str parser_name
    bool supports_streaming
    bool supports_required
    str structural_tag_model
    str tokenizer
    Vec<str> tools
}
func new(str name) . BaseToolParser {
    BaseToolParser {
        parser_name: name,
        supports_streaming: true,
        supports_required: true,
        structural_tag_model: "",
        tokenizer: "default",
        tools: Vec_new()
    }
}
func set_tools(self, Vec<str> tools) . BaseToolParser {
    self.tools = tools
    self
}
func set_streaming(self, bool streaming) . BaseToolParser {
    self.supports_streaming = streaming
    self
}
func set_tool_choice_required(self, bool required) . BaseToolParser {
    self.supports_required = required
    self
}
func set_structural_tag(self, str tag) . BaseToolParser {
    self.structural_tag_model = tag
    self
}
struct ToolExtractionContext {
    i32 current_pos
    i32 bracket_depth
    bool in_string
    bool escaped
    i32 last_newline_pos
    i32 tool_call_count
}
func create_extraction_context() . ToolExtractionContext {
    ToolExtractionContext {
        current_pos: 0,
        bracket_depth: 0,
        in_string: false,
        escaped: false,
        last_newline_pos: 0,
        tool_call_count: 0
    }
}
func find_json_boundaries(str text, i32 start) . (i32, i32) {
    brace_depth := 0
    in_string := false
    escaped := false
    start_pos := -1
    end_pos := -1
    chars := strings_chars(text)
    i := start
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
                if brace_depth == 0 {
                    start_pos = i
                }
                brace_depth = brace_depth + 1
            } else if c == '}' {
                brace_depth = brace_depth - 1
                if brace_depth == 0 && start_pos >= 0 {
                    end_pos = i + 1
                    break
                }
            }
        }
        i = i + 1
    }
    (start_pos, end_pos)
}
func extract_json_field(str json_str, str field_name) . str {
    pattern := "\"" + field_name + "\"\\s*:\\s*\"([^\"]*)\""
    re := regex_compile(pattern)
    match re_find_string(re, json_str) {
        Some(m) => m.group(1).to_string(),
        None => ""
    }
}
func validate_tool_call(ToolCall tool_call, Vec<str> available_tools) . bool {
    found := false
    for tool_name in available_tools {
        if tool_name == tool_call.function.name {
            found = true
            break
        }
    }
    found && tool_call.type != ""
}
