package main
use neurx.runtime.io.{runtime_run_command_output, runtime_read_text_file, runtime_write_text_file}

func string_char(int c) string {
    string(c)
}

func split_lines(string s) []string {
    int capacity = 1
    int j = 0
    while j < len(s) {
        if s[j] == 10 {
            capacity = capacity + 1
        }
        j = j + 1
    }
    []string out = []string{cap: capacity}
    string line = ""
    int idx = 0
    int i = 0
    while i < len(s) {
        if s[i] == 10 || s[i] == 13 {
            if len(line) > 0 {
                out[idx] = line
                idx = idx + 1
                line = ""
            }
            i = i + 1
            continue
        }
        line = line + string_char(s[i])
        i = i + 1
    }
    if len(line) > 0 {
        out[idx] = line
    }
    out
}

func strip_comments(string text) string {
    string out = ""
    int i = 0
    int n = len(text)
    bool in_sq = false
    bool in_dq = false
    bool in_line = false
    bool in_block = false
    bool escape = false
    while i < n {
        int c = text[i]
        int nc = -1
        if i + 1 < n {
            nc = text[i+1]
        }
        if in_line {
            if c == 10 {
                in_line = false
                out = out + string_char(c)
            }
        } else if in_block {
            if c == 42 && nc == 47 {
                in_block = false
                i = i + 1
            }
        } else if in_sq {
            out = out + string_char(c)
            if !escape && c == 39 {
                in_sq = false
            }
            escape = (c == 92 && !escape)
        } else if in_dq {
            out = out + string_char(c)
            if !escape && c == 34 {
                in_dq = false
            }
            escape = (c == 92 && !escape)
        } else {
            if c == 47 && nc == 47 {
                in_line = true
                i = i + 1
            } else if c == 47 && nc == 42 {
                in_block = true
                i = i + 1
            } else if c == 39 {
                in_sq = true
                out = out + string_char(c)
                escape = false
            } else if c == 34 {
                in_dq = true
                out = out + string_char(c)
                escape = false
            } else {
                out = out + string_char(c)
            }
        }
        i = i + 1
    }
    out
}

func main() int {
    string root_find = "."
    string find_cmd = "find " + root_find + " -type f -name '*.s' -not -path '*/.git/*' -not -path './artifacts/*'"
    string list_text = runtime_run_command_output(find_cmd)
    if trim(list_text) == "" {
        println("No .s files found")
        return 0
    }
    []string files = split_lines(list_text)
    int i = 0
    int modified = 0
    while i < len(files) {
        string path = trim(files[i])
        if path == "" {
            i = i + 1
            continue
        }
        string content = runtime_read_text_file(path)
        string new = strip_comments(content)
        if new != content {
            runtime_write_text_file(path, new)
            println("Stripped comments: " + path)
            modified = modified + 1
        }
        i = i + 1
    }
    println("Done. Modified files.")
    0
}
