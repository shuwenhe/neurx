package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    string log_fifo = runtime_env_get("NEURX_SHARD_LOG_FIFO", ".neurx-shard-log")
    _ = runtime_run_command("rm -f " + runtime_shell_escape(log_fifo))
    if !runtime_run_command("mkfifo " + runtime_shell_escape(log_fifo)).ok {
        println("failed to create fifo: " + log_fifo)
        return 1
    }
    println("NeurX shard monitor (S)")
    println("FIFO: " + log_fifo)
    println("Waiting for shard processing logs...")
    _ = runtime_run_command("cat " + runtime_shell_escape(log_fifo))
    _ = runtime_run_command("rm -f " + runtime_shell_escape(log_fifo))
    0
}

