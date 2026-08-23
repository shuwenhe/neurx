package neurx.tool_parsers

use std.json
use std.regex
use std.strings

struct ToolCall {
    type: str
    id: str
    function: FunctionCall
}

struct FunctionCall {
    name: str
    arguments: str
}

struct ExtractedToolCallInformation {
    tools_called: bool
    tool_calls: Vec<ToolCall>
    content: str
}

struct DeltaToolCall {
    index: i32
    type: str
    function: DeltaFunctionCall
}

struct DeltaFunctionCall {
    name: str
    arguments: str
}

struct ParserRequest {
    messages: Vec<str>
    tools: Vec<str>
    tool_choice: str
    model: str
}

struct ParserResponse {
    tools_called: bool
    tool_calls: Vec<ToolCall>
    content: str
    is_streaming: bool
}

trait ToolParser {
    fn extract_tool_calls(model_output: str, request: ParserRequest) -> ExtractedToolCallInformation

    fn extract_tool_calls_streaming(
        previous_text: str,
        current_text: str,
        delta_text: str,
        request: ParserRequest
    ) -> DeltaToolCall

    fn adjust_request(request: ParserRequest) -> ParserRequest {
        request
    }

    fn get_parser_name() -> str

    fn supports_streaming() -> bool {
        true
    }

    fn supports_tool_choice_required() -> bool {
        true
    }

    fn get_structural_tag_model() -> str {
        ""
    }
}

struct BaseToolParser {
    parser_name: str
    supports_streaming: bool
    supports_required: bool
    structural_tag_model: str
    tokenizer: str
    tools: Vec<str>
}

impl BaseToolParser {
    func new(name: str) -> BaseToolParser {
        BaseToolParser {
            parser_name: name,
            supports_streaming: true,
            supports_required: true,
            structural_tag_model: "",
            tokenizer: "default",
            tools: Vec::new()
        }
    }

    func set_tools(mut self, tools: Vec<str>) -> BaseToolParser {
        self.tools = tools
        self
    }

    func set_streaming(mut self, streaming: bool) -> BaseToolParser {
        self.supports_streaming = streaming
        self
    }

    func set_tool_choice_required(mut self, required: bool) -> BaseToolParser {
        self.supports_required = required
        self
    }

    func set_structural_tag(mut self, tag: str) -> BaseToolParser {
        self.structural_tag_model = tag
        self
    }
}

struct ToolExtractionContext {
    current_pos: i32
    bracket_depth: i32
    in_string: bool
    escaped: bool
    last_newline_pos: i32
    tool_call_count: i32
}

func create_extraction_context() -> ToolExtractionContext {
    ToolExtractionContext {
        current_pos: 0,
        bracket_depth: 0,
        in_string: false,
        escaped: false,
        last_newline_pos: 0,
        tool_call_count: 0
    }
}

func find_json_boundaries(text: str, start: i32) -> (i32, i32) {
    let mut brace_depth = 0
    let mut in_string = false
    let mut escaped = false
    let mut start_pos = -1
    let mut end_pos = -1

    let chars = strings::chars(text)
    let i = start
    while i < len(chars) {
        let c = chars[i]

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

func extract_json_field(json_str: str, field_name: str) -> str {
    let pattern = "\"" + field_name + "\"\\s*:\\s*\"([^\"]*)\""
    let re = regex::compile(pattern)
    match re::find_string(re, json_str) {
        Some(m) => m.group(1).to_string(),
        None => ""
    }
}

func validate_tool_call(tool_call: ToolCall, available_tools: Vec<str>) -> bool {
    let mut found = false
    for tool_name in available_tools {
        if tool_name == tool_call.function.name {
            found = true
            break
        }
    }
    found && tool_call.type != ""
}
