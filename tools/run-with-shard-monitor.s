package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println
func main() int {
    string s_compiler = runtime_env_get("S_COMPILER", "/home/shuwen/s/bin/s")
    string root = runtime_env_get("NEURX_ROOT", ".")
    string log_pipe = root + "/.neurx-shard-log-pipe"
    string ir_file = root + "/artifacts/build/run_large_pretrain/minimal_train.ir"
    _ = runtime_run_command("rm -f " + runtime_shell_escape(log_pipe))
    _ = runtime_run_command("mkfifo " + runtime_shell_escape(log_pipe))
    println("Starting shard monitor on " + log_pipe)
    println("Compiling and running " + ir_file)
    _ = runtime_run_command("sh -c " + runtime_shell_escape("cat " + log_pipe + " > /dev/null") + " &")
    if !runtime_run_command(runtime_shell_escape(s_compiler) + " " + runtime_shell_escape(ir_file)).ok {
        _ = runtime_run_command("rm -f " + runtime_shell_escape(log_pipe))
        return 1
    }
    _ = runtime_run_command("rm -f " + runtime_shell_escape(log_pipe))
    println("Training session complete")
    0
}
