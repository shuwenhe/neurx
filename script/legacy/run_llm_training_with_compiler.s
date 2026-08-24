package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("Running LLM training with compiler entry")
    println("Project root: " + project_root)
    println("Delegating to: make run-training-s")
    string cmd = "make -C " + runtime_shell_escape(project_root) + " run-training-s"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}
