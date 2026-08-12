package neurx.posttrain.lib.test_json_simple
use std.io.eprintln
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
func (j json_value) contains(key string) bool {
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
func (j json_value) at(key string) json_value {
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
struct json_parser {
    string text
    int pos
}
func json_parser_create(text string) json_parser {
    p := json_parser{}
    p.text = text
    p.pos = 0
    return p
}
func parser_skip_whitespace(p *json_parser) {
    for p.pos < len(p.text) {
        ch := byte(p.text[p.pos])
        if ch != byte(32) && ch != byte(9) && ch != byte(10) && ch != byte(13) {
            break
        }
        p.pos = p.pos + 1
    }
}
func parser_peek(p *json_parser) byte {
    if p.pos >= len(p.text) {
        return 0
    }
    return byte(p.text[p.pos])
}
func parser_advance(p *json_parser) byte {
    if p.pos >= len(p.text) {
        return 0
    }
    ch := byte(p.text[p.pos])
    p.pos = p.pos + 1
    return ch
}
func parser_parse_value(p *json_parser) json_value {
    parser_skip_whitespace(p)
    ch := parser_peek(p)
    if ch == byte(110) {
        return parser_parse_null(p)
    }
    if ch == byte(116) || ch == byte(102) {
        return parser_parse_bool(p)
    }
    if ch == byte(34) {
        str := parser_parse_string(p)
        val := json_value{}
        val.type = 3
        val.string_value = str
        return val
    }
    if ch == byte(91) {
        arr := parser_parse_array(p)
        val := json_value{}
        val.type = 4
        val.array_value = arr
        return val
    }
    if ch == byte(123) {
        keys := make([]string, 0)
        vals := make([]json_value, 0)
        parser_parse_object(p, &keys, &vals)
        val := json_value{}
        val.type = 5
        val.object_keys = keys
        val.object_values = vals
        return val
    }
    if ch == byte(45) || (ch >= byte(48) && ch <= byte(57)) {
        num := parser_parse_number(p)
        val := json_value{}
        val.type = 2
        val.number_value = num
        return val
    }
    panic("unexpected character in JSON")
}
func parser_parse_null(p *json_parser) json_value {
    parser_advance(p)
    parser_advance(p)
    parser_advance(p)
    parser_advance(p)
    val := json_value{}
    val.type = 0
    return val
}
func parser_parse_bool(p *json_parser) json_value {
    if parser_peek(p) == byte(116) {
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
func parser_parse_string(p *json_parser) string {
    if parser_advance(p) != byte(34) {
        panic("expected quote")
    }
    result := ""
    for p.pos < len(p.text) {
        ch := parser_advance(p)
        if ch == byte(34) {
            return result
        }
        if ch == byte(92) {
            if p.pos >= len(p.text) {
                panic("unexpected end of string")
            }
            escaped := parser_advance(p)
            if escaped == byte(34) {
                result = result + "\""
            } else if escaped == byte(92) {
                result = result + "\\"
            } else if escaped == byte(47) {
                result = result + "/"
            } else if escaped == byte(110) {
                result = result + "\n"
            } else if escaped == byte(116) {
                result = result + "\t"
            }
        } else {
            result = result + string(ch)
        }
    }
    panic("unexpected end of string")
}
func parser_parse_number(p *json_parser) float {
    start := p.pos
    if parser_peek(p) == byte(45) {
        parser_advance(p)
    }
    for parser_peek(p) >= byte(48) && parser_peek(p) <= byte(57) {
        parser_advance(p)
    }
    if parser_peek(p) == byte(46) {
        parser_advance(p)
        for parser_peek(p) >= byte(48) && parser_peek(p) <= byte(57) {
            parser_advance(p)
        }
    }
    num_str := p.text[start:p.pos]
    return parse_float(num_str)
}
func parser_parse_array(p *json_parser) []json_value {
    if parser_advance(p) != byte(91) {
        panic("expected [")
    }
    result := make([]json_value, 0)
    parser_skip_whitespace(p)
    if parser_peek(p) == byte(93) {
        parser_advance(p)
        return result
    }
    for {
        val := parser_parse_value(p)
        result = append(result, val)
        parser_skip_whitespace(p)
        ch := parser_peek(p)
        if ch == byte(93) {
            parser_advance(p)
            return result
        }
        if ch != byte(44) {
            panic("expected comma or ]")
        }
        parser_advance(p)
    }
}
func parser_parse_object(p *json_parser, keys *[]string, values *[]json_value) {
    if parser_advance(p) != byte(123) {
        panic("expected {")
    }
    parser_skip_whitespace(p)
    if parser_peek(p) == byte(125) {
        parser_advance(p)
        return
    }
    for {
        parser_skip_whitespace(p)
        if parser_peek(p) != byte(34) {
            panic("expected key in object")
        }
        key := parser_parse_string(p)
        parser_skip_whitespace(p)
        if parser_advance(p) != byte(58) {
            panic("expected colon in object")
        }
        val := parser_parse_value(p)
        *keys = append(*keys, key)
        *values = append(*values, val)
        parser_skip_whitespace(p)
        ch := parser_peek(p)
        if ch == byte(125) {
            parser_advance(p)
            return
        }
        if ch != byte(44) {
            panic("expected comma or }")
        }
        parser_advance(p)
    }
}
func parse_float(s string) float {
    f := 0.0
    negative := false
    dot_pos := -1
    start_idx := 0
    if len(s) > 0 && byte(s[0]) == byte(45) {
        negative = true
        start_idx = 1
    }
    for i := start_idx; i < len(s); i = i + 1 {
        if byte(s[i]) == byte(46) && dot_pos == -1 {
            dot_pos = i
        }
    }
    if dot_pos == -1 {
        dot_pos = len(s)
    }
    int_part := 0
    for i := start_idx; i < dot_pos; i = i + 1 {
        ch := byte(s[i])
        if ch >= byte(48) && ch <= byte(57) {
            int_part = int_part * 10 + int(ch - byte(48))
        }
    }
    f = float(int_part)
    frac_part := 0.0
    frac_divisor := 10.0
    for i := dot_pos + 1; i < len(s); i = i + 1 {
        ch := byte(s[i])
        if ch >= byte(48) && ch <= byte(57) {
            frac_part = frac_part + float(int(ch - byte(48))) / frac_divisor
            frac_divisor = frac_divisor * 10.0
        }
    }
    f = f + frac_part
    if negative {
        f = -f
    }
    return f
}
func json_parse(text string) json_value {
    parser := json_parser_create(text)
    result := parser_parse_value(&parser)
    parser_skip_whitespace(&parser)
    if parser.pos < len(text) {
        panic("unexpected characters after JSON")
    }
    return result
}
func main() {
    eprintln("Testing Pure-S JSON Parser")
    test_null()
    test_bool()
    test_number()
    test_string()
    test_array()
    test_object()
    eprintln("All JSON tests passed")
}
func test_null() {
    eprintln("Test 1: Null value")
    val := json_parse("null")
    if !val.is_null() {
        panic("Expected null")
    }
    eprintln("  OK")
}
func test_bool() {
    eprintln("Test 2: Boolean values")
    val_true := json_parse("true")
    if !val_true.is_bool() || !val_true.as_bool() {
        panic("Expected true")
    }
    eprintln("  true OK")
    val_false := json_parse("false")
    if !val_false.is_bool() || val_false.as_bool() {
        panic("Expected false")
    }
    eprintln("  false OK")
}
func test_number() {
    eprintln("Test 3: Number values")
    val_int := json_parse("42")
    if !val_int.is_number() {
        panic("Expected number")
    }
    eprintln("  integer OK")
    val_float := json_parse("3")
    if !val_float.is_number() {
        panic("Expected float")
    }
    eprintln("  float OK")
}
func test_string() {
    eprintln("Test 4: String values")
    val := json_parse("\"hello\"")
    if !val.is_string() || val.as_string() != "hello" {
        panic("Expected hello")
    }
    eprintln("  OK")
}
func test_array() {
    eprintln("Test 5: Array values")
    val := json_parse("[1,2,3]")
    if !val.is_array() {
        panic("Expected array")
    }
    arr := val.as_array()
    if len(arr) != 3 {
        panic("Expected length 3")
    }
    eprintln("  OK")
}
func test_object() {
    eprintln("Test 6: Object values")
    val := json_parse("{\"key\":\"value\"}")
    if !val.is_object() {
        panic("Expected object")
    }
    if !val.contains("key") {
        panic("Expected key field")
    }
    key_val := val.at("key")
    if !key_val.is_string() || key_val.as_string() != "value" {
        panic("Expected value")
    }
    eprintln("  OK")
}
