package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println
func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string model_size = runtime_env_get("MODEL_SIZE", "1t")
    string allow_local = runtime_env_get("NEURX_ALLOW_FULL_1T_LOCAL", "1")
    println("NeurX 1T MoE entry (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("model size   : " + model_size)
    println("Local allow  : " + allow_local)
    println("")
    string cmd = "MODEL_SIZE=" + runtime_shell_escape(model_size) + " NEURX_ALLOW_FULL_1T_LOCAL=" + runtime_shell_escape(allow_local) + " make -C " + runtime_shell_escape(project_root) + " run-large-pretrain-s"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}
