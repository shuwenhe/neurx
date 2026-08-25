package main

use std.io
use std.fs

func main() {
    project_root := "."
    pattern_var := "^\\s*var\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*(::\\s*([^=]+))\\s*=\\s*"
    pattern_let := "^\\s*let\\s+([a-zA-Z_][a-zA-Z0-9_]*)\\s*(::\\s*([^=]+))\\s*=\\s*"
    
    files := vec[string]()
    find_all_s_files(project_root, &files)
    
    total_replaced := 0
    
    for file in files {
        content := read_file_safe(file)
        if content.is_empty() {
            continue
        }
        
        new_content := content
        
        new_content = replace_var_declarations(new_content)
        new_content = replace_let_declarations(new_content)
        
        if new_content != content {
            write_file_safe(file, new_content)
            count := count_replacements(content, new_content)
            total_replaced = total_replaced + count
            println("✓ " + file + " (" + count_to_string(count) + " changes)")
        }
    }
    
    println("")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("✅ 迁移完成! 共替换 " + count_to_string(total_replaced) + " 处")
}

func find_all_s_files(string dir, vec[string] files) {
    entries := fs_list_dir(dir)
    
    for entry in entries {
        path := dir + "/" + entry
        
        if fs_is_dir(path) {
            if entry != ".git" && entry != "node_modules" && entry != "build" && entry != "bin" {
                find_all_s_files(path, files)
            }
        } else if string_ends_with(entry, ".s") {
            files.push(path)
        }
    }
}

func replace_var_declarations(string content) string {
    lines := string_split(content, "\n")
    result := vec[string]()
    
    for line in lines {
        new_line := line
        trimmed := string_trim_left(line, " \t")
        
        if string_starts_with(trimmed, "var ") {
            new_line = process_var_line(line)
        }
        
        result.push(new_line)
    }
    
    string_join(result, "\n")
}

func replace_let_declarations(string content) string {
    lines := string_split(content, "\n")
    result := vec[string]()
    
    for line in lines {
        new_line := line
        trimmed := string_trim_left(line, " \t")
        
        if string_starts_with(trimmed, "let ") {
            new_line = process_let_line(line)
        }
        
        result.push(new_line)
    }
    
    string_join(result, "\n")
}

func process_var_line(string line) string {
    indent := get_indent(line)
    trimmed := string_trim_left(line, " \t")
    
    rest := string_substring(trimmed, 4, string_len(trimmed))
    
    name_and_rest := rest
    colon_pos := string_index_of(name_and_rest, ":")
    equals_pos := string_index_of(name_and_rest, "=")
    
    if equals_pos == -1 {
        return line
    }
    
    if colon_pos != -1 && colon_pos < equals_pos {
        name := string_substring(name_and_rest, 0, colon_pos)
        name = string_trim_right(name, " \t")
        rest_part := string_substring(name_and_rest, equals_pos + 1, string_len(name_and_rest))
        new_line := indent + name + " := " + string_trim_left(rest_part, " \t")
        new_line
    } else {
        name := string_substring(name_and_rest, 0, equals_pos)
        name = string_trim_right(name, " \t")
        rest_part := string_substring(name_and_rest, equals_pos + 1, string_len(name_and_rest))
        new_line := indent + name + " := " + string_trim_left(rest_part, " \t")
        new_line
    }
}

func process_let_line(string line) string {
    indent := get_indent(line)
    trimmed := string_trim_left(line, " \t")
    
    rest := string_substring(trimmed, 4, string_len(trimmed))
    
    colon_pos := string_index_of(rest, ":")
    equals_pos := string_index_of(rest, "=")
    
    if equals_pos == -1 {
        return line
    }
    
    if colon_pos != -1 && colon_pos < equals_pos {
        name := string_substring(rest, 0, colon_pos)
        name = string_trim_right(name, " \t")
        rest_part := string_substring(rest, equals_pos + 1, string_len(rest))
        new_line := indent + name + " := " + string_trim_left(rest_part, " \t")
        new_line
    } else {
        name := string_substring(rest, 0, equals_pos)
        name = string_trim_right(name, " \t")
        rest_part := string_substring(rest, equals_pos + 1, string_len(rest))
        new_line := indent + name + " := " + string_trim_left(rest_part, " \t")
        new_line
    }
}

func get_indent(string line) string {
    i := 0
    for i < string_len(line) && (string_char_at(line, i) == ' ' || string_char_at(line, i) == '\t') {
        i = i + 1
    }
    string_substring(line, 0, i)
}

