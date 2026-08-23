package neurx.inference.advanced.tool_parser

func tool_choice_none() int { 1 }

func tool_choice_auto() int { 2 }

func tool_choice_required() int { 3 }

func tool_choice_named() int { 4 }

struct tool_definition {
    string name
    string description
    []string required_arguments
}

struct tool_choice {
    int mode
    string required_name
}

struct parsed_tool_call {
    string call_id
    string name
    string arguments_json
    string parser_name
    bool found
    bool valid
    string error_message
}

struct tool_parser_registry {
    []string parser_names
    []tool_definition tools
}

func new_tool_parser_registry() tool_parser_registry {
    tool_parser_registry {
        parser_names: ["openai", "hermes", "deepseek", "mistral"],
        tools: [],
    }
}

func tool_register(tool_parser_registry registry, tool_definition definition) tool_parser_registry {
    int i = 0
    while i < len(registry.tools) {
        if registry.tools[i].name == definition.name {
            registry.tools[i] = definition
            return registry
        }
        i = i + 1
    }
    registry.tools.push(definition)
    registry
}

func tool_find_substring(string text, string pattern, int start) int {
    if len(pattern) == 0 {
        return start
    }
    int i = start
    while i + len(pattern) <= len(text) {
        int j = 0
        bool matches = true
        while j < len(pattern) {
            if text[i + j] != pattern[j] {
                matches = false
                break
            }
            j = j + 1
        }
        if matches {
            return i
        }
        i = i + 1
    }
    -1
}

func tool_is_space(int ch) bool {
    ch == 32 || ch == 10 || ch == 13 || ch == 9
}

func tool_skip_space(string text, int start) int {
    int i = start
    while i < len(text) && tool_is_space(int(text[i])) {
        i = i + 1
    }
    i
}

func tool_substring(string text, int start, int end) string {
    string result = ""
    int i = start
    while i < end && i < len(text) {
        result = result + string(text[i])
        i = i + 1
    }
    result
}

func tool_json_string_field(string text, string field_name) string {
    string key = "\"" + field_name + "\""
    int key_start = tool_find_substring(text, key, 0)
    if key_start < 0 {
        return ""
    }
    int colon = tool_find_substring(text, ":", key_start + len(key))
    if colon < 0 {
        return ""
    }
    int start = tool_skip_space(text, colon + 1)
    if start >= len(text) || int(text[start]) != 34 {
        return ""
    }
    string value = ""
    bool escaped = false
    int i = start + 1
    while i < len(text) {
        int ch = int(text[i])
        if escaped {
            value = value + string(text[i])
            escaped = false
        } else if ch == 92 {
            value = value + "\\"
            escaped = true
        } else if ch == 34 {
            return value
        } else {
            value = value + string(text[i])
        }
        i = i + 1
    }
    ""
}

func tool_balanced_json_value(string text, int start) string {
    int value_start = tool_skip_space(text, start)
    if value_start >= len(text) {
        return ""
    }
    int first = int(text[value_start])
    if first != 123 && first != 91 {
        return ""
    }
    int object_depth = 0
    int array_depth = 0
    bool in_string = false
    bool escaped = false
    int i = value_start
    while i < len(text) {
        int ch = int(text[i])
        if in_string {
            if escaped {
                escaped = false
            } else if ch == 92 {
                escaped = true
            } else if ch == 34 {
                in_string = false
            }
        } else if ch == 34 {
            in_string = true
        } else if ch == 123 {
            object_depth = object_depth + 1
        } else if ch == 125 {
            object_depth = object_depth - 1
        } else if ch == 91 {
            array_depth = array_depth + 1
        } else if ch == 93 {
            array_depth = array_depth - 1
        }
        if !in_string && object_depth == 0 && array_depth == 0 {
            return tool_substring(text, value_start, i + 1)
        }
        i = i + 1
    }
    ""
}

