package neurx.script.data_utils
use std.io
use std.os
use std.strings

struct json_value {
    string type
    string str_val
    []json_value array_val
    map[string]json_value obj_val
}

func json_encode_string(string s) string {
    result := "\""
    for i = 0; i < len(s); i = i + 1 {
        ch := s[i]
        match ch {
            case '"':
                result = result + "\\\""
            case '\\':
                result = result + "\\\\"
            case '\n':
                result = result + "\\n"
            case '\r':
                result = result + "\\r"
            case '\t':
                result = result + "\\t"
            case _:
                result = result + string(ch)
        }
    }
    result = result + "\""
    result
}

func json_decode_string(string s) string {
    if !string_has_prefix(s, "\"") || !string_has_suffix(s, "\"") {
        ""
    }
    inner := s[1 : len(s) - 1]
    result := ""
    i := 0
    for i < len(inner) {
        if inner[i] == '\\' && i + 1 < len(inner) {
            match inner[i + 1] {
                case '"':
                    result = result + "\""
                    i = i + 2
                case '\\':
                    result = result + "\\"
                    i = i + 2
                case 'n':
                    result = result + "\n"
                    i = i + 2
                case 'r':
                    result = result + "\r"
                    i = i + 2
                case 't':
                    result = result + "\t"
                    i = i + 2
                case _:
                    result = result + string(inner[i])
                    i = i + 1
            }
        } else {
            result = result + string(inner[i])
            i = i + 1
        }
    }
    result
}

func json_object_to_string(map fields[string]string, int indent) string {
    result := "{\n"
    pad := string_repeat(" ", indent)
    first := true
    for k, v in fields {
        if !first {
            result = result + ",\n"
        }
        first = false
        result = result + pad + "  " + json_encode_string(k) + ": " + v
    }
    result = result + "\n" + pad + "}"
    result
}

func path_join([]string parts) string {
    string_join(parts, "/")
}

func path_dirname(string path) string {
    parts := string_split(path, "/")
    if len(parts) <= 1 {
        "."
    } else {
        string_join(parts[0 : len(parts) - 1], "/")
    }
}

func path_basename(string path) string {
    parts := string_split(path, "/")
    if len(parts) == 0 {
        ""
    } else {
        parts[len(parts) - 1]
    }
}

func path_exists(string path) bool {
    runtime_file_exists(path)
}

func path_is_dir(string path) bool {
    runtime_is_dir(path)
}

func file_read_text(string path) (string, bool) {
    runtime_read_text_file(path)
}

func file_write_text(string path, string content) bool {
    dir := path_dirname(path)
    if !path_exists(dir) {
        _ = runtime_make_dirs(dir)
    }
    runtime_write_text_file(path, content)
}

func file_append_text(string path, string content) bool {
    (existing, ok) := file_read_text(path)
    if !ok && path_exists(path) {
        return false
    }
    new_content := if ok { existing + content } else { content }
    file_write_text(path, new_content)
}

func file_delete(string path) bool {
    runtime_remove_file(path)
}

func file_size(string path) i64 {
    runtime_file_size(path)
}

func file_count_lines(string path) (i64, bool) {
    (content, ok) := file_read_text(path)
    if !ok {
        (0, false)
    }
    lines := string_split(content, "\n")
    (i64(len(lines)), true)
}

func dir_list_files(string path, []string suffixes) []string {
    if !path_is_dir(path) {
        return []string{}
    }
    files := runtime_list_dir(path)
    result := []string{}
    for _, file in files {
        fname := path_basename(file)
        for _, suffix in suffixes {
            if string_has_suffix(string_to_lower(fname), suffix) {
                result = append(result, path_join([]string{path, fname}))
                break
            }
        }
    }
    result
}

func string_repeat(string s, int count) string {
    result := ""
    for i = 0; i < count; i = i + 1 {
        result = result + s
    }
    result
}

func normalize_whitespace(string s) string {
    parts := string_split(string_trim(s), " ")
    string_join(parts, " ")
}

func hash_key(string s) string {
    "hash_" + string_to_lower(s[0 : min(10, len(s))])
}

func ensure_dir(string path) bool {
    if path_exists(path) {
        return path_is_dir(path)
    }
    runtime_make_dirs(path)
}

func clear_dir(string path) bool {
    if !path_exists(path) {
        return ensure_dir(path)
    }
    files := runtime_list_dir(path)
    for _, file in files {
        _ = file_delete(file)
    }
    true
}

func get_env(string key, string default_val) string {
    val := runtime_env_get(key)
    if val == "" {
        default_val
    } else {
        val
    }
}

func get_env_int(string key, int default_val) int {
    val := runtime_env_get(key)
    if val == "" {
        default_val
    } else {
        default_val
    }
}
pub func log_info(string msg) {
    println(msg)
}
pub func log_warn(string msg) {
    println("⚠ " + msg)
}
pub func log_error(string msg) {
    println("✗ " + msg)
}
pub func log_success(string msg) {
    println("✓ " + msg)
}

func min(i64 a, i64 b) i64 {
    if a < b { a } else { b }
}

func max(i64 a, i64 b) i64 {
    if a > b { a } else { b }
}

func div_round_up(i64 a, i64 b) i64 {
    (a + b - 1) / b
}