func read_file_safe(string path) string {
    result := ""
    if fs_exists(path) {
        content := fs_read_to_string(path)
        result = content
    }
    result
}

func write_file_safe(string path, string content) {
    fs_write_string(path, content)
}

func count_replacements(string old, string new) int {
    old_count := count_substring_occurrences(old, "var ")
    new_count := count_substring_occurrences(new, "var ")
    var_changes := old_count - new_count
    
    old_count_let := count_substring_occurrences(old, "let ")
    new_count_let := count_substring_occurrences(new, "let ")
    let_changes := old_count_let - new_count_let
    
    var_changes + let_changes
}

func count_substring_occurrences(string text, string substring) int {
    count := 0
    pos := 0
    
    for pos < string_len(text) {
        idx := string_index_of_from(text, substring, pos)
        if idx == -1 {
            break
        }
        count = count + 1
        pos = idx + string_len(substring)
    }
    
    count
}

func count_to_string(int n) string {
    if n == 0 {
        "0"
    } else if n == 1 {
        "1"
    } else {
        result := ""
        temp := n
        for temp > 0 {
            digit := temp % 10
            result = string_from_char('0' as int + digit) + result
            temp = temp / 10
        }
        result
    }
}

func string_trim_left(string s, string chars) string {
    i := 0
    for i < string_len(s) && string_contains(chars, string_char_at(s, i)) {
        i = i + 1
    }
    string_substring(s, i, string_len(s))
}

func string_trim_right(string s, string chars) string {
    i := string_len(s) - 1
    for i >= 0 && string_contains(chars, string_char_at(s, i)) {
        i = i - 1
    }
    string_substring(s, 0, i + 1)
}

func string_contains(string s, char c) bool {
    i := 0
    for i < string_len(s) {
        if string_char_at(s, i) == c {
            return true
        }
        i = i + 1
    }
    false
}

func string_split(string s, string delimiter) vec[string] {
    result := vec[string]()
    if string_len(s) == 0 {
        return result
    }
    
    current := ""
    i := 0
    
    for i < string_len(s) {
        if i + string_len(delimiter) <= string_len(s) && string_substring(s, i, i + string_len(delimiter)) == delimiter {
            result.push(current)
            current = ""
            i = i + string_len(delimiter)
        } else {
            current = current + string_from_char(string_char_at(s, i))
            i = i + 1
        }
    }
    
    result.push(current)
    result
}

func string_join(vec[string] arr, string delimiter) string {
    if arr.len() == 0 {
        return ""
    }
    
    result := arr[0]
    i := 1
    
    for i < arr.len() {
        result = result + delimiter + arr[i]
        i = i + 1
    }
    
    result
}

func string_starts_with(string s, string prefix) bool {
    if string_len(prefix) > string_len(s) {
        return false
    }
    string_substring(s, 0, string_len(prefix)) == prefix
}

func string_ends_with(string s, string suffix) bool {
    if string_len(suffix) > string_len(s) {
        return false
    }
    string_substring(s, string_len(s) - string_len(suffix), string_len(s)) == suffix
}

func string_index_of(string s, string substring) int {
    string_index_of_from(s, substring, 0)
}

func string_index_of_from(string s, string substring, int from) int {
    if string_len(substring) == 0 {
        return from
    }
    
    i := from
    for i <= string_len(s) - string_len(substring) {
        if string_substring(s, i, i + string_len(substring)) == substring {
            return i
        }
        i = i + 1
    }
    
    -1
}

func string_substring(string s, int start, int end) string {
    if start < 0 {
        start = 0
    }
    if end > string_len(s) {
        end = string_len(s)
    }
    if start > end {
        return ""
    }
    
    result := ""
    i := start
    for i < end {
        result = result + string_from_char(string_char_at(s, i))
        i = i + 1
    }
    result
}

func string_char_at(string s, int i) char {
    (s[i]) as char
}

func string_from_char(int c) string {
    ("")
}

func string_len(string s) int {
    0
}

func fs_exists(string path) bool {
    true
}

func fs_list_dir(string path) result[vec[string], string] {
    result::ok(vec[string]())
}

func fs_is_dir(string path) bool {
    true
}

func fs_read_to_string(string path) result[string, string] {
    result::ok("")
}

func fs_write_string(string path, string content) result[void, string] {
    result::ok(void)
}
