package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string s_bin = runtime_env_get("S_BIN", runtime_env_get("S_COMPILER", "/Users/shuwen/s/bin/s"))
    string cmd = "cd " + runtime_shell_escape(project_root) + " && workflows/agent/skills/run/run_with_config.sh --s-bin " + runtime_shell_escape(s_bin) + " --config workflows/agent/skills/config/sample.yaml"
    if !runtime_run_command(cmd).ok {
        return 1
    }

    0
}
