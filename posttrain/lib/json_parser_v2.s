package neurx.posttrain.lib
use std.io.eprintln
func string_starts_with(text string, pos int, prefix string) bool {
    end := pos + len(prefix)
    if end > len(text) {
        return false
    }
    for i := 0; i < len(prefix); i = i + 1 {
        if byte(text[pos + i]) != byte(prefix[i]) {
            return false
        }
    }
    return true
}

func parse_json_null(text string, pos int) int {
    if string_starts_with(text, pos, "null") {
        return pos + 4
    }
    return -1
}

func parse_json_bool(text string, pos int) int {
    if string_starts_with(text, pos, "true") {
        return pos + 4
    }
    if string_starts_with(text, pos, "false") {
        return pos + 5
    }
    return -1
}

func parse_json_number(text string, pos int) int {
    start := pos
    if pos < len(text) && byte(text[pos]) == byte(45) {
        pos = pos + 1
    }
    for pos < len(text) && byte(text[pos]) >= byte(48) && byte(text[pos]) <= byte(57) {
        pos = pos + 1
    }
    if pos < len(text) && byte(text[pos]) == byte(46) {
        pos = pos + 1
        for pos < len(text) && byte(text[pos]) >= byte(48) && byte(text[pos]) <= byte(57) {
            pos = pos + 1
        }
    }
    if start == pos {
        return -1
    }
    return pos
}

func parse_json_string(text string, pos int) int {
    if pos >= len(text) || byte(text[pos]) != byte(34) {
        return -1
    }
    pos = pos + 1
    for pos < len(text) {
        ch := byte(text[pos])
        if ch == byte(34) {
            return pos + 1
        }
        if ch == byte(92) {
            pos = pos + 2
        } else {
            pos = pos + 1
        }
    }
    return -1
}

func skip_whitespace(text string, pos int) int {
    for pos < len(text) {
        ch := byte(text[pos])
        if ch == byte(32) || ch == byte(9) || ch == byte(10) || ch == byte(13) {
            pos = pos + 1
        } else {
            break
        }
    }
    return pos
}

func parse_json_value(text string, pos int) int {
    pos = skip_whitespace(text, pos)
    if pos >= len(text) {
        return -1
    }
    ch := byte(text[pos])
    if ch == byte(110) {
        return parse_json_null(text, pos)
    }
    if ch == byte(116) || ch == byte(102) {
        return parse_json_bool(text, pos)
    }
    if ch == byte(34) {
        return parse_json_string(text, pos)
    }
    if ch == byte(45) || (ch >= byte(48) && ch <= byte(57)) {
        return parse_json_number(text, pos)
    }
    if ch == byte(91) {
        return parse_json_array(text, pos)
    }
    if ch == byte(123) {
        return parse_json_object(text, pos)
    }
    return -1
}

func parse_json_array(text string, pos int) int {
    if pos >= len(text) || byte(text[pos]) != byte(91) {
        return -1
    }
    pos = pos + 1
    pos = skip_whitespace(text, pos)
    if pos < len(text) && byte(text[pos]) == byte(93) {
        return pos + 1
    }
    for {
        new_pos := parse_json_value(text, pos)
        if new_pos == -1 {
            return -1
        }
        pos = new_pos
        pos = skip_whitespace(text, pos)
        if pos >= len(text) {
            return -1
        }
        ch := byte(text[pos])
        if ch == byte(93) {
            return pos + 1
        }
        if ch == byte(44) {
            pos = pos + 1
        } else {
            return -1
        }
    }
}

func parse_json_object(text string, pos int) int {
    if pos >= len(text) || byte(text[pos]) != byte(123) {
        return -1
    }
    pos = pos + 1
    pos = skip_whitespace(text, pos)
    if pos < len(text) && byte(text[pos]) == byte(125) {
        return pos + 1
    }
    for {
        pos = skip_whitespace(text, pos)
        if pos >= len(text) || byte(text[pos]) != byte(34) {
            return -1
        }
        new_pos := parse_json_string(text, pos)
        if new_pos == -1 {
            return -1
        }
        pos = new_pos
        pos = skip_whitespace(text, pos)
        if pos >= len(text) || byte(text[pos]) != byte(58) {
            return -1
        }
        pos = pos + 1
        new_pos = parse_json_value(text, pos)
        if new_pos == -1 {
            return -1
        }
        pos = new_pos
        pos = skip_whitespace(text, pos)
        if pos >= len(text) {
            return -1
        }
        ch := byte(text[pos])
        if ch == byte(125) {
            return pos + 1
        }
        if ch == byte(44) {
            pos = pos + 1
        } else {
            return -1
        }
    }
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
    pos := parse_json_value("null", 0)
    if pos != 4 {
        panic("Failed to parse null")
    }
    eprintln("  OK")
}

func test_bool() {
    eprintln("Test 2: Boolean values")
    pos := parse_json_value("true", 0)
    if pos != 4 {
        panic("Failed to parse true")
    }
    eprintln("  true OK")
    pos = parse_json_value("false", 0)
    if pos != 5 {
        panic("Failed to parse false")
    }
    eprintln("  false OK")
}

func test_number() {
    eprintln("Test 3: Number values")
    pos := parse_json_value("42", 0)
    if pos != 2 {
        panic("Failed to parse integer")
    }
    eprintln("  integer OK")
    pos = parse_json_value("3.14", 0)
    if pos != 4 {
        panic("Failed to parse float")
    }
    eprintln("  float OK")
}

func test_string() {
    eprintln("Test 4: String values")
    pos := parse_json_value("\"hello\"", 0)
    if pos != 7 {
        panic("Failed to parse string")
    }
    eprintln("  OK")
}

func test_array() {
    eprintln("Test 5: Array values")
    pos := parse_json_value("[1,2,3]", 0)
    if pos != 7 {
        panic("Failed to parse array")
    }
    eprintln("  OK")
}

func test_object() {
    eprintln("Test 6: Object values")
    pos := parse_json_value("{\"key\":\"value\"}", 0)
    if pos != 16 {
        panic("Failed to parse object")
    }
    eprintln("  OK")
}
