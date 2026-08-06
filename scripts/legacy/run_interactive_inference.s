package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let checkpoint_dir = runtime_env_get("NEURX_CHECKPOINT_DIR", project_root + "/checkpoint/NeurX-1.3")
    let output_dir = runtime_env_get("NEURX_INFER_OUTPUT_DIR", project_root + "/artifacts/inference_output")
    println("NeurX Interactive Chat (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("checkpoint : " + checkpoint_dir)
    println("")
    println("  inference source : " + check_path("inference/production_inference.s"))
    println("  checkpoint dir   : " + check_path(checkpoint_dir))
    println("  output dir       : " + check_path(output_dir))
    println("")
    if runtime_file_exists(checkpoint_dir) {
        println("✓ Ready for interactive chat")
        println("  Type your question and press Enter")
    } else {
        println("✗ checkpoint not available - cannot start chat")
    }
    0
}
func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
