package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Quick Test (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  smart inference source : " + check_path("s/smart_inference.s"))
    println("  build dir              : " + check_path("build"))
    println("  docs                    : " + check_path("docs"))
    println("")
    println("This S entrypoint centralizes the quick-test status layer.")
    0
}


func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

