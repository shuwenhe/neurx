package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command_output, runtime_file_exists, trim}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    let log_dir = project_root + "/artifacts/logs"
    let checkpoint_dir = project_root + "/artifacts/checkpoints"

    println("NeurX 训练进度监控 (S 入口)")
    println("")

    let latest_log = trim(runtime_run_command_output("cd '" + log_dir + "' && ls -t train_*.log 2>/dev/null | head -1"))
    if latest_log == "" {
        println("未找到训练日志文件")
        return 1
    }

    println("最新日志: " + latest_log)
    println("")
    println("日志大小: " + trim(runtime_run_command_output("cd '" + log_dir + "' && du -h '" + latest_log + "' 2>/dev/null | cut -f1")))
    println("最后修改: " + trim(runtime_run_command_output("cd '" + log_dir + "' && ls -l '" + latest_log + "' 2>/dev/null | awk '{print $6, $7, $8}'")))
    println("")

    print_flag("数据清洁进程", runtime_run_command_output("pgrep -f clean_data 2>/dev/null") != "")
    print_flag("训练进程", runtime_run_command_output("pgrep -f 'neurx.*train' 2>/dev/null") != "")
    print_flag("S 编译器", runtime_file_exists("/home/shuwen/s/bin/s"))

    println("")
    if runtime_file_exists(project_root + "/dataset/pretrain/cleaned/pretrain_data_cleaned.jsonl") {
        println("数据清洁: 完成")
    } else {
        println("数据清洁: 未完成或进行中")
    }

    if runtime_file_exists(project_root + "/dataset/pretrain/manifest.json") {
        println("Manifest: 已生成")
    } else {
        println("Manifest: 未生成")
    }

    println("")
    println("最新日志内容 (最后20行):")
    println("─────────────────────────────────────────────────────────────────")
    println(trim(runtime_run_command_output("cd '" + log_dir + "' && tail -20 '" + latest_log + "'")))
    println("─────────────────────────────────────────────────────────────────")
    0
}

func print_flag(string name, bool ok) {
    if ok {
        println("✓ " + name + " 运行中")
    } else {
        println("✗ " + name + " 未运行")
    }
}
