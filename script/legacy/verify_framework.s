package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Framework Verification (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  src/runtime/distributed/moe_all_to_all.s      : " + check_path("src/runtime/distributed/moe_all_to_all.s"))
    println("  src/runtime/distributed/tensor_parallel.s     : " + check_path("src/runtime/distributed/tensor_parallel.s"))
    println("  src/runtime/distributed/zero_gradient_reduce.s: " + check_path("src/runtime/distributed/zero_gradient_reduce.s"))
    println("  src/observability/metrics/moe_1t_metrics.s: " + check_path("src/observability/metrics/moe_1t_metrics.s"))
    println("  src/runtime/scheduler/lr_scheduler_moe_1t.s    : " + check_path("src/runtime/scheduler/lr_scheduler_moe_1t.s"))
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
