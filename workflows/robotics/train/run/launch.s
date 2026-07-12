package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string cmd = "cd " + runtime_shell_escape(project_root) + " && workflows/robotics/train/run/run_with_config.sh --config workflows/robotics/train/config/sample.yaml"
    if !runtime_run_command(cmd).ok {
        return 1
    }

    0
}
