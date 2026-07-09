package main

use neurx.runtime.io.{runtime_env_get, runtime_execute_file}
use std.io.println

func main() int {
    let ir_path = runtime_env_get("S_IR_RUNNER_INPUT", "")
    let entry = runtime_env_get("S_IR_RUNNER_ENTRY", "main")

    if ir_path == "" {
        println("usage: s_ir_runner <input.ir> [entry]")
        return 2
    }

    return runtime_execute_file(ir_path, entry)
}
