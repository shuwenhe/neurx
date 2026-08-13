import os
import io
import strings
import path
import sys
func remove_line_comments(string line) string {
	idx := strings.index(line, "
	if idx != -1 {
		return strings.substring(line, 0, idx)
	}
	return line
}
func remove_comments(string content) string {
	lines := strings.split(content, "\n")
	result := []string{}
	in_multiline := false
	for i := 0; i < len(lines); i += 1 {
		line := lines[i]
		if in_multiline {
			idx := strings.index(line, "*/")
			if idx != -1 {
				line = strings.substring(line, idx + 2, len(line))
				in_multiline = false
			} else {
				continue
			}
		}
		idx := strings.index(line, "
")
			if end != -1 {
				line = before + strings.substring(rest, end + 2, len(rest))
			} else {
				line = before
				in_multiline = true
			}
		}
		line = remove_line_comments(line)
		result = result + [line]
	}
	return strings.join(result, "\n")
}
func remove_extra_blank_lines(string content) string {
	lines := strings.split(content, "\n")
	result := []string{}
	blank_count := 0
	for i := 0; i < len(lines); i += 1 {
		line := lines[i]
		trimmed := strings.trim(line)
		if trimmed == "" {
			blank_count += 1
			if blank_count <= 1 {
				result = result + [""]
			}
		} else {
			blank_count = 0
			result = result + [line]
		}
	}
	return strings.join(result, "\n")
}
func ensure_spacing(string content) string {
	lines := strings.split(content, "\n")
	result := []string{}
	for i := 0; i < len(lines); i += 1 {
		line := lines[i]
		result = result + [line]
		if i < len(lines) - 1 {
			trimmed := strings.trim(line)
			next_trimmed := strings.trim(lines[i + 1])
			is_func := strings.has_prefix(trimmed, "func ") && strings.has_suffix(trimmed, "{")
			is_struct := strings.has_prefix(trimmed, "struct ") && strings.has_suffix(trimmed, "{")
			next_is_decl := (strings.has_prefix(next_trimmed, "func ") || strings.has_prefix(next_trimmed, "struct ")) && next_trimmed != ""
			if (is_func || is_struct) && next_is_decl {
				if i + 2 < len(lines) && strings.trim(lines[i + 1]) != "" {
					result = result + [""]
				}
			}
		}
	}
	content = strings.join(result, "\n")
	return remove_extra_blank_lines(content)
}
func clean_file(string fpath) {
	content := io.read_file(fpath)
	content = remove_comments(content)
	content = remove_extra_blank_lines(content)
	content = ensure_spacing(content)
	content = strings.trim_right(content, " \t\n") + "\n"
	io.write_file(fpath, content, 0644)
}
func walk_dir(string dir) {
	entries := os.list_dir(dir)
	for i := 0; i < len(entries); i += 1 {
		entry := entries[i]
		full_path := path.join(dir, entry)
		if os.is_dir(full_path) {
			if entry != ".git" {
				walk_dir(full_path)
			}
		} else if strings.has_suffix(entry, ".s") {
			sys.println("Cleaning: " + full_path)
			clean_file(full_path)
		}
	}
}
func main() {
	if len(sys.argv) < 2 {
		sys.println("Usage: cleanup_code <directory>")
		sys.exit(1)
	}
	dir := sys.argv[1]
	walk_dir(dir)
	sys.println("Code cleanup completed successfully!")
}
