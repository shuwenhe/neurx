package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let source_file = runtime_env_get("NEURX_SMALL_MODEL_SOURCE", project_root + "/train/train_llm.s")
    let checkpoint_dir = runtime_env_get("NEURX_SMALL_MODEL_CHECKPOINT_DIR", project_root + "/artifacts/checkpoints/llm_s_pretrain")

    println("NeurX Small Model Training (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("Source file  : " + check_path(source_file))
    println("Checkpoint   : " + check_path(checkpoint_dir))
    println("Steps        : " + runtime_env_get("NEURX_S_PRETRAIN_STEPS", "50"))
    println("Warmup steps : " + runtime_env_get("NEURX_S_PRETRAIN_WARMUP_STEPS", "10"))
    println("")
    println("This S entrypoint centralizes the small-model training status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
