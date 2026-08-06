package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("Launching 70B training entry")
    println("Project root: " + project_root)
    println("Delegating to: make -f Makefile -f configs/Makefile.large_models train-xlarge")
    string cmd = "make -f " + runtime_shell_escape(project_root + "/Makefile") + " -f " + runtime_shell_escape(project_root + "/configs/Makefile.large_models") + " train-xlarge"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}

