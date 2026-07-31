package main
use neurx.runtime.io.{runtime_env_get}
use neurx.runtime.io.{runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Training Pipeline (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("Pipeline mode: train -> checkpoint -> infer")
    println("")
    println("  training runner : " + check_path("scripts/legacy/run_llm_training.s"))
    println("  inference entry : " + check_path("scripts/legacy/run_inference_llm.s"))
    println("  split entry     : " + check_path("scripts/legacy/split_data.s"))
    println("")
    println("This S entrypoint centralizes the pipeline selection layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
