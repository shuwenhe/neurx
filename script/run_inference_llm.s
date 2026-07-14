package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let inference_source = runtime_env_get("NEURX_INFERENCE_SOURCE", project_root + "/inference/production_inference.s")
    // Use NEURX_CHECKPOINT_DIR if set, otherwise fall back to default
    let checkpoint_dir = runtime_env_get("NEURX_CHECKPOINT_DIR", runtime_env_get("NEURX_INFER_CHECKPOINT", project_root + "/checkpoint/NeurX-1.3"))
    let output_dir = runtime_env_get("NEURX_INFER_OUTPUT_DIR", project_root + "/artifacts/inference_output")

    println("NeurX LLM Inference Orchestrator (S Lang)")
    println("")
    println("Project root  : " + project_root)
    println("Inference src : " + inference_source)
    println("Checkpoint dir: " + checkpoint_dir)
    println("Output dir    : " + output_dir)
    println("")
    print_flag("inference source", runtime_file_exists(inference_source))
    print_flag("checkpoint dir", runtime_file_exists(checkpoint_dir))
    print_flag("output dir", runtime_file_exists(output_dir))
    println("")
    println("This S entrypoint keeps the inference surface stable.")
    println("Backend compilation and execution remain delegated to the existing runner.")
    0
}

func print_flag(string name, bool ok) {
    if ok {
        println("  - " + name + ": ready")
    } else {
        println("  - " + name + ": missing")
    }
}
