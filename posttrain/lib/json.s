package neurx.posttrain.lib.json

use std.io.eprintln

func check_prefix(string text, int pos, string prefix) bool {
    int end = pos + len(prefix)
    if end > len(text) {
        return false
    }
    int i = 0
    while i < len(prefix) {
        if byte(text[pos + i]) != byte(prefix[i]) {
            return false
        }
        i = i + 1
    }
    return true
}

func skip_whitespace(string text, int pos) int {
    while pos < len(text) {
        byte ch = byte(text[pos])
        if ch == byte(32) || ch == byte(9) || ch == byte(10) || ch == byte(13) {
            pos = pos + 1
        } else {
            break
        }
    }
    return pos
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

    if pos < len(text) && byte(text[pos]) == byte(45) {
        pos = pos + 1
    }

    while pos < len(text) && byte(text[pos]) >= byte(48) && byte(text[pos]) <= byte(57) {
        pos = pos + 1
    }

    if pos < len(text) && byte(text[pos]) == byte(46) {
        pos = pos + 1
        while pos < len(text) && byte(text[pos]) >= byte(48) && byte(text[pos]) <= byte(57) {
            pos = pos + 1
        }
    }

    if start == pos {
        return -1
    }

    return pos
}

func parse_string(string text, int pos) int {
    if pos >= len(text) || byte(text[pos]) != byte(34) {
        return -1
    }

    pos = pos + 1
    while pos < len(text) {
        byte ch = byte(text[pos])
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

func parse_array(string text, int pos) int {
    if pos >= len(text) || byte(text[pos]) != byte(91) {
        return -1
    }

    pos = pos + 1
    pos = skip_whitespace(text, pos)

    if pos < len(text) && byte(text[pos]) == byte(93) {
        return pos + 1
    }

    bool first = true
    while true {
        if !first {
            byte ch = byte(text[pos])
            if ch != byte(44) {
                return -1
            }
            pos = pos + 1
        }
        first = false

        int new_pos = parse_value(text, pos)
        if new_pos == -1 {
            return -1
        }
        pos = new_pos

        pos = skip_whitespace(text, pos)

        if pos >= len(text) {
            return -1
        }

        byte next_ch = byte(text[pos])
        if next_ch == byte(93) {
            return pos + 1
        }
        if next_ch != byte(44) {
            return -1
        }
    }
}

func parse_object(string text, int pos) int {
    if pos >= len(text) || byte(text[pos]) != byte(123) {
        return -1
    }

    pos = pos + 1
    pos = skip_whitespace(text, pos)

    if pos < len(text) && byte(text[pos]) == byte(125) {
        return pos + 1
    }

    bool first = true
    while true {
        if !first {
            if pos >= len(text) || byte(text[pos]) != byte(44) {
                return -1
            }
            pos = pos + 1
        }
        first = false

        pos = skip_whitespace(text, pos)

        if pos >= len(text) || byte(text[pos]) != byte(34) {
            return -1
        }

        int new_pos = parse_string(text, pos)
        if new_pos == -1 {
            return -1
        }
        pos = new_pos

        pos = skip_whitespace(text, pos)

        if pos >= len(text) || byte(text[pos]) != byte(58) {
            return -1
        }
        pos = pos + 1

        new_pos = parse_value(text, pos)
        if new_pos == -1 {
            return -1
        }
        pos = new_pos

        pos = skip_whitespace(text, pos)

        if pos >= len(text) {
            return -1
        }

        byte next_ch = byte(text[pos])
        if next_ch == byte(125) {
            return pos + 1
        }
        if next_ch != byte(44) {
            return -1
        }
    }
}

func parse_value(string text, int pos) int {
    pos = skip_whitespace(text, pos)

    if pos >= len(text) {
        return -1
    }

    byte ch = byte(text[pos])

    if ch == byte(110) {
        return parse_null(text, pos)
    }
    if ch == byte(116) {
        return parse_true(text, pos)
    }
    if ch == byte(102) {
        return parse_false(text, pos)
    }
    if ch == byte(34) {
        return parse_string(text, pos)
    }
    if ch == byte(45) || (ch >= byte(48) && ch <= byte(57)) {
        return parse_number(text, pos)
    }
    if ch == byte(91) {
        return parse_array(text, pos)
    }
    if ch == byte(123) {
        return parse_object(text, pos)
    }

    return -1
}

func parse(string text) bool {
    int pos = parse_value(text, 0)
    if pos == -1 {
        return false
    }

    pos = skip_whitespace(text, pos)
    if pos != len(text) {
        return false
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
