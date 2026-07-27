package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Training Integration status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  checkpoint dir : " + check_path("artifacts/checkpoints"))
    println("  log dir        : " + check_path("logs"))
    println("  bin dir        : " + check_path("bin"))
    println("")
    println("This S entrypoint centralizes the training integration status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
