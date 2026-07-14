package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string hooks_dir = project_root + "/.githooks"

    string cmd = "git -C " + runtime_shell_escape(project_root) + " rev-parse --is-inside-work-tree >/dev/null 2>&1 && test -d " + runtime_shell_escape(hooks_dir) + " && git -C " + runtime_shell_escape(project_root) + " config core.hooksPath .githooks && chmod +x " + runtime_shell_escape(hooks_dir + "/post-commit") + " " + runtime_shell_escape(hooks_dir + "/post-merge")
    if !runtime_run_command(cmd).ok {
        return 1
    }

    0
}
