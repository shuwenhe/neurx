package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let shards_dir = runtime_env_get("SHARDS_DIR", "/home/shuwen/shuwen/train/neurx/dataset/pretrain/shard")
    let out_path = runtime_env_get("OUT", "/app/train/neurx/dataset/report.json")
    let manifest_path = runtime_env_get("MANIFEST", "/home/shuwen/shuwen/train/neurx/dataset/pretrain/manifest.json")

    println("NeurX Dataset Analyze (S Lang)")
    println("")
    println("Shards dir: " + shards_dir)
    println("manifest  : " + manifest_path)
    println("Report out: " + out_path)
    println("")

    println("Availability:")
    print_flag("manifest file", runtime_file_exists(manifest_path))
    println("")
    println("This runner is intentionally minimal until full file IO support lands.")
    println("Use make verify-dataset-s for shard-level verification once runtime IO is expanded.")
    0
}

func print_flag(string name, bool ok) {
    if ok {
        println("  - " + name + ": ready")
    } else {
        println("  - " + name + ": missing")
    }
}
