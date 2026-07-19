package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_file_exists, runtime_shell_escape}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string log_dir = project_root + "/artifacts/logs"

    println("════════════════════════════════════════════════════════════════")
    println("🚀 start NeurX training")
    println("════════════════════════════════════════════════════════════════")
    println("")
    println("▶ startmake train...")

    string launch_cmd = "cd " + runtime_shell_escape(project_root) + " && make train > /dev/null 2>&1 & echo $! | tr -d '\\n'"
    string make_pid = runtime_run_command_output(launch_cmd)
    if make_pid == "" {
        println("✗ trainingstartfailure")
        return 1
    }

    println("✓ trainingEnglish textstart (PID: " + make_pid + ")")
    println("")
    println("▶ English textlogfilegenerate...")
    if !runtime_run_command("sleep 2").ok {
        return 1
    }

    println("▶ startEnglish textmonitoring...")
    println("  English text Ctrl+C English textlogEnglish text(trainingEnglish text)")
    println("")
    println("════════════════════════════════════════════════════════════════")

    string latest_log = runtime_run_command_output("cd " + runtime_shell_escape(log_dir) + " && ls -t train_*.log 2>/dev/null | head -1 | tr -d '\\n'")
    if latest_log != "" && runtime_file_exists(log_dir + "/" + latest_log) {
        string tail_cmd = "tail -f " + runtime_shell_escape(log_dir + "/" + latest_log)
        if !runtime_run_command(tail_cmd).ok {
            return 1
        }
    } else {
        println("✗ English textlogfile, trainingEnglish textfailureEnglish textstart")
        println("")
        println("English textinformation: ")
        string diag_cmd = "cd " + runtime_shell_escape(project_root) + " && make train 2>&1 | head -50"
        if !runtime_run_command(diag_cmd).ok {
            return 1
        }
    }

    0
}
