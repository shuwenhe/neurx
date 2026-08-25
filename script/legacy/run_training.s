package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    project_root := runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("=======================================================================")
    println("NeurX Deep Learning Framework - S Training entry")
    println("=======================================================================")
    println("")
    println("Project root: " + project_root)
    println("Delegating to: make run-training-s")
    println("")
    result := runtime_run_command("make -C " + runtime_shell_escape(project_root) + " run-training-s")
    if !result.ok {
        return result.exit_code
    }
    0
}
