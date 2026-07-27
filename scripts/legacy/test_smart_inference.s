package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Smart Inference Test (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  smart inference src : " + check_path("s/smart_inference.s"))
    println("  model dir           : " + check_path("model"))
    println("  inference dir       : " + check_path("inference"))
    println("")
    println("This S entrypoint centralizes the smart-inference test status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
