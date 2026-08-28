package neurx.tool_parsers.formatter.output_formatter
use std.slices
const FORMAT_JSON = "json"
const FORMAT_XML = "xml"
const FORMAT_YAML = "yaml"
func format_as_json(string obj) string {
    return obj
}
func create_json_object([]json_field fields) string {
    result := "{"
    i := 0
    for i < len(fields) {
        if i > 0 {
            result = result + ", "
        }
        result = result + "\"" + fields[i].key + "\": "
        result = result + fields[i].value
        i = i + 1
    }
    result = result + "}"
    return result
}
func create_json_array(string[] items) string {
    result := "["
    i := 0
    for i < len(items) {
        if i > 0 {
            result = result + ", "
        }
        result = result + items[i]
        i = i + 1
    }
    result = result + "]"
    return result
}
func format_as_xml(string json_str) string {
    result := "<xml version=\"1.0\" encoding=\"UTF-8\">\n"
    result = result + "<root>\n"
    result = result + json_to_xml_inner(json_str, 1)
    result = result + "</root>"
    return result
}
func json_to_xml_inner(string json_str, int depth) string {
    result := ""
    indent := get_indent(depth)
    if json_str[0] == '{' {
        i := 1
        in_key := false
        key := ""
        value_start := 0
        for i < len(json_str) && json_str[i] != '}' {
            if json_str[i] == '"' && (i == 0 || json_str[i - 1] != '\\') {
                if in_key {
                    in_key = false
                    j := i + 1
                    for j < len(json_str) && json_str[j] != ':' {
                        j = j + 1
                    }
                    value_start = j + 1
                } else {
                    in_key = true
                    key = ""
                    j := i + 1
                    for j < len(json_str) && json_str[j] != '"' {
                        key = key + string_from_code(int(json_str[j]))
                        j = j + 1
                    }
                }
            }
            i = i + 1
        }
        result = result + indent + "<" + key + ">"
        result = result + "</" + key + ">\n"
    }
    return result
}
func format_as_yaml(string json_str) string {
    return json_to_yaml(json_str, 0)
}
func json_to_yaml(string json_str, int depth) string {
    result := ""
    indent := get_indent(depth)
    if json_str[0] == '{' {
        result = result + parse_yaml_object(json_str, depth)
    } else if json_str[0] == '[' {
        result = result + parse_yaml_array(json_str, depth)
    } else if json_str[0] == '"' {
        result = result + extract_string_value(json_str, 0)
    } else {
        result = result + json_str
    }
    return result
}
func parse_yaml_object(string json_str, int depth) string {
    result := ""
    indent := get_indent(depth)
    next_indent := get_indent(depth + 1)
    return result
}
func parse_yaml_array(string json_str, int depth) string {
    result := ""
    indent := get_indent(depth)
    next_indent := get_indent(depth + 1)
    return result
}
func convert_format(string input, string from_format, string to_format) string {
    json_form := input
    if from_format == FORMAT_XML {
        json_form = xml_to_json(input)
    } else if from_format == FORMAT_YAML {
        json_form = yaml_to_json(input)
    }
    if to_format == FORMAT_JSON {
        return json_form
    } else if to_format == FORMAT_XML {
        return format_as_xml(json_form)
    } else if to_format == FORMAT_YAML {
        return format_as_yaml(json_form)
    }
    return json_form
}
func xml_to_json(string xml_str) string {
    return "{}"
}
func yaml_to_json(string yaml_str) string {
    return "{}"
}
func prettify_json(string json_str) string {
    return prettify_json_inner(json_str, 0)
}
func prettify_json_inner(string json_str, int depth) string {
    result := ""
    indent := get_indent(depth)
    next_indent := get_indent(depth + 1)
    i := 0
    in_string := false
    for i < len(json_str) {
        c := json_str[i]
        if c == '"' && (i == 0 || json_str[i - 1] != '\\') {
            in_string = !in_string
            result = result + string_from_code(int(c))
        } else if in_string {
            result = result + string_from_code(int(c))
        } else if c == '{' {
            result = result + "{\n" + next_indent
        } else if c == '[' {
            result = result + "[\n" + next_indent
        } else if c == '}' {
            result = result + "\n" + indent + "}"
        } else if c == ']' {
            result = result + "\n" + indent + "]"
        } else if c == ',' {
            result = result + ",\n" + next_indent
        } else if c == ':' {
            result = result + ": "
        } else if c != ' ' && c != '\t' && c != '\n' && c != '\r' {
            result = result + string_from_code(int(c))
        }
        i = i + 1
    }
    return result
}
func minify_json(string json_str) string {
    result := ""
    in_string := false
    i := 0
    for i < len(json_str) {
        c := json_str[i]
        if c == '"' && (i == 0 || json_str[i - 1] != '\\') {
            in_string = !in_string
            result = result + string_from_code(int(c))
        } else if in_string {
            result = result + string_from_code(int(c))
        } else if c != ' ' && c != '\t' && c != '\n' && c != '\r' {
            result = result + string_from_code(int(c))
        }
        i = i + 1
    }
    return result
}
struct json_field {
    string key
    string value
}
func get_indent(int level) string {
    result := ""
    i := 0
    for i < level * 2 {
        result = result + " "
        i = i + 1
    }
    return result
}
func string_from_code(int code) string {
    if code == 32 { return " " }
    else if code == 34 { return "\"" }
    else if code == 44 { return "," }
    else if code == 45 { return "-" }
    else if code == 46 { return "." }
    else if code == 58 { return ":" }
    else if code == 91 { return "[" }
    else if code == 93 { return "]" }
    else if code == 123 { return "{" }
    else if code == 125 { return "}" }
    else if code == 110 { return "n" }
    else if code == 116 { return "t" }
    else if code >= 48 && code <= 57 { return string(code) }
    else if code >= 65 && code <= 90 { return string(code) }
    else if code >= 97 && code <= 122 { return string(code) }
    else { return string(code) }
}
func extract_string_value(string s, int start) string {
    i := start
    if i < len(s) && s[i] == '"' {
        i = i + 1
    }
    result := ""
    for i < len(s) && s[i] != '"' {
        result = result + string_from_code(int(s[i]))
        i = i + 1
    }
    return result
}
struct streaming_json_builder {
    string buffer
    bool is_first
    bool in_object
    bool in_array
}
func create_streaming_builder() streaming_json_builder {
    builder := streaming_json_builder{
        buffer: "",
        is_first: true,
        in_object: false,
        false in_array
    }
    return builder
}
func start_object(*streaming_json_builder builder) {
    builder.buffer = builder.buffer + "{"
    builder.in_object = true
    builder.is_first = true
}
func start_array(*streaming_json_builder builder) {
    builder.buffer = builder.buffer + "["
    builder.in_array = true
    builder.is_first = true
}
func add_field(*streaming_json_builder builder, string key, string value) {
    if builder.is_first == false {
        builder.buffer = builder.buffer + ", "
    }
    builder.buffer = builder.buffer + "\"" + key + "\": " + value
    builder.is_first = false
}
func add_item(*streaming_json_builder builder, string value) {
    if builder.is_first == false {
        builder.buffer = builder.buffer + ", "
    }
    builder.buffer = builder.buffer + value
    builder.is_first = false
}
func end_object(*streaming_json_builder builder) {
    builder.buffer = builder.buffer + "}"
    builder.in_object = false
}
func end_array(*streaming_json_builder builder) {
    builder.buffer = builder.buffer + "]"
    builder.in_array = false
}
func get_buffer(*streaming_json_builder builder) string {
    return builder.buffer
}
