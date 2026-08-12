package main
use neurx.runtime.io.{runtime_env_get, runtime_dir_exists, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let shards_dir = runtime_env_get("VERIFY_DATASET_DIR", project_root + "/dataset/pretrain/shard")
    let sample_file = shards_dir + "/shard_00000.jsonl"
    println("NeurX Dataset Verification (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("Shards dir  : " + shards_dir)
    println("")
    println("  shard dir   : " + check_dir(shards_dir))
    println("  sample file : " + check_path(sample_file))
    println("")
    println("This S entrypoint centralizes the dataset verification status layer.")
    0
}
func check_dir(string path) string {
    if runtime_dir_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
