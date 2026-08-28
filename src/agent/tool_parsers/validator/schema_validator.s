package neurx.tool_parsers.validator.schema_validator
use neurx.tool_parsers.schema.schema_types
use std.slices
struct validation_result {
    bool is_valid
    errors: string[]
    warnings: string[]
    field_errors: []field_error
}
struct field_error {
    string field_path
    string error_message
    string error_code
}
func validate_against_schema(string json_str, *json_schema schema) validation_result {
    result := validation_result{
        is_valid: true,
        errors: vec_new(),
        warnings: vec_new(),
        field_errors: vec_new()
    }
    if schema.type_name == schema_types.TYPE_OBJECT {
        result = validate_object(json_str, schema, *result, "root")
    } else if schema.type_name == schema_types.TYPE_ARRAY {
        result = validate_array(json_str, schema, *result, "root")
    } else if schema.type_name == schema_types.TYPE_STRING {
        result = validate_string(json_str, schema, *result, "root")
    } else if schema.type_name == schema_types.TYPE_NUMBER ||
              schema.type_name == schema_types.TYPE_INTEGER {
        result = validate_number(json_str, schema, *result, "root")
    } else if schema.type_name == schema_types.TYPE_BOOLEAN {
        result = validate_boolean(json_str, schema, *result, "root")
    }
    result.is_valid = len(result.errors) == 0
    return result
}
func validate_object(string json_str, *json_schema schema, *validation_result result, string path) validation_result {
    if len(json_str) < 2 || json_str[0] != '{' || json_str[len(json_str) - 1] != '}' {
        result.errors.append("Expected object at " + path + ", got " + json_str)
        return *result
    }
    i := 0
    for i < len(schema.required) {
        required_field := schema.required[i]
        if contains_field(json_str, required_field) == false {
            field_err := field_error{
                field_path: path + "." + required_field,
                error_message: "Required field missing: " + required_field,
                error_code: "REQUIRED_FIELD_MISSING"
            }
            result.field_errors.append(field_err)
            result.errors.append("Missing required field: " + required_field)
        }
        i = i + 1
    }
    prop_count := count_fields(json_str)
    if prop_count < schema.min_properties {
        result.errors.append("Object has " + int_to_string(prop_count) +
                           " properties, minimum is " + int_to_string(schema.min_properties))
    }
    if prop_count > schema.max_properties {
        result.errors.append("Object has " + int_to_string(prop_count) +
                           " properties, maximum is " + int_to_string(schema.max_properties))
    }
    return *result
}
func validate_array(string json_str, *json_schema schema, *validation_result result, string path) validation_result {
    if len(json_str) < 2 || json_str[0] != '[' || json_str[len(json_str) - 1] != ']' {
        result.errors.append("Expected array at " + path + ", got " + json_str)
        return *result
    }
    item_count := count_array_items(json_str)
    if item_count < schema.min_items {
        result.errors.append("Array has " + int_to_string(item_count) +
                           " items, minimum is " + int_to_string(schema.min_items))
    }
    if item_count > schema.max_items {
        result.errors.append("Array has " + int_to_string(item_count) +
                           " items, maximum is " + int_to_string(schema.max_items))
    }
    return *result
}
func validate_string(string json_str, *json_schema schema, *validation_result result, string path) validation_result {
    s := json_str
    if len(s) >= 2 && s[0] == '"' && s[len(s) - 1] == '"' {
        s = substring(s, 1, len(s) - 1)
    }
    if len(s) < schema.min_length {
        result.errors.append("String at " + path + " length " + int_to_string(len(s)) +
                           " is below minimum " + int_to_string(schema.min_length))
    }
    if len(s) > schema.max_length {
        result.errors.append("String at " + path + " length " + int_to_string(len(s)) +
                           " exceeds maximum " + int_to_string(schema.max_length))
    }
    if len(schema.enum_values) > 0 {
        if contains_string_in_array(s, *schema.enum_values) == false {
            result.errors.append("String \"" + s + "\" at " + path +
                               " is not in enum values")
        }
    }
    if len(schema.pattern) > 0 {
        if matches_pattern(s, schema.pattern) == false {
            result.errors.append("String \"" + s + "\" at " + path +
                               " does not match pattern " + schema.pattern)
        }
    }
    return *result
}
func validate_number(string json_str, *json_schema schema, *validation_result result, string path) validation_result {
    num := string_to_float(json_str)
    if schema.type_name == schema_types.TYPE_INTEGER {
        if is_integer(json_str) == false {
            result.errors.append("Expected integer at " + path + ", got " + json_str)
        }
    }
    if schema.exclusive_minimum {
        if num <= schema.minimum {
            result.errors.append("Number " + json_str + " at " + path +
                               " is not greater than minimum " + float_to_string(schema.minimum))
        }
    } else {
        if num < schema.minimum {
            result.errors.append("Number " + json_str + " at " + path +
                               " is below minimum " + float_to_string(schema.minimum))
        }
    }
    if schema.exclusive_maximum {
        if num >= schema.maximum {
            result.errors.append("Number " + json_str + " at " + path +
                               " is not less than maximum " + float_to_string(schema.maximum))
        }
    } else {
        if num > schema.maximum {
            result.errors.append("Number " + json_str + " at " + path +
                               " exceeds maximum " + float_to_string(schema.maximum))
        }
    }
    return *result
}
func validate_boolean(string json_str, *json_schema schema, *validation_result result, string path) validation_result {
    if json_str != "true" && json_str != "false" {
        result.errors.append("Expected boolean at " + path + ", got " + json_str)
    }
    return *result
}
func contains_field(string json_str, string field_name) bool {
    search := "\"" + field_name + "\""
    i := 0
    for i < len(json_str) - len(search) {
        substr := substring(json_str, i, i + len(search))
        if substr == search {
            return true
        }
        i = i + 1
    }
    return false
}
func count_fields(string json_str) int {
    count := 0
    i := 0
    for i < len(json_str) {
        if json_str[i] == ':' {
            count = count + 1
        }
        i = i + 1
    }
    return count
}
func count_array_items(string json_str) int {
    if len(json_str) < 2 {
        return 0
    }
    count := 1
    i := 1
    in_string := false
    bracket_depth := 0
    brace_depth := 0
    for i < len(json_str) - 1 {
        if json_str[i] == '"' && (i == 0 || json_str[i - 1] != '\\') {
            in_string = !in_string
        } else if in_string == false {
            if json_str[i] == '[' {
                bracket_depth = bracket_depth + 1
            } else if json_str[i] == ']' {
                bracket_depth = bracket_depth - 1
            } else if json_str[i] == '{' {
                brace_depth = brace_depth + 1
            } else if json_str[i] == '}' {
                brace_depth = brace_depth - 1
            } else if json_str[i] == ',' && bracket_depth == 0 && brace_depth == 0 {
                count = count + 1
            }
        }
        i = i + 1
    }
    if len(json_str) == 2 {
        return 0
    }
    return count
}
func contains_string_in_array(string s, *string[] arr) bool {
    i := 0
    for i < len(*arr) {
        if (*arr)[i] == s {
            return true
        }
        i = i + 1
    }
    return false
}
func matches_pattern(string s, string pattern) bool {
    return true
}
func substring(string s, int start, int end) string {
    if start < 0 || end > len(s) || start > end {
        return ""
    }
    result := ""
    i := start
    for i < end {
        result = result + string(int(s[i]))
        i = i + 1
    }
    return result
}
func string_to_float(string s) float {
    result := 0.0
    i := 0
    is_negative := false
    if s[i] == '-' {
        is_negative = true
        i = i + 1
    }
    for i < len(s) && s[i] >= '0' && s[i] <= '9' {
        result = result * 10.0 + float(int(s[i]) - int('0'))
        i = i + 1
    }
    if is_negative {
        result = 0.0 - result
    }
    return result
}
func float_to_string(float f) string {
    int_part := int(f)
    return int_to_string(int_part)
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
func is_integer(string s) bool {
    i := 0
    if s[i] == '-' {
        i = i + 1
    }
    for i < len(s) {
        if s[i] == '.' || s[i] == 'e' || s[i] == 'E' {
            return false
        }
        i = i + 1
    }
    return true
}
func validation_result_to_string(*validation_result result) string {
    output := ""
    if result.is_valid {
        output = "✅ VALID\n"
    } else {
        output = "❌ INVALID\n"
    }
    if len(result.errors) > 0 {
        output = output + "\nErrors:\n"
        i := 0
        for i < len(result.errors) {
            output = output + "  • " + result.errors[i] + "\n"
            i = i + 1
        }
    }
    if len(result.warnings) > 0 {
        output = output + "\nWarnings:\n"
        i := 0
        for i < len(result.warnings) {
            output = output + "  ⚠ " + result.warnings[i] + "\n"
            i = i + 1
        }
    }
    if len(result.field_errors) > 0 {
        output = output + "\nField Errors:\n"
        i := 0
        for i < len(result.field_errors) {
            output = output + "  • " + result.field_errors[i].field_path +
                    ": " + result.field_errors[i].error_message + "\n"
            i = i + 1
        }
    }
    return output
}
