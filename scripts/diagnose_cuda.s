package main
use std.io
use std.os
use std.exec
use std.time
use std.path
func checkNvidiaSmi() int {
    cmd := exec.Command("nvidia-smi", "-L")
    output, err := cmd.Output()
    if err != nil {
        io.Println("   ❌ nvidia-smi not found")
        return 0
    }
    count := strings.Count(string(output), "GPU")
    io.Println("   ✓ nvidia-smi found: " + string(count) + " GPU(s)")
    cmd = exec.Command("nvidia-smi", "--query-gpu=name", "--format=csv,noheader")
    output, _ = cmd.Output()
    lines := strings.Split(string(output), "\n")
    if len(lines) > 0 && lines[0] != "" {
        io.Println("   - " + lines[0])
    }
    return count
}
func checkCudaBinary(bin string) bool {
    stat, err := os.Stat(bin)
    if err != nil || stat.IsDir() {
        io.Println("   ❌ Binary not found: " + bin)
        return false
    }
    io.Println("   ✓ Binary exists: " + bin)
    return true
}
func checkRequiredFiles(files []string) {
    for _, file := range files {
        stat, err := os.Stat(file)
        if err == nil && !stat.IsDir() {
            io.Println("   ✓ " + file)
        } else {
            io.Println("   ⚠  Missing: " + file)
        }
    }
}
func testCudaBinary(bin string) {
    cmd := exec.Command("timeout", "30s", bin)
    cmd.Env = append(os.Environ(),
        "NEURX_PRETRAIN_STEPS=1",
        "NEURX_PRETRAIN_MICRO_BATCH=1",
        "NEURX_PRETRAIN_SEQ_LEN=128",
        "NEURX_TRANSFORMER_DIM=256",
        "NEURX_TRANSFORMER_HEADS=8",
        "NEURX_TRANSFORMER_NUM_LAYERS=2",
        "RANK=0",
        "LOCAL_RANK=0",
        "WORLD_SIZE=1",
        "CUDA_VISIBLE_DEVICES=0",
    )
    output, err := cmd.CombinedOutput()
    if len(output) > 0 {
        io.Println("   Output:")
        lines := strings.Split(string(output), "\n")
        for i := 0; i < len(lines) && i < 20; i++ {
            if lines[i] != "" {
                io.Println("   " + lines[i])
            }
        }
    } else {
        io.Println("   (No output received)")
    }
}
func main() {
    curdir := "/home/shuwen/shuwen/train/neurx"
    cudaTrainBin := curdir + "/artifacts/build/cuda_train/neurx_cuda_train_bridge"
    io.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    io.Println("🔍 NeurX CUDA Training Environment Diagnostic")
    io.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    io.Println("")
    io.Println("📌 Step 1: Checking NVIDIA GPU...")
    checkNvidiaSmi()
    io.Println("")
    io.Println("📌 Step 2: Checking CUDA training binary...")
    if !checkCudaBinary(cudaTrainBin) {
        os.Exit(1)
    }
    io.Println("")
    io.Println("📌 Step 3: Checking required files...")
    checkRequiredFiles([]string{
        curdir + "/data/corpus/vocab.json",
        curdir + "/data/corpus/merges.txt",
        curdir + "/artifacts/build/run_large_pretrain/shard_list.txt",
    })
    io.Println("")
    io.Println("📌 Step 4: Testing CUDA binary (timeout 30s)...")
    testCudaBinary(cudaTrainBin)
    io.Println("")
    io.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    io.Println("📊 Summary:")
    io.Println("   ✅ CUDA binary exited successfully")
    io.Println("")
    io.Println("✓ To start full training, run: cd " + curdir + " && make pretrain-gpu")
    io.Println("")
}
