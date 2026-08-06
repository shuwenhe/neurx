package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Framework Verification (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  distributed/moe_all_to_all.s      : " + check_path("distributed/moe_all_to_all.s"))
    println("  distributed/tensor_parallel.s     : " + check_path("distributed/tensor_parallel.s"))
    println("  distributed/zero_gradient_reduce.s: " + check_path("distributed/zero_gradient_reduce.s"))
    println("  monitoring/moe_1t_metrics.s       : " + check_path("monitoring/moe_1t_metrics.s"))
    println("  scheduler/lr_scheduler_moe_1t.s    : " + check_path("scheduler/lr_scheduler_moe_1t.s"))
    println("")
    println("This S entrypoint centralizes the framework verification status layer.")
    0
}
func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
