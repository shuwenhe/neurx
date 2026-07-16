package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string script_path = project_root + "/scripts/legacy/split_industrial_dataset.py"
    string cmd = "python3 " + runtime_shell_escape(script_path)
    if !runtime_run_command(cmd).ok {
        return 1
    }

    0
}
