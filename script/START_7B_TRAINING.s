package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string script_dir = project_root + "/script"
    string config_file = runtime_env_get("NEURX_7B_CONFIG", script_dir + "/configs/7b_training.json")

    if !runtime_file_exists(config_file) {
        println("❌ Missing 7B config: " + config_file)
        return 1
    }

    string launch_cmd = "NEURX_7B_CONFIG=" + runtime_shell_escape(config_file) + " bash " + runtime_shell_escape(script_dir + "/LAUNCH_7B_TRAINING.sh")
    if !runtime_run_command(launch_cmd).ok {
        return 1
    }

    0
}
