package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Large Pretrain Status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  pretrain script : " + check_path("script/run_large_pretrain.sh"))
    println("  model source    : " + check_path("pretrain/llm/large_pretrain.s"))
    println("  checkpoint dir  : " + check_path("artifacts/checkpoints/neurx_1t_moe"))
    println("  data manifest   : " + check_path("data/training_data_shards/manifest.txt"))
    println("")
    println("This S entrypoint centralizes the large pretrain status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
