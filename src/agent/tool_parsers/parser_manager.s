package neurx.tool_parsers

use std.map
use std.vec

type ToolParserFactory = func() -> ToolParser

struct ToolParserManager {
    parsers: Map<str, ToolParserFactory>
    lazy_parsers: Map<str, (str, str)>
    loaded_modules: Map<str, bool>
}

struct ToolParserManagerInstance {
    instance: ToolParserManager
}

_TOOL_PARSER_MANAGER := ToolParserManagerInstance {
    instance: ToolParserManager {
        parsers: map::new(),
        lazy_parsers: map::new(),
        loaded_modules: map::new()
    }
}

impl ToolParserManager {
    func new() -> ToolParserManager {
        ToolParserManager {
            parsers: map::new(),
            lazy_parsers: map::new(),
            loaded_modules: map::new()
        }
    }

    func register_parser(mut self, str name, ToolParserFactory factory) {
        self.parsers.insert(name, factory)
    }

    func register_lazy_parser(mut self, str name, str module, str class_name) {
        self.lazy_parsers.insert(name, (module, class_name))
    }

    func get_parser(self, str name) -> Option<ToolParser> {
        match self.parsers.get(name) {
            Some(factory) => Some(factory()),
            None => {
                match self.lazy_parsers.get(name) {
                    Some((module, class)) => {
                        load_parser_module(module, class, name)
                    }
                    None => None
                }
            }
        }
    }

    func list_parsers(self) -> Vec<str> {
        names := Vec::new()
        for (name, _) in self.parsers.iter() {
            names.push(name.clone())
        }
        for (name, _) in self.lazy_parsers.iter() {
            names.push(name.clone())
        }
        names
    }

    func get_parser_for_model(self, str model_name) -> Option<ToolParser> {
        parser_name := infer_parser_from_model_name(model_name)
        self.get_parser(parser_name)
    }
}

func get_manager() -> ToolParserManager {
    _TOOL_PARSER_MANAGER.instance.clone()
}

func register_global_parser(str name, ToolParserFactory factory) {
    _TOOL_PARSER_MANAGER.instance.register_parser(name, factory)
}

func register_global_lazy_parser(str name, str module, str class_name) {
    _TOOL_PARSER_MANAGER.instance.register_lazy_parser(name, module, class_name)
}

func load_parser_module(str module, str class_name, str parser_name) -> Option<ToolParser> {
    None
}

func infer_parser_from_model_name(str model_name) -> str {
    match model_name {
        s if strings::contains_str(s, "deepseek-v3") => "deepseek_v3",
        s if strings::contains_str(s, "deepseek-v31") => "deepseek_v31",
        s if strings::contains_str(s, "deepseek-v32") => "deepseek_v32",
        s if strings::contains_str(s, "deepseek-v4") => "deepseek_v4",
        s if strings::contains_str(s, "qwen") && strings::contains_str(s, "3") => "qwen3",
        s if strings::contains_str(s, "gemma") && strings::contains_str(s, "4") => "gemma4",
        s if strings::contains_str(s, "mistral") => "mistral",
        s if strings::contains_str(s, "llama") && strings::contains_str(s, "3") => "llama3",
        s if strings::contains_str(s, "llama") && strings::contains_str(s, "4") => "llama4",
        s if strings::contains_str(s, "hermes") => "hermes",
        s if strings::contains_str(s, "kimi") => "kimi",
        s if strings::contains_str(s, "glm") => "glm",
        s if strings::contains_str(s, "internlm") => "internlm",
        s if strings::contains_str(s, "minimax") => "minimax",
        s if strings::contains_str(s, "minicp m") => "minicpm",
        s if strings::contains_str(s, "cohere") => "cohere",
        _ => "default"
    }
}
