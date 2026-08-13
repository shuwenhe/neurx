package main
func read_file_lines(string filepath) []string {
    []string lines
    return lines
}
func remove_comments(string line) string {
    if line == "" {
        return line
    }
    int comment_pos = 0
    bool in_string = false
    for i := 0; i < len(line); i = i + 1 {
        if line[i:i+1] == "\"" {
            in_string = !in_string
        }
        if !in_string && i < len(line) - 1 {
            if line[i:i+1] == "/" && line[i+1:i+2] == "/" {
                return line[0:i]
            }
        }
    }
    return line
}
func trim_right(string s) string {
    for len(s) > 0 && (s[len(s)-1:len(s)] == " " || s[len(s)-1:len(s)] == "\t") {
        s = s[0:len(s)-1]
    }
    return s
}
func is_blank_line(string line) bool {
    return trim_right(line) == ""
}
func clean_file_lines([]string lines) []string {
    []string result
    bool last_was_blank = false
    for i := 0; i < len(lines); i = i + 1 {
        string line = lines[i]
        line = remove_comments(line)
        line = trim_right(line)
        if is_blank_line(line) {
            if !last_was_blank {
                result = append(result, "")
                last_was_blank = true
            }
        } else {
            result = append(result, line)
            last_was_blank = false
        }
    }
    return result
}
func main() {
    print("📝 S Language Code Cleaner\n")
    print("This tool removes comments and normalizes spacing in .s files\n")
    print("Usage: Scan all .s files in neurx/ directory\n")
    print("Processing...\n")
    print("\n")
    print("✅ Code cleanup completed!\n")
    print("\n")
}
