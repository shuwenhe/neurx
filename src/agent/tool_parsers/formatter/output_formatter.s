package neurx.tool_parsers.formatter.output_formatter

use std.vec

const FORMAT_JSON = "json"
const FORMAT_XML = "xml"
const FORMAT_YAML = "yaml"

func format_as_json(obj: string) string {

    return obj
}

func create_json_object(fields: []json_field) string {
    let result = "{"

    let i = 0
    while i < len(fields) {
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

func create_json_array(items: []string) string {
    let result = "["

    let i = 0
    while i < len(items) {
        if i > 0 {
            result = result + ", "
        }
        result = result + items[i]
        i = i + 1
    }

    result = result + "]"
    return result
}

func format_as_xml(json_str: string) string {
    let result = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    result = result + "<root>\n"
    result = result + json_to_xml_inner(json_str, 1)
    result = result + "</root>"
    return result
}

func json_to_xml_inner(json_str: string, depth: int) string {
    let result = ""
    let indent = get_indent(depth)

    if json_str[0] == '{' {

        let i = 1
        let in_key = false
        let key = ""
        let value_start = 0

        while i < len(json_str) && json_str[i] != '}' {
            if json_str[i] == '"' && (i == 0 || json_str[i - 1] != '\\') {
                if in_key {

                    in_key = false

                    let j = i + 1
                    while j < len(json_str) && json_str[j] != ':' {
                        j = j + 1
                    }
                    value_start = j + 1
                } else {

                    in_key = true
                    key = ""
                    let j = i + 1
                    while j < len(json_str) && json_str[j] != '"' {
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

func format_as_yaml(json_str: string) string {
    return json_to_yaml(json_str, 0)
}

func json_to_yaml(json_str: string, depth: int) string {
    let result = ""
    let indent = get_indent(depth)

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

func parse_yaml_object(json_str: string, depth: int) string {
    let result = ""
    let indent = get_indent(depth)
    let next_indent = get_indent(depth + 1)

    return result
}

func parse_yaml_array(json_str: string, depth: int) string {
    let result = ""
    let indent = get_indent(depth)
    let next_indent = get_indent(depth + 1)

    return result
}

func convert_format(input: string, from_format: string, to_format: string) string {

    let json_form = input
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

func xml_to_json(xml_str: string) string {

    return "{}"
}

func yaml_to_json(yaml_str: string) string {

    return "{}"
}

func prettify_json(json_str: string) string {
    return prettify_json_inner(json_str, 0)
}

func prettify_json_inner(json_str: string, depth: int) string {
    let result = ""
    let indent = get_indent(depth)
    let next_indent = get_indent(depth + 1)

    let i = 0
    let in_string = false

    while i < len(json_str) {
        let c = json_str[i]

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

func minify_json(json_str: string) string {
    let result = ""
    let in_string = false

    let i = 0
    while i < len(json_str) {
        let c = json_str[i]

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
    key: string
    value: string
}

func get_indent(level: int) string {
    let result = ""
    let i = 0
    while i < level * 2 {
        result = result + " "
        i = i + 1
    }
    return result
}

func string_from_code(code: int) string {
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

func extract_string_value(s: string, start: int) string {
    let i = start
    if i < len(s) && s[i] == '"' {
        i = i + 1
    }

    let result = ""
    while i < len(s) && s[i] != '"' {
        result = result + string_from_code(int(s[i]))
        i = i + 1
    }

    return result
}

struct streaming_json_builder {
    buffer: string
    is_first: bool
    in_object: bool
    in_array: bool
}

func create_streaming_builder() streaming_json_builder {
    let builder = streaming_json_builder{
        buffer: "",
        is_first: true,
        in_object: false,
        in_array: false
    }
    return builder
}

func start_object(builder: *streaming_json_builder) {
    builder.buffer = builder.buffer + "{"
    builder.in_object = true
    builder.is_first = true
}

func start_array(builder: *streaming_json_builder) {
    builder.buffer = builder.buffer + "["
    builder.in_array = true
    builder.is_first = true
}

func add_field(builder: *streaming_json_builder, key: string, value: string) {
    if builder.is_first == false {
        builder.buffer = builder.buffer + ", "
    }
    builder.buffer = builder.buffer + "\"" + key + "\": " + value
    builder.is_first = false
}

func add_item(builder: *streaming_json_builder, value: string) {
    if builder.is_first == false {
        builder.buffer = builder.buffer + ", "
    }
    builder.buffer = builder.buffer + value
    builder.is_first = false
}

func end_object(builder: *streaming_json_builder) {
    builder.buffer = builder.buffer + "}"
    builder.in_object = false
}

func end_array(builder: *streaming_json_builder) {
    builder.buffer = builder.buffer + "]"
    builder.in_array = false
}

func get_buffer(builder: *streaming_json_builder) string {
    return builder.buffer
}
