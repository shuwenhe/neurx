package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println
func main() {
    string startup_env = runtime_env_get("NEURX_CLUSTER_ENV", "./training_startup.env")
    string project_root = runtime_env_get("NEURX_ROOT", "/Users/shuwen/shuwen/train/neurx")
    println("NeurX Production Launch Plan (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("Startup env  : " + startup_env)
    println("")
    string cmd = ". " + runtime_shell_escape(startup_env) + " && export NEURX_PRETRAIN_USE_LAUNCH_PLAN=0 NEURX_CLUSTER_DISABLE=1 && make -C " + runtime_shell_escape(project_root) + " run-training-s"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}
