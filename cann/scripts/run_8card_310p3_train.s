package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string ascend_home = runtime_env_get("ASCEND_HOME_PATH", "/usr/local/Ascend/ascend-toolkit/latest")
    string model_size = runtime_env_get("MODEL_SIZE", "gpt-large")
    string s_compiler = runtime_env_get("S_COMPILER", runtime_env_get("COMPILER_BIN", "s"))

    println("NeurX 8x Ascend 310P3 Training Entry (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("ASCEND_HOME  : " + ascend_home)
    println("Model size   : " + model_size)
    println("")

    string cmd = "ASCEND_HOME_PATH=" + runtime_shell_escape(ascend_home) + " MODEL_SIZE=" + runtime_shell_escape(model_size) + " S_COMPILER=" + runtime_shell_escape(s_compiler) + " make -C " + runtime_shell_escape(project_root) + " run-large-pretrain-s"
    if !runtime_run_command(cmd).ok {
        return 1
    }

    0
}
