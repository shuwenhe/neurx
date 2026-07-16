package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string build_dir = runtime_env_get("NEURX_SMART_INFERENCE_BUILD_DIR", project_root + "/build")
    string bin_file = build_dir + "/smart_inference.bin"

    println("NeurX Smart Inference Launcher (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("Binary path  : " + bin_file)
    println("")

    if !runtime_file_exists(bin_file) {
        println("Binary missing, building it first...")
        string build_cmd = "cd " + runtime_shell_escape(project_root) + " && make build-smart-inference-s"
        if !runtime_run_command(build_cmd).ok {
            return 1
        }
    }

    if !runtime_file_exists(bin_file) {
        println("Error: binary still missing")
        return 1
    }

    string run_cmd = runtime_shell_escape(bin_file)
    if !runtime_run_command(run_cmd).ok {
        return 1
    }

    0
}
