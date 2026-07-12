package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Integration Tests Status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  integration script : " + check_path("script/run_integration_tests.s"))
    println("  core modules       : " + check_path("distributed"))
    println("  checkpoints dir    : " + check_path("artifacts/checkpoints"))
    println("")
    println("This S entrypoint centralizes the integration test status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
