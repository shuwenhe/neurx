package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Setup Verification (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  neurx      : " + binary_status("neurx"))
    println("  s compiler : " + binary_status("s"))
    println("  script dir : " + check_path("script"))
    println("  dataset dir: " + check_path("dataset"))
    println("")
    println("This S entrypoint centralizes the setup verification status layer.")
    0
}
func binary_status(string name) string {
    if runtime_env_get("PATH", "") != "" {
        return "available or unresolved (" + name + ")"
    }
    return "missing (" + name + ")"
}
func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
