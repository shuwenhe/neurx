package main
import (
    "neurx.runtime.io."
    "std.io.println"
)

func main() {
    project_root := runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Quickstart (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  training guide : " + check_path("TRAINING_GUIDE.md"))
    println("  model dir      : " + check_path("model"))
    println("  train dir      : " + check_path("train"))
    println("")
    println("This S entrypoint centralizes the quickstart status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
