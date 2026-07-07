package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let data_dir = runtime_env_get("NEURX_SFT_DATA_DIR", project_root + "/data/instructions")
    let output_dir = runtime_env_get("NEURX_SFT_OUTPUT_DIR", project_root + "/artifacts/checkpoints/sft")

    println("NeurX SFT Training (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("Data dir    : " + check_path(data_dir))
    println("Output dir  : " + check_path(output_dir))
    println("Trainer src : " + check_path("script/sft_trainer.s"))
    println("")
    println("This S entrypoint centralizes the SFT training status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
