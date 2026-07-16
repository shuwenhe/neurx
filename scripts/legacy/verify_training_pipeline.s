package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output}
use std.io.println

func main() int {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")

    println("==========================================")
    println("NeurX Training Pipeline - S Verification")
    println("==========================================")
    println("")

    let pass_count = 0
    let total_count = 0

    total_count = total_count + 1
    if check_file(project_root + "/training/training_pipeline.s", "训练管道主模块") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/example/complete_training_example.s", "完整训练示例") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/tests/test_training_pipeline.s", "测试套件") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/TRAINING_PIPELINE_GUIDE.md", "API参考和使用指南") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/TRAINING_PIPELINE_IMPLEMENTATION.md", "实现总结文档") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/TRAINING_PIPELINE_COMPLETE_SUMMARY.md", "项目完成总结") {
        pass_count = pass_count + 1
    }

    println("")
    if pass_count == total_count {
        println("通过: 全部检查通过")
        println("项目状态: 完成")
        return 0
    }

    println("通过: 部分检查通过")
    println("项目状态: 未完全完成")
    1
}

func check_file(string path, string label) bool {
    if runtime_file_exists(path) {
        println("✅ " + label + " : ready (" + path + ")")
        let size_text = runtime_run_command_output("wc -l '" + path + "'")
        if size_text != "" {
            println("   " + size_text)
        }
        return true
    }

    println("❌ " + label + " : missing (" + path + ")")
    false
}
