package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command_output, runtime_file_exists, trim}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let log_dir = project_root + "/artifacts/logs"
    let checkpoint_dir = project_root + "/artifacts/checkpoints"

    println("NeurX trainingEnglish textmonitoring (S English text)")
    println("")

    let latest_log = trim(runtime_run_command_output("cd '" + log_dir + "' && ls -t train_*.log 2>/dev/null | head -1"))
    if latest_log == "" {
        println("English texttraininglogfile")
        return 1
    }

    println("English textlog: " + latest_log)
    println("")
    println("logEnglish text: " + trim(runtime_run_command_output("cd '" + log_dir + "' && du -h '" + latest_log + "' 2>/dev/null | cut -f1")))
    println("English text: " + trim(runtime_run_command_output("cd '" + log_dir + "' && ls -l '" + latest_log + "' 2>/dev/null | awk '{print $6, $7, $8}'")))
    println("")

    print_flag("dataEnglish text", runtime_run_command_output("pgrep -f clean_data 2>/dev/null") != "")
    print_flag("trainingEnglish text", runtime_run_command_output("pgrep -f 'neurx.*train' 2>/dev/null") != "")
    print_flag("S compileEnglish text", runtime_file_exists("/home/shuwen/s/bin/s"))

    println("")
    if runtime_file_exists(project_root + "/dataset/pretrain/cleaned/pretrain_data_cleaned.jsonl") {
        println("dataEnglish text: English text")
    } else {
        println("dataEnglish text: English text")
    }

    if runtime_file_exists(project_root + "/dataset/pretrain/manifest.json") {
        println("Manifest: English textgenerate")
    } else {
        println("Manifest: English textgenerate")
    }

    println("")
    println("English textlogcontent (English text20English text):")
    println("─────────────────────────────────────────────────────────────────")
    println(trim(runtime_run_command_output("cd '" + log_dir + "' && tail -20 '" + latest_log + "'")))
    println("─────────────────────────────────────────────────────────────────")
    0
}

func print_flag(string name, bool ok) {
    if ok {
        println("✓ " + name + " runEnglish text")
    } else {
        println("✗ " + name + " English textrun")
    }
}
