package neurx.tool_parsers.parsers

use std.strings
use std.regex
use neurx.tool_parsers

struct GlmParser {
    base: BaseToolParser
}

impl GlmParser {
    func new() . GlmParser {
        parser := GlmParser {
            base: BaseToolParser::new("glm")
        }
        parser.base = parser.base.set_structural_tag("glm_4_7")
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_xml_tools(model_output, "tool_call")
    }
}

struct Glm47MoeParser {
    base: BaseToolParser
}

impl Glm47MoeParser {
    func new() . Glm47MoeParser {
        parser := Glm47MoeParser {
            base: BaseToolParser::new("glm47")
        }
        parser.base = parser.base.set_structural_tag("glm_4_7")
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_xml_tools(model_output, "tool_call")
    }
}

struct KimiK3Parser {
    base: BaseToolParser
}

impl KimiK3Parser {
    func new() . KimiK3Parser {
        parser := KimiK3Parser {
            base: BaseToolParser::new("kimi_k3")
        }
        parser.base = parser.base.set_structural_tag("kimi")
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_xml_tools(model_output, "function")
    }
}

struct InternlmParser {
    base: BaseToolParser
}

impl InternlmParser {
    func new() . InternlmParser {
        parser := InternlmParser {
            base: BaseToolParser::new("internlm")
        }
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_qwen_json_tools(model_output)
    }
}

struct MinimaxM3Parser {
    base: BaseToolParser
}

impl MinimaxM3Parser {
    func new() . MinimaxM3Parser {
        parser := MinimaxM3Parser {
            base: BaseToolParser::new("minimax_m3")
        }
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_qwen_json_tools(model_output)
    }
}

struct MiniCpm5Parser {
    base: BaseToolParser
}

impl MiniCpm5Parser {
    func new() . MiniCpm5Parser {
        parser := MiniCpm5Parser {
            base: BaseToolParser::new("minicpm5")
        }
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_xml_function_tools(model_output)
    }
}

struct CohereCommand3Parser {
    base: BaseToolParser
}

impl CohereCommand3Parser {
    func new() . CohereCommand3Parser {
        parser := CohereCommand3Parser {
            base: BaseToolParser::new("cohere_command3")
        }
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_json_tool_array(model_output)
    }
}

struct CohereCommand4Parser {
    base: BaseToolParser
}

impl CohereCommand4Parser {
    func new() . CohereCommand4Parser {
        parser := CohereCommand4Parser {
            base: BaseToolParser::new("cohere_command4")
        }
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_json_tool_array(model_output)
    }
}

struct GraniteParser {
    base: BaseToolParser
}

impl GraniteParser {
    func new() . GraniteParser {
        parser := GraniteParser {
            base: BaseToolParser::new("granite")
        }
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_qwen_xml_tools(model_output)
    }
}

struct PythonicToolParser {
    base: BaseToolParser
}

impl PythonicToolParser {
    func new() . PythonicToolParser {
        parser := PythonicToolParser {
            base: BaseToolParser::new("pythonic")
        }
        parser
    }

    func extract_tool_calls(self, str model_output, ParserRequest request) . ExtractedToolCallInformation {
        extract_python_tool_calls(model_output)
    }
}

func extract_xml_tools(str model_output, str tag) . ExtractedToolCallInformation {
    start_tag := "<" + tag + ">"
    end_tag := "</" + tag + ">"

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

func extract_xml_function_tools(str model_output) . ExtractedToolCallInformation {
    start_tag := "<function name=\""
    end_tag := "</function>"

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

        full_tag_end := strings::index_of_from(model_output, ">", call_start)
        func_name := strings::substring(
            model_output,
            call_start + strings::len(start_tag),
            full_tag_end - 1
        )

        call_content := strings::substring(
            model_output,
            full_tag_end + 1,
            call_end
        )

        arguments := extract_param_values(call_content)

        tool_calls.push(ToolCall {
            type: "function",
            id: "",
            function: FunctionCall {
                name: func_name,
                arguments: arguments
            }
        })

        search_pos = call_end + strings::len(end_tag)
    }

    ExtractedToolCallInformation {
        tools_called: len(tool_calls) > 0,
        tool_calls: tool_calls,
        content: content
    }
}

func extract_json_tool_array(str model_output) . ExtractedToolCallInformation {
    pattern := "\\[\\s*\\{[^\\]]*\\}\\s*\\]"
    re := regex::compile(pattern)

    match regex::find_string(re, model_output) {
        Some(m) => {
            json_array := extract_group(m, 0)
            tool_calls := Vec::new()

            pattern2 := "\\{[^}]*\\}"
            re2 := regex::compile(pattern2)

            match regex::find_string(re2, json_array) {
                Some(m2) => {
                    json_obj := extract_group(m2, 0)
                    match parse_qwen_json_tool(json_obj) {
                        Some(tc) => tool_calls.push(tc),
                        None => {}
                    }
                }
                None => {}
            }

            content_end := strings::index_of(model_output, "[")
            content := if content_end > 0 {
                strings::substring(model_output, 0, content_end)
            } else {
                ""
            }

            ExtractedToolCallInformation {
                tools_called: len(tool_calls) > 0,
                tool_calls: tool_calls,
                content: content
            }
        }
        None => {
            ExtractedToolCallInformation {
                tools_called: false,
                tool_calls: Vec::new(),
                content: model_output
            }
        }
    }
}

func extract_python_tool_calls(str model_output) . ExtractedToolCallInformation {
    pattern := "\\[([a-zA-Z_][a-zA-Z0-9_]*\\([^)]*\\)[,\\s]*)+\\]"
    re := regex::compile(pattern)

    match regex::find_string(re, model_output) {
        Some(m) => {
            tool_list := extract_group(m, 0)
            tool_calls := Vec::new()

            pattern2 := "([a-zA-Z_][a-zA-Z0-9_]*)\\(([^)]*)\\)"
            re2 := regex::compile(pattern2)

            match regex::find_string(re2, tool_list) {
                Some(m2) => {
                    func_name := extract_group(m2, 1)
                    func_args := extract_group(m2, 2)

                    tool_calls.push(ToolCall {
                        type: "function",
                        id: "",
                        function: FunctionCall {
                            name: func_name,
                            arguments: "{\"args\": \"" + func_args + "\"}"
                        }
                    })
                }
                None => {}
            }

            content_end := strings::index_of(model_output, "[")
            content := if content_end > 0 {
                strings::substring(model_output, 0, content_end)
            } else {
                ""
            }

            ExtractedToolCallInformation {
                tools_called: len(tool_calls) > 0,
                tool_calls: tool_calls,
                content: content
            }
        }
        None => {
            ExtractedToolCallInformation {
                tools_called: false,
                tool_calls: Vec::new(),
                content: model_output
            }
        }
    }
}

func extract_param_values(str content) . str {
    pattern := "<param name=\"([^\"]+)\">([^<]*)</param>"
    ""
}

func extract_group(RegexMatch m, i32 group) . str {
    ""
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

func extract_json_field(str json_str, str field_name) . str {
    pattern := "\"" + field_name + "\"\\s*:\\s*\"([^\"]*)\""
    re := regex::compile(pattern)
    match regex::find_string(re, json_str) {
        Some(m) => extract_group(m, 1),
        None => ""
    }
}
