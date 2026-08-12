package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX File Creation Diagnostic (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  tools source : " + check_path("src/bridge/AgentController.cpp"))
    println("  build dir    : " + check_path("build"))
    println("  docs dir     : " + check_path("docs"))
    println("")
    println("This S entrypoint centralizes the file creation diagnostic status layer.")
    0
}


func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

