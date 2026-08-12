package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_shell_escape}
use std.io.println
func main() {
    string config = runtime_env_get("NEURX_PRETRAIN_CONFIG", "workflows/llm/pretrain/config/sample.yaml")
    string steps_override = runtime_env_get("NEURX_PRETRAIN_STEPS_OVERRIDE", "")
    string s_bin_override = runtime_env_get("S_BIN", runtime_env_get("S_COMPILER", ""))
    string root = runtime_run_command_output("git rev-parse --show-toplevel 2>/dev/null || pwd")
    if root == "" {
        root = "."
    }
    if !runtime_run_command("test -f " + runtime_shell_escape(config)).ok {
        println("config not found: " + config)
        return 1
    }
    string max_steps = yaml_value(config, "max_steps")
    if steps_override != "" {
        max_steps = steps_override
    }
    if max_steps == "" {
        max_steps = "0"
    }
    string micro_batch = default_if_empty(yaml_value(config, "micro_batch_size"), "8")
    string seq_len = default_if_empty(yaml_value(config, "seq_len"), "16")
    string lr = default_if_empty(yaml_value(config, "lr"), "0.00015")
    string warmup_steps = default_if_empty(yaml_value(config, "warmup_steps"), "128")
    string min_lr = default_if_empty(yaml_value(config, "min_lr"), "0.00003")
    string weight_decay = default_if_empty(yaml_value(config, "weight_decay"), "0.1")
    string dataset_manifest = default_if_empty(yaml_value(config, "dataset_manifest"), "data/pretrain/mini_manifest.json")
    string output_dir = default_if_empty(yaml_value(config, "output_dir"), "artifacts/checkpoints/run_20260518_001")
    string checkpoint_root = default_if_empty(yaml_value(config, "checkpoint_root"), output_dir)
    string log_interval = default_if_empty(yaml_value(config, "log_interval"), "8")
    string eval_interval = default_if_empty(yaml_value(config, "eval_interval"), "16")
    string save_interval = default_if_empty(yaml_value(config, "save_interval"), "32")
    string tp_degree = default_if_empty(yaml_value(config, "tensor_parallel_degree"), "4")
    string pp_degree = default_if_empty(yaml_value(config, "pipeline_parallel_degree"), "2")
    string dp_degree = default_if_empty(yaml_value(config, "data_parallel_degree"), "1")
    string sp_degree = default_if_empty(yaml_value(config, "sequence_parallel_degree"), "1")
    string zero_stage = default_if_empty(yaml_value(config, "zero_stage"), "2")
    string hidden_dim = default_if_empty(yaml_value(config, "hidden_dim"), "128")
    string num_layers = default_if_empty(yaml_value(config, "num_layers"), "4")
    string num_attn_heads = default_if_empty(yaml_value(config, "num_attention_heads"), "8")
    string num_kv_heads = default_if_empty(yaml_value(config, "num_kv_heads"), "2")
    string intermediate_dim = default_if_empty(yaml_value(config, "intermediate_dim"), "512")
    string vocab_size = default_if_empty(yaml_value(config, "vocab_size"), "4096")
    println("LLM pretrain workflow (S)")
    println("config: " + config)
    println("Steps : " + max_steps)
    string s_bin = s_bin_override
    if s_bin == "" {
        s_bin = runtime_run_command_output("command -v s 2>/dev/null || true")
    }
    if s_bin == "" {
        println("missing runnable s executable")
        return 1
    }
    string tmp_s = "/tmp/neurx_llm_pretrain_run_tmp.s"
    string tmp_ir = "/tmp/neurx_llm_pretrain_run_tmp.ir"
    string tmp_src = ""
    tmp_src = tmp_src + "package neurx.workflows.llm.pretrain.run_tmp\n\n"
    tmp_src = tmp_src + "use neurx.workflows.llm.pretrain.run.pipeline_runner.{run_pretrain_with_distributed_config}\n\n"
    tmp_src = tmp_src + "func main() {\n"
    tmp_src = tmp_src + "  run_pretrain_with_distributed_config(" + micro_batch + ", " + seq_len + ", " + lr + ", " + max_steps + ", " + warmup_steps + ", " + min_lr + ", " + weight_decay + ", " + log_interval + ", " + eval_interval + ", " + save_interval + ", " + runtime_shell_escape(dataset_manifest) + ", " + runtime_shell_escape(checkpoint_root) + ", " + tp_degree + ", " + pp_degree + ", " + dp_degree + ", " + sp_degree + ", " + zero_stage + ", " + hidden_dim + ", " + num_layers + ", " + num_attn_heads + ", " + num_kv_heads + ", " + intermediate_dim + ", " + vocab_size + ")\n"
    tmp_src = tmp_src + "  0\n}\n"
    _ = runtime_run_command("printf %s " + runtime_shell_escape(tmp_src) + " > " + runtime_shell_escape(tmp_s))
    if !runtime_run_command(runtime_shell_escape(s_bin) + " " + runtime_shell_escape(tmp_s) + " " + runtime_shell_escape(tmp_ir)).ok {
        return 1
    }
    println("Compiled pretrain workflow entrypoint with steps=" + max_steps + ", micro_batch=" + micro_batch + ", seq_len=" + seq_len + ", lr=" + lr + ", model=" + hidden_dim + "h/" + num_layers + "l/" + num_attn_heads + "q/" + num_kv_heads + "kv/" + intermediate_dim + "ff/" + vocab_size + "v, log/eval/save=" + log_interval + "/" + eval_interval + "/" + save_interval + ", manifest=" + dataset_manifest + ", checkpoint_root=" + checkpoint_root + ", tp/pp/dp/sp/zero=" + tp_degree + "/" + pp_degree + "/" + dp_degree + "/" + sp_degree + "/" + zero_stage)
    0
}

func usage() {
    println("Usage: run_with_config.s")
    println("Configure via NEURX_PRETRAIN_CONFIG, NEURX_PRETRAIN_STEPS_OVERRIDE and S_BIN.")
}

func yaml_value(string file, string key) string {
    string cmd = "awk -F\":\" '/^" + key + "[[:space:]]*:/ {sub(/^[[:space:]]*/, \"\", $2); gsub(/^\"|\"$/, \"\", $2); gsub(/ /, \"\", $2); print $2; exit}' " + runtime_shell_escape(file)
    string value = runtime_run_command_output(cmd)
    trim(value)
}

func default_if_empty(string value, string fallback) string {
    if value == "" {
        return fallback
    }
    value
}

