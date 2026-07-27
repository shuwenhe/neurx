package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println
func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string pretrain_source = runtime_env_get("NEURX_PRETRAIN_SOURCE", project_root + "/pretrain/llm/model_large_pretrain.s")
    string output_dir = runtime_env_get("NEURX_PRETRAIN_OUTPUT_DIR", project_root + "/checkpoint/NeurX-1.3")
    string s_compiler = runtime_env_get("S_COMPILER", runtime_env_get("COMPILER_BIN", "s"))
    println("NeurX Large Model Pretrain Entry (S Lang)")
    println("")
    println("Project root : " + project_root)
    println("Source file  : " + pretrain_source)
    println("Output dir   : " + output_dir)
    println("S compiler   : " + s_compiler)
    println("")
    string cmd = "NEURX_PRETRAIN_SOURCE=" + runtime_shell_escape(pretrain_source) + " NEURX_PRETRAIN_OUTPUT_DIR=" + runtime_shell_escape(output_dir) + " S_COMPILER=" + runtime_shell_escape(s_compiler) + " make -C " + runtime_shell_escape(project_root) + " run-large-pretrain-s"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}
