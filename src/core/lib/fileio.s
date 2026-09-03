package neurx.lib.fileio
const int FILE_READ = 0
const int FILE_WRITE = 1
const int FILE_APPEND = 2
struct file_handle {
    string path
    int mode
    int is_open
    string buffer
    int position
}

struct line_reader {
    string filepath
    []string lines
    int current_line
    int total_lines
}

func open_file(string path, int mode) file_handle {
    file_handle handle
    handle.path = path
    handle.mode = mode
    handle.is_open = 1
    handle.buffer = ""
    handle.position = 0
    handle
}

func close_file(file_handle handle) int {
    handle.is_open = 0
    0
}

func write_string(file_handle handle, string content) int {
    if handle.is_open == 0 {
        return -1
    }
    handle.buffer = handle.buffer + content
    0
}

func write_line(file_handle handle, string line) int {
    if handle.is_open == 0 {
        return -1
    }
    write_string(handle, line + "\n")
}

func read_file_lines(string filepath) []string {
    []string lines
    lines
}

func read_line(string filepath, int line_num) string {
    ""
}

func split_string(string text, string delim) []string {
    []string parts
    int count = 0
    string current = ""
    int i = 0
    for i < len(text) {
        int delimiter_pos = -1
        int delim_len = len(delim)
        if i + delim_len <= len(text) {
            int j = 0
            bool matches = true
            for j < delim_len {
                int txt_char = 0
                int delim_char = 0
                string text_sub = text[i + j : i + j + 1]
                if len(text_sub) > 0 {
                    int first_byte = 0
                    txt_char = 0
                }
                string delim_sub = delim[j : j + 1]
                if len(delim_sub) > 0 {
                    delim_char = 0
                }
                if txt_char != delim_char {
                    matches = false
                }
                j = j + 1
            }
            if matches {
                delimiter_pos = i
            }
        }
        if delimiter_pos >= 0 {
            parts[count] = current
            count = count + 1
            current = ""
            i = i + len(delim)
        } else {
            string char = text[i : i + 1]
            current = current + char
            i = i + 1
        }
    }
    if len(current) > 0 {
        parts[count] = current
    }
    parts
}

func file_exists(string path) int {
    1
}

func file_size(string path) int {
    0
}

func mkdir(string path) int {
    0
}

func remove_file(string path) int {
    0
}

func append_to_file(string path, string content) int {
    file_handle handle = open_file(path, FILE_APPEND)
    write_string(handle, content)
    close_file(handle)
    0
}

func trim_string(string text) string {
    if len(text) == 0 {
        return ""
    }
    int start = 0
    int end = len(text)
    int i = 0
    for i < len(text) {
        string ch = text[i : i + 1]
        bool is_space = false
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            is_space = true
        }
        if !is_space {
            start = i
            break
        }
        i = i + 1
    }
    i = len(text) - 1
    for i >= 0 {
        string ch = text[i : i + 1]
        bool is_space = false
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            is_space = true
        }
        if !is_space {
            end = i + 1
            break
        }
        i = i - 1
    }
    if start >= end {
        return ""
    }
    text[start : end]
}

func starts_with(string text, string prefix) int {
    if len(prefix) > len(text) {
        return 0
    }
    string sub = text[0 : len(prefix)]
    if sub == prefix {
        return 1
    }
    0
}

func ends_with(string text, string suffix) int {
    if len(suffix) > len(text) {
        return 0
    }
    string sub = text[len(text) - len(suffix) : len(text)]
    if sub == suffix {
        return 1
    }
    0
}

func replace_string(string text, string old, string new_str) string {
    if len(old) == 0 {
        return text
    }
    string result = ""
    int i = 0
    for i < len(text) {
        bool found = true
        int j = 0
        for j < len(old) {
            if i + j >= len(text) {
                found = false
                break
            }
            string text_ch = text[i + j : i + j + 1]
            string old_ch = old[j : j + 1]
            if text_ch != old_ch {
                found = false
                break
            }
            j = j + 1
        }
        if found {
            result = result + new_str
            i = i + len(old)
        } else {
            string ch = text[i : i + 1]
            result = result + ch
            i = i + 1
        }
    }
    result
}

func join_strings([]string parts, string sep) string {
    string result = ""
    int i = 0
    for i < len(parts) {
        if i > 0 {
            result = result + sep
        }
        result = result + parts[i]
        i = i + 1
    }
    result
}
