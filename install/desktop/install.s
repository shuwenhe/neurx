package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_shell_escape, trim}
use std.io.println

func main() int {
    string gpu = runtime_env_get("NEURX_GPU", "auto")
    string os_name = runtime_run_command_output("uname -s")
    if gpu == "auto" {
        if runtime_run_command("command -v nvidia-smi >/dev/null 2>&1").ok {
            gpu = "nvidia"
        } else if trim(os_name) == "Darwin" {
            gpu = "apple"
        } else if runtime_run_command("command -v rocm-smi >/dev/null 2>&1").ok {
            gpu = "amd"
        } else {
            gpu = "none"
        }
    }
    println("NeurX Desktop install (S)")
    println("OS: " + trim(os_name))
    println("GPU: " + gpu)
    println("This entrypoint now lives in S and intentionally stays conservative.")
    0
}
