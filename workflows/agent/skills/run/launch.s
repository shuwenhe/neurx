package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string s_bin = runtime_env_get("S_BIN", runtime_env_get("S_COMPILER", "s"))
    string src = project_root + "/workflows/agent/skills/run/run_with_config.s"
    string ir = "/tmp/neurx_agent_skills_launch.ir"
    if !runtime_run_command(runtime_shell_escape(s_bin) + " " + runtime_shell_escape(src) + " " + runtime_shell_escape(ir)).ok {
        return 1
    }
    if !runtime_run_command(runtime_shell_escape(s_bin) + " " + runtime_shell_escape(ir)).ok {
        return 1
    }
    0
}
