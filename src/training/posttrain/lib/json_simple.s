package neurx.posttrain.lib.json_simple
use std.io.readfile

struct json_value {
    int type
    bool bool_value
    float number_value
    string string_value
    []json_value array_value
    []string object_keys
    []json_value object_values
}

func (j json_value) is_null() bool {
    return j.type == 0
}

func (j json_value) is_bool() bool {
    return j.type == 1
}

func (j json_value) is_number() bool {
    return j.type == 2
}

func (j json_value) is_string() bool {
    return j.type == 3
}

func (j json_value) is_array() bool {
    return j.type == 4
}

func (j json_value) is_object() bool {
    return j.type == 5
}

func (j json_value) as_bool() bool {
    if j.type != 1 {
        panic("JSON value is not a boolean")
    }
    return j.bool_value
}

func (j json_value) as_number() float {
    if j.type != 2 {
        panic("JSON value is not a number")
    }
    return j.number_value
}

func (j json_value) as_int() int {
    if j.type != 2 {
        panic("JSON value is not a number")
    }
    v := int(j.number_value)
    if float(v) != j.number_value {
        panic("JSON number is not an integer")
    }
    return v
}

func (j json_value) as_string() string {
    if j.type != 3 {
        panic("JSON value is not a string")
    }
    return j.string_value
}

func (j json_value) as_array() []json_value {
    if j.type != 4 {
        panic("JSON value is not an array")
    }
    return j.array_value
}

func (string j json_value) contains(key) bool {
    if j.type != 5 {
        return false
    }
    for i := 0; i < len(j.object_keys); i = i + 1 {
        if j.object_keys[i] == key {
            return true
        }
    }
    return false
}

func (string j json_value) at(key) json_value {
    if j.type != 5 {
        panic("JSON value is not an object")
    }
    for i := 0; i < len(j.object_keys); i = i + 1 {
        if j.object_keys[i] == key {
            return j.object_values[i]
        }
    }
    panic("missing JSON field: " + key)
}

func parse(string text) json_value {
    parser := json_parser_create(text)
    result := parser_parse_value(*parser)
    parser_skip_whitespace(*parser)
    if parser.pos < len(text) {
        panic("unexpected characters after JSON value")
    }
    return result
}

func parse_file(string path) json_value {
    content := readfile(path)
    if len(content) == 0 {
        panic("cannot read JSON file: " + path)
    }
    return parse(string(content))
}

struct json_parser {
    string text
    int pos
}

func json_parser_create(string text) json_parser {
    p := json_parser{}
    p.text = text
    p.pos = 0
    return p
}

func parser_skip_whitespace(json_parser* p) {
    for p.pos < len(p.text) {
        ch := byte(p.text[p.pos])
        if ch != ' ' && ch != '\t' && ch != '\n' && ch != '\r' {
            break
        }
        p.pos = p.pos + 1
    }
}

func parser_peek(json_parser* p) byte {
    if p.pos >= len(p.text) {
        return 0
    }
    return byte(p.text[p.pos])
}

func parser_advance(json_parser* p) byte {
    if p.pos >= len(p.text) {
        return 0
    }
    ch := byte(p.text[p.pos])
    p.pos = p.pos + 1
    return ch
}

func parser_parse_value(json_parser* p) json_value {
    parser_skip_whitespace(p)
    ch := parser_peek(p)
    if ch == byte('n') {
        return parser_parse_null(p)
    }
    if ch == byte('t') || ch == byte('f') {
        return parser_parse_bool(p)
    }
    if ch == byte('"') {
        str := parser_parse_string(p)
        val := json_value{}
        val.type = 3
        val.string_value = str
        return val
    }
    if ch == byte('[') {
        arr := parser_parse_array(p)
        val := json_value{}
        val.type = 4
        val.array_value = arr
        return val
    }
    if ch == byte('{') {
        keys := make([]string, 0)
        vals := make([]json_value, 0)
        parser_parse_object(p, *keys, *vals)
        val := json_value{}
        val.type = 5
        val.object_keys = keys
        val.object_values = vals
        return val
    }
    if ch == byte('-') || (ch >= byte('0') && ch <= byte('9')) {
        num := parser_parse_number(p)
        val := json_value{}
        val.type = 2
        val.number_value = num
        return val
    }
    panic("unexpected character in JSON")
}

func parser_parse_null(json_parser* p) json_value {
    parser_advance(p)
    parser_advance(p)
    parser_advance(p)
    parser_advance(p)
    val := json_value{}
    val.type = 0
    return val
}

func parser_parse_bool(json_parser* p) json_value {
    if parser_peek(p) == byte('t') {
        parser_advance(p)
        parser_advance(p)
        parser_advance(p)
        parser_advance(p)
        val := json_value{}
        val.type = 1
        val.bool_value = true
        return val
    } else {
        parser_advance(p)
        parser_advance(p)
        parser_advance(p)
        parser_advance(p)
        parser_advance(p)
        val := json_value{}
        val.type = 1
        val.bool_value = false
        return val
    }
}

