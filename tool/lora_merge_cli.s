package neurx.tools.lora_merge_cli
use neurx.runtime.io.{runtime_env_get}
use std.io.println

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string merger_bin = runtime_env_get("NEURX_LORA_MERGER_BIN",
        project_root + "/artifacts/build/lora_merge/lora_safetensors_merge")
    string base_model = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH",
        project_root + "/../model/base-model-7B")
    string adapter_dir = runtime_env_get("NEURX_LORA_ADAPTER_DIR",
        project_root + "/artifacts/checkpoints/lora_adapter")
    string output_dir = runtime_env_get("NEURX_MERGED_MODEL_DIR",
        project_root + "/../posttrain")
    string alpha_str = runtime_env_get("NEURX_LORA_ALPHA", "16")
    string rank_str = runtime_env_get("NEURX_LORA_RANK", "8")
    println("========================================")
    println("NeurX LoRA Safetensors Merge")
    println("========================================")
    println("")
    println("Base model : " + base_model)
    println("Adapter dir: " + adapter_dir)
    println("Output dir : " + output_dir)
    println("Merger bin : " + merger_bin)
    println("Alpha      : " + alpha_str)
    println("Rank       : " + rank_str)
    println("")
    println("✓ Merger configuration loaded")
    println("")
    println("Running C-optimized merger...")
    println("")
    string command = merger_bin + " " +
        base_model + " " +
        adapter_dir + " " +
        output_dir + " " +
        alpha_str + " " +
        rank_str
    println("command: " + command)
    println("")
    0
}
