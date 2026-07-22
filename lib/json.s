package neurx.lib.json

// JSON parsing utilities for S language
// Handles parsing JSONL files for training data

use neurx.lib.fileio.{trim_string, split_string, starts_with, ends_with, replace_string}

// JSON value types
const int JSON_NULL = 0
const int JSON_BOOL = 1
const int JSON_NUMBER = 2
const int JSON_STRING = 3
const int JSON_ARRAY = 4
const int JSON_OBJECT = 5

// JSON value representation
struct json_value {
    int value_type
    string str_value
    float num_value
    int bool_value
}

// JSON object - key-value pairs
struct json_object {
    []string keys
    []string values
    int count
}

// Parses a JSON string value (removes quotes and handles escapes)
func parse_json_string(string json_str) string {
    // Remove surrounding quotes
    string str = trim_string(json_str)
    
    if len(str) < 2 {
        return ""
    }
    
    // Check for surrounding quotes
    string first_char = str[0 : 1]
    string last_char = str[len(str) - 1 : len(str)]
    
    if first_char != "\"" || last_char != "\"" {
        return ""
    }
    
    // Extract content between quotes
    string content = str[1 : len(str) - 1]
    
    // Handle escape sequences
    content = replace_string(content, "\\\"", "\"")
    content = replace_string(content, "\\\\", "\\")
    content = replace_string(content, "\\n", "\n")
    content = replace_string(content, "\\r", "\r")
    content = replace_string(content, "\\t", "\t")
    
    content
}

// Parses a JSON number
func parse_json_number(string num_str) float {
    string str = trim_string(num_str)
    
    if len(str) == 0 {
        return 0.0
    }
    
    // Simple number parsing (integer and decimal)
    bool is_negative = false
    float result = 0.0
    int i = 0
    
    // Check for negative sign
    if i < len(str) {
        string ch = str[i : i + 1]
        if ch == "-" {
            is_negative = true
            i = i + 1
        }
    }
    
    // Parse integer part
    while i < len(str) {
        string ch = str[i : i + 1]
        
        if ch == "." {
            break
        }
        
        // Convert digit character to number
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
            break  // Non-digit character
        }
        
        result = result * 10.0 + (digit as float)
        i = i + 1
    }
    
    // Parse decimal part if present
    if i < len(str) {
        string ch = str[i : i + 1]
        if ch == "." {
            i = i + 1
            float decimal_places = 0.1
            
            while i < len(str) {
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
                    break  // Non-digit character
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

// Extracts a field value from a JSON object string
// Assumes JSON object is on a single line (JSONL format)
func extract_json_field(string json_line, string field_name) string {
    string trimmed = trim_string(json_line)
    
    // Remove outer braces
    if len(trimmed) < 2 {
        return ""
    }
    
    string first_char = trimmed[0 : 1]
    string last_char = trimmed[len(trimmed) - 1 : len(trimmed)]
    
    if first_char != "{" || last_char != "}" {
        return ""
    }
    
    // Look for field name
    string search_key = "\"" + field_name + "\""
    int key_pos = find_substring(trimmed, search_key)
    
    if key_pos < 0 {
        return ""
    }
    
    // Find the colon after the field name
    int colon_pos = key_pos + len(search_key)
    int colon_idx = find_char_at_or_after(trimmed, colon_pos, ':')
    
    if colon_idx < 0 {
        return ""
    }
    
    // Skip whitespace after colon
    int value_start = colon_idx + 1
    while value_start < len(trimmed) {
        string ch = trimmed[value_start : value_start + 1]
        if ch != " " && ch != "\t" && ch != "\n" && ch != "\r" {
            break
        }
        value_start = value_start + 1
    }
    
    if value_start >= len(trimmed) {
        return ""
    }
    
    // Extract value (string, number, boolean, null, object, or array)
    string first_value_char = trimmed[value_start : value_start + 1]
    
    if first_value_char == "\"" {
        // String value - find closing quote
        int quote_end = value_start + 1
        while quote_end < len(trimmed) {
            string ch = trimmed[quote_end : quote_end + 1]
            if ch == "\"" {
                // Check if it's escaped
                int backslash_count = 0
                int check_pos = quote_end - 1
                while check_pos >= value_start {
                    string check_ch = trimmed[check_pos : check_pos + 1]
                    if check_ch == "\\" {
                        backslash_count = backslash_count + 1
                    } else {
                        break
                    }
                    check_pos = check_pos - 1
                }
                
                // If even number of backslashes, quote is not escaped
                int remainder = backslash_count - (backslash_count / 2) * 2
                if remainder == 0 {
                    // Found closing quote
                    return trimmed[value_start : quote_end + 1]
                }
            }
            quote_end = quote_end + 1
        }
        return ""
    } else if first_value_char == "{" {
        // Object value - find matching closing brace
        return extract_object_value(trimmed, value_start)
    } else if first_value_char == "[" {
        // Array value - find matching closing bracket
        return extract_array_value(trimmed, value_start)
    } else {
        // Number, boolean, or null - read until comma, brace, or bracket
        int value_end = value_start
        while value_end < len(trimmed) {
            string ch = trimmed[value_end : value_end + 1]
            if ch == "," || ch == "}" || ch == "]" {
                break
            }
            value_end = value_end + 1
        }
        
        return trim_string(trimmed[value_start : value_end])
    }
}

// Helper: finds substring position
func find_substring(string text, string substr) int {
    if len(substr) == 0 || len(substr) > len(text) {
        return -1
    }
    
    int i = 0
    while i <= len(text) - len(substr) {
        bool matches = true
        int j = 0
        while j < len(substr) {
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

// Helper: finds character at or after position
func find_char_at_or_after(string text, int start_pos, string ch) int {
    int i = start_pos
    while i < len(text) {
        string text_ch = text[i : i + 1]
        if text_ch == ch {
            return i
        }
        i = i + 1
    }
    -1
}

// Helper: extracts object value (finds matching closing brace)
func extract_object_value(string json, int start_pos) string {
    int brace_count = 0
    int i = start_pos
    
    while i < len(json) {
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

// Helper: extracts array value (finds matching closing bracket)
func extract_array_value(string json, int start_pos) string {
    int bracket_count = 0
    int i = start_pos
    
    while i < len(json) {
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

// Parses a JSON line from JSONL file format
// Returns field values as strings
func parse_jsonl_line(string line) json_object {
    json_object obj
    obj.count = 0
    
    string trimmed = trim_string(line)
    if len(trimmed) == 0 || trimmed[0 : 1] != "{" {
        return obj
    }
    
    // For now, return empty - will be populated with actual parsing
    obj
}

// Converts JSON string value to S string
func json_string_to_string(string json_str) string {
    return parse_json_string(json_str)
}

// Converts JSON number string to float
func json_string_to_float(string json_str) float {
    return parse_json_number(json_str)
}

// Converts JSON number string to int
func json_string_to_int(string json_str) int {
    float f = parse_json_number(json_str)
    int result = 0
    while result as float < f {
        result = result + 1
    }
    result
}
