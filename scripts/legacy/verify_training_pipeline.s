package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output}
use std.io.println
func main() {
    let project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    println("==========================================")
    println("NeurX Training Pipeline - S Verification")
    println("==========================================")
    println("")
    let pass_count = 0
    let total_count = 0
    total_count = total_count + 1
    if check_file(project_root + "/training/training_pipeline.s", "trainingEnglish textmainEnglish text") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/example/complete_training_example.s", "completetrainingexample") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/tests/test_training_pipeline.s", "testEnglish text") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/TRAINING_PIPELINE_GUIDE.md", "APIEnglish textuseEnglish text") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/TRAINING_PIPELINE_IMPLEMENTATION.md", "implementationEnglish text") {
        pass_count = pass_count + 1
    }
    total_count = total_count + 1
    if check_file(project_root + "/TRAINING_PIPELINE_COMPLETE_SUMMARY.md", "English text") {
        pass_count = pass_count + 1
    }
    println("")
    if pass_count == total_count {
        println("English text: English text")
        println("English textstate: English text")
        return 0
    }
    println("English text: English text")
    println("English textstate: English text")
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

