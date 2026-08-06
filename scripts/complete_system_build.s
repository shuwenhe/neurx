package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/Users/shuwen/shuwen/train/neurx")
    println("NeurX Complete S System Build")
    println("")
    println("Project root : " + project_root)
    println("Build target : make compile-all-components-s")
    println("")
    string cmd = "make -C " + runtime_shell_escape(project_root) + " compile-all-components-s"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}

