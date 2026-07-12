package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_file_exists, runtime_shell_escape}
use std.io.println

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string log_dir = project_root + "/artifacts/logs"

    println("════════════════════════════════════════════════════════════════")
    println("🚀 启动 NeurX 训练")
    println("════════════════════════════════════════════════════════════════")
    println("")
    println("▶ 启动make train...")

    string launch_cmd = "cd " + runtime_shell_escape(project_root) + " && make train > /dev/null 2>&1 & echo $! | tr -d '\\n'"
    string make_pid = runtime_run_command_output(launch_cmd)
    if make_pid == "" {
        println("✗ 训练启动失败")
        return 1
    }

    println("✓ 训练已启动 (PID: " + make_pid + ")")
    println("")
    println("▶ 等待日志文件生成...")
    if !runtime_run_command("sleep 2").ok {
        return 1
    }

    println("▶ 启动实时监控...")
    println("  按 Ctrl+C 停止日志查看（训练会继续进行）")
    println("")
    println("════════════════════════════════════════════════════════════════")

    string latest_log = runtime_run_command_output("cd " + runtime_shell_escape(log_dir) + " && ls -t train_*.log 2>/dev/null | head -1 | tr -d '\\n'")
    if latest_log != "" && runtime_file_exists(log_dir + "/" + latest_log) {
        string tail_cmd = "tail -f " + runtime_shell_escape(log_dir + "/" + latest_log)
        if !runtime_run_command(tail_cmd).ok {
            return 1
        }
    } else {
        println("✗ 未找到日志文件，训练可能失败或尚未启动")
        println("")
        println("诊断信息：")
        string diag_cmd = "cd " + runtime_shell_escape(project_root) + " && make train 2>&1 | head -50"
        if !runtime_run_command(diag_cmd).ok {
            return 1
        }
    }

    0
}
