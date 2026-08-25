package neurx.tool_parsers.parsers

use std.strings
use std.regex
use std.json
use neurx.tool_parsers

struct Qwen3Parser {
    base: BaseToolParser
    use_xml: bool
}

impl Qwen3Parser {
    func new() . Qwen3Parser {
        parser := Qwen3Parser {
            base: BaseToolParser::new("qwen3"),
            use_xml: false
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
}

struct Qwen3CoderParser {
    base: BaseToolParser
}

impl Qwen3CoderParser {
    func new() . Qwen3CoderParser {
        parser := Qwen3CoderParser {
            base: BaseToolParser::new("qwen3_coder")
        }
        parser.base = parser.base.set_structural_tag("qwen_3_coder")
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_qwen_json_tools(model_output)
    }
}

struct Gemma4Parser {
    base: BaseToolParser
}

impl Gemma4Parser {
    func new() . Gemma4Parser {
        parser := Gemma4Parser {
            base: BaseToolParser::new("gemma4")
        }
        parser.base = parser.base.set_structural_tag("gemma4")
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_gemma_json_tools(model_output)
    }
}

struct MistralParser {
    base: BaseToolParser
}

impl MistralParser {
    func new() . MistralParser {
        parser := MistralParser {
            base: BaseToolParser::new("mistral")
        }
        parser.base = parser.base.set_tool_choice_required(false)
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_mistral_tools(model_output)
    }
}

struct Llama3JsonParser {
    base: BaseToolParser
}

impl Llama3JsonParser {
    func new() . Llama3JsonParser {
        parser := Llama3JsonParser {
            base: BaseToolParser::new("llama3_json")
        }
        parser.base = parser.base.set_structural_tag("llama")
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_llama_json_tools(model_output)
    }
}

struct HermesParser {
    base: BaseToolParser
}

impl HermesParser {
    func new() . HermesParser {
        parser := HermesParser {
            base: BaseToolParser::new("hermes")
        }
        parser.base = parser.base.set_structural_tag("hermes")
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_hermes_xml_tools(model_output)
    }
}

func extract_qwen_json_tools(str model_output) . ExtractedToolCallInformation {
    pattern := "\\{[^}]*\\\"function\\\"[^}]*\\}"
    re := regex::compile(pattern)

    tool_calls := Vec::new()
    search_pos := 0
    content_end := strings::len(model_output)

    for search_pos < content_end {
        match regex::find_at(re, model_output, search_pos) {
            Some(m) => {
                json_str := strings::substring(model_output, m.start, m.end)
                match parse_qwen_json_tool(json_str) {
                    Some(tc) => tool_calls.push(tc),
                    None => {}
                }
                search_pos = m.end
            }
            None => break
        }
    }

    content_end_pos := if len(tool_calls) > 0 {
        strings::index_of(model_output, "{")
    } else {
        strings::len(model_output)
    }

    content := if content_end_pos > 0 {
        strings::substring(model_output, 0, content_end_pos)
    } else {
        ""
    }

    ExtractedToolCallInformation {
        tools_called: len(tool_calls) > 0,
        tool_calls: tool_calls,
        content: content
    }
}

func extract_qwen_xml_tools(str model_output) . ExtractedToolCallInformation {
    start_tag := "<tool_call>"
    end_tag := "</tool_call>"

    if !strings::contains_str(model_output, start_tag) {
        return ExtractedToolCallInformation {
            tools_called: false,
            tool_calls: Vec::new(),
            content: model_output
        }
    }

    content_end := strings::index_of(model_output, start_tag)
    content := if content_end > 0 {
        strings::substring(model_output, 0, content_end)
    } else {
        ""
    }

    tool_calls := Vec::new()
    search_pos := 0

    for search_pos < strings::len(model_output) {
        call_start := strings::index_of_from(model_output, start_tag, search_pos)
        if call_start < 0 {
            break
        }

        call_end := strings::index_of_from(model_output, end_tag, call_start)
        if call_end < 0 {
            break
        }

        call_content := strings::substring(
            model_output,
            call_start + strings::len(start_tag),
            call_end
        )

        match parse_qwen_json_tool(call_content) {
            Some(tc) => tool_calls.push(tc),
            None => {}
        }

        search_pos = call_end + strings::len(end_tag)
    }

    ExtractedToolCallInformation {
        tools_called: len(tool_calls) > 0,
        tool_calls: tool_calls,
        content: content
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

    if !strings::contains_str(model_output, tool_start) {
        return ExtractedToolCallInformation {
            tools_called: false,
            tool_calls: Vec::new(),
            content: model_output
        }
    }

    content_end := strings::index_of(model_output, tool_start)
    content := if content_end > 0 {
        strings::substring(model_output, 0, content_end)
    } else {
        ""
    }

    tool_section_start := content_end + strings::len(tool_start)
    tool_section_end := strings::index_of_from(model_output, tool_end, tool_section_start)

    tool_calls := Vec::new()

    if tool_section_end > tool_section_start {
        tool_section := strings::substring(model_output, tool_section_start, tool_section_end)
        pattern := "\\[TOOL_CALL\\]([^\\[]+)\\[\\/TOOL_CALL\\]"
        re := regex::compile(pattern)

        match regex::find_string(re, tool_section) {
            Some(m) => {
                call_str := extract_group(m, 1)
                match parse_mistral_tool_call(call_str) {
                    Some(tc) => tool_calls.push(tc),
                    None => {}
                }
            }
            None => {}
        }
    }

    ExtractedToolCallInformation {
        tools_called: len(tool_calls) > 0,
        tool_calls: tool_calls,
        content: content
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
                arguments: arguments
            }
        })
    } else {
        None
    }
}

func parse_mistral_tool_call(str call_str) . Option<ToolCall> {
    pattern := "([a-zA-Z_][a-zA-Z0-9_]*)\\((.*)\\)"
    re := regex::compile(pattern)

    match regex::find_string(re, call_str) {
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
    re := regex::compile(pattern)
    match regex::find_string(re, json_str) {
        Some(m) => extract_group(m, 1),
        None => ""
    }
}

func extract_group(RegexMatch m, i32 group) . str {
    ""
}
