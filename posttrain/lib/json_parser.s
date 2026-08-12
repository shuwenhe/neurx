package neurx.posttrain.lib.json_parser
use std.io.{readfile, writefile}
struct json_value {
    int type
    bool bool_value
    float number_value
    string string_value
    []json_value array_value
    map[string]json_value object_value
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
func (j json_value) as_object() map[string]json_value {
    if j.type != 5 {
        panic("JSON value is not an object")
    }
    return j.object_value
}
func (j json_value) contains(key string) bool {
    if j.type != 5 {
        return false
    }
    obj := j.object_value
    _, exists := obj[key]
    return exists
}
func (j json_value) at(key string) json_value {
    if j.type != 5 {
        panic("JSON value is not an object")
    }
    obj := j.object_value
    val, exists := obj[key]
    if !exists {
        panic("missing JSON field: " + key)
    }
    return val
}
func parse(text string) json_value {
    parser := json_parser_create(text)
    result := parser_parse_value(&parser)
    parser_skip_whitespace(&parser)
    if parser.pos < len(text) {
        panic("unexpected characters after JSON value")
    }
    return result
}
func parse_file(path string) json_value {
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
func json_parser_create(text string) json_parser {
    return json_parser{text: text, pos: 0}
}
func parser_skip_whitespace(p *json_parser) {
    for p.pos < len(p.text) {
        ch := p.text[p.pos]
        if ch != ' ' && ch != '\t' && ch != '\n' && ch != '\r' {
            break
        }
        p.pos = p.pos + 1
    }
}
func parser_peek(p *json_parser) byte {
    if p.pos >= len(p.text) {
        return 0
    }
    return p.text[p.pos]
}
func parser_advance(p *json_parser) byte {
    if p.pos >= len(p.text) {
        return 0
    }
    ch := p.text[p.pos]
    p.pos = p.pos + 1
    return ch
}
func parser_parse_value(p *json_parser) json_value {
    parser_skip_whitespace(p)
    ch := parser_peek(p)
    if ch == 'n' {
        return parser_parse_null(p)
    }
    if ch == 't' || ch == 'f' {
        return parser_parse_bool(p)
    }
    if ch == '"' {
        str := parser_parse_string(p)
        return json_value{type: 3, string_value: str}
    }
    if ch == '[' {
        arr := parser_parse_array(p)
        return json_value{type: 4, array_value: arr}
    }
    if ch == '{' {
        obj := parser_parse_object(p)
        return json_value{type: 5, object_value: obj}
    }
    if ch == '-' || (ch >= '0' && ch <= '9') {
        num := parser_parse_number(p)
        return json_value{type: 2, number_value: num}
    }
    panic("unexpected character in JSON: " + string(ch))
}
func parser_parse_null(p *json_parser) json_value {
    if p.text[p.pos:p.pos+4] != "null" {
        panic("expected 'null'")
    }
    p.pos = p.pos + 4
    return json_value{type: 0}
}
func parser_parse_bool(p *json_parser) json_value {
    if p.text[p.pos] == 't' {
        if p.text[p.pos:p.pos+4] != "true" {
            panic("expected 'true'")
        }
        p.pos = p.pos + 4
        return json_value{type: 1, bool_value: true}
    } else {
        if p.text[p.pos:p.pos+5] != "false" {
            panic("expected 'false'")
        }
        p.pos = p.pos + 5
        return json_value{type: 1, bool_value: false}
    }
}
func parser_parse_string(p *json_parser) string {
    if parser_advance(p) != '"' {
        panic("expected '\"'")
    }
    result := ""
    for p.pos < len(p.text) {
        ch := parser_advance(p)
        if ch == '"' {
            return result
        }
        if ch == '\\' {
            if p.pos >= len(p.text) {
                panic("unexpected end of string")
            }
            escaped := parser_advance(p)
            if escaped == '"' {
                result = result + "\""
            } else if escaped == '\\' {
                result = result + "\\"
            } else if escaped == '/' {
                result = result + "/"
            } else if escaped == 'b' {
                result = result + "\b"
            } else if escaped == 'f' {
                result = result + "\f"
            } else if escaped == 'n' {
                result = result + "\n"
            } else if escaped == 'r' {
                result = result + "\r"
            } else if escaped == 't' {
                result = result + "\t"
            } else if escaped == 'u' {
                p.pos = p.pos + 4
            } else {
                panic("invalid escape sequence")
            }
        } else {
            result = result + string(ch)
        }
    }
    panic("unexpected end of string")
}
func parser_parse_number(p *json_parser) float {
    start := p.pos
    if parser_peek(p) == '-' {
        parser_advance(p)
    }
    if parser_peek(p) == '0' {
        parser_advance(p)
    } else if parser_peek(p) >= '1' && parser_peek(p) <= '9' {
        for parser_peek(p) >= '0' && parser_peek(p) <= '9' {
            parser_advance(p)
        }
    } else {
        panic("invalid number format")
    }
    if parser_peek(p) == '.' {
        parser_advance(p)
        if parser_peek(p) < '0' || parser_peek(p) > '9' {
            panic("invalid decimal point in number")
        }
        for parser_peek(p) >= '0' && parser_peek(p) <= '9' {
            parser_advance(p)
        }
    }
    if parser_peek(p) == 'e' || parser_peek(p) == 'E' {
        parser_advance(p)
        if parser_peek(p) == '+' || parser_peek(p) == '-' {
            parser_advance(p)
        }
        if parser_peek(p) < '0' || parser_peek(p) > '9' {
            panic("invalid exponent in number")
        }
        for parser_peek(p) >= '0' && parser_peek(p) <= '9' {
            parser_advance(p)
        }
    }
    num_str := p.text[start:p.pos]
    return parse_float(num_str)
}
func parser_parse_array(p *json_parser) []json_value {
    if parser_advance(p) != '[' {
        panic("expected '['")
    }
    result := make([]json_value, 0)
    parser_skip_whitespace(p)
    if parser_peek(p) == ']' {
        parser_advance(p)
        return result
    }
    for {
        val := parser_parse_value(p)
        result = append(result, val)
        parser_skip_whitespace(p)
        ch := parser_peek(p)
        if ch == ']' {
            parser_advance(p)
            return result
        }
        if ch != ',' {
            panic("expected ',' or ']' in array")
        }
        parser_advance(p)
    }
}
func parser_parse_object(p *json_parser) map[string]json_value {
    if parser_advance(p) != '{' {
        panic("expected '{'")
    }
    result := make(map[string]json_value)
    parser_skip_whitespace(p)
    if parser_peek(p) == '}' {
        parser_advance(p)
        return result
    }
    for {
        parser_skip_whitespace(p)
        if parser_peek(p) != '"' {
            panic("expected string key in object")
        }
        key := parser_parse_string(p)
        parser_skip_whitespace(p)
        if parser_advance(p) != ':' {
            panic("expected ':' in object")
        }
        val := parser_parse_value(p)
        result[key] = val
        parser_skip_whitespace(p)
        ch := parser_peek(p)
        if ch == '}' {
            parser_advance(p)
            return result
        }
        if ch != ',' {
            panic("expected ',' or '}' in object")
        }
        parser_advance(p)
    }
}
func parse_float(s string) float {
    f := 0.0
    negative := false
    dot_pos := -1
    e_pos := -1
    start_idx := 0
    if len(s) > 0 && s[0] == '-' {
        negative = true
        start_idx = 1
    }
    for i := start_idx; i < len(s); i = i + 1 {
        if s[i] == '.' && dot_pos == -1 {
            dot_pos = i
        } else if (s[i] == 'e' || s[i] == 'E') && e_pos == -1 {
            e_pos = i
        }
    }
    int_part := 0
    frac_part := 0
    frac_digits := 0
    end_pos := len(s)
    if e_pos != -1 {
        end_pos = e_pos
    }
    if dot_pos == -1 {
        dot_pos = end_pos
    }
    for i := start_idx; i < dot_pos; i = i + 1 {
        ch := s[i]
        if ch >= '0' && ch <= '9' {
            int_part = int_part * 10 + int(ch - '0')
        }
    }
    if dot_pos < end_pos {
        for i := dot_pos + 1; i < end_pos; i = i + 1 {
            ch := s[i]
            if ch >= '0' && ch <= '9' {
                frac_part = frac_part * 10 + int(ch - '0')
                frac_digits = frac_digits + 1
            }
        }
    }
    f = float(int_part)
    if frac_digits > 0 {
        divisor := 1.0
        for j := 0; j < frac_digits; j = j + 1 {
            divisor = divisor * 10.0
        }
        f = f + float(frac_part) / divisor
    }
    if e_pos != -1 {
        exp_str := s[e_pos+1:]
        exp_negative := false
        exp_start := 0
        if len(exp_str) > 0 && exp_str[0] == '-' {
            exp_negative = true
            exp_start = 1
        } else if len(exp_str) > 0 && exp_str[0] == '+' {
            exp_start = 1
        }
        exp_val := 0
        for i := exp_start; i < len(exp_str); i = i + 1 {
            ch := exp_str[i]
            if ch >= '0' && ch <= '9' {
                exp_val = exp_val * 10 + int(ch - '0')
            }
        }
        if exp_negative {
            for i := 0; i < exp_val; i = i + 1 {
                f = f / 10.0
            }
        } else {
            for i := 0; i < exp_val; i = i + 1 {
                f = f * 10.0
            }
        }
    }
    if negative {
        f = -f
    }
    return f
}
