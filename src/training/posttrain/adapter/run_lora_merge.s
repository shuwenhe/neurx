package main
use neurx.runtime.io.{runtime_env_get}
use std.io.println
func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/Users/shuwen/shuwen/train/neurx")
    string merger_bin = runtime_env_get("NEURX_LORA_MERGER_BIN", project_root + "/artifact/build/lora_merge/lora_safetensors_merge")
    string base_model = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", project_root + "/../model/base-model-7B")
    string adapter_dir = runtime_env_get("NEURX_LORA_ADAPTER_DIR", project_root + "/artifact/checkpoints/lora_adapter")
    string output_dir = runtime_env_get("NEURX_MERGED_MODEL_DIR", project_root + "/../posttrain")
    string alpha = runtime_env_get("NEURX_LORA_ALPHA", "16")
    string rank = runtime_env_get("NEURX_LORA_RANK", "8")
    println("========================================")
    println("NeurX S LoRA safetensors merge")
    println("========================================")
    println("Base model : " + base_model)
    println("Adapter dir: " + adapter_dir)
    println("Output dir : " + output_dir)
    println("Merger bin : " + merger_bin)
    println("Alpha      : " + alpha)
    println("Rank       : " + rank)
    println("")
    println("✓ Configuration loaded successfully")
    println("")
    println("To complete the merge, run the merger binary:")
    println("")
    string command = merger_bin + " " +
        base_model + " " +
        adapter_dir + " " +
        output_dir + " " +
        alpha + " " +
        rank
    println(command)
    println("")
    0
}
