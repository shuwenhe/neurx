package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string script_dir = project_root + "/script"
    string target = script_dir + "/LAUNCH_70B_TRAINING.sh"

    println("Launching 70B training entry")
    println("Project root: " + project_root)

    string cmd = "bash " + runtime_shell_escape(target)
    if !runtime_run_command(cmd).ok {
        return 1
    }

    0
}
