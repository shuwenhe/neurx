package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_shell_escape, trim}
use std.io.println
func main() {
    string config = runtime_env_get("NEURX_SKILLS_CONFIG", "workflows/agent/skills/config/sample.yaml")
    string generations_override = runtime_env_get("NEURX_SKILLS_GENERATIONS", "")
    string s_bin_override = runtime_env_get("S_BIN", runtime_env_get("S_COMPILER", ""))
    if !runtime_run_command("test -f " + runtime_shell_escape(config)).ok {
        println("config not found: " + config)
        return 1
    }
    string max_generations = default_if_empty(yaml_value(config, "max_generations"), "20")
    string promotion_threshold = default_if_empty(yaml_value(config, "promotion_threshold"), "85.0")
    string retire_threshold = default_if_empty(yaml_value(config, "retire_threshold"), "20.0")
    string min_success_rate = default_if_empty(yaml_value(config, "min_success_rate"), "0.80")
    string max_avg_steps = default_if_empty(yaml_value(config, "max_avg_steps"), "12")
    string output_dir = default_if_empty(yaml_value(config, "output_dir"), "artifacts/checkpoints/agent/skills")
    if generations_override != "" {
        max_generations = generations_override
    }
    string s_bin = s_bin_override
    if s_bin == "" {
        s_bin = runtime_run_command_output("command -v s 2>/dev/null || true")
    }
    if s_bin == "" {
        println("missing runnable s executable")
        return 1
    }
    string tmp_s = "/tmp/neurx_agent_skills_run_tmp.s"
    string tmp_ir = "/tmp/neurx_agent_skills_run_tmp.ir"
    string tmp_src = ""
    tmp_src = tmp_src + "package neurx.workflows.agent.skills.run_tmp\n\n"
    tmp_src = tmp_src + "use neurx.workflows.agent.skills.pipeline_runner.{run_agent_skills_workflow}\n\n"
    tmp_src = tmp_src + "func main() {\n"
    tmp_src = tmp_src + "    run_agent_skills_workflow(" + max_generations + ", " + promotion_threshold + ", " + retire_threshold + ", " + min_success_rate + ", " + max_avg_steps + ", " + runtime_shell_escape(output_dir) + ")\n"
    tmp_src = tmp_src + "    0\n}\n"
    _ = runtime_run_command("printf %s " + runtime_shell_escape(tmp_src) + " > " + runtime_shell_escape(tmp_s))
    if !runtime_run_command(runtime_shell_escape(s_bin) + " " + runtime_shell_escape(tmp_s) + " " + runtime_shell_escape(tmp_ir)).ok {
        return 1
    }
    println("Ran agent skills workflow with generations=" + max_generations + ", promote=" + promotion_threshold + ", retire=" + retire_threshold + ", min_success=" + min_success_rate + ", max_avg_steps=" + max_avg_steps + ", output=" + output_dir + ", s_bin=" + s_bin)
    0
}

func usage() {
    println("Usage: run_with_config.s")
    println("Configure via NEURX_SKILLS_CONFIG, NEURX_SKILLS_GENERATIONS and S_BIN.")
}

func yaml_value(string file, string key) string {
    string cmd = "awk -F\":\" '/^" + key + "[[:space:]]*:/ {gsub(/ /, \"\", $2); print $2; exit}' " + runtime_shell_escape(file)
    trim(runtime_run_command_output(cmd))
}

func default_if_empty(string value, string fallback) string {
    if value == "" {
        return fallback
    }
    value
}

