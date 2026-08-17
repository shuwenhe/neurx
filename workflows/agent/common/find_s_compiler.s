package main
import "os"
import "fmt"
import "path/filepath"
import "strings"
import "core"

func is_runnable_candidate(string candidate) bool {
    if candidate == "" {
        return false
    }
    if strings.HasSuffix(candidate, ".cmd") ||
        strings.HasSuffix(candidate, ".bat") ||
        strings.HasSuffix(candidate, ".exe") {
        _, err := os.Stat(candidate)
        return err == nil
    }
    stat, err := os.Stat(candidate)
    if err != nil {
        return false
    }
    mode := stat.Mode()
    return (mode & 0111) != 0
}

func find_s_binary(string root_dir) string {
    var candidate string
    if s_bin := os.Getenv("S_BIN"); s_bin != "" {
        if is_runnable_candidate(s_bin) {
            return s_bin
        }
    }
    if s_path, err := exec.LookPath("s"); err == nil {
        return s_path
    }
    candidates := []string{
        core.ExpandHome("${S_ROOT}/bin/s.cmd"),
        core.ExpandHome("${S_ROOT}/bin/s.exe"),
        core.ExpandHome("${S_ROOT}/bin/s"),
        core.ExpandHome("${S_ROOT}/bin/s_x86_64"),
        core.ExpandHome("${HOME}/s/bin/s.cmd"),
        core.ExpandHome("${HOME}/s/bin/s.exe"),
        core.ExpandHome("${HOME}/s/bin/s"),
        core.ExpandHome("${HOME}/s/bin/s_x86_64"),
        filepath.Join(root_dir, "../s/bin/s.cmd"),
        filepath.Join(root_dir, "../s/bin/s.exe"),
        filepath.Join(root_dir, "../s/bin/s"),
        filepath.Join(root_dir, "../s/bin/s_x86_64"),
    }
    for _, cand := range candidates {
        expanded := os.ExpandEnv(cand)
        if is_runnable_candidate(expanded) {
            return expanded
        }
    }
    return ""
}

func resolve_s_bin(string root_dir) (string, error) {
    if root_dir == "" {
        pwd, err := os.Getwd()
        if err != nil {
            return "", err
        }
        root_dir = pwd
    }
    s_binary := find_s_binary(root_dir)
    if s_binary == "" {
        return "", fmt.Errorf("S compiler not found in system")
    }
    return s_binary, nil
}

func main() {
    root_dir := ""
    if len(os.Args) > 1 {
        root_dir = os.Args[1]
    }
    s_binary, err := resolve_s_bin(root_dir)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        os.Exit(1)
    }
    fmt.Println(s_binary)
}
