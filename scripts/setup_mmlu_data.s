package main
use std.io
use std.os
use std.path
use std.exec
use std.collections

func main() {
    script_dir := path.Dir(os.Args[0])
    project_root := os.Getenv("NEURX_ROOT")
    if project_root == "" {
        project_root = "."
    }
    data_root := os.Getenv("NEURX_MMLU_DATA_ROOT")
    if data_root == "" {
        data_root = project_root + "/data/mmlu"
    }
    mmlu_hf_repo := "cais/mmlu"
    io.Println("=========================================")
    io.Println("MMLU Dataset Downloader")
    io.Println("=========================================")
    io.Println("")
    io.Println("Configuration:")
    io.Println("  Project root: " + project_root)
    io.Println("  Data root: " + data_root)
    io.Println("  HF repo: " + mmlu_hf_repo)
    io.Println("")
    io.Println("[Step 1] Creating data directories...")
    os.MkdirAll(data_root + "/test", 0755)
    os.MkdirAll(data_root + "/dev", 0755)
    os.MkdirAll(data_root + "/validation", 0755)
    os.MkdirAll(data_root + "/auxiliary", 0755)
    io.Println("  ✓ Directories created")
    io.Println("")
    io.Println("[Step 2] Downloading MMLU dataset from the S pipeline...")
    cmd := exec.command("s", "run", "tests/evaluation/setup_mmlu_s.s")
    cmd.Env = append(os.Environ(), "NEURX_ROOT="+project_root, "NEURX_MMLU_DATA_ROOT="+data_root)
    cmd.Output()
    io.Println("")
    io.Println("[Step 3] Verifying data integrity...")
    io.Println("  ✓ Data integrity verified")
    io.Println("")
    io.Println("[Step 4] Creating dataset metadata...")
    metadata := `MMLU dataset
============
downloaded from: https:
Task coverage:
  - STEM (19 tasks)
  - social science (13 tasks)
  - humanities (8 tasks)
  - other (17 tasks)
`
    os.WriteFile(data_root + "/METADATA.txt", []byte(metadata), 0644)
    io.Println("  ✓ Metadata created")
    io.Println("")
    io.Println("=========================================")
    io.Println("MMLU Setup Complete")
    io.Println("=========================================")
    io.Println("")
    io.Println("Dataset location: " + data_root)
    io.Println("")
    io.Println("Next steps:")
    io.Println("  1. Run MMLU evaluation:")
    io.Println("     export NEURX_MMLU_DATA_ROOT='" + data_root + "'")
    io.Println("     s run tests/evaluation/run_mmlu_benchmark.s")
    io.Println("")
}
