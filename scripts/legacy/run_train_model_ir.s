package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX model IR Train status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  source file : " + check_path("train/train_model.s"))
    println("  ir dir      : " + check_path("build"))
    println("  runner bin  : " + check_path("build/s_ir_runner"))
    println("")
    println("This S entrypoint centralizes the model-IR training status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

