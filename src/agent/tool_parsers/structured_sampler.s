package neurx.tool_parsers.structured_sampler

use neurx.tool_parsers.schema.schema_types
use neurx.tool_parsers.schema.schema_parser
use neurx.tool_parsers.constraint.constraint_generator
use std.slices

struct structured_sampler {
    json_schema schema
    string mode
    allowed_next: []int
    string current_output
    parse_context: schema_types.parse_context
    int state
    int violations
    warnings: []string
}

func create_structured_sampler(*json_schema schema, string mode) structured_sampler {
    sampler := structured_sampler{
        schema: *schema,
        mode: mode,
        allowed_next: vec_new(),
        current_output: "",
        parse_context: schema_types.create_empty_parse_context(),
        state: 0,
        violations: 0,
        warnings: vec_new()
    }

    init_constraint := constraint_generator.generate_initial_constraint(schema)
    sampler.allowed_next = init_constraint.allowed_tokens

    return sampler
}

func filter_logits(*structured_sampler sampler, []float logits) []float {
    result := logits

    i := 0
    for i < len(result) {
        allowed := is_token_allowed(i, *sampler.allowed_next)

        if allowed == false {
            if sampler.mode == schema_types.CONSTRAINT_STRICT {

                result[i] = -1000000.0
            } else if sampler.mode == schema_types.CONSTRAINT_PERMISSIVE {

                result[i] = result[i] - 10.0
            }
        }

        i = i + 1
    }

    return result
}

func update_after_token(*structured_sampler sampler, int token_id, string token_str) {

    sampler.current_output = sampler.current_output + token_str

    was_allowed := is_token_allowed(token_id, *sampler.allowed_next)
    if was_allowed == false {
        sampler.violations = sampler.violations + 1
        sampler.warnings.append("Token ID " + int_to_string(token_id) + " not in allowed set")
    }

    constraint := constraint_generator.get_next_constraint(
        sampler.current_output,
        *sampler.schema,
        *sampler.parse_context
    )

    sampler.allowed_next = constraint.allowed_tokens
    sampler.state = constraint.state

    if is_complete_output(sampler.current_output, *sampler.schema) {
        sampler.state = 999
    }
}

func is_complete_output(string output, *json_schema schema) bool {
    if len(output) == 0 {
        return false
    }

    if schema.type_name == schema_types.TYPE_OBJECT {
        return is_complete_json_object(output)
    } else if schema.type_name == schema_types.TYPE_ARRAY {
        return is_complete_json_array(output)
    } else if schema.type_name == schema_types.TYPE_STRING {
        return output[len(output) - 1] == '"'
    } else if schema.type_name == schema_types.TYPE_NUMBER ||
              schema.type_name == schema_types.TYPE_INTEGER {
        return is_valid_json_number(output)
    }

    return false
}

func is_complete_json_object(string s) bool {
    if len(s) < 2 {
        return false
    }
    if s[0] != '{' || s[len(s) - 1] != '}' {
        return false
    }

    count := 0
    i := 0
    for i < len(s) {
        if s[i] == '{' {
            count = count + 1
        } else if s[i] == '}' {
            count = count - 1
            if count < 0 {
                return false
            }
        }
        i = i + 1
    }
    return count == 0
}

func is_complete_json_array(string s) bool {
    if len(s) < 2 {
        return false
    }
    if s[0] != '[' || s[len(s) - 1] != ']' {
        return false
    }

    count := 0
    i := 0
    for i < len(s) {
        if s[i] == '[' {
            count = count + 1
        } else if s[i] == ']' {
            count = count - 1
            if count < 0 {
                return false
            }
        }
        i = i + 1
    }
    return count == 0
}

func is_valid_json_number(string s) bool {
    if len(s) == 0 {
        return false
    }

    i := 0

    if s[i] == '-' {
        i = i + 1
    }

    if i >= len(s) {
        return false
    }

    if s[i] < '0' || s[i] > '9' {
        return false
    }

    for i < len(s) && s[i] >= '0' && s[i] <= '9' {
        i = i + 1
    }

    if i < len(s) && s[i] == '.' {
        i = i + 1
        if i >= len(s) || s[i] < '0' || s[i] > '9' {
            return false
        }
        for i < len(s) && s[i] >= '0' && s[i] <= '9' {
            i = i + 1
        }
    }

    if i < len(s) && (s[i] == 'e' || s[i] == 'E') {
        i = i + 1
        if i < len(s) && (s[i] == '+' || s[i] == '-') {
            i = i + 1
        }
        if i >= len(s) || s[i] < '0' || s[i] > '9' {
            return false
        }
        for i < len(s) && s[i] >= '0' && s[i] <= '9' {
            i = i + 1
        }
    }

    return i == len(s)
}

func process_batch(*[]structured_sampler samplers, [][]float logits_batch) [][]float {
    result := vec_new()

    i := 0
    for i < len(logits_batch) {
        constrained := filter_logits(&(*samplers)[i], logits_batch[i])
        result.append(constrained)
        i = i + 1
    }

    return result
}

func get_sampler_stats(*structured_sampler sampler) string {
    stats := "Structured Sampler Stats:\n"
    stats = stats + "  Current output: " + sampler.current_output + "\n"
    stats = stats + "  Mode: " + sampler.mode + "\n"
    stats = stats + "  State: " + int_to_string(sampler.state) + "\n"
    stats = stats + "  Allowed next tokens: " + int_to_string(len(sampler.allowed_next)) + "\n"
    stats = stats + "  Violations: " + int_to_string(sampler.violations) + "\n"
    stats = stats + "  Parse depth: " + int_to_string(sampler.parse_context.depth) + "\n"

    return stats
}

func print_sampler_debug(*structured_sampler sampler) {
    print(get_sampler_stats(sampler))

    if len(sampler.warnings) > 0 {
        print("  Warnings:\n")
        i := 0
        for i < len(sampler.warnings) {
            print("    - " + sampler.warnings[i] + "\n")
            i = i + 1
        }
    }
}

func is_token_allowed(int token_id, *[]int allowed) bool {
    i := 0
    for i < len(*allowed) {
        if (*allowed)[i] == token_id {
            return true
        }
        i = i + 1
    }
    return false
}

func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }

    is_negative := n < 0
    abs_n := n
    if is_negative {
        abs_n = 0 - n
    }

    result := ""
    for abs_n > 0 {
        result = string(abs_n % 10) + result
        abs_n = abs_n / 10
    }

    if is_negative {
        result = "-" + result
    }

    return result
}

func create_function_call_schema() json_schema {
    func_name_prop := json_property{
        name: "name",
        schema: schema_parser.create_string_schema(1, 100, ""),
        required: true,
        description: "Function name"
    }

    func_args_prop := json_property{
        name: "arguments",
        schema: schema_parser.create_string_schema(0, 10000, ""),
        required: true,
        description: "Function arguments as JSON string"
    }

    props := vec_new()
    props.append(func_name_prop)
    props.append(func_args_prop)

    required := vec_new()
    required.append("name")
    required.append("arguments")

    return schema_parser.create_object_schema(props, required)
}

func create_json_object_schema() json_schema {
    return schema_parser.create_object_schema(vec_new(), vec_new())
}

func create_json_array_schema() json_schema {
    item_schema := schema_parser.create_string_schema(0, 10000, "")
    return schema_parser.create_array_schema(*item_schema, 0, 1000)
}
