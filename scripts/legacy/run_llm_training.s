package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let train_split = runtime_env_get("NEURX_TRAIN_SPLIT_PATH", project_root + "/dataset/pretrain/cleaned/train.jsonl")
    let val_split = runtime_env_get("NEURX_VAL_SPLIT_PATH", project_root + "/dataset/pretrain/cleaned/val.jsonl")
    let test_split = runtime_env_get("NEURX_TEST_SPLIT_PATH", project_root + "/dataset/pretrain/cleaned/test.jsonl")
    let manifest = runtime_env_get("NEURX_PRETRAIN_MANIFEST", project_root + "/dataset/pretrain/manifest.json")
    let output_dir = runtime_env_get("NEURX_PRETRAIN_OUTPUT_DIR", project_root + "/artifacts/checkpoints/llm_s_pretrain")
    println("NeurX LLM Training Orchestrator (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("Output dir  : " + output_dir)
    println("Train split : " + train_split)
    println("Val split   : " + val_split)
    println("Test split  : " + test_split)
    println("manifest    : " + manifest)
    println("")
    print_flag("train split", runtime_file_exists(train_split))
    print_flag("val split", runtime_file_exists(val_split))
    print_flag("test split", runtime_file_exists(test_split))
    print_flag("manifest", runtime_file_exists(manifest))
    println("")
    println("This S entrypoint currently acts as the orchestration/status layer.")
    println("Use make train / make run-s-pretrain-s for the compiled training backend.")
    0
}

func print_flag(string name, bool ok) {
    if ok {
        println("  - " + name + ": ready")
    } else {
        println("  - " + name + ": missing")
    }
}
