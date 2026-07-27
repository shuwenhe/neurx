package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX Inference Pipeline Verification (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  inference src : " + check_path("inference/production_inference.s"))
    println("  tokenizer data : " + check_path("data/corpus/vocab.json"))
    println("  build dir      : " + check_path("build"))
    println("  artifacts dir  : " + check_path("artifacts"))
    println("")
    println("This S entrypoint centralizes the inference verification status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
