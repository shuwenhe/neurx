package neurx.tool_parsers

use neurx.tool_parsers.parsers

struct ToolParserRegistry {
    parsers: Map<str, func() -> ToolParser>
}

impl ToolParserRegistry {
    func new() -> ToolParserRegistry {
        registry := ToolParserRegistry {
            parsers: map::new()
        }
        registry.register_default_parsers()
        registry
    }

    func register_default_parsers(mut self) {
        self.register_parser("deepseek_v3", || DeepSeekV3Parser::new())
        self.register_parser("deepseek_v31", || DeepSeekV3Parser::new())
        self.register_parser("deepseek_v32", || DeepSeekV32Parser::new())
        self.register_parser("deepseek_v4", || DeepSeekV4Parser::new())

        self.register_parser("qwen3", || Qwen3Parser::new())
        self.register_parser("qwen3_coder", || Qwen3CoderParser::new())
        self.register_parser("qwen3_xml", || Qwen3Parser::new())

        self.register_parser("gemma4", || Gemma4Parser::new())
        self.register_parser("gemma", || Gemma4Parser::new())

        self.register_parser("mistral", || MistralParser::new())

        self.register_parser("llama3", || Llama3JsonParser::new())
        self.register_parser("llama3_json", || Llama3JsonParser::new())
        self.register_parser("llama4", || Llama3JsonParser::new())
        self.register_parser("llama4_json", || Llama3JsonParser::new())

        self.register_parser("hermes", || HermesParser::new())

        self.register_parser("glm", || GlmParser::new())
        self.register_parser("glm45", || Glm47MoeParser::new())
        self.register_parser("glm47", || Glm47MoeParser::new())

        self.register_parser("kimi", || KimiK3Parser::new())
        self.register_parser("kimi_k3", || KimiK3Parser::new())

        self.register_parser("internlm", || InternlmParser::new())
        self.register_parser("internlm2", || InternlmParser::new())

        self.register_parser("minimax_m3", || MinimaxM3Parser::new())
        self.register_parser("minimax", || MinimaxM3Parser::new())

        self.register_parser("minicpm5", || MiniCpm5Parser::new())
        self.register_parser("minicpm", || MiniCpm5Parser::new())

        self.register_parser("cohere_command3", || CohereCommand3Parser::new())
        self.register_parser("cohere_command4", || CohereCommand4Parser::new())
        self.register_parser("cohere", || CohereCommand4Parser::new())

        self.register_parser("granite", || GraniteParser::new())
        self.register_parser("granite4", || GraniteParser::new())

        self.register_parser("pythonic", || PythonicToolParser::new())
        self.register_parser("python", || PythonicToolParser::new())
    }

    func register_parser(mut self, name: str, factory: func() -> ToolParser) {
        self.parsers.insert(name, factory)
    }

    func get_parser(self, name: str) -> Option<ToolParser> {
        match self.parsers.get(name) {
            Some(factory) => Some(factory()),
            None => None
        }
    }

    func get_parser_for_model(self, model_name: str) -> Option<ToolParser> {
        parser_name := infer_parser_from_model_name(model_name)
        self.get_parser(parser_name)
    }

    func list_available_parsers(self) -> Vec<str> {
        names := Vec::new()
        for (name, _) in self.parsers.iter() {
            names.push(name.clone())
        }
        names
    }
}

_GLOBAL_PARSER_REGISTRY := None

func get_global_registry() -> ToolParserRegistry {
    match _GLOBAL_PARSER_REGISTRY {
        Some(r) => r,
        None => {
            _GLOBAL_PARSER_REGISTRY = Some(ToolParserRegistry::new())
            _GLOBAL_PARSER_REGISTRY.unwrap()
        }
    }
}

func get_parser_for_model(model_name: str) -> Option<ToolParser> {
    registry := get_global_registry()
    registry.get_parser_for_model(model_name)
}

func list_available_parsers() -> Vec<str> {
    registry := get_global_registry()
    registry.list_available_parsers()
}

func extract_tool_calls(
    model_name: str,
    model_output: str,
    tools: Vec<str>
) -> ExtractedToolCallInformation {
    match get_parser_for_model(model_name) {
        Some(parser) => {
            request := ParserRequest {
                messages: Vec::new(),
                tools: tools,
                tool_choice: "auto",
                model: model_name
            }
            parser.extract_tool_calls(model_output, request)
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

func validate_tool_calls(
    tool_calls: Vec<ToolCall>,
    available_tools: Vec<str>
) -> Vec<ToolCall> {
    validator := ToolCallValidator::new(available_tools, true)
    validator.validate_tool_calls(tool_calls)
}

struct ToolParserConfig {
    strict_mode: bool
    enable_streaming: bool
    enable_structural_validation: bool
    max_tool_calls_per_response: i32
    supported_formats: Vec<str>
}

impl ToolParserConfig {
    func default() -> ToolParserConfig {
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

    func set_strict_mode(mut self, strict: bool) -> ToolParserConfig {
        self.strict_mode = strict
        self
    }

    func set_streaming_enabled(mut self, enabled: bool) -> ToolParserConfig {
        self.enable_streaming = enabled
        self
    }
}
