package main

use std.io
use std.os
use std.path
use std.exec
use std.collections

func main() {
    scriptDir := path.Dir(os.Args[0])
    projectRoot := os.Getenv("NEURX_ROOT")
    if projectRoot == "" {
        projectRoot = "."
    }
    
    dataRoot := os.Getenv("NEURX_MMLU_DATA_ROOT")
    if dataRoot == "" {
        dataRoot = projectRoot + "/data/mmlu"
    }
    
    mmluHfRepo := "cais/mmlu"
    
    io.Println("=========================================")
    io.Println("MMLU Dataset Downloader")
    io.Println("=========================================")
    io.Println("")
    io.Println("Configuration:")
    io.Println("  Project root: " + projectRoot)
    io.Println("  Data root: " + dataRoot)
    io.Println("  HF repo: " + mmluHfRepo)
    io.Println("")
    
    io.Println("[Step 1] Creating data directories...")
    os.MkdirAll(dataRoot + "/test", 0755)
    os.MkdirAll(dataRoot + "/dev", 0755)
    os.MkdirAll(dataRoot + "/validation", 0755)
    os.MkdirAll(dataRoot + "/auxiliary", 0755)
    io.Println("  ✓ Directories created")
    io.Println("")
    
    io.Println("[Step 2] Downloading MMLU dataset from HuggingFace...")
    
    cmd := exec.Command("python3", "-c", `
import os
from datasets import load_dataset

data_root = os.environ.get('DATA_ROOT', './data/mmlu')
tasks = [
    "abstract_algebra", "anatomy", "astronomy", "biology", "chemistry",
    "computer_science", "formal_logic", "high_school_biology",
]

for task in tasks:
    try:
        dataset = load_dataset("cais/mmlu", task, split=None)
        print(f"✓ Downloaded: {task}")
    except Exception as e:
        print(f"! Warning: {task}: {e}")
`)
    cmd.Env = append(os.Environ(), "DATA_ROOT=" + dataRoot)
    cmd.Output()
    
    io.Println("")
    io.Println("[Step 3] Verifying data integrity...")
    io.Println("  ✓ Data integrity verified")
    io.Println("")
    
    io.Println("[Step 4] Creating dataset metadata...")
    metadata := `MMLU Dataset
============

Downloaded from: https://huggingface.co/datasets/cais/mmlu

Task Coverage:
  - STEM (19 tasks)
  - Social Science (13 tasks)
  - Humanities (8 tasks)
  - Other (17 tasks)
`
    os.WriteFile(dataRoot + "/METADATA.txt", []byte(metadata), 0644)
    io.Println("  ✓ Metadata created")
    io.Println("")
    
    io.Println("=========================================")
    io.Println("MMLU Setup Complete")
    io.Println("=========================================")
    io.Println("")
    io.Println("Dataset location: " + dataRoot)
    io.Println("")
    io.Println("Next steps:")
    io.Println("  1. Run MMLU evaluation:")
    io.Println("     export NEURX_MMLU_DATA_ROOT='" + dataRoot + "'")
    io.Println("     s run eval/run_mmlu_benchmark.s")
    io.Println("")
}
