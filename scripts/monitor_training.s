package main
use std.io
use std.os
use std.path
use std.exec
use std.strings
use std.regexp

func findLatestLog(dir string) string {
    stat, err := os.Stat(dir)
    if err != nil || !stat.IsDir() {
        return ""
    }
    entries, err := os.ReadDir(dir)
    if err != nil {
        return ""
    }
    latestFile := ""
    latestTime := int64(0)
    for _, entry := range entries {
        if strings.HasPrefix(entry.Name(), "pretrain_gpu_") && strings.HasSuffix(entry.Name(), ".log") {
            info, _ := entry.Info()
            if info.ModTime().Unix() > latestTime {
                latestTime = info.ModTime().Unix()
                latestFile = path.Join(dir, entry.Name())
            }
        }
    }
    return latestFile
}

func main() {
    neurxRoot := os.Getenv("NEURX_ROOT")
    if neurxRoot == "" {
        neurxRoot = "."
    }
    logDir := os.Getenv("LOG_DIR")
    if logDir == "" {
        logDir = neurxRoot + "/checkpoint/NeurX-1.3/logs"
    }
    artifactLogDir := os.Getenv("ARTIFACT_LOG_DIR")
    if artifactLogDir == "" {
        artifactLogDir = neurxRoot + "/artifacts/logs"
    }
    logFile := findLatestLog(artifactLogDir)
    if logFile == "" {
        logFile = findLatestLog(logDir)
    }
    if logFile == "" {
        io.Println("❌ No training log file found in:")
        io.Println("   - " + artifactLogDir)
        io.Println("   - " + logDir)
        io.Println("")
        io.Println("✓ Start training with: make pretrain-gpu")
        os.Exit(1)
    }
    io.Println("📊 Monitoring training progress...")
    io.Println("📄 Log file: " + logFile)
    io.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    io.Println("")
    cmd := exec.command("tail", "-f", logFile)
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    cmd.Run()
}
