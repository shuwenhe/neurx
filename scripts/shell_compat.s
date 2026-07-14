// neurx/scripts/shell_compat.s
// shell compatibility utilities for replacing bash scripts with S
// Provides file I/O, process management, environment access, and logging

package scripts

import (
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
    "time"
)

// ============================================================
// File System Operations
// ============================================================

// mkdir creates a directory and parent directories if needed
func mkdir(path string) error {
    err := os.MkdirAll(path, 0755)
    if err != nil {
        return fmt.Errorf("failed to create directory %s: %w", path, err)
    }
    return nil
}

// file_exists checks if a file exists
func file_exists(path string) bool {
    _, err := os.Stat(path)
    return err == nil
}

// dir_exists checks if a directory exists
func dir_exists(path string) bool {
    info, err := os.Stat(path)
    if err != nil {
        return false
    }
    return info.IsDir()
}

// remove_file removes a file
func remove_file(path string) error {
    return os.Remove(path)
}

// remove_dir removes a directory and its contents
func remove_dir(path string) error {
    return os.RemoveAll(path)
}

// read_file reads entire file contents
func read_file(path string) (string, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return "", fmt.Errorf("failed to read file %s: %w", path, err)
    }
    return string(data), nil
}

// write_file writes content to a file
func write_file(path string, content string) error {
    err := os.WriteFile(path, []byte(content), 0644)
    if err != nil {
        return fmt.Errorf("failed to write file %s: %w", path, err)
    }
    return nil
}

