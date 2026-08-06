package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Cluster Launch status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  launch script : " + check_path("scripts/legacy/cluster_launch.s"))
    println("  deployment dir : " + check_path("production_deployment"))
    println("  checkpoints   : " + check_path("artifacts/checkpoints"))
    println("")
    println("This S entrypoint centralizes the cluster launch status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

