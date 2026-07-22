

package main

import "os"
import "fmt"
import "path/filepath"
import "strings"
import "core"

func isRunnableCandidate(candidate string) bool {
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

func findSBinary(rootDir string) string {
    var candidate string

    if sBin := os.Getenv("S_BIN"); sBin != "" {
        if isRunnableCandidate(sBin) {
            return sBin
        }
    }

    if sPath, err := exec.LookPath("s"); err == nil {
        return sPath
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
        filepath.Join(rootDir, "../s/bin/s.cmd"),
        filepath.Join(rootDir, "../s/bin/s.exe"),
        filepath.Join(rootDir, "../s/bin/s"),
        filepath.Join(rootDir, "../s/bin/s_x86_64"),
    }

    for _, cand := range candidates {
        expanded := os.ExpandEnv(cand)
        if isRunnableCandidate(expanded) {
            return expanded
        }
    }

    return ""
}

func ResolveSBin(rootDir string) (string, error) {
    if rootDir == "" {
        pwd, err := os.Getwd()
        if err != nil {
            return "", err
        }
        rootDir = pwd
    }

    sBinary := findSBinary(rootDir)
    if sBinary == "" {
        return "", fmt.Errorf("S compiler not found in system")
    }

    return sBinary, nil
}

func main() {
    rootDir := ""
    if len(os.Args) > 1 {
        rootDir = os.Args[1]
    }

    sBinary, err := ResolveSBin(rootDir)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        os.Exit(1)
    }

    fmt.Println(sBinary)
}
