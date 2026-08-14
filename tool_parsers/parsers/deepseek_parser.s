package neurx.tool_parsers.parsers

use std.strings
use std.regex
use neurx.tool_parsers

struct DeepSeekV3Parser {
    base: BaseToolParser
}

impl DeepSeekV3Parser {
    func new() -> DeepSeekV3Parser {
        let mut parser = DeepSeekV3Parser {
            base: BaseToolParser::new("deepseek_v3")
        }
        parser.base = parser.base.set_structural_tag("deepseek_r1")
        parser
    }
    
    func extract_tool_calls(self, model_output: str, request: ParserRequest) -> ExtractedToolCallInformation {
        let tool_start = "<｜tool▁calls▁begin｜>"
        let tool_end = "<｜tool▁calls▁end｜>"
        let single_call_start = "<｜tool▁call▁begin｜>"
        let single_call_end = "<｜tool▁call▁end｜>"
        
        if !strings::contains_str(model_output, tool_start) {
            return ExtractedToolCallInformation {
                tools_called: false,
                tool_calls: Vec::new(),
                content: model_output
            }
        }
        
        let content_end = strings::index_of(model_output, tool_start)
        let content = if content_end > 0 {
            strings::substring(model_output, 0, content_end)
        } else {
            ""
        }
        
        let tool_section_start = content_end
        let tool_section_end = strings::index_of_from(model_output, tool_end, tool_section_start)
        
        let mut tool_calls = Vec::new()
        
        if tool_section_end > tool_section_start {
            let tool_section = strings::substring(
                model_output,
                tool_section_start + strings::len(tool_start),
                tool_section_end
            )
            
            let mut search_pos = 0
            while search_pos < strings::len(tool_section) {
                let call_start_pos = strings::index_of_from(tool_section, single_call_start, search_pos)
                if call_start_pos < 0 {
                    break
                }
                
                let call_end_pos = strings::index_of_from(tool_section, single_call_end, call_start_pos)
                if call_end_pos < 0 {
                    break
                }
                
                let call_content = strings::substring(
                    tool_section,
                    call_start_pos + strings::len(single_call_start),
                    call_end_pos
                )
                
                match parse_deepseek_tool_call(call_content) {
                    Some(tc) => tool_calls.push(tc),
                    None => {}
                }
                
                search_pos = call_end_pos + strings::len(single_call_end)
            }
        }
        
        ExtractedToolCallInformation {
            tools_called: len(tool_calls) > 0,
            tool_calls: tool_calls,
            content: content
        }
    }
}

struct DeepSeekV32Parser {
    base: BaseToolParser
}

impl DeepSeekV32Parser {
    func new() -> DeepSeekV32Parser {
        let mut parser = DeepSeekV32Parser {
            base: BaseToolParser::new("deepseek_v32")
        }
        parser.base = parser.base.set_structural_tag("deepseek_r1")
        parser
    }
    
    func extract_tool_calls(self, model_output: str, request: ParserRequest) -> ExtractedToolCallInformation {
        DeepSeekV3Parser::new().extract_tool_calls(model_output, request)
    }
}

struct DeepSeekV4Parser {
    base: BaseToolParser
}

impl DeepSeekV4Parser {
    func new() -> DeepSeekV4Parser {
        let mut parser = DeepSeekV4Parser {
            base: BaseToolParser::new("deepseek_v4")
        }
        parser.base = parser.base.set_structural_tag("deepseek_v3_1")
        parser
    }
    
    func extract_tool_calls(self, model_output: str, request: ParserRequest) -> ExtractedToolCallInformation {
        DeepSeekV3Parser::new().extract_tool_calls(model_output, request)
    }
}

func parse_deepseek_tool_call(call_content: str) -> Option<ToolCall> {
    let lines = strings::split(call_content, "\n")
    
    let mut func_type = ""
    let mut func_name = ""
    let mut func_args = ""
    
    for line in lines {
        let trimmed = strings::trim(line)
        
        if strings::starts_with(trimmed, "<") && strings::ends_with(trimmed, ">") {
            func_type = trimmed
        } else if strings::starts_with(trimmed, "```json") {
            func_args = strings::substring(trimmed, 7, strings::len(trimmed))
        }
    }
    
    if len(func_name) > 0 && len(func_args) > 0 {
        Some(ToolCall {
            type: "function",
            id: "",
            function: FunctionCall {
                name: func_name,
                arguments: func_args
            }
        })
    } else {
        None
    }
}
