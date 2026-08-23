package main
use std.conv.parse_int_default as parse_int
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func valid_engine(string engine) bool {
    engine == "neurx" || engine == "vllm" || engine == "sglang"
}

func main() {
    string benchmark_bin = runtime_env_get("NEURX_BENCHMARK_BIN", "")
    string engine = runtime_env_get("NEURX_BENCHMARK_ENGINE", "")
    string output = runtime_env_get("NEURX_BENCHMARK_OUTPUT", "")
    string model = runtime_env_get("NEURX_MODEL", "")
    string validator = runtime_env_get("NEURX_BENCHMARK_VALIDATOR", "tools/validate_benchmark_result.js")
    string repetitions_text = runtime_env_get("NEURX_BENCHMARK_REPETITIONS", "3")
    int repetitions = parse_int(repetitions_text, 0)
    if benchmark_bin == "" || output == "" || model == "" || !valid_engine(engine) || repetitions < 3 {
        println("[neurx-benchmark] executable, output, model, valid engine, and at least three repetitions are required")
        return 2
    }
    if !runtime_run_command("test -x " + runtime_shell_escape(benchmark_bin)).ok {
        println("[neurx-benchmark] benchmark binary is not executable")
        return 3
    }
    string command = "NEURX_BENCHMARK_ENGINE=" + runtime_shell_escape(engine)
        + " NEURX_BENCHMARK_OUTPUT=" + runtime_shell_escape(output)
        + " NEURX_BENCHMARK_REPETITIONS=" + runtime_shell_escape(repetitions_text)
        + " NEURX_MODEL=" + runtime_shell_escape(model)
        + " exec " + runtime_shell_escape(benchmark_bin)
    var result = runtime_run_command(command)
    if !result.ok {
        println("[neurx-benchmark] measurement failed: " + result.error)
        return result.exit_code
    }
    if !runtime_run_command("test -s " + runtime_shell_escape(output)).ok {
        println("[neurx-benchmark] benchmark did not produce a non-empty result")
        return 4
    }
    if !runtime_run_command("node " + runtime_shell_escape(validator) + " " + runtime_shell_escape(output)).ok {
        println("[neurx-benchmark] result does not satisfy the benchmark schema")
        return 5
    }
    println("[neurx-benchmark] measured result: " + output)
    0
}
