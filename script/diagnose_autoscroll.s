package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Autoscroll Diagnostic (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  chat panel      : " + check_path("src/qml/ChatPanel.qml"))
    println("  agent controller: " + check_path("src/bridge/AgentController.cpp"))
    println("  build dir       : " + check_path("build"))
    println("")
    println("This S entrypoint centralizes the autoscroll diagnostic status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
