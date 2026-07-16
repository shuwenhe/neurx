package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Production Deployment Status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  deployment script : " + check_path("scripts/legacy/setup_production_deployment.s"))
    println("  config dir        : " + check_path("production_deployment"))
    println("  scripts dir       : " + check_path("deploy/production/scripts"))
    println("")
    println("This S entrypoint centralizes the production deployment status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
