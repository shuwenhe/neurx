package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_shell_escape, trim}
use std.io.println

func main() {
    string config = runtime_env_get("NEURX_ROBOTICS_OBSERVE_CONFIG", "workflows/robotics/train/config/sample.yaml")
    string steps_override = runtime_env_get("NEURX_ROBOTICS_OBSERVE_STEPS", "")
    if !runtime_run_command("test -f " + runtime_shell_escape(config)).ok {
        println("config not found: " + config)
        return 1
    }
    string obs_dim = default_if_empty(yaml_value(config, "obs_dim"), "8")
    string latent_dim = default_if_empty(yaml_value(config, "latent_dim"), "16")
    string act_dim = default_if_empty(yaml_value(config, "act_dim"), "4")
    string max_steps = default_if_empty(yaml_value(config, "max_steps"), "16")
    string sample_count = default_if_empty(yaml_value(config, "sample_count"), "64")
    string eval_every = default_if_empty(yaml_value(config, "eval_every"), "8")
    string save_every = default_if_empty(yaml_value(config, "save_every"), "16")
    string learning_rate = default_if_empty(yaml_value(config, "learning_rate"), "0.001")
    string task_name = default_if_empty(yaml_value(config, "task_name"), "robotics_workflow_default")
    if steps_override != "" {
        max_steps = steps_override
    }
    string root = runtime_run_command_output("git rev-parse --show-toplevel 2>/dev/null || pwd")
    if root == "" {
        root = "."
    }
    string s_compiler = runtime_run_command_output("command -v s 2>/dev/null || true")
    if s_compiler == "" {
        println("missing runnable s executable")
        return 1
    }
    string tmp_s = "/tmp/neurx_robotics_workflow_observe_tmp.s"
    string tmp_ir = "/tmp/neurx_robotics_workflow_observe_tmp.ir"
    string tmp_src = ""
    tmp_src = tmp_src + "package neurx.workflows.robotics.train.observe_tmp\n\n"
    tmp_src = tmp_src + "use neurx.workflows.robotics.train.pipeline_runner.{run_robotics_training_schedule_state, robotics_workflow_training_state, robotics_workflow_eval_count, robotics_workflow_save_count, robotics_workflow_last_eval_step, robotics_workflow_last_save_step, robotics_workflow_eval_interval, robotics_workflow_save_interval}\n"
    tmp_src = tmp_src + "use neurx.model.robotics.train.{robotics_trajectory_train_state}\n\n"
    tmp_src = tmp_src + "func main() {\n"
    tmp_src = tmp_src + "    let workflow = run_robotics_training_schedule_state(" + obs_dim + ", " + latent_dim + ", " + act_dim + ", " + max_steps + ", " + sample_count + ", " + eval_every + ", " + save_every + ", " + learning_rate + ", " + runtime_shell_escape(task_name) + ")\n"
    tmp_src = tmp_src + "    let training = robotics_workflow_training_state(workflow)\n"
    tmp_src = tmp_src + "    println(\"task_name: \" + " + runtime_shell_escape(task_name) + ")\n"
    tmp_src = tmp_src + "    println(\"final_step: \")\n"
    tmp_src = tmp_src + "    println(\"final_loss: \")\n"
    tmp_src = tmp_src + "    println(\"final_action_error: \")\n"
    tmp_src = tmp_src + "    println(\"eval_interval: \")\n"
    tmp_src = tmp_src + "    println(\"save_interval: \")\n"
    tmp_src = tmp_src + "    println(\"eval_count: \")\n"
    tmp_src = tmp_src + "    println(\"save_count: \")\n"
    tmp_src = tmp_src + "    println(\"last_eval_step: \")\n"
    tmp_src = tmp_src + "    println(\"last_save_step: \")\n"
    tmp_src = tmp_src + "    0\n}\n"
    _ = runtime_run_command("printf %s " + runtime_shell_escape(tmp_src) + " > " + runtime_shell_escape(tmp_s))
    if !runtime_run_command("make s-compile-runtime").ok {
        return 1
    }
    if !runtime_run_command(runtime_shell_escape(s_compiler) + " " + runtime_shell_escape(tmp_s) + " " + runtime_shell_escape(tmp_ir)).ok {
        return 1
    }
    println("Compiled robotics observation entrypoint with obs=" + obs_dim + ", latent=" + latent_dim + ", act=" + act_dim + ", steps=" + max_steps + ", samples=" + sample_count + ", eval_every=" + eval_every + ", save_every=" + save_every + ", lr=" + learning_rate + ", task=" + task_name)
    println("Note: current S CLI invocation validates compilation of the observation runner; it does not execute main() in this environment.")
    0
}

func usage() {
    println("Usage: observe_with_config.s")
    println("Configure via NEURX_ROBOTICS_OBSERVE_CONFIG and NEURX_ROBOTICS_OBSERVE_STEPS.")
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
