package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Complete Training Cycle Status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  config file : " + check_path("configs/config_large_model.json"))
    println("  data path   : " + check_path("dataset/pretrain"))
    println("  logs dir    : " + check_path("logs"))
    println("")
    println("This S entrypoint centralizes the complete training cycle status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
