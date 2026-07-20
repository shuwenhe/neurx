package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command_exit_code}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/Users/shuwen/shuwen/train/neurx")
    string merger_bin = runtime_env_get("NEURX_QWEN_LORA_MERGER_BIN", project_root + "/artifacts/build/qwen_lora_merge/qwen_lora_safetensors_merge")
    string base_model = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", project_root + "/../model/Qwen2.5-0.5B-Instruct")
    string adapter_dir = runtime_env_get("NEURX_LORA_ADAPTER_DIR", project_root + "/artifacts/checkpoints/qwen2_5_0_5b_lora_adapter")
    string output_dir = runtime_env_get("NEURX_MERGED_MODEL_DIR", project_root + "/../model/Qwen2.5-0.5B-Instruct-posttrain")
    string alpha = runtime_env_get("NEURX_LORA_ALPHA", "16")
    string rank = runtime_env_get("NEURX_LORA_RANK", "8")

    println("========================================")
    println("NeurX S Qwen LoRA safetensors merge")
    println("========================================")
    println("Base model : " + base_model)
    println("Adapter dir: " + adapter_dir)
    println("Output dir : " + output_dir)
    println("Merger bin : " + merger_bin)
    println("Alpha      : " + alpha)
    println("Rank       : " + rank)

    string command = merger_bin + " " +
        base_model + " " +
        adapter_dir + " " +
        output_dir + " " +
        alpha + " " +
        rank

    int exit_code = runtime_run_command_exit_code(command)
    if exit_code == 0 {
        println("Qwen LoRA merge complete")
        return 0
    }

    println("Qwen LoRA merge failed")
    return exit_code
}
