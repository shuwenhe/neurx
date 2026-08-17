package scripts
import (
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
    "time"
)

func mkdir(string path) error {
    err := os.MkdirAll(path, 0755)
    if err != nil {
        return fmt.Errorf("failed to create directory %s: %w", path, err)
    }
    return nil
}

func file_exists(string path) bool {
    _, err := os.Stat(path)
    return err == nil
}

func dir_exists(string path) bool {
    info, err := os.Stat(path)
    if err != nil {
        return false
    }
    return info.IsDir()
}

func remove_file(string path) error {
    return os.Remove(path)
}

func remove_dir(string path) error {
    return os.RemoveAll(path)
}

func read_file(string path) (string, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return "", fmt.Errorf("failed to read file %s: %w", path, err)
    }
    return string(data), nil
}

func write_file(string path, string content) error {
    err := os.WriteFile(path, []byte(content), 0644)
    if err != nil {
        return fmt.Errorf("failed to write file %s: %w", path, err)
    }
    return nil
}

func append_file(string path, string content) error {
    file, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
    if err != nil {
        return fmt.Errorf("failed to open file %s: %w", path, err)
    }
    defer file.Close()
    _, err = file.WriteString(content)
    if err != nil {
        return fmt.Errorf("failed to write to file %s: %w", path, err)
    }
    return nil
}

func copy_file(string src, string dst) error {
    data, err := os.ReadFile(src)
    if err != nil {
        return fmt.Errorf("failed to read source %s: %w", src, err)
    }
    err = os.WriteFile(dst, data, 0644)
    if err != nil {
        return fmt.Errorf("failed to write destination %s: %w", dst, err)
    }
    return nil
}

func list_dir(string path) ([]string, error) {
    entries, err := os.ReadDir(path)
    if err != nil {
        return []string{}, fmt.Errorf("failed to list directory %s: %w", path, err)
    }
    var results []string
    for _, entry := range entries {
        results = append(results, entry.Name())
    }
    return results, nil
}

func find_files(string dir, string pattern) ([]string, error) {
    var results []string
    err := filepath.Walk(dir, func(path string, info os.file_info, err error) error {
        if err != nil {
            return err
        }
        if !info.IsDir() {
            matched, _ := filepath.Match(pattern, filepath.Base(path))
            if matched {
                results = append(results, path)
            }
        }
        return nil
    })
    return results, err
}

struct exec_command_result {
    command string
    stdout  string
    stderr  string
    exit_code int
    error   error
}

func exec_command(string cmd, args ...string) exec_command_result {
    command := exec.command(cmd, args...)
    var stdout strings.Builder
    var stderr strings.Builder
    command.Stdout = &stdout
    command.Stderr = &stderr
    err := command.Run()
    exit_code := 0
    if err != nil {
        if exit_err, ok := err.(*exec.Exiterror); ok {
            exit_code = exit_err.ExitCode()
        } else {
            exit_code = 1
        }
    }
    return exec_command_result{
        command:  cmd,
        stdout:   stdout.String(),
        stderr:   stderr.String(),
        exit_code: exitCode,
        error:    err,
    }
}

func exec_in_dir(string dir, string cmd, args ...string) exec_command_result {
    command := exec.command(cmd, args...)
    command.Dir = dir
    var stdout strings.Builder
    var stderr strings.Builder
    command.Stdout = &stdout
    command.Stderr = &stderr
    err := command.Run()
    exit_code := 0
    if err != nil {
        if exit_err, ok := err.(*exec.Exiterror); ok {
            exit_code = exit_err.ExitCode()
        } else {
            exit_code = 1
        }
    }
    return exec_command_result{
        command:  cmd,
        stdout:   stdout.String(),
        stderr:   stderr.String(),
        exit_code: exitCode,
        error:    err,
    }
}

func shell(string command) exec_command_result {
    cmd := exec.command("bash", "-c", command)
    var stdout strings.Builder
    var stderr strings.Builder
    cmd.Stdout = &stdout
    cmd.Stderr = &stderr
    err := cmd.Run()
    exit_code := 0
    if err != nil {
        if exit_err, ok := err.(*exec.Exiterror); ok {
            exit_code = exit_err.ExitCode()
        } else {
            exit_code = 1
        }
    }
    return exec_command_result{
        command:  command,
        stdout:   stdout.String(),
        stderr:   stderr.String(),
        exit_code: exitCode,
        error:    err,
    }
}

func command_exists(string cmd) bool {
    _, err := exec.LookPath(cmd)
    return err == nil
}

func get_env(string key, string default_value) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return default_value
}

func set_env(string key, string value) error {
    return os.Setenv(key, value)
}

func get_env_int(string key, int default_value) int {
    if value := os.Getenv(key); value != "" {
        if int_val, err := strconv.Atoi(value); err == nil {
            return int_val
        }
    }
    return default_value
}

func abs_path(string path) (string, error) {
    return filepath.Abs(path)
}

func norm_path(string path) string {
    return filepath.Clean(path)
}

func join_paths(elem ...string) string {
    return filepath.Join(elem...)
}

func base_path(string path) string {
    return filepath.Base(path)
}

func dir_path(string path) string {
    return filepath.Dir(path)
}

struct logger_2 {
    prefix    string
    timestamp bool
}

func new_logger(string prefix) logger_2 {
    return logger_2{prefix: prefix, timestamp: true}
}

func (string l logger_2) log(msg, args ...interface{}) {
    output := fmt.Sprintf("[INFO] %s: %s\n", l.prefix, fmt.Sprintf(msg, args...))
    if l.timestamp {
        output = fmt.Sprintf("[%s] %s", time.Now().Format("15:04:05"), output)
    }
    fmt.Print(output)
}

func (string l logger_2) error(msg, args ...interface{}) {
    output := fmt.Sprintf("[ERROR] %s: %s\n", l.prefix, fmt.Sprintf(msg, args...))
    if l.timestamp {
        output = fmt.Sprintf("[%s] %s", time.Now().Format("15:04:05"), output)
    }
    fmt.Fprint(os.Stderr, output)
}

func (string l logger_2) warn(msg, args ...interface{}) {
    output := fmt.Sprintf("[WARN] %s: %s\n", l.prefix, fmt.Sprintf(msg, args...))
    if l.timestamp {
        output = fmt.Sprintf("[%s] %s", time.Now().Format("15:04:05"), output)
    }
    fmt.Print(output)
}

func (string l logger_2) success(msg, args ...interface{}) {
    output := fmt.Sprintf("[✓] %s: %s\n", l.prefix, fmt.Sprintf(msg, args...))
    if l.timestamp {
        output = fmt.Sprintf("[%s] %s", time.Now().Format("15:04:05"), output)
    }
    fmt.Print(output)
}

func sleep_seconds(seconds float64) {
    time.Sleep(time.Duration(seconds * 1e9))
}

func timestamp() string {
    return time.Now().Format("20060102_150405")
}

func timestamp_full() string {
    return time.Now().Format("2006-01-02 15:04:05")
}

func contains([]string slice, string value) bool {
    for _, item := range slice {
        if item == value {
            return true
        }
    }
    return false
}

func join(string sep, strs ...string) string {
    return strings.Join(strs, sep)
}

func split(string str, string sep) []string {
    return strings.Split(str, sep)
}

func trim_text(string str) string {
    return strings.TrimSpace(str)
}

func to_lower(string str) string {
    return strings.ToLower(str)
}

func to_upper(string str) string {
    return strings.ToUpper(str)
}
