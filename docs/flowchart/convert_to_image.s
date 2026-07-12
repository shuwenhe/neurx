package main

use neurx.runtime.io.{runtime_file_exists, runtime_run_command, runtime_run_command_output, runtime_shell_escape}
use std.io.println

func main() int {
    string script_dir = runtime_run_command_output("cd " + runtime_shell_escape(".") + " >/dev/null 2>&1 && pwd")
    if script_dir == "" {
        script_dir = "."
    }
    string mmd_file = script_dir + "/neurx-code-architecture.mmd"
    string output_dir = script_dir

    println("==========================================")
    println("neurx-code Flowchart Converter")
    println("==========================================")
    println("")

    if !runtime_file_exists(mmd_file) {
        println("Error: " + mmd_file + " not found")
        return 1
    }

    println("Input: " + mmd_file)
    println("Output: " + output_dir)
    println("")

    if !runtime_run_command("command -v curl >/dev/null 2>&1").ok {
        println("curl not found")
        return 1
    }
    if !runtime_run_command("command -v jq >/dev/null 2>&1").ok {
        println("jq not found")
        return 1
    }

    string diagram_content = runtime_run_command_output("jq -Rs . < " + runtime_shell_escape(mmd_file))
    string payload = "{\"diagram_source\":" + diagram_content + "}"
    bool png_ok = runtime_run_command("curl -s -X POST -H 'Content-Type: application/json' -d " + runtime_shell_escape(payload) + " https://kroki.io/mermaid/png -o " + runtime_shell_escape(output_dir + "/neurx-code-architecture.png")).ok
    bool svg_ok = runtime_run_command("curl -s -X POST -H 'Content-Type: application/json' -d " + runtime_shell_escape(payload) + " https://kroki.io/mermaid/svg -o " + runtime_shell_escape(output_dir + "/neurx-code-architecture.svg")).ok

    if png_ok || svg_ok {
        println("Conversion finished")
        0
    } else if runtime_run_command("command -v mmdc >/dev/null 2>&1").ok {
        _ = runtime_run_command("mmdc -i " + runtime_shell_escape(mmd_file) + " -o " + runtime_shell_escape(output_dir + "/neurx-code-architecture.png"))
        _ = runtime_run_command("mmdc -i " + runtime_shell_escape(mmd_file) + " -o " + runtime_shell_escape(output_dir + "/neurx-code-architecture.svg"))
        0
    } else {
        println("All conversion methods failed")
        return 1
    }
}
