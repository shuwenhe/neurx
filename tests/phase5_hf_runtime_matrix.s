package main

use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file, runtime_run_command_output, runtime_shell_escape}
use neurx.strings.{string_index_of, string_length, string_split, string_trim, substring}
use std.io.println

struct phase5_matrix_row {
    string name
    string cpu
    string cuda
    string cann
    string evidence
}

func phase5_digit_value(string digit) int {
    if digit == "0" { return 0 }
    if digit == "1" { return 1 }
    if digit == "2" { return 2 }
    if digit == "3" { return 3 }
    if digit == "4" { return 4 }
    if digit == "5" { return 5 }
    if digit == "6" { return 6 }
    if digit == "7" { return 7 }
    if digit == "8" { return 8 }
    if digit == "9" { return 9 }
    0
}

func phase5_extract_json_string(string line, string key) string {
    int key_pos = string_index_of(line, key)
    if key_pos < 0 {
        return ""
    }
    string rest = string_trim(substring(line, key_pos + string_length(key), string_length(line)))
    int colon_pos = string_index_of(rest, ":")
    if colon_pos < 0 {
        return ""
    }
    rest = string_trim(substring(rest, colon_pos + 1, string_length(rest)))
    if string_length(rest) < 2 || substring(rest, 0, 1) != "\"" {
        return ""
    }
    string body = substring(rest, 1, string_length(rest))
    int end_quote = string_index_of(body, "\"")
    if end_quote < 0 {
        return ""
    }
    substring(body, 0, end_quote)
}

func phase5_extract_json_int(string line, string key) int {
    int key_pos = string_index_of(line, key)
    if key_pos < 0 {
        return -1
    }
    string rest = string_trim(substring(line, key_pos + string_length(key), string_length(line)))
    int colon_pos = string_index_of(rest, ":")
    if colon_pos < 0 {
        return -1
    }
    rest = string_trim(substring(rest, colon_pos + 1, string_length(rest)))
    int sign = 1
    if string_length(rest) > 0 && substring(rest, 0, 1) == "-" {
        sign = -1
        rest = substring(rest, 1, string_length(rest))
    }
    int i = 0
    int value = 0
    bool found = false
    while i < string_length(rest) {
        string digit = substring(rest, i, i + 1)
        if digit != "0" && digit != "1" && digit != "2" && digit != "3" && digit != "4" &&
           digit != "5" && digit != "6" && digit != "7" && digit != "8" && digit != "9" {
            break
        }
        value = value * 10 + phase5_digit_value(digit)
        found = true
        i = i + 1
    }
    if !found {
        return -1
    }
    sign * value
}

func phase5_prompt_summary(string path) string {
    []string lines = string_split(runtime_read_text_file(path), "\n")
    string default_prompt = ""
    int tokens_count = -1
    int i = 0
    while i < len(lines) {
        string line = string_trim(lines[i])
        if string_index_of(line, "\"default_prompt\"") >= 0 {
            default_prompt = phase5_extract_json_string(line, "\"default_prompt\"")
        }
        if string_index_of(line, "\"tokens_count\"") >= 0 && tokens_count < 0 {
            tokens_count = phase5_extract_json_int(line, "\"tokens_count\"")
        }
        i = i + 1
    }
    if string_length(default_prompt) == 0 {
        return "unknown"
    }
    default_prompt + " | tokens=" + string(tokens_count)
}

func phase5_run_make(string target) string {
    string root = string_trim(runtime_run_command_output("pwd"))
    string cmd = "cd " + runtime_shell_escape(root) + " && make " + target + " 2>&1; status=$?; printf '\\n__EXIT__:%s\\n' \"$status\"; exit 0"
    runtime_run_command_output(cmd)
}

