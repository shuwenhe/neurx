package main
use neurx.runtime.io.{runtime_file_exists, runtime_run_command_output}
use std.io.println
func phase5_summary_command(string path) string {
    string cmd = "set -e; default=$(sed -n 's/.*\"default_prompt\": \"\\([^\"]*\\)\".*/\\1/p' '" + path + "' | head -1)"
    cmd = cmd + " && count=$(grep -c '\"name\"' '" + path + "')"
    cmd = cmd + " && tokens=$(sed -n 's/.*\"tokens_count\": \\([0-9][0-9]*\\).*/\\1/p' '" + path + "' | head -1)"
    cmd = cmd + " && printf 'prompts=%s default=%s tokens=%s\\n' \"$count\" \"$default\" \"$tokens\""
    cmd
}

func main() {
    string prompt_path = "tests/golden/prompts.json"
    if !runtime_file_exists(prompt_path) {
        println("phase5-golden-prompt FAIL missing_file=" + prompt_path)
        return 1
    }
    string summary = runtime_run_command_output(phase5_summary_command(prompt_path))
    if summary != "prompts=5 default=What is the treatment for chronic urinary tract infection? tokens=10\n" {
        println("phase5-golden-prompt FAIL summary_unavailable")
        return 1
    }
    println("phase5-golden-prompt PASS " + summary)
    0
}
