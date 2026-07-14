package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")

    println("Running local inference entry")
    println("Project root: " + project_root)
    println("Delegating to: make run-inference-s")

    string cmd = "make -C " + runtime_shell_escape(project_root) + " run-inference-s"
    if !runtime_run_command(cmd).ok {
        return 1
    }

    0
}
