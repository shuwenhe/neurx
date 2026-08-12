package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command, runtime_shell_escape}
use std.io.println
func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string mode = runtime_env_get("NEURX_INFER_MODE", "batch")
    string checkpoint_dir = runtime_env_get("NEURX_CHECKPOINT_DIR", project_root + "/artifacts/checkpoints/llm_training")
    string output_dir = runtime_env_get("NEURX_OUTPUT_DIR", project_root + "/artifacts/inference_output")
    string log_dir = runtime_env_get("NEURX_LOG_DIR", project_root + "/artifacts/logs")
    println("NeurX Full Inference Pipeline (S Lang)")
    println("")
    println("Project root  : " + project_root)
    println("Mode          : " + mode)
    println("checkpoint dir: " + checkpoint_dir)
    println("Output dir    : " + output_dir)
    println("Log dir       : " + log_dir)
    println("")
    print_flag("checkpoint dir", runtime_file_exists(checkpoint_dir))
    print_flag("output dir", runtime_file_exists(output_dir))
    print_flag("log dir", runtime_file_exists(log_dir))
    println("")
    string mkdir_cmd = "mkdir -p " + runtime_shell_escape(output_dir) + " " + runtime_shell_escape(log_dir)
    if !runtime_run_command(mkdir_cmd).ok {
        return 1
    }
    println("Delegating to: make run-inference-s")
    string run_cmd = "NEURX_INFER_MODE=" + runtime_shell_escape(mode) + " NEURX_CHECKPOINT_DIR=" + runtime_shell_escape(checkpoint_dir) + " NEURX_OUTPUT_DIR=" + runtime_shell_escape(output_dir) + " make -C " + runtime_shell_escape(project_root) + " run-inference-s"
    if !runtime_run_command(run_cmd).ok {
        return 1
    }
    0
}

func print_flag(string name, bool ok) {
    if ok {
        println("  - " + name + ": ready")
    } else {
        println("  - " + name + ": missing")
    }
}

