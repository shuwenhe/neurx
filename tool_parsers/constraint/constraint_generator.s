package neurx.tool_parsers.constraint.constraint_generator

use neurx.tool_parsers.schema.schema_types
use std.vec

func generate_initial_constraint(schema: &json_schema) token_constraint {
    let constraint = schema_types.create_empty_constraint()
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

func get_next_constraint(current_output: string, schema: &json_schema, context: &schema_types.parse_context) token_constraint {
    let constraint = schema_types.create_empty_constraint()

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

func get_object_constraint(current_output: string, schema: &json_schema, context: &schema_types.parse_context) token_constraint {
    let constraint = schema_types.create_empty_constraint()
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

func get_array_constraint(current_output: string, schema: &json_schema, context: &schema_types.parse_context) token_constraint {
    let constraint = schema_types.create_empty_constraint()
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

func get_string_constraint(current_output: string, schema: &json_schema, context: &schema_types.parse_context) token_constraint {
    let constraint = schema_types.create_empty_constraint()
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

func get_number_constraint(current_output: string, schema: &json_schema, context: &schema_types.parse_context) token_constraint {
    let constraint = schema_types.create_empty_constraint()
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

func add_digit_tokens(tokens: &[]int) {
    let i = 48
    while i <= 57 {
        tokens.append(i)
        i = i + 1
    }
}

func add_letter_tokens(tokens: &[]int) {

    let i = 97
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

func add_value_start_tokens(tokens: &[]int) {
    tokens.append(34)
    tokens.append(45)
    tokens.append(123)
    tokens.append(91)
    tokens.append(116)
    tokens.append(102)
    tokens.append(110)
    add_digit_tokens(tokens)
}

func ends_with(s: string, suffix: string) bool {
    if len(suffix) > len(s) {
        return false
    }
    let start = len(s) - len(suffix)
    let i = 0
    while i < len(suffix) {
        if s[start + i] != suffix[i] {
            return false
        }
        i = i + 1
    }
    return true
}

func contains_char(s: string, c: int) bool {
    let i = 0
    while i < len(s) {
        if int(s[i]) == c {
            return true
        }
        i = i + 1
    }
    return false
}

func count_unclosed_braces(s: string) int {
    let count = 0
    let i = 0
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

func is_valid_number(s: string) bool {
    if len(s) == 0 {
        return false
    }
    let has_dot = false
    let i = 0
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

func apply_pattern_constraint(constraint: token_constraint, pattern: string, context: &schema_types.parse_context) token_constraint {

    return constraint
}

func update_parse_context(output: string, context: &schema_types.parse_context) {
    context.depth = count_unclosed_braces(output)

    let i = 0
    let in_string = false
    while i < len(output) {
        if output[i] == '"' && (i == 0 || output[i - 1] != '\\') {
            in_string = !in_string
        }
        i = i + 1
    }
    context.in_string = in_string
    context.current_value = output
}

func apply_constraint_to_logits(logits: []float, constraint: &token_constraint) []float {
    let result = logits

    let i = 0
    while i < len(result) {
        let is_allowed = is_token_allowed(i, &constraint.allowed_tokens)
        if is_allowed == false {
            result[i] = -1000000.0
        }
        i = i + 1
    }

    return result
}

func is_token_allowed(token_id: int, allowed_tokens: &[]int) bool {
    let i = 0
    while i < len(*allowed_tokens) {
        if (*allowed_tokens)[i] == token_id {
            return true
        }
        i = i + 1
    }
    return false
}
