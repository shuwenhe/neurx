package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Run-With-Logs status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  train script : " + check_path("scripts/legacy/run_training.s"))
    println("  log dir      : " + check_path("artifacts/logs"))
    println("  build dir    : " + check_path("build"))
    println("")
    println("This S entrypoint centralizes the run-with-logs status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

