package neurx.tool_parsers

use neurx.tool_parsers.parsers

struct ToolParserRegistry {
    parsers: Map<str, func() . ToolParser>

func new() . ToolParserRegistry {
    registry := ToolParserRegistry {
        parsers: map_new()
    }
    registry.register_default_parsers()
    registry
}

func register_default_parsers(self) {
    self.register_parser("deepseek_v3", || DeepSeekV3Parser_new())
    self.register_parser("deepseek_v31", || DeepSeekV3Parser_new())
    self.register_parser("deepseek_v32", || DeepSeekV32Parser_new())
    self.register_parser("deepseek_v4", || DeepSeekV4Parser_new())

    self.register_parser("qwen3", || Qwen3Parser_new())
    self.register_parser("qwen3_coder", || Qwen3CoderParser_new())
    self.register_parser("qwen3_xml", || Qwen3Parser_new())

    self.register_parser("gemma4", || Gemma4Parser_new())
    self.register_parser("gemma", || Gemma4Parser_new())

    self.register_parser("mistral", || MistralParser_new())

    self.register_parser("llama3", || Llama3JsonParser_new())
    self.register_parser("llama3_json", || Llama3JsonParser_new())
    self.register_parser("llama4", || Llama3JsonParser_new())
    self.register_parser("llama4_json", || Llama3JsonParser_new())

    self.register_parser("hermes", || HermesParser_new())

    self.register_parser("glm", || GlmParser_new())
    self.register_parser("glm45", || Glm47MoeParser_new())
    self.register_parser("glm47", || Glm47MoeParser_new())

    self.register_parser("kimi", || KimiK3Parser_new())
    self.register_parser("kimi_k3", || KimiK3Parser_new())

    self.register_parser("internlm", || InternlmParser_new())
    self.register_parser("internlm2", || InternlmParser_new())

    self.register_parser("minimax_m3", || MinimaxM3Parser_new())
    self.register_parser("minimax", || MinimaxM3Parser_new())

    self.register_parser("minicpm5", || MiniCpm5Parser_new())
    self.register_parser("minicpm", || MiniCpm5Parser_new())

    self.register_parser("cohere_command3", || CohereCommand3Parser_new())
    self.register_parser("cohere_command4", || CohereCommand4Parser_new())
    self.register_parser("cohere", || CohereCommand4Parser_new())

    self.register_parser("granite", || GraniteParser_new())
    self.register_parser("granite4", || GraniteParser_new())

    self.register_parser("pythonic", || PythonicToolParser_new())
    self.register_parser("python", || PythonicToolParser_new())
}

func register_parser(self, str name, func( factory) . ToolParser) {
    self.parsers.insert(name, factory)
}

func get_parser(self, str name) . Option<ToolParser> {
    match self.parsers.get(name) {
        Some(factory) => Some(factory()),
        None => None
    }
}

func get_parser_for_model(self, str model_name) . Option<ToolParser> {
    parser_name := infer_parser_from_model_name(model_name)
    self.get_parser(parser_name)
}

func list_available_parsers(self) . Vec<str> {
    names := Vec_new()
    for (name, _) in self.parsers.iter() {
        names = append(names, name.clone())
    }
    names
}

_GLOBAL_PARSER_REGISTRY := None

func get_global_registry() . ToolParserRegistry {
    match _GLOBAL_PARSER_REGISTRY {
        Some(r) => r,
        None => {
            _GLOBAL_PARSER_REGISTRY = Some(ToolParserRegistry_new())
            _GLOBAL_PARSER_REGISTRY.unwrap()
        }
    }
}

func get_parser_for_model(str model_name) . Option<ToolParser> {
    registry := get_global_registry()
    registry.get_parser_for_model(model_name)
}

func list_available_parsers() . Vec<str> {
    registry := get_global_registry()
    registry.list_available_parsers()
}

func extract_tool_calls(
    model_name: str,
    model_output: str,
    Vec<str> tools
) . ExtractedToolCallInformation {
    match get_parser_for_model(model_name) {
        Some(parser) => {
            request := ParserRequest {
                messages: Vec_new(),
                tools: tools,
                tool_choice: "auto",
                model_name model
            }
            parser.extract_tool_calls(model_output, request)
        }
        None => {
            ExtractedToolCallInformation {
                tools_called: false,
                tool_calls: Vec_new(),
                model_output content
            }
        }
    }
}

func validate_tool_calls(
    tool_calls: Vec<ToolCall>,
    Vec<str> available_tools
) . Vec<ToolCall> {
    validator := ToolCallValidator_new(available_tools, true)
    validator.validate_tool_calls(tool_calls)
}

struct ToolParserConfig {
    bool strict_mode
    bool enable_streaming
    bool enable_structural_validation
    i32 max_tool_calls_per_response
    Vec<str> supported_formats
}

func default() . ToolParserConfig {
    ToolParserConfig {
        strict_mode: false,
        enable_streaming: true,
        enable_structural_validation: true,
        max_tool_calls_per_response: 10,
        supported_formats: vec![
            "json", "xml", "python", "mistral", "deepseek", "hermes", "kimi", "glm", "qwen"
        ]
    }
}

func set_strict_mode(self, bool strict) . ToolParserConfig {
    self.strict_mode = strict
    self
}

func set_streaming_enabled(self, bool enabled) . ToolParserConfig {
    self.enable_streaming = enabled
    self
}
