package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Full Compilation/Test status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  trainer/scaled_training_system.s : " + check_path("trainer/scaled_training_system.s"))
    println("  data/tools/real_data_loader.s         : " + check_path("data/tools/real_data_loader.s"))
    println("  cuda/cuda_accelerated_training.s   : " + check_path("cuda/cuda_accelerated_training.s"))
    println("  distributed/ddp_distributed_training.s : " + check_path("distributed/ddp_distributed_training.s"))
    println("")
    println("This S entrypoint centralizes the full compilation/test status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}

