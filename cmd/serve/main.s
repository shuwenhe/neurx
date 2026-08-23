package main
use std.conv.parse_int_default as parse_int
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use neurx.serving.api.contracts.{serving_config, serving_validation_result, validate_serving_config}

func main() {
    string serve_bin = runtime_env_get("NEURX_SERVE_BIN", "")
    serving_config config = serving_config {
        model: runtime_env_get("NEURX_MODEL", ""),
        bind_address: runtime_env_get("NEURX_BIND_ADDRESS", "localhost"),
        port: parse_int(runtime_env_get("NEURX_PORT", "8000"), 8000),
        max_concurrency: parse_int(runtime_env_get("NEURX_MAX_CONCURRENCY", "128"), 128),
        request_timeout_ms: parse_int(runtime_env_get("NEURX_REQUEST_TIMEOUT_MS", "30000"), 30000),
        shutdown_grace_ms: parse_int(runtime_env_get("NEURX_SHUTDOWN_GRACE_MS", "30000"), 30000),
    }
    serving_validation_result validation = validate_serving_config(config)
    if !validation.valid {
        println("[neurx-serve] invalid configuration: " + validation.error_code + ": " + validation.error_message)
        return 2
    }
    if serve_bin == "" || !runtime_run_command("test -x " + runtime_shell_escape(serve_bin)).ok {
        println("[neurx-serve] NEURX_SERVE_BIN must reference an executable production server")
        return 3
    }
    println("[neurx-serve] model=" + config.model + " bind=" + config.bind_address)
    string command = "NEURX_MODEL=" + runtime_shell_escape(config.model)
        + " NEURX_BIND_ADDRESS=" + runtime_shell_escape(config.bind_address)
        + " NEURX_PORT=" + runtime_shell_escape(runtime_env_get("NEURX_PORT", "8000"))
        + " NEURX_MAX_CONCURRENCY=" + runtime_shell_escape(runtime_env_get("NEURX_MAX_CONCURRENCY", "128"))
        + " NEURX_REQUEST_TIMEOUT_MS=" + runtime_shell_escape(runtime_env_get("NEURX_REQUEST_TIMEOUT_MS", "30000"))
        + " NEURX_SHUTDOWN_GRACE_MS=" + runtime_shell_escape(runtime_env_get("NEURX_SHUTDOWN_GRACE_MS", "30000"))
        + " exec " + runtime_shell_escape(serve_bin)
    var result = runtime_run_command(command)
    if !result.ok {
        println("[neurx-serve] server exited with an error: " + result.error)
        return result.exit_code
    }
    0
}
