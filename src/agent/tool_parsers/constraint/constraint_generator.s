package neurx.tool_parsers.constraint.constraint_generator

use neurx.tool_parsers.schema.schema_types
use std.vec

func generate_initial_constraint(*json_schema schema) token_constraint {
    constraint := schema_types.create_empty_constraint()
    constraint.context = "root"
    constraint.state = 0
    constraint.is_terminal = false

    if schema.type_name == schema_types.TYPE_OBJECT {

        constraint.allowed_tokens.append(123)
    } else if schema.type_name == schema_types.TYPE_ARRAY {

        constraint.allowed_tokens.append(91)
    } else if schema.type_name == schema_types.TYPE_STRING {

        constraint.allowed_tokens.append(34)
    } else if schema.type_name == schema_types.TYPE_NUMBER ||
              schema.type_name == schema_types.TYPE_INTEGER {

        constraint.allowed_tokens.append(45)
        add_digit_tokens(&constraint.allowed_tokens)
    } else if schema.type_name == schema_types.TYPE_BOOLEAN {

        constraint.allowed_tokens.append(116)
        constraint.allowed_tokens.append(102)
    } else if schema.type_name == schema_types.TYPE_NULL {

        constraint.allowed_tokens.append(110)
    }

    return constraint
}

func get_next_constraint(string current_output, *json_schema schema, *schema_types.parse_context context) token_constraint {
    constraint := schema_types.create_empty_constraint()

    update_parse_context(current_output, context)

    if schema.type_name == schema_types.TYPE_OBJECT {
        constraint = get_object_constraint(current_output, schema, context)
    } else if schema.type_name == schema_types.TYPE_ARRAY {
        constraint = get_array_constraint(current_output, schema, context)
    } else if schema.type_name == schema_types.TYPE_STRING {
        constraint = get_string_constraint(current_output, schema, context)
    } else if schema.type_name == schema_types.TYPE_NUMBER ||
              schema.type_name == schema_types.TYPE_INTEGER {
        constraint = get_number_constraint(current_output, schema, context)
    }

    return constraint
}

func get_object_constraint(string current_output, *json_schema schema, *schema_types.parse_context context) token_constraint {
    constraint := schema_types.create_empty_constraint()
    constraint.context = "object"

    if ends_with(current_output, "{") {
        if schema.properties.len() > 0 {
            constraint.allowed_tokens.append(34)
        }
        constraint.allowed_tokens.append(125)
    }

    else if ends_with(current_output, ": ") || ends_with(current_output, ":") {
        add_value_start_tokens(&constraint.allowed_tokens)
    }

    else if context.in_string == false && count_unclosed_braces(current_output) == 0 {
        constraint.allowed_tokens.append(44)
        constraint.allowed_tokens.append(125)
    }

    return constraint
}

func get_array_constraint(string current_output, *json_schema schema, *schema_types.parse_context context) token_constraint {
    constraint := schema_types.create_empty_constraint()
    constraint.context = "array"

    if ends_with(current_output, "[") {
        add_value_start_tokens(&constraint.allowed_tokens)
        constraint.allowed_tokens.append(93)
    }

    else if context.in_string == false && ends_with(current_output, "\"") == false {
        constraint.allowed_tokens.append(44)
        constraint.allowed_tokens.append(93)
    }

    return constraint
}

func get_string_constraint(string current_output, *json_schema schema, *schema_types.parse_context context) token_constraint {
    constraint := schema_types.create_empty_constraint()
    constraint.context = "string"

    if context.in_string == false {
        constraint.allowed_tokens.append(34)
    } else {

        add_letter_tokens(&constraint.allowed_tokens)
        add_digit_tokens(&constraint.allowed_tokens)
        constraint.allowed_tokens.append(32)
        constraint.allowed_tokens.append(34)

        if len(schema.pattern) > 0 {
            constraint = apply_pattern_constraint(constraint, schema.pattern, context)
        }
    }

    return constraint
}

func get_number_constraint(string current_output, *json_schema schema, *schema_types.parse_context context) token_constraint {
    constraint := schema_types.create_empty_constraint()
    constraint.context = "number"

    if len(context.current_value) == 0 {
        constraint.allowed_tokens.append(45)
        add_digit_tokens(&constraint.allowed_tokens)
    } else {
        add_digit_tokens(&constraint.allowed_tokens)
        if contains_char(context.current_value, '.') == false {
            constraint.allowed_tokens.append(46)
        }

        if is_valid_number(context.current_value) {
            constraint.allowed_tokens.append(44)
            constraint.allowed_tokens.append(125)
            constraint.allowed_tokens.append(93)
        }
    }

    return constraint
}

func add_digit_tokens(*[]int tokens) {
    i := 48
    while i <= 57 {
        tokens.append(i)
        i = i + 1
    }
}

func add_letter_tokens(*[]int tokens) {

    i := 97
    while i <= 122 {
        tokens.append(i)
        i = i + 1
    }

    i = 65
    while i <= 90 {
        tokens.append(i)
        i = i + 1
    }
}

func add_value_start_tokens(*[]int tokens) {
    tokens.append(34)
    tokens.append(45)
    tokens.append(123)
    tokens.append(91)
    tokens.append(116)
    tokens.append(102)
    tokens.append(110)
    add_digit_tokens(tokens)
}

func ends_with(string s, string suffix) bool {
    if len(suffix) > len(s) {
        return false
    }
    start := len(s) - len(suffix)
    i := 0
    while i < len(suffix) {
        if s[start + i] != suffix[i] {
            return false
        }
        i = i + 1
    }
    return true
}

func contains_char(string s, int c) bool {
    i := 0
    while i < len(s) {
        if int(s[i]) == c {
            return true
        }
        i = i + 1
    }
    return false
}

func count_unclosed_braces(string s) int {
    count := 0
    i := 0
    while i < len(s) {
        if s[i] == '{' || s[i] == '[' {
            count = count + 1
        } else if s[i] == '}' || s[i] == ']' {
            count = count - 1
        }
        i = i + 1
    }
    return count
}

func is_valid_number(string s) bool {
    if len(s) == 0 {
        return false
    }
    has_dot := false
    i := 0
    while i < len(s) {
        if s[i] == '.' {
            if has_dot {
                return false
            }
            has_dot = true
        } else if s[i] < '0' || s[i] > '9' {
            if i != 0 || s[i] != '-' {
                return false
            }
        }
        i = i + 1
    }
    return true
}

func apply_pattern_constraint(token_constraint constraint, string pattern, *schema_types.parse_context context) token_constraint {

    return constraint
}

func update_parse_context(string output, *schema_types.parse_context context) {
    context.depth = count_unclosed_braces(output)

    i := 0
    in_string := false
    while i < len(output) {
        if output[i] == '"' && (i == 0 || output[i - 1] != '\\') {
            in_string = !in_string
        }
        i = i + 1
    }
    context.in_string = in_string
    context.current_value = output
}

func apply_constraint_to_logits([]float logits, *token_constraint constraint) []float {
    result := logits

    i := 0
    while i < len(result) {
        is_allowed := is_token_allowed(i, &constraint.allowed_tokens)
        if is_allowed == false {
            result[i] = -1000000.0
        }
        i = i + 1
    }

    return result
}

func is_token_allowed(int token_id, *[]int allowed_tokens) bool {
    i := 0
    while i < len(*allowed_tokens) {
        if (*allowed_tokens)[i] == token_id {
            return true
        }
        i = i + 1
    }
    return false
}
