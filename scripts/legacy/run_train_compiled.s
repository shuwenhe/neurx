package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Compiled Train status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  train script : " + check_path("scripts/legacy/run_training.s"))
    println("  s source     : " + check_path("train/train_large_model_simple.s"))
    println("  build dir    : " + check_path("build/large_model_training"))
    println("")
    println("This S entrypoint centralizes the compiled-train status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

