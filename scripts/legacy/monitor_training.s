package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command_output, runtime_shell_escape, trim}

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/app/shuwen/neurx")
    string log_dir = project_root + "/artifacts/logs"
    string latest_log = latest_phase2a_log(log_dir)
    println("==========================================")
    println("NeurX PostTrain Training Monitor (S)")
    println("==========================================")
    println("")
    if latest_log == "" {
        println("ERROR: no training log found")
        println("Expected pattern: " + log_dir + "/posttrain_phase2a_*.log")
    }
    println("Log file: " + latest_log)
    println("File size: " + file_size_human(latest_log))
    println("Updated:   " + file_mtime(latest_log))
    println("")
    println("Training process status:")
    string process_lines = trim(runtime_run_command_output(
        "ps -eo %cpu,%mem,etime,args | grep '[s]_ir_runner' || true"
    ))
    if process_lines == "" {
        println("  not running")
    } else {
        print_indented_block(process_lines)
    }
    println("")
    println("Training progress (last 30 lines):")
    println("----------------------------------------")
    string tail_output = trim(runtime_run_command_output(
        "tail -n 30 " + runtime_shell_escape(latest_log) + " 2>/dev/null"
    ))
    if tail_output == "" {
        println("  (log is empty)")
    } else {
        println(tail_output)
    }
    println("----------------------------------------")
    println("")
    println("Training stats:")
    println("  Total log lines: " + count_lines(latest_log))
    println("  Started epochs:  " + count_matches(latest_log, "epoch.*started"))
    println("  Started samples: " + count_matches(latest_log, "sample.*start"))
    println("  Module events:   " + count_matches(latest_log, "Processing module"))
    println("")
    println("Live monitoring commands:")
    println("  watch -n 2 'tail -n 30 " + latest_log + "'")
    println("  tail -f " + latest_log)
    0
}

func latest_phase2a_log(string log_dir) string {
    string cmd = "cd " + runtime_shell_escape(log_dir) + " && ls -t posttrain_phase2a_*.log 2>/dev/null | head -n 1"
    trim(runtime_run_command_output(cmd))
}

func file_size_human(string path) string {
    string out = trim(runtime_run_command_output("du -h " + runtime_shell_escape(path) + " 2>/dev/null | cut -f1"))
    if out == "" {
        return "unknown"
    }
    out
}

func file_mtime(string path) string {
    string out = trim(runtime_run_command_output("stat -c '%y' " + runtime_shell_escape(path) + " 2>/dev/null"))
    if out == "" {
        out = trim(runtime_run_command_output("ls -l " + runtime_shell_escape(path) + " 2>/dev/null | awk '{print $6, $7, $8}'"))
    }
    if out == "" {
        return "unknown"
    }
    out
}

func count_lines(string path) string {
    string out = trim(runtime_run_command_output("wc -l < " + runtime_shell_escape(path) + " 2>/dev/null"))
    if out == "" {
        return "0"
    }
    out
}

func count_matches(string path, string pattern) string {
    string out = trim(runtime_run_command_output(
        "awk '/" + pattern + "/ {c++} END {print c+0}' " + runtime_shell_escape(path) + " 2>/dev/null"
    ))
    if out == "" {
        return "0"
    }
    out
}

func print_indented_block(string text) {
    int i = 0
    string line = ""
    while i <= len(text) {
        bool at_end = i == len(text)
        bool at_newline = !at_end && string(text[i]) == "\n"
        if at_end || at_newline {
            if trim(line) != "" {
                println("  " + line)
            }
            line = ""
        } else if string(text[i]) != "\r" {
            line = line + string(text[i])
        }
        i = i + 1
    }
}
