package main
import (
  "os"
  "io/ioutil"
  "strings"
  "path/filepath"
)
func remove_comments(content string) string {
  lines := strings.Split(content, "\n")
  result := []string{}
  in_block_comment := false
  for _, line := range lines {
    if in_block_comment {
      if strings.Contains(line, "*/") {
        idx := strings.Index(line, "*/")
        line = line[idx+2:]
        in_block_comment = false
      } else {
        continue
      }
    }
        end_idx := strings.Index(line[idx:], "*/")
        line = line[:idx] + line[idx+end_idx+2:]
      } else {
        line = line[:idx]
        in_block_comment = true
        break
      }
    }
    if idx := strings.Index(line, "
      line = line[:idx]
    }
    trimmed := strings.TrimRight(line, " \t")
    if trimmed != "" || len(result) == 0 {
      result = append(result, line)
    }
  }
  return strings.Join(result, "\n")
}

func ProcessFile(filepath string) error {
  content, err := ioutil.ReadFile(filepath)
  if err != nil {
    return err
  }
  cleanContent := RemoveComments(string(content))
  err = ioutil.WriteFile(filepath, []byte(cleanContent), 0644)
  if err != nil {
    return err
  }
  return nil
}

func GetFilesWithComments(rootDir string) []string {
  var files []string
  filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
    if err != nil {
      return err
    }
    if !info.IsDir() && strings.HasSuffix(path, ".s") {
      content, err := ioutil.ReadFile(path)
      if err != nil {
        return nil
      }
      contentStr := string(content)
      if strings.Contains(contentStr, "
        files = append(files, path)
      }
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
  println("Found", len(files), "files with comments")
  for _, file := range files {
    err := process_file(file)
    if err != nil {
      println("Error processing", file, ":", err.Error())
    } else {
      println("Processed:", file)
    }
  }
  println("Done! All comments removed.")
}
