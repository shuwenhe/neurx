package main

use neurx.runtime.io.{runtime_env_get}
use neurx.pretrain.llm.entry
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let checkpoint_root = runtime_env_get("NEURX_PRETRAIN_OUTPUT_DIR", project_root + "/artifacts/checkpoints/llm_training")
    
    println("🚀 NeurX Large Pretrain Starting (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("Checkpoint root: " + checkpoint_root)
    println("")
    
    // Launch actual training
    println("Starting training pipeline...")
    let result = entry.main()
    
    if result == 0 {
        println("")
        println("✅ Training completed successfully")
    } else {
        println("")
        println("❌ Training failed with exit code: " + string(result))
    }
    
    result
}
