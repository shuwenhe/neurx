package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists}
use std.io.println
func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("NeurX End-to-End Verification Status (S Lang)")
    println("")
    println("Project root: " + project_root)
    println("")
    println("  verification script : " + check_path("scripts/legacy/run_end_to_end_verification.s"))
    println("  training src        : " + check_path("trainer/trainer.s"))
    println("  tests src           : " + check_path("tests/test_suite_complete.s"))
    println("")
    println("This S entrypoint centralizes the end-to-end verification status layer.")
    0
}

func check_path(string path) string {
    if runtime_file_exists(path) {
        return "ready (" + path + ")"
    }
    return "missing (" + path + ")"
}
