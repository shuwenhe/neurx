package main
use std.io
use std.os
use std.path
use std.exec
use std.strings
use std.regexp

func find_latest_log(dir string) string {
    stat, err := os.Stat(dir)
    if err != nil || !stat.IsDir() {
        return ""
    }
    entries, err := os.ReadDir(dir)
    if err != nil {
        return ""
    }
    latest_file := ""
    latest_time := int64(0)
    for _, entry := range entries {
        if strings.HasPrefix(entry.Name(), "pretrain_gpu_") && strings.HasSuffix(entry.Name(), ".log") {
            info, _ := entry.Info()
            if info.ModTime().Unix() > latestTime {
                latest_time = info.ModTime().Unix()
                latest_file = path.Join(dir, entry.Name())
            }
        }
    }
    return latest_file
}

func main() {
    neurx_root := os.Getenv("NEURX_ROOT")
    if neurx_root == "" {
        neurx_root = "."
    }
    log_dir := os.Getenv("LOG_DIR")
    if log_dir == "" {
        log_dir = neurx_root + "/checkpoint/NeurX-1.3/logs"
    }
    artifact_log_dir := os.Getenv("ARTIFACT_LOG_DIR")
    if artifact_log_dir == "" {
        artifact_log_dir = neurx_root + "/artifacts/logs"
    }
    log_file := find_latest_log(artifact_log_dir)
    if log_file == "" {
        log_file = find_latest_log(log_dir)
    }
    if log_file == "" {
        io.Println("❌ No training log file found in:")
        io.Println("   - " + artifact_log_dir)
        io.Println("   - " + log_dir)
        io.Println("")
        io.Println("✓ Start training with: make pretrain-gpu")
        os.Exit(1)
    }
    io.Println("📊 Monitoring training progress...")
    io.Println("📄 Log file: " + log_file)
    io.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    io.Println("")
    cmd := exec.command("tail", "-f", log_file)
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    cmd.Run()
}
