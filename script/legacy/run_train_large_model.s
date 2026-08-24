package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Large model Train status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  training script : " + check_path("script/legacy/run_llm_training.s"))
    println("  large model src : " + check_path("train/train_large_model.s"))
    println("  output dir      : " + check_path("output/large_model"))
    println("")
    println("This S entrypoint centralizes the large-model training status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
