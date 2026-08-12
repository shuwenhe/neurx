package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Linux Build status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  build script : " + check_path("scripts/legacy/build-linux.s"))
    println("  cmake cache  : " + check_path("build/linux-Release/CMakeCache.txt"))
    println("  qt bundle    : " + check_path("build/linux-Release"))
    println("")
    println("This S entrypoint centralizes the Linux build status layer.")
    0
}


func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