func tool_json_object_field(string text, string field_name) string {
    string key = "\"" + field_name + "\""
    int key_start = tool_find_substring(text, key, 0)
    if key_start < 0 {
        return ""
    }
    int colon = tool_find_substring(text, ":", key_start + len(key))
    if colon < 0 {
        return ""
    }
    tool_balanced_json_value(text, colon + 1)
}

func tool_extract_tag(string text, string open_tag, string close_tag) string {
    int start = tool_find_substring(text, open_tag, 0)
    if start < 0 {
        return ""
    }
    start = start + len(open_tag)
    int end = tool_find_substring(text, close_tag, start)
    if end < 0 {
        return ""
    }
    tool_substring(text, start, end)
}

func tool_exists(tool_parser_registry registry, string name) bool {
    int i = 0
    while i < len(registry.tools) {
        if registry.tools[i].name == name {
            return true
        }
        i = i + 1
    }
    false
}

func tool_required_argument(tool_definition definition, int index) string {
    definition.required_arguments[index]
}

func tool_definition_at(tool_parser_registry registry, int index) tool_definition {
    registry.tools[index]
}

func tool_arguments_have_required(string arguments_json, tool_definition definition) bool {
    int i = 0
    while i < len(definition.required_arguments) {
        string argument_name = tool_required_argument(definition, i)
        string key = "\"" + argument_name + "\""
        if tool_find_substring(arguments_json, key, 0) < 0 {
            return false
        }
        i = i + 1
    }
    true
}

func tool_validate(tool_parser_registry registry, tool_choice choice, parsed_tool_call call) parsed_tool_call {
    if choice.mode == tool_choice_none() {
        if call.found {
            call.valid = false
            call.error_message = "tool calls are disabled"
        } else {
            call.valid = true
        }
        return call
    }
    if !call.found {
        if choice.mode == tool_choice_required() || choice.mode == tool_choice_named() {
            call.valid = false
            call.error_message = "a tool call is required"
        } else {
            call.valid = true
        }
        return call
    }
    if choice.mode == tool_choice_named() && call.name != choice.required_name {
        call.valid = false
        call.error_message = "tool choice name mismatch"
        return call
    }
    if !tool_exists(registry, call.name) {
        call.valid = false
        call.error_message = "unknown tool: " + call.name
        return call
    }
    int i = 0
    while i < len(registry.tools) {
        tool_definition definition = tool_definition_at(registry, i)
        if definition.name == call.name && !tool_arguments_have_required(call.arguments_json, definition) {
            call.valid = false
            call.error_message = "missing required tool argument"
            return call
        }
        i = i + 1
    }
    call.valid = true
    call.error_message = ""
    call
}

func parse_tool_call(tool_parser_registry registry, string parser_name, string text, tool_choice choice) parsed_tool_call {
    string payload = text
    if parser_name == "hermes" || parser_name == "mistral" {
        payload = tool_extract_tag(text, "<tool_call>", "</tool_call>")
    } else if parser_name == "deepseek" {
        string tagged = tool_extract_tag(text, "<｜tool▁calls▁begin｜>", "<｜tool▁calls▁end｜>")
        if tagged != "" {
            payload = tagged
        } else {
            payload = tool_extract_tag(text, "<tool_call>", "</tool_call>")
        }
    }
    parsed_tool_call call
    call.call_id = tool_json_string_field(payload, "id")
    call.name = tool_json_string_field(payload, "name")
    call.arguments_json = tool_json_object_field(payload, "arguments")
    call.parser_name = parser_name
    call.found = false
    call.valid = false
    call.error_message = ""
    if call.arguments_json == "" {
        call.arguments_json = tool_json_string_field(payload, "arguments")
    }
    if call.arguments_json == "" {
        call.arguments_json = tool_json_object_field(payload, "parameters")
    }
    call.found = call.name != ""
    tool_validate(registry, choice, call)
}

func split_reasoning_content(string text, string end_marker) []string {
    int end = tool_find_substring(text, end_marker, 0)
    if end < 0 {
        return [text, ""]
    }
    [tool_substring(text, 0, end), tool_substring(text, end + len(end_marker), len(text))]
}