func parser_parse_string(json_parser* p) string {
    if parser_advance(p) != byte('"') {
        panic("expected '\"'")
    }
    result := ""
    for p.pos < len(p.text) {
        ch := parser_advance(p)
        if ch == byte('"') {
            return result
        }
        if ch == byte('\\') {
            if p.pos >= len(p.text) {
                panic("unexpected end of string")
            }
            escaped := parser_advance(p)
            if escaped == byte('"') {
                result = result + "\""
            } else if escaped == byte('\\') {
                result = result + "\\"
            } else if escaped == byte('/') {
                result = result + "/"
            } else if escaped == byte('b') {
                result = result + "\b"
            } else if escaped == byte('f') {
                result = result + "\f"
            } else if escaped == byte('n') {
                result = result + "\n"
            } else if escaped == byte('r') {
                result = result + "\r"
            } else if escaped == byte('t') {
                result = result + "\t"
            } else if escaped == byte('u') {
                p.pos = p.pos + 4
            }
        } else {
            result = result + string(ch)
        }
    }
    panic("unexpected end of string")
}

func parser_parse_number(json_parser* p) float {
    start := p.pos
    if parser_peek(p) == byte('-') {
        parser_advance(p)
    }
    for parser_peek(p) >= byte('0') && parser_peek(p) <= byte('9') {
        parser_advance(p)
    }
    if parser_peek(p) == byte('.') {
        parser_advance(p)
        for parser_peek(p) >= byte('0') && parser_peek(p) <= byte('9') {
            parser_advance(p)
        }
    }
    if parser_peek(p) == byte('e') || parser_peek(p) == byte('E') {
        parser_advance(p)
        if parser_peek(p) == byte('+') || parser_peek(p) == byte('-') {
            parser_advance(p)
        }
        for parser_peek(p) >= byte('0') && parser_peek(p) <= byte('9') {
            parser_advance(p)
        }
    }
    num_str := p.text[start:p.pos]
    return parse_float(num_str)
}

func parser_parse_array(json_parser* p) []json_value {
    if parser_advance(p) != byte('[') {
        panic("expected '['")
    }
    result := make([]json_value, 0)
    parser_skip_whitespace(p)
    if parser_peek(p) == byte(']') {
        parser_advance(p)
        return result
    }
    for {
        val := parser_parse_value(p)
        result = append(result, val)
        parser_skip_whitespace(p)
        ch := parser_peek(p)
        if ch == byte(']') {
            parser_advance(p)
            return result
        }
        if ch != byte(',') {
            panic("expected ',' or ']' in array")
        }
        parser_advance(p)
    }
}

func parser_parse_object(p *json_parser, keys *[]string, values *[]json_value) {
    if parser_advance(p) != byte('{') {
        panic("expected '{'")
    }
    parser_skip_whitespace(p)
    if parser_peek(p) == byte('}') {
        parser_advance(p)
        return
    }
    for {
        parser_skip_whitespace(p)
        if parser_peek(p) != byte('"') {
            panic("expected string key in object")
        }
        key := parser_parse_string(p)
        parser_skip_whitespace(p)
        if parser_advance(p) != byte(':') {
            panic("expected ':' in object")
        }
        val := parser_parse_value(p)
        *keys = append(*keys, key)
        *values = append(*values, val)
        parser_skip_whitespace(p)
        ch := parser_peek(p)
        if ch == byte('}') {
            parser_advance(p)
            return
        }
        if ch != byte(',') {
            panic("expected ',' or '}' in object")
        }
        parser_advance(p)
    }
}

func parse_float(string s) float {
    f := 0.0
    negative := false
    dot_pos := -1
    start_idx := 0
    if len(s) > 0 && byte(s[0]) == byte('-') {
        negative = true
        start_idx = 1
    }
    for i := start_idx; i < len(s); i = i + 1 {
        if byte(s[i]) == byte('.') && dot_pos == -1 {
            dot_pos = i
        }
    }
    if dot_pos == -1 {
        dot_pos = len(s)
    }
    int_part := 0
    for i := start_idx; i < dot_pos; i = i + 1 {
        ch := byte(s[i])
        if ch >= byte('0') && ch <= byte('9') {
            int_part = int_part * 10 + int(ch - byte('0'))
        }
    }
    f = float(int_part)
    frac_part := 0.0
    frac_divisor := 10.0
    for i := dot_pos + 1; i < len(s); i = i + 1 {
        ch := byte(s[i])
        if ch >= byte('0') && ch <= byte('9') {
            frac_part = frac_part + float(int(ch - byte('0'))) / frac_divisor
            frac_divisor = frac_divisor * 10.0
        }
    }
    f = f + frac_part
    if negative {
        f = -f
    }
    return f
}
