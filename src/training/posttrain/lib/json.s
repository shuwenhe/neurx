package neurx.posttrain.lib.json
use std.io.eprintln

func check_prefix(string text, int pos, string prefix) bool {
    int end = pos + len(prefix)
    if end > len(text) {
        return false
    }
    int i = 0
    for i < len(prefix) {
        if byte(text[pos + i]) != byte(prefix[i]) {
            return false
        }
        i = i + 1
    }
    return true
}

func skip_whitespace(string text, int pos) int {
    int current = pos
    for current < len(text) {
        byte ch = byte(text[current])
        if ch == byte(32) || ch == byte(9) || ch == byte(10) || ch == byte(13) {
            current = current + 1
        } else {
            break
        }
    }
    return current
}

func parse_null(string text, int pos) int {
    if check_prefix(text, pos, "null") {
        return pos + 4
    }
    return -1
}

func parse_true(string text, int pos) int {
    if check_prefix(text, pos, "true") {
        return pos + 4
    }
    return -1
}

func parse_false(string text, int pos) int {
    if check_prefix(text, pos, "false") {
        return pos + 5
    }
    return -1
}

func parse_number(string text, int pos) int {
    int start = pos
    int current = pos
    if current < len(text) && byte(text[current]) == byte(45) {
        current = current + 1
    }
    for current < len(text) && byte(text[current]) >= byte(48) && byte(text[current]) <= byte(57) {
        current = current + 1
    }
    if current < len(text) && byte(text[current]) == byte(46) {
        current = current + 1
        for current < len(text) && byte(text[current]) >= byte(48) && byte(text[current]) <= byte(57) {
            current = current + 1
        }
    }
    if start == current {
        return -1
    }
    return current
}

func parse_string(string text, int pos) int {
    if pos >= len(text) || byte(text[pos]) != byte(34) {
        return -1
    }
    int current = pos + 1
    for current < len(text) {
        byte ch = byte(text[current])
        if ch == byte(34) {
            return current + 1
        }
        if ch == byte(92) {
            current = current + 2
        } else {
            current = current + 1
        }
    }
    return -1
}

func parse_array(string text, int pos) int {
    if pos >= len(text) || byte(text[pos]) != byte(91) {
        return -1
    }
    int current = pos + 1
    current = skip_whitespace(text, current)
    if current < len(text) && byte(text[current]) == byte(93) {
        return current + 1
    }
    bool first = true
    for true {
        if !first {
            if current >= len(text) || byte(text[current]) != byte(44) {
                return -1
            }
            current = current + 1
        }
        first = false
        int new_pos = parse_value(text, current)
        if new_pos == -1 {
            return -1
        }
        current = new_pos
        current = skip_whitespace(text, current)
        if current >= len(text) {
            return -1
        }
        byte next_ch = byte(text[current])
        if next_ch == byte(93) {
            return current + 1
        }
        if next_ch != byte(44) {
            return -1
        }
    }
    return -1
}

func parse_object(string text, int pos) int {
    if pos >= len(text) || byte(text[pos]) != byte(123) {
        return -1
    }
    int current = pos + 1
    current = skip_whitespace(text, current)
    if current < len(text) && byte(text[current]) == byte(125) {
        return current + 1
    }
    bool first = true
    for true {
        if !first {
            if current >= len(text) || byte(text[current]) != byte(44) {
                return -1
            }
            current = current + 1
        }
        first = false
        current = skip_whitespace(text, current)
        if current >= len(text) || byte(text[current]) != byte(34) {
            return -1
        }
        int new_pos = parse_string(text, current)
        if new_pos == -1 {
            return -1
        }
        current = new_pos
        current = skip_whitespace(text, current)
        if current >= len(text) || byte(text[current]) != byte(58) {
            return -1
        }
        current = current + 1
        new_pos = parse_value(text, current)
        if new_pos == -1 {
            return -1
        }
        current = new_pos
        current = skip_whitespace(text, current)
        if current >= len(text) {
            return -1
        }
        byte next_ch = byte(text[current])
        if next_ch == byte(125) {
            return current + 1
        }
        if next_ch != byte(44) {
            return -1
        }
    }
    return -1
}

func parse_value(string text, int pos) int {
    int current = skip_whitespace(text, pos)
    if current >= len(text) {
        return -1
    }
    int ch_int = int(byte(text[current]))
    if ch_int == 110 {
        return parse_null(text, current)
    }
    if ch_int == 116 {
        return parse_true(text, current)
    }
    if ch_int == 102 {
        return parse_false(text, current)
    }
    if ch_int == 34 {
        return parse_string(text, current)
    }
    if ch_int == 45 || (ch_int >= 48 && ch_int <= 57) {
        return parse_number(text, current)
    }
    if ch_int == 91 {
        return parse_array(text, current)
    }
    if ch_int == 123 {
        return parse_object(text, current)
    }
    return -1
}

func parse(string text) bool {
    int pos = parse_value(text, 0)
    if pos == -1 {
        return false
    }
    int final_pos = skip_whitespace(text, pos)
    if final_pos != len(text) {
    }
    return true
}

func main() {
    eprintln("JSON Parser Test Suite")
    eprintln("")
    eprintln("Test 1: null")
    if parse("null") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("Test 2: true")
    if parse("true") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("Test 3: false")
    if parse("false") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("Test 4: number 42")
    if parse("42") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("Test 5: float 3.14")
    if parse("3.14") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("Test 6: string")
    if parse("\"hello\"") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("Test 7: empty array")
    if parse("[]") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("Test 8: array with elements")
    if parse("[1,2,3]") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("Test 9: empty object")
    if parse("{}") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("Test 10: object with fields")
    if parse("{\"key\":\"value\"}") {
        eprintln("  PASS")
    } else {
        eprintln("  FAIL")
    }
    eprintln("")
    eprintln("All tests completed")
    0
}
