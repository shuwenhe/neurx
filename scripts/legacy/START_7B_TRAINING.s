package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string config_file = runtime_env_get("NEURX_7B_CONFIG", project_root + "/configs/7b_training.json")

    if !runtime_file_exists(config_file) {
        println("❌ Missing 7B config: " + config_file)
        return 1
    }

    println("Starting 7B training entry")
    println("Project root: " + project_root)
    println("Config file  : " + config_file)
    println("Delegating to: make -f Makefile -f Makefile.large_models train-large")

    string launch_cmd = "NEURX_7B_CONFIG=" + runtime_shell_escape(config_file) + " make -f " + runtime_shell_escape(project_root + "/Makefile") + " -f " + runtime_shell_escape(project_root + "/Makefile.large_models") + " train-large"
    if !runtime_run_command(launch_cmd).ok {
        return 1
    }

    0
}
