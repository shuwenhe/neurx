package main
use neurx.runtime.io.{runtime_run_command_output, runtime_read_text_file, runtime_write_text_file, trim}
func string_char(int c) string {
    string(c)
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

func main() {
    string root_find = "."