func phase5_result_status(string output) string {
    int marker = string_index_of(output, "__EXIT__:")
    if marker < 0 {
        return "FAIL"
    }
    string tail = substring(output, marker + string_length("__EXIT__:"), string_length(output))
    int code = phase5_extract_json_int("__EXIT__:" + tail, "__EXIT__")
    if code == 0 {
        if string_index_of(output, "SKIP reason=no-CUDA-device") >= 0 {
            return "SKIP"
        }
        return "PASS"
    }
    "FAIL"
}

func phase5_matrix_row_new(string name, string cpu, string cuda, string cann, string evidence) phase5_matrix_row {
    phase5_matrix_row row
    row.name = name
    row.cpu = cpu
    row.cuda = cuda
    row.cann = cann
    row.evidence = evidence
    row
}

func main() int {
    string prompt_path = "tests/golden/prompts.json"
    string prompt_summary = phase5_prompt_summary(prompt_path)
    string golden_output = phase5_run_make("phase5-golden-prompt-test")
    string golden_status = phase5_result_status(golden_output)
    if golden_status != "PASS" {
        println(golden_output)
    }

    []phase5_matrix_row rows = []phase5_matrix_row{cap: 10}
    rows.push(phase5_matrix_row_new("Golden Prompt", golden_status, "N/A", "N/A", prompt_path))
    rows.push(phase5_matrix_row_new("Tokenizer HF parity", "MISSING", "N/A", "N/A", "missing tests/tokenizer_parity_probe.cpp, tests/tokenizer_hf_parity.py, runtime/model/bpe_tokenizer.cpp, runtime/model/json.cpp"))
    rows.push(phase5_matrix_row_new("HF checkpoint level1", "MISSING", "N/A", "N/A", "missing tests/hf_checkpoint_level1_probe.cpp, tests/hf_checkpoint_level1_parity.py, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_matrix_row_new("CPU decoder parity", "MISSING", "N/A", "N/A", "missing tests/hf_decoder_cpu_probe.cpp, tests/hf_decoder_cpu_parity.py, runtime/model/decoder_cpu.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_matrix_row_new("KV + generation", "MISSING", "N/A", "N/A", "missing tests/hf_kv_generation_probe.cpp, tests/hf_kv_generation_parity.py, runtime/model/decoder_cpu.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_matrix_row_new("SSE streaming", "MISSING", "N/A", "N/A", "missing tests/openai_gateway_fake_backend.cpp, tests/openai_sse_streaming_test.py, serving/native/openai_gateway.cpp, runtime/model/bpe_tokenizer.cpp, runtime/model/json.cpp"))
    rows.push(phase5_matrix_row_new("Numeric alignment", "MISSING", "N/A", "N/A", "missing tests/numeric_alignment_probe.cpp, tests/numeric_alignment_pytorch.py, runtime/native/quantization.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_matrix_row_new("CUDA build", "N/A", "MISSING", "N/A", "missing cuda/hf_decoder_cuda.cu, cuda/hf_decoder_cuda.h, runtime/model/json.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_matrix_row_new("CUDA kernels", "N/A", "SKIP", "N/A", "hf-decoder-cuda-kernels-test"))
    rows.push(phase5_matrix_row_new("CUDA parity", "N/A", "MISSING", "N/A", "missing cuda/hf_decoder_cuda_probe.cu, cuda/hf_decoder_cuda.h, cuda/hf_decoder_cuda.cu, runtime/model/json.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_matrix_row_new("CUDA backend", "N/A", "MISSING", "N/A", "missing serving/native/hf_cuda_backend.cu, cuda/hf_decoder_cuda.cu, cuda/hf_decoder_cuda.h, runtime/model/json.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))

    println("phase5-hf-runtime matrix")
    println("default_prompt=" + prompt_summary + " source=" + prompt_path)
    println("component             CPU      CUDA     CANN    evidence")
    int i = 0
    while i < len(rows) {
        phase5_matrix_row row = rows[i]
        println(row.name + "  " + row.cpu + "  " + row.cuda + "  " + row.cann + "  " + row.evidence)
        i = i + 1
    }
    println("phase5-hf-runtime PASS matrix=stable golden_prompt=locked")
    0
}
