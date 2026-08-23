package main
use neurx.runtime.command.{runtime_env_get, runtime_parse_int, runtime_run_command_exit_code, runtime_shell_escape}
use neurx.training.api.contracts.{training_job_config, training_validation_result, validate_training_job}

func main() {
    string mode = runtime_env_get("NEURX_TRAIN_MODE", "pretrain")
    training_job_config config = training_job_config {
        job_id: runtime_env_get("NEURX_JOB_ID", ""),
        mode: mode,
        model: runtime_env_get("NEURX_MODEL", ""),
        backend: runtime_env_get("NEURX_BACKEND", "cuda"),
        dataset: runtime_env_get("NEURX_DATASET", ""),
        world_size: runtime_parse_int(runtime_env_get("WORLD_SIZE", "1"), 1),
        max_steps: runtime_parse_int(runtime_env_get("NEURX_MAX_STEPS", "1000"), 1000),
        checkpoint_interval: runtime_parse_int(runtime_env_get("NEURX_CHECKPOINT_INTERVAL", "100"), 100),
    }
    training_validation_result validation = validate_training_job(config)
    if !validation.valid {
        println("[neurx-train] invalid configuration: " + validation.error_code + ": " + validation.error_message)
        return 2
    }
    string root = runtime_env_get("NEURX_ROOT", ".")
    string target = "pretrain-gpu"
    if mode == "posttrain" { target = "posttrain-gpu" }
    println("[neurx-train] job=" + config.job_id + " mode=" + mode + " backend=" + config.backend)
    int exit_code = runtime_run_command_exit_code("make -C " + runtime_shell_escape(root) + " " + runtime_shell_escape(target))
    if exit_code != 0 {
        println("[neurx-train] launch failed")
        return exit_code
    }
    0
}
