package neurx.inference.advanced.structured_output

func structured_root_object() int { 1 }

func structured_root_array() int { 2 }

struct structured_field_rule {
    string field_name
    string value_type
    bool required
    string[] enum_values
}

struct structured_schema {
    string schema_name
    int root_type
    []structured_field_rule fields
    bool allow_additional_fields
}

struct json_stream_state {
    int object_depth
    int array_depth
    bool in_string
    bool escape_next
    bool started
    bool complete
    bool valid
    string error_message
    string text
    string delimiter_stack
}

struct structured_validation_result {
    bool valid
    string error_message
    string normalized_text
}

func new_structured_validation_result(bool valid, string error_message, string normalized_text) structured_validation_result {
    structured_validation_result result
    result.valid = valid
    result.error_message = error_message
    result.normalized_text = normalized_text
    result
}

func structured_substring(string text, int start, int end) string {
    string result = ""
    int i = start
    for i < end && i < len(text) {
        result = result + string(text[i])
        i = i + 1
    }
    result
}

func new_json_stream_state() json_stream_state {
    json_stream_state {
        object_depth: 0,
        array_depth: 0,
        in_string: false,
        escape_next: false,
        started: false,
        complete: false,
        valid: true,
        error_message: "",
        text: "",
        delimiter_stack: "",
    }
}

func structured_is_space(int ch) bool {
    ch == 32 || ch == 10 || ch == 13 || ch == 9
}

func structured_stack_top(string stack) int {
    if len(stack) == 0 {
        return -1
    }
    int(stack[len(stack) - 1])
}

func structured_stack_pop(string stack) string {
    if len(stack) <= 1 {
        return ""
    }
    string result = ""
    int i = 0
    for i < len(stack) - 1 {
        result = result + string(stack[i])
        i = i + 1
    }
    result
}

func json_stream_consume(json_stream_state state, string chunk) json_stream_state {
    if !state.valid {
        return state
    }
    int i = 0
    for i < len(chunk) {
        int ch = int(chunk[i])
        if state.complete {
            if !structured_is_space(ch) {
                state.valid = false
                state.error_message = "content after JSON root"
                return state
            }
            state.text = state.text + string(chunk[i])
            i = i + 1
            continue
        }
        if !state.started {
            if structured_is_space(ch) {
                state.text = state.text + string(chunk[i])
                i = i + 1
                continue
            }
            if ch == 123 {
                state.object_depth = 1
                state.delimiter_stack = "{"
            } else if ch == 91 {
                state.array_depth = 1
                state.delimiter_stack = "["
            } else {
                state.valid = false
                state.error_message = "JSON root must be object or array"
                return state
            }
            state.started = true
            state.text = state.text + string(chunk[i])
            i = i + 1
            continue
        }
        if state.in_string {
            if state.escape_next {
                state.escape_next = false
            } else if ch == 92 {
                state.escape_next = true
            } else if ch == 34 {
                state.in_string = false
            }
        } else if ch == 34 {
            state.in_string = true
        } else if ch == 123 {
            state.object_depth = state.object_depth + 1
            state.delimiter_stack = state.delimiter_stack + "{"
        } else if ch == 125 {
            if structured_stack_top(state.delimiter_stack) != 123 {
                state.valid = false
                state.error_message = "mismatched JSON delimiter"
                return state
            }
            state.object_depth = state.object_depth - 1
            state.delimiter_stack = structured_stack_pop(state.delimiter_stack)
        } else if ch == 91 {
            state.array_depth = state.array_depth + 1
            state.delimiter_stack = state.delimiter_stack + "["
        } else if ch == 93 {
            if structured_stack_top(state.delimiter_stack) != 91 {
                state.valid = false
                state.error_message = "mismatched JSON delimiter"
                return state
            }
            state.array_depth = state.array_depth - 1
            state.delimiter_stack = structured_stack_pop(state.delimiter_stack)
        }
        if state.object_depth < 0 || state.array_depth < 0 {
            state.valid = false
            state.error_message = "unbalanced JSON delimiter"
            return state
        }
        state.text = state.text + string(chunk[i])
        if !state.in_string && state.object_depth == 0 && state.array_depth == 0 {
            state.complete = true
        }
        i = i + 1
    }
    state
}

func json_stream_finish(json_stream_state state) structured_validation_result {
    if !state.valid {
        return new_structured_validation_result(false, state.error_message, state.text)
    }
    if !state.started {
        return new_structured_validation_result(false, "empty JSON output", state.text)
    }
    if state.in_string || state.escape_next {
        return new_structured_validation_result(false, "unterminated JSON string", state.text)
    }
    if !state.complete || state.object_depth != 0 || state.array_depth != 0 {
        return new_structured_validation_result(false, "incomplete JSON output", state.text)
    }
    new_structured_validation_result(true, "", state.text)
}

