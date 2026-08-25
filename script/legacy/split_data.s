package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    dataset_root := runtime_env_get("NEURX_SPLIT_DATASET_ROOT", "dataset/pretrain")
    source_file := runtime_env_get("NEURX_SPLIT_SOURCE_FILE", dataset_root + "/cleaned/train.jsonl")
    output_dir := runtime_env_get("NEURX_SPLIT_OUTPUT_DIR", dataset_root + "/split")
    println("NeurX Dataset Split entry (S Lang)")
    println("")
    println("  source file : " + check_path(source_file))
    println("  output dir  : " + check_path(output_dir))
    println("  dataset root: " + check_path(dataset_root))
    println("")
    println("This S entrypoint centralizes the split-data status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
