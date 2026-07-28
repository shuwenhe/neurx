package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string ascend_home = runtime_env_get("ASCEND_HOME_PATH", "/usr/local/Ascend/ascend-toolkit/latest")
    println("NeurX 8x Ascend 310P3 Inference entry (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("ASCEND_HOME  : " + ascend_home)
    println("")
    string cmd = "ASCEND_HOME_PATH=" + runtime_shell_escape(ascend_home) + " bash " + runtime_shell_escape(project_root + "/cann/scripts/launch_8card_310p3_inference.sh")
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}
