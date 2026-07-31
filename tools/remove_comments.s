package main
import (
  "os"
  "io/ioutil"
  "strings"
  "path/filepath"
)
func RemoveComments(content string) string {
  lines := strings.Split(content, "\n")
  result := []string{}
  inBlockComment := false
  for _, line := range lines {
    if inBlockComment {
      if strings.Contains(line, "*/") {
        idx := strings.Index(line, "*/")
        line = line[idx+2:]
        inBlockComment = false
      } else {
        continue
      }
    }
    for strings.Contains(line, "/*") {
      idx := strings.Index(line, "/*")
      if strings.Contains(line[idx:], "*/") {
        endIdx := strings.Index(line[idx:], "*/")
        line = line[:idx] + line[idx+endIdx+2:]
      } else {
        line = line[:idx]
        inBlockComment = true
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
  rootDir := "."
  if len(os.Args) > 1 {
    rootDir = os.Args[1]
  }
  files := GetFilesWithComments(rootDir)
  println("Found", len(files), "files with comments")
  for _, file := range files {
    err := ProcessFile(file)
    if err != nil {
      println("Error processing", file, ":", err.Error())
    } else {
      println("Processed:", file)
    }
  }
  println("Done! All comments removed.")
}
