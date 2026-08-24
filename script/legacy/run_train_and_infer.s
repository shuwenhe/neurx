package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let mode = runtime_env_get("MODE", "all")
    let checkpoint_dir = runtime_env_get("NEURX_CHECKPOINT_DIR", project_root + "/artifacts/checkpoints/llm_training")
    let output_dir = runtime_env_get("NEURX_OUTPUT_DIR", project_root + "/artifacts/inference_output")
    println("NeurX Train + Infer Orchestrator (S Lang)")
    println("")
    println("Project root  : " + project_root)
    println("Mode          : " + mode)
    println("checkpoint dir: " + checkpoint_dir)
    println("Output dir    : " + output_dir)
    println("")
    print_flag("checkpoint dir", runtime_file_exists(checkpoint_dir))
    print_flag("output dir", runtime_file_exists(output_dir))
    println("")
    println("This S entrypoint keeps the orchestration surface stable.")
    println("Backend training and inference remain delegated to the existing runners.")
    0
}

func print_flag(string name, bool ok) {
    if ok {
        println("  - " + name + ": ready")
    } else {
        println("  - " + name + ": missing")
    }
}
