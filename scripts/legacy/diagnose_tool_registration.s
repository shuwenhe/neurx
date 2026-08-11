package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Tool Registration Diagnostic (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  agent controller : " + check_path("src/bridge/AgentController.cpp"))
    println("  tool registry    : " + check_path("src/tools/NeurXStandardTools.cpp"))
    println("  build dir        : " + check_path("build"))
    println("")
    println("This S entrypoint centralizes the tool registration diagnostic status layer.")
    0
}
func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
