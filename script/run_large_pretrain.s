package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let checkpoint_root = runtime_env_get("NEURX_PRETRAIN_OUTPUT_DIR", project_root + "/artifacts/checkpoints/llm_training")
    println("NeurX Large Pretrain Setup Verification")
    println("")
    println("Project root: " + project_root)
    println("Checkpoint root: " + checkpoint_root)
    println("")
    println("  pretrain script : " + check_path("script/run_large_pretrain.sh"))
    println("  model source    : " + check_path("pretrain/llm/large_pretrain.s"))
    println("  training source : " + check_path("script/run_training_pipeline.s"))
    println("  checkpoint ptr  : " + checkpoint_pointer_status(checkpoint_root))
    println("  data manifest   : " + check_path("dataset/pretrain/manifest.json"))
    println("")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

func checkpoint_pointer_status(string checkpoint_root) string {
    let latest_path = checkpoint_root + "/latest_checkpoint.txt"
    if runtime_file_exists(latest_path) {
        return "ready (" + latest_path + ")"
    }
    return "missing (" + latest_path + ")"
}
