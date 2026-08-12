package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Quick Start (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  script tree : " + check_path("script"))
    println("  data tree   : " + check_path("dataset"))
    println("  workflow dir: " + check_path("workflows"))
    println("")
    println("This S entrypoint centralizes the quick-start status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