func structured_find_substring(string text, string pattern, int start) int {
    if len(pattern) == 0 {
        return start
    }
    int i = start
    for i + len(pattern) <= len(text) {
        int j = 0
        bool matches = true
        for j < len(pattern) {
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

func structured_skip_space(string text, int start) int {
    int i = start
    for i < len(text) && structured_is_space(int(text[i])) {
        i = i + 1
    }
    i
}

func structured_value_start(string text, string field_name) int {
    string key = "\"" + field_name + "\""
    int key_start = structured_find_substring(text, key, 0)
    if key_start < 0 {
        return -1
    }
    int colon = structured_find_substring(text, ":", key_start + len(key))
    if colon < 0 {
        return -1
    }
    structured_skip_space(text, colon + 1)
}

func structured_value_type(string text, int start) string {
    if start < 0 || start >= len(text) {
        return "missing"
    }
    int ch = int(text[start])
    if ch == 34 { return "string" }
    if ch == 123 { return "object" }
    if ch == 91 { return "array" }
    if ch == 116 || ch == 102 { return "boolean" }
    if ch == 110 { return "null" }
    if ch == 45 || (ch >= 48 && ch <= 57) {
        int i = start
        for i < len(text) {
            if int(text[i]) == 46 || int(text[i]) == 101 || int(text[i]) == 69 {
                return "number"
            }
            if int(text[i]) == 44 || int(text[i]) == 125 || int(text[i]) == 93 || structured_is_space(int(text[i])) {
                break
            }
            i = i + 1
        }
        return "integer"
    }
    "invalid"
}

func structured_read_string(string text, int start) string {
    if start < 0 || start >= len(text) || int(text[start]) != 34 {
        return ""
    }
    string value = ""
    bool escaped = false
    int i = start + 1
    for i < len(text) {
        int ch = int(text[i])
        if escaped {
            value = value + string(text[i])
            escaped = false
        } else if ch == 92 {
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

func structured_enum_contains(string[] values, string value) bool {
    int i = 0
    for i < len(values) {
        if values[i] == value {
            return true
        }
        i = i + 1
    }
    false
}

func structured_field_at(structured_schema schema, int index) structured_field_rule {
    schema.fields[index]
}

func structured_schema_has_field(structured_schema schema, string field_name) bool {
    int i = 0
    for i < len(schema.fields) {
        structured_field_rule field = structured_field_at(schema, i)
        if field.field_name == field_name {
            return true
        }
        i = i + 1
    }
    false
}

func structured_unknown_top_level_field(structured_schema schema, string text) string {
    int object_depth = 0
    int array_depth = 0
    bool in_string = false
    bool escaped = false
    int string_start = -1
    int i = 0
    for i < len(text) {
        int ch = int(text[i])
        if in_string {
            if escaped {
                escaped = false
            } else if ch == 92 {
                escaped = true
            } else if ch == 34 {
                in_string = false
                if object_depth == 1 && array_depth == 0 && string_start >= 0 {
                    int next = structured_skip_space(text, i + 1)
                    if next < len(text) && int(text[next]) == 58 {
                        string key = structured_substring(text, string_start, i)
                        if !structured_schema_has_field(schema, key) {
                            return key
                        }
                    }
                }
            }
        } else if ch == 34 {
            in_string = true
            string_start = i + 1
        } else if ch == 123 {
            object_depth = object_depth + 1
        } else if ch == 125 {
            object_depth = object_depth - 1
        } else if ch == 91 {
            array_depth = array_depth + 1
        } else if ch == 93 {
            array_depth = array_depth - 1
        }
        i = i + 1
    }
    ""
}

func validate_structured_output(structured_schema schema, string text) structured_validation_result {
    json_stream_state stream = json_stream_consume(new_json_stream_state(), text)
    structured_validation_result syntax = json_stream_finish(stream)
    if !syntax.valid {
        return syntax
    }
    int root = structured_skip_space(text, 0)
    if schema.root_type == structured_root_object() && (root >= len(text) || int(text[root]) != 123) {
        return new_structured_validation_result(false, "expected JSON object", text)
    }
    if schema.root_type == structured_root_array() && (root >= len(text) || int(text[root]) != 91) {
        return new_structured_validation_result(false, "expected JSON array", text)
    }
    if schema.root_type == structured_root_object() && !schema.allow_additional_fields {
        string unknown_field = structured_unknown_top_level_field(schema, text)
        if unknown_field != "" {
            return new_structured_validation_result(false, "additional field is not allowed: " + unknown_field, text)
        }
    }
    int i = 0
    for i < len(schema.fields) {
        structured_field_rule rule = schema.fields[i]
        int value_start = structured_value_start(text, rule.field_name)
        if value_start < 0 {
            if rule.required {
                return new_structured_validation_result(false, "missing required field: " + rule.field_name, text)
            }
            i = i + 1
            continue
        }
        string actual_type = structured_value_type(text, value_start)
        bool type_matches = actual_type == rule.value_type
        if rule.value_type == "number" && actual_type == "integer" {
            type_matches = true
        }
        if !type_matches {
            return new_structured_validation_result(false, "invalid type for field: " + rule.field_name, text)
        }
        if len(rule.enum_values) > 0 {
            string value = structured_read_string(text, value_start)
            if !structured_enum_contains(rule.enum_values, value) {
                return new_structured_validation_result(false, "invalid enum value for field: " + rule.field_name, text)
            }
        }
        i = i + 1
    }
    new_structured_validation_result(true, "", text)
}

func structured_prefix_allowed(structured_schema schema, string prefix) bool {
    json_stream_state stream = json_stream_consume(new_json_stream_state(), prefix)
    if !stream.valid {
        return false
    }
    int root = structured_skip_space(prefix, 0)
    if root >= len(prefix) {
        return true
    }
    if schema.root_type == structured_root_object() {
        return int(prefix[root]) == 123
    }
    if schema.root_type == structured_root_array() {
        return int(prefix[root]) == 91
    }
    false
}
