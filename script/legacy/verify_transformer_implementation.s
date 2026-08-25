package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println

func main() {
    project_root := runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX transformer_2 Verification (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  src/model/transformer/position_encoding.s  : " + check_path("src/model/transformer/position_encoding.s"))
    println("  src/model/transformer/layer_norm.s         : " + check_path("src/model/transformer/layer_norm.s"))
    println("  src/model/transformer/transformer_forward.s: " + check_path("src/model/transformer/transformer_forward.s"))
    println("  src/model/transformer/transformer_backward.s: " + check_path("src/model/transformer/transformer_backward.s"))
    println("")
    println("This S entrypoint centralizes the transformer verification status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
