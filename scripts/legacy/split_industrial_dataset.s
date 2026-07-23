package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string msg = "split_industrial_dataset: Python entry removed; use the S data pipeline for dataset preparation"
    string cmd = "printf %s " + runtime_shell_escape(msg)
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}
