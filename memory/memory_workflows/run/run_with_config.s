package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_shell_escape, trim}
use std.io.println
func main() {
    string config = runtime_env_get("NEURX_MEMORY_CONFIG", "workflows/agent/memory/config/sample.yaml")
    string steps_override = runtime_env_get("NEURX_MEMORY_STEPS", "")
    string s_bin_override = runtime_env_get("S_BIN", runtime_env_get("S_COMPILER", ""))
    if !runtime_run_command("test -f " + runtime_shell_escape(config)).ok {
        println("config not found: " + config)
        return 1
    }
    string max_steps = default_if_empty(yaml_value(config, "max_steps"), "100")
    string dataset_manifest = default_if_empty(yaml_value(config, "dataset_manifest"), "data/agent/memory/mini_manifest.json")
    string output_dir = default_if_empty(yaml_value(config, "output_dir"), "artifacts/checkpoints/agent/memory")
    if steps_override != "" {
        max_steps = steps_override
    }
    string root = runtime_env_get("NEURX_ROOT", ".")
    string s_bin = s_bin_override
    if s_bin == "" {
        s_bin = runtime_run_command_output("command -v s 2>/dev/null || true")
    }
    if s_bin == "" {
        println("missing runnable s executable")
        return 1
    }
    string tmp_s = "/tmp/neurx_agent_memory_run_tmp.s"
    string tmp_ir = "/tmp/neurx_agent_memory_run_tmp.ir"
    string tmp_src = ""
    tmp_src = tmp_src + "package neurx.workflows.agent.memory.run_tmp\n\n"
    tmp_src = tmp_src + "use neurx.workflows.agent.memory.pipeline_runner.{run_agent_memory_workflow}\n\n"
    tmp_src = tmp_src + "func main() {\n"
    tmp_src = tmp_src + "    run_agent_memory_workflow(" + max_steps + ", " + runtime_shell_escape(output_dir) + ", " + runtime_shell_escape(dataset_manifest) + ")\n"
    tmp_src = tmp_src + "    0\n}\n"
    _ = runtime_run_command("printf %s " + runtime_shell_escape(tmp_src) + " > " + runtime_shell_escape(tmp_s))
    if !runtime_run_command(runtime_shell_escape(s_bin) + " " + runtime_shell_escape(tmp_s) + " " + runtime_shell_escape(tmp_ir)).ok {
        return 1
    }
    println("Ran agent memory workflow with steps=" + max_steps + ", dataset=" + dataset_manifest + ", output=" + output_dir + ", s_bin=" + s_bin + ", root=" + root)
    0
}


func usage() {
    println("Usage: run_with_config.s")
    println("Configure via NEURX_MEMORY_CONFIG, NEURX_MEMORY_STEPS and S_BIN.")
}


func yaml_value(string file, string key) string {
    string cmd = "awk -F\":\" '/^" + key + "[[:space:]]*:/ {sub(/^[[:space:]]*/, \"\", $2); gsub(/^\"|\"$/, \"\", $2); print $2; exit}' " + runtime_shell_escape(file)
    trim(runtime_run_command_output(cmd))
}


func default_if_empty(string value, string fallback) string {
    if value == "" {
        return fallback
    }
    value
}

