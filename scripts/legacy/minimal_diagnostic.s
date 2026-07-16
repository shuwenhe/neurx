package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Minimal Diagnostic (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  script dir  : " + check_path("script"))
    println("  artifacts   : " + check_path("artifacts"))
    println("  logs dir    : " + check_path("artifacts/logs"))
    println("")
    println("This S entrypoint centralizes the minimal diagnostic status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
