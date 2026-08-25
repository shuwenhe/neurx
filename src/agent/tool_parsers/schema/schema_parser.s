package neurx.tool_parsers.schema.schema_parser

use neurx.tool_parsers.schema.schema_types
use std.conv.string_to_int
use std.vec

func parse_schema_from_json(string json_str) json_schema {
    schema := schema_types.create_empty_schema()
    schema = parse_schema_object(json_str, 0, &schema)
    return schema
}

func parse_schema_object(string json_str, int start_pos, *json_schema schema) json_schema {
    result := *schema

    title_end := find_json_string_value(json_str, "\"title\"", start_pos)
    if title_end > start_pos {
        result.title = extract_string_value(json_str, title_end)
    }

    type_end := find_json_string_value(json_str, "\"type\"", start_pos)
    if type_end > start_pos {
        result.type_name = extract_type_value(json_str, type_end)
    }

    desc_end := find_json_string_value(json_str, "\"description\"", start_pos)
    if desc_end > start_pos {
        result.description = extract_string_value(json_str, desc_end)
    }

    required_end := find_json_string_value(json_str, "\"required\"", start_pos)
    if required_end > start_pos {
        result.required = extract_string_array(json_str, required_end)
    }

    props_end := find_json_string_value(json_str, "\"properties\"", start_pos)
    if props_end > start_pos {
        result.properties = extract_properties(json_str, props_end, &result.required)
    }

    min_len_end := find_json_string_value(json_str, "\"minLength\"", start_pos)
    if min_len_end > start_pos {
        result.min_length = extract_int_value(json_str, min_len_end)
    }

    max_len_end := find_json_string_value(json_str, "\"maxLength\"", start_pos)
    if max_len_end > start_pos {
        result.max_length = extract_int_value(json_str, max_len_end)
    }

    pattern_end := find_json_string_value(json_str, "\"pattern\"", start_pos)
    if pattern_end > start_pos {
        result.pattern = extract_string_value(json_str, pattern_end)
    }

    enum_end := find_json_string_value(json_str, "\"enum\"", start_pos)
    if enum_end > start_pos {
        result.enum_values = extract_string_array(json_str, enum_end)
    }

    return result
}

func find_json_string_value(string json_str, string key, int start_pos) int {
    i := start_pos
    for i < len(json_str) {
        if i + len(key) <= len(json_str) {
            substr := substring(json_str, i, i + len(key))
            if substr == key {

                j := i + len(key)

                for j < len(json_str) && (json_str[j] == ' ' || json_str[j] == ':' || json_str[j] == '\t') {
                    j = j + 1
                }
                return j
            }
        }
        i = i + 1
    }
    return -1
}

func extract_string_value(string json_str, int pos) string {
    i := pos

    if i < len(json_str) && json_str[i] == '"' {
        i = i + 1
    }

    result := ""
    for i < len(json_str) && json_str[i] != '"' {
        result = result + string_from_char(json_str[i])
        i = i + 1
    }
    return result
}

func extract_type_value(string json_str, int pos) string {
    return extract_string_value(json_str, pos)
}

func extract_int_value(string json_str, int pos) int {
    i := pos
    result := ""
    for i < len(json_str) && json_str[i] >= '0' && json_str[i] <= '9' {
        result = result + string_from_char(json_str[i])
        i = i + 1
    }
    return string_to_int(result)
}

func extract_string_array(string json_str, int pos) []string {
    result := vec_new()
    i := pos

    for i < len(json_str) && json_str[i] != '[' {
        i = i + 1
    }
    if i >= len(json_str) {
        return result
    }
    i = i + 1

    in_string := false
    current_str := ""
    for i < len(json_str) && json_str[i] != ']' {
        if json_str[i] == '"' {
            if in_string {

                result.append(current_str)
                current_str = ""
                in_string = false
            } else {

                in_string = true
            }
        } else if in_string {
            current_str = current_str + string_from_char(json_str[i])
        }
        i = i + 1
    }

    return result
}

func extract_properties(string json_str, int pos, *[]string required) []json_property {
    result := vec_new()
    i := pos

    for i < len(json_str) && json_str[i] != '{' {
        i = i + 1
    }
    if i >= len(json_str) {
        return result
    }
    i = i + 1

    brace_count := 1
    in_string := false
    prop_name := ""
    capturing_name := false

    for i < len(json_str) && brace_count > 0 {
        if json_str[i] == '"' && !in_string {
            in_string = true
            capturing_name = true
            prop_name = ""
        } else if json_str[i] == '"' && in_string {
            in_string = false
            if capturing_name {

                is_req := is_property_required(prop_name, required)
                prop := json_property{
                    name: prop_name,
                    schema: schema_types.create_empty_schema(),
                    required: is_req,
                    description: ""
                }
                result.append(prop)
                capturing_name = false
            }
        } else if capturing_name && in_string {
            prop_name = prop_name + string_from_char(json_str[i])
        } else if json_str[i] == '{' {
            brace_count = brace_count + 1
        } else if json_str[i] == '}' {
            brace_count = brace_count - 1
        }

        i = i + 1
    }

    return result
}

func is_property_required(string name, *[]string required) bool {
    i := 0
    for i < len(*required) {
        if (*required)[i] == name {
            return true
        }
        i = i + 1
    }
    return false
}

func substring(string s, int start, int end) string {
    if start < 0 || end > len(s) || start > end {
        return ""
    }
    result := ""
    i := start
    for i < end {
        result = result + string_from_char(s[i])
        i = i + 1
    }
    return result
}

func string_from_char(int c) string {

    result := ""
    if c == 32 { result = " " }
    else if c == 34 { result = "\"" }
    else if c == 39 { result = "'" }
    else if c == 44 { result = "," }
    else if c == 45 { result = "-" }
    else if c == 46 { result = "." }
    else if c == 47 { result = "/" }
    else if c == 58 { result = ":" }
    else if c == 91 { result = "[" }
    else if c == 93 { result = "]" }
    else if c == 123 { result = "{" }
    else if c == 125 { result = "}" }
    else if c >= 48 && c <= 57 { result = string(c) }
    else if c >= 65 && c <= 90 { result = string(c) }
    else if c >= 97 && c <= 122 { result = string(c) }
    else { result = string(c) }
    return result
}

func create_string_schema(int min_len, int max_len, string pattern) json_schema {
    schema := schema_types.create_empty_schema()
    schema.type_name = schema_types.TYPE_STRING
    schema.min_length = min_len
    schema.max_length = max_len
    schema.pattern = pattern
    return schema
}

func create_object_schema([]json_property properties, []string required) json_schema {
    schema := schema_types.create_empty_schema()
    schema.type_name = schema_types.TYPE_OBJECT
    schema.properties = properties
    schema.required = required
    return schema
}

func create_array_schema(*json_schema item_schema, int min_items, int max_items) json_schema {
    schema := schema_types.create_empty_schema()
    schema.type_name = schema_types.TYPE_ARRAY
    schema.items = item_schema
    schema.min_items = min_items
    schema.max_items = max_items
    return schema
}

func create_enum_schema([]string values) json_schema {
    schema := schema_types.create_empty_schema()
    schema.type_name = schema_types.TYPE_STRING
    schema.enum_values = values
    return schema
}
