package neurx.lib.json
use neurx.lib.fileio.{trim_string, split_string, starts_with, ends_with, replace_string}
const int JSON_NULL = 0
const int JSON_BOOL = 1
const int JSON_NUMBER = 2
const int JSON_STRING = 3
const int JSON_ARRAY = 4
const int JSON_OBJECT = 5

struct json_value {
    int value_type
    string str_value
    float num_value
    int bool_value
}

struct json_object {
    string[] keys
    string[] values
    int count
}

func parse_json_string(string json_str) string {
    string str = trim_string(json_str)
    if len(str) < 2 {
        return ""
    }
    string first_char = str[0 : 1]
    string last_char = str[len(str) - 1 : len(str)]
    if first_char != "\"" || last_char != "\"" {
        return ""
    }
    string content = str[1 : len(str) - 1]
    content = replace_string(content, "\\\"", "\"")
    content = replace_string(content, "\\\\", "\\")
    content = replace_string(content, "\\n", "\n")
    content = replace_string(content, "\\r", "\r")
    content = replace_string(content, "\\t", "\t")
    content
}

func parse_json_number(string num_str) float {
    string str = trim_string(num_str)
    if len(str) == 0 {
        return 0.0
    }
    bool is_negative = false
    float result = 0.0
    int i = 0
    if i < len(str) {
        string ch = str[i : i + 1]
        if ch == "-" {
            is_negative = true
            i = i + 1
        }
    }
    for i < len(str) {
        string ch = str[i : i + 1]
        if ch == "." {
            break
        }
        int digit = 0
        if ch == "0" {
            digit = 0
        } else if ch == "1" {
            digit = 1
        } else if ch == "2" {
            digit = 2
        } else if ch == "3" {
            digit = 3
        } else if ch == "4" {
            digit = 4
        } else if ch == "5" {
            digit = 5
        } else if ch == "6" {
            digit = 6
        } else if ch == "7" {
            digit = 7
        } else if ch == "8" {
            digit = 8
        } else if ch == "9" {
            digit = 9
        } else {
            break
        }
        result = result * 10.0 + (digit as float)
        i = i + 1
    }
    if i < len(str) {
        string ch = str[i : i + 1]
        if ch == "." {
            i = i + 1
            float decimal_places = 0.1
            for i < len(str) {
                string dch = str[i : i + 1]
                int digit = 0
                if dch == "0" {
                    digit = 0
                } else if dch == "1" {
                    digit = 1
                } else if dch == "2" {
                    digit = 2
                } else if dch == "3" {
                    digit = 3
                } else if dch == "4" {
                    digit = 4
                } else if dch == "5" {
                    digit = 5
                } else if dch == "6" {
                    digit = 6
                } else if dch == "7" {
                    digit = 7
                } else if dch == "8" {
                    digit = 8
                } else if dch == "9" {
                    digit = 9
                } else {
                    break
                }
                result = result + (digit as float) * decimal_places
                decimal_places = decimal_places * 0.1
                i = i + 1
            }
        }
    }
    if is_negative {
        result = 0.0 - result
    }
    result
}

func extract_json_field(string json_line, string field_name) string {
    string trimmed = trim_string(json_line)
    if len(trimmed) < 2 {
        return ""
    }
    string first_char = trimmed[0 : 1]
    string last_char = trimmed[len(trimmed) - 1 : len(trimmed)]
    if first_char != "{" || last_char != "}" {
        return ""
    }
    string search_key = "\"" + field_name + "\""
    int key_pos = find_substring(trimmed, search_key)
    if key_pos < 0 {
        return ""
    }
    int colon_pos = key_pos + len(search_key)
    int colon_idx = find_char_at_or_after(trimmed, colon_pos, ':')
    if colon_idx < 0 {
        return ""
    }
    int value_start = colon_idx + 1
    for value_start < len(trimmed) {
        string ch = trimmed[value_start : value_start + 1]
        if ch != " " && ch != "\t" && ch != "\n" && ch != "\r" {
            break
        }
        value_start = value_start + 1
    }
    if value_start >= len(trimmed) {
        return ""
    }
    string first_value_char = trimmed[value_start : value_start + 1]
    if first_value_char == "\"" {
        int quote_end = value_start + 1
        for quote_end < len(trimmed) {
            string ch = trimmed[quote_end : quote_end + 1]
            if ch == "\"" {
                int backslash_count = 0
                int check_pos = quote_end - 1
                for check_pos >= value_start {
                    string check_ch = trimmed[check_pos : check_pos + 1]
                    if check_ch == "\\" {
                        backslash_count = backslash_count + 1
                    } else {
                        break
                    }
                    check_pos = check_pos - 1
                }
                int remainder = backslash_count - (backslash_count / 2) * 2
                if remainder == 0 {
                    return trimmed[value_start : quote_end + 1]
                }
            }
            quote_end = quote_end + 1
        }
        return ""
    } else if first_value_char == "{" {
        return extract_object_value(trimmed, value_start)
    } else if first_value_char == "[" {
        return extract_array_value(trimmed, value_start)
    } else {
        int value_end = value_start
        for value_end < len(trimmed) {
            string ch = trimmed[value_end : value_end + 1]
            if ch == "," || ch == "}" || ch == "]" {
                break
            }
            value_end = value_end + 1
        }
        return trim_string(trimmed[value_start : value_end])
    }
}

func find_substring(string text, string substr) int {
    if len(substr) == 0 || len(substr) > len(text) {
        return -1
    }
    int i = 0
    for i <= len(text) - len(substr) {
        bool matches = true
        int j = 0
        for j < len(substr) {
            string text_ch = text[i + j : i + j + 1]
            string substr_ch = substr[j : j + 1]
            if text_ch != substr_ch {
                matches = false
                break
            }
            j = j + 1
        }
        if matches {
            return i
        }
        i = i + 1
    }
    -1
}

func find_char_at_or_after(string text, int start_pos, string ch) int {
    int i = start_pos
    for i < len(text) {
        string text_ch = text[i : i + 1]
        if text_ch == ch {
            return i
        }
        i = i + 1
    }
    -1
}

func extract_object_value(string json, int start_pos) string {
    int brace_count = 0
    int i = start_pos
    for i < len(json) {
        string ch = json[i : i + 1]
        if ch == "{" {
            brace_count = brace_count + 1
        } else if ch == "}" {
            brace_count = brace_count - 1
            if brace_count == 0 {
                return json[start_pos : i + 1]
            }
        }
        i = i + 1
    }
    ""
}

func extract_array_value(string json, int start_pos) string {
    int bracket_count = 0
    int i = start_pos
    for i < len(json) {
        string ch = json[i : i + 1]
        if ch == "[" {
            bracket_count = bracket_count + 1
        } else if ch == "]" {
            bracket_count = bracket_count - 1
            if bracket_count == 0 {
                return json[start_pos : i + 1]
            }
        }
        i = i + 1
    }
    ""
}

func parse_jsonl_line(string line) json_object {
    json_object obj
    obj.count = 0
    string trimmed = trim_string(line)
    if len(trimmed) == 0 || trimmed[0 : 1] != "{" {
        return obj
    }
    obj
}

func json_string_to_string(string json_str) string {
    return parse_json_string(json_str)
}

func json_string_to_float(string json_str) float {
    return parse_json_number(json_str)
}

func json_string_to_int(string json_str) int {
    float f = parse_json_number(json_str)
    int result = 0
    for result as float < f {
        result = result + 1
    }
    result
}