// append_file appends content to a file
func append_file(path string, content string) error {
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

// copy_file copies a file from source to destination
func copy_file(src string, dst string) error {
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

// list_dir lists files and directories in a path
func list_dir(path string) ([]string, error) {
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

// find_files finds files matching a pattern
func find_files(dir string, pattern string) ([]string, error) {
    var results []string
    err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
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

// ============================================================
// Process exec_commandution
// ============================================================

// exec_commandResult holds command execution results
struct exec_commandResult {
    Command string
    Stdout  string
    Stderr  string
    ExitCode int
    error   error
}

// exec_command executes a command and returns stdout, stderr, and exit code
func exec_command(cmd string, args ...string) exec_commandResult {
    command := exec.Command(cmd, args...)
    
    var stdout strings.Builder
    var stderr strings.Builder
    command.Stdout = &stdout
    command.Stderr = &stderr
    
    err := command.Run()
    exitCode := 0
    if err != nil {
        if exitErr, ok := err.(*exec.Exiterror); ok {
            exitCode = exitErr.ExitCode()
        } else {
            exitCode = 1
        }
    }
    
    return exec_commandResult{
        Command:  cmd,
        Stdout:   stdout.String(),
        Stderr:   stderr.String(),
        ExitCode: exitCode,
        error:    err,
    }
}

// exec_in_dir executes a command in a specific directory
func exec_in_dir(dir string, cmd string, args ...string) exec_commandResult {
    command := exec.Command(cmd, args...)
    command.Dir = dir
    
    var stdout strings.Builder
    var stderr strings.Builder
    command.Stdout = &stdout
    command.Stderr = &stderr
    
    err := command.Run()
    exitCode := 0
    if err != nil {
        if exitErr, ok := err.(*exec.Exiterror); ok {
            exitCode = exitErr.ExitCode()
        } else {
            exitCode = 1
        }
    }
    
    return exec_commandResult{
        Command:  cmd,
        Stdout:   stdout.String(),
        Stderr:   stderr.String(),
        ExitCode: exitCode,
        error:    err,
    }
}

// shell executes a command via shell
func shell(command string) exec_commandResult {
    cmd := exec.Command("bash", "-c", command)
    
    var stdout strings.Builder
    var stderr strings.Builder
    cmd.Stdout = &stdout
    cmd.Stderr = &stderr
    
    err := cmd.Run()
    exitCode := 0
    if err != nil {
        if exitErr, ok := err.(*exec.Exiterror); ok {
            exitCode = exitErr.ExitCode()
        } else {
            exitCode = 1
        }
    }
    
    return exec_commandResult{
        Command:  command,
        Stdout:   stdout.String(),
        Stderr:   stderr.String(),
        ExitCode: exitCode,
        error:    err,
    }
}

// command_exists checks if a command exists in PATH
func command_exists(cmd string) bool {
    _, err := exec.LookPath(cmd)
    return err == nil
}

// ============================================================
// Environment Variables
// ============================================================

// get_env gets environment variable with default value
func get_env(key string, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

// set_env sets an environment variable
func set_env(key string, value string) error {
    return os.Setenv(key, value)
}

// get_env_int gets an environment variable as integer
func get_env_int(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        if intVal, err := strconv.Atoi(value); err == nil {
            return intVal
        }
    }
    return defaultValue
}

// ============================================================
// Path Operations
// ============================================================

// abs_path converts a path to absolute
func abs_path(path string) (string, error) {
    return filepath.Abs(path)
}

// norm_path normalizes a path
func norm_path(path string) string {
    return filepath.Clean(path)
}

// join_paths joins path components
func join_paths(elem ...string) string {
    return filepath.Join(elem...)
}

// base_path returns the base name of a path
func base_path(path string) string {
    return filepath.Base(path)
}

// dir_path returns the directory of a path
func dir_path(path string) string {
    return filepath.Dir(path)
}

// ============================================================
// Logging & Output
// ============================================================

// Logger provides structured logging
struct Logger {
    prefix    string
    timestamp bool
}

// new_logger creates a new logger
func new_logger(prefix string) Logger {
    return Logger{prefix: prefix, timestamp: true}
}

// Log logs an info message
func (l Logger) log(msg string, args ...interface{}) {
    output := fmt.Sprintf("[INFO] %s: %s\n", l.prefix, fmt.Sprintf(msg, args...))
    if l.timestamp {
        output = fmt.Sprintf("[%s] %s", time.Now().Format("15:04:05"), output)
    }
    fmt.Print(output)
}

// error logs an error message
func (l Logger) error(msg string, args ...interface{}) {
    output := fmt.Sprintf("[ERROR] %s: %s\n", l.prefix, fmt.Sprintf(msg, args...))
    if l.timestamp {
        output = fmt.Sprintf("[%s] %s", time.Now().Format("15:04:05"), output)
    }
    fmt.Fprint(os.Stderr, output)
}

// warn logs a warning message
func (l Logger) warn(msg string, args ...interface{}) {
    output := fmt.Sprintf("[WARN] %s: %s\n", l.prefix, fmt.Sprintf(msg, args...))
    if l.timestamp {
        output = fmt.Sprintf("[%s] %s", time.Now().Format("15:04:05"), output)
    }
    fmt.Print(output)
}

// success logs a success message
func (l Logger) success(msg string, args ...interface{}) {
    output := fmt.Sprintf("[✓] %s: %s\n", l.prefix, fmt.Sprintf(msg, args...))
    if l.timestamp {
        output = fmt.Sprintf("[%s] %s", time.Now().Format("15:04:05"), output)
    }
    fmt.Print(output)
}

// ============================================================
// Utility Functions
// ============================================================

// sleep_seconds pauses execution for duration in seconds
func sleep_seconds(seconds float64) {
    time.Sleep(time.Duration(seconds * 1e9))
}

// timestamp returns current timestamp
func timestamp() string {
    return time.Now().Format("20060102_150405")
}

// timestamp_full returns full timestamp with date
func timestamp_full() string {
    return time.Now().Format("2006-01-02 15:04:05")
}

// contains checks if string slice contains value
func contains(slice []string, value string) bool {
    for _, item := range slice {
        if item == value {
            return true
        }
    }
    return false
}

// join joins strings with separator
func join(sep string, strs ...string) string {
    return strings.Join(strs, sep)
}

// split splits string by separator
func split(str string, sep string) []string {
    return strings.Split(str, sep)
}

// trim_text removes leading and trailing whitespace
func trim_text(str string) string {
    return strings.TrimSpace(str)
}

// to_lower converts string to lowercase
func to_lower(str string) string {
    return strings.ToLower(str)
}

// to_upper converts string to uppercase
func to_upper(str string) string {
    return strings.ToUpper(str)
}
