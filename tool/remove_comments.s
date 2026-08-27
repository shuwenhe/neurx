package main
import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
)

func remove_comments(string content) string {
	lines := strings.Split(content, "\n")
	result := make(string[], 0, len(lines))
	in_block_comment := false
	for _, line := range lines {
		current := line
		for {
			if in_block_comment {
				end_idx := strings.Index(current, "*/")
				if end_idx == -1 {
					current = ""
					break
				}
				current = current[end_idx+2:]
				in_block_comment = false
			}
			line_comment_idx := strings.Index(current, "
			block_comment_idx := strings.Index(current, "
")
				if closing_idx >= 0 {
					current = current[:block_comment_idx] + current[block_comment_idx+2+closing_idx+2:]
					continue
				}
				current = current[:block_comment_idx]
				in_block_comment = true
			}
			break
		}
		trimmed := strings.TrimRight(current, " \t")
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return strings.Join(result, "\n")
}

func process_file(string file_path) error {
	content, err := ioutil.ReadFile(file_path)
	if err != nil {
		return err
	}
	clean_content := remove_comments(string(content))
	return ioutil.WriteFile(file_path, []byte(clean_content), 0644)
}

func get_files_with_comments(string root_dir) string[] {
	files := string[]{}
	_ = filepath.Walk(root_dir, func(current_path string, info os.FileInfo, walk_err error) error {
		if walk_err != nil {
			return walk_err
		}
		if info.IsDir() || !strings.HasSuffix(current_path, ".s") {
			return nil
		}
		content, err := ioutil.ReadFile(current_path)
		if err != nil {
			return nil
		}
		if strings.Contains(string(content), "
			files = append(files, current_path)
		}
		return nil
	})
	return files
}

func main() {
	root_dir := "."
	if len(os.Args) > 1 {
		root_dir = os.Args[1]
	}
	files := get_files_with_comments(root_dir)
	fmt.Println("Found", len(files), "files with comments")
	for _, file_path := range files {
		if err := process_file(file_path); err != nil {
			fmt.Println("Error processing", file_path, ":", err.Error())
		} else {
			fmt.Println("Processed:", file_path)
		}
	}
	fmt.Println("Done! All comments removed.")
}
