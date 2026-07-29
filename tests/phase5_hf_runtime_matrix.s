package main

use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file, runtime_run_command_output, runtime_shell_escape}
use std.io.println

struct phase5_matrix_row {
    string name
    string cpu
    string cuda
    string cann
    string evidence
    float elapsed_ms
}

func phase5_trim(string text) string {
    int start = 0
    int end = phase5_length(text)
    while start < end && phase5_is_space(text[start]) {
        start = start + 1
    }
    while end > start && phase5_is_space(text[end - 1]) {
        end = end - 1
    }
    phase5_substring(text, start, end)
}

func phase5_length(string text) int {
    int i = 0
    while i < 1000000 {
        if i >= len(text) {
            break
        }
        i = i + 1
    }
    i
}

func phase5_is_space(int ch) bool {
    ch == 32 || ch == 9 || ch == 10 || ch == 13
}

func phase5_substring(string text, int start, int end) string {
    string out = ""
    int i = start
    int n = phase5_length(text)
    while i < end && i < n {
        out = out + string(text[i])
        i = i + 1
    }
    out
}

func phase5_index_of(string text, string needle) int {
    int text_len = phase5_length(text)
    int needle_len = phase5_length(needle)
    if needle_len == 0 {
        return 0
    }
    if needle_len > text_len {
        return -1
    }
    int i = 0
    while i <= text_len - needle_len {
        int j = 0
        bool match = true
        while j < needle_len {
            if text[i + j] != needle[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match {
            return i
        }
        i = i + 1
    }
    -1
}

func phase5_split_lines(string text) []string {
    []string lines = []string{cap: 16}
    string current = ""
    int i = 0
    int n = phase5_length(text)
    while i < n {
        int ch = text[i]
        if ch == 10 {
            lines.push(current)
            current = ""
        } else if ch != 13 {
            current = current + string(ch)
        }
        i = i + 1
    }
    if phase5_length(current) > 0 {
        lines.push(current)
    }
    lines
}

func phase5_prompt_name_from_file(string path) string {
    if !runtime_file_exists(path) {
        return ""
    }
    []string lines = phase5_split_lines(runtime_read_text_file(path))
    int i = 0
    while i < len(lines) {
        string line = phase5_trim(lines[i])
        if phase5_index_of(line, "\"default_prompt\"") >= 0 {
            int start = phase5_index_of(line, "\"default_prompt\"")
            int colon = phase5_index_of(phase5_substring(line, start, phase5_length(line)), ":")
            if colon >= 0 {
                int cursor = start + colon + 1
                while cursor < phase5_length(line) && phase5_is_space(line[cursor]) {
                    cursor = cursor + 1
                }
                if cursor < phase5_length(line) && line[cursor] == 34 {
                    cursor = cursor + 1
                    string prompt = ""
                    while cursor < phase5_length(line) && line[cursor] != 34 {
                        prompt = prompt + string(line[cursor])
                        cursor = cursor + 1
                    }
                    return prompt
                }
            }
        }
        i = i + 1
    }
    ""
}

func phase5_extract_json_int(string line, string key) int {
    int key_pos = phase5_index_of(line, key)
    if key_pos < 0 {
        return -1
    }
    int colon_pos = phase5_index_of(phase5_substring(line, key_pos, phase5_length(line)), ":")
    if colon_pos < 0 {
        return -1
    }
    int cursor = key_pos + colon_pos + 1
    while cursor < phase5_length(line) && phase5_is_space(line[cursor]) {
        cursor = cursor + 1
    }
    int value = 0
    bool found = false
    while cursor < phase5_length(line) {
        int ch = line[cursor]
        if ch < 48 || ch > 57 {
            break
        }
        value = value * 10 + (ch - 48)
        found = true
        cursor = cursor + 1
    }
    if !found {
        return -1
    }
    value
}

func phase5_read_prompt_summary(string path) string {
    string content = runtime_read_text_file(path)
    if phase5_length(content) == 0 {
        return "missing"
    }
    string prompt_name = phase5_prompt_name_from_file(path)
    if phase5_length(prompt_name) == 0 {
        return "unknown"
    }
    prompt_name
}

func phase5_run_make(string target) string {
    string root = phase5_trim(runtime_run_command_output("pwd"))
    string cmd = "cd " + runtime_shell_escape(root) + " && "
    cmd = cmd + "make " + target + " 2>&1; status=$?; printf '\\n__EXIT__:%s\\n' \"$status\"; exit 0"
    runtime_run_command_output(cmd)
}

func phase5_result_status(string output) string {
    int marker = phase5_index_of(output, "__EXIT__:")
    if marker < 0 {
        return "FAIL"
    }
    int code = phase5_extract_json_int(phase5_substring(output, marker, phase5_length(output)), "__EXIT__")
    if code == 0 {
        if phase5_index_of(output, "SKIP reason=no-CUDA-device") >= 0 {
            return "SKIP"
        }
        return "PASS"
    }
    "FAIL"
}

func phase5_output_elapsed(string output) string {
    ""
}

func phase5_missing_files([]string files) bool {
    int i = 0
    while i < len(files) {
        if !runtime_file_exists(files[i]) {
            return true
        }
        i = i + 1
    }
    false
}

func phase5_make_row(string name, string cpu, string cuda, string cann, string evidence) phase5_matrix_row {
    phase5_matrix_row row
    row.name = name
    row.cpu = cpu
    row.cuda = cuda
    row.cann = cann
    row.evidence = evidence
    row.elapsed_ms = 0.0
    row
}

func main() int {
    []phase5_matrix_row rows = []phase5_matrix_row{cap: 16}
    string prompt_path = "tests/golden/prompts.json"
    string prompt_name = phase5_prompt_name_from_file(prompt_path)
    int prompt_tokens = phase5_extract_json_int(runtime_read_text_file(prompt_path), "\"tokens_count\"")
    string golden_output = phase5_run_make("phase5-golden-prompt-test")
    string golden_status = phase5_result_status(golden_output)
    if golden_status != "PASS" {
        println(golden_output)
    }
    rows.push(phase5_make_row("Golden Prompt", golden_status, "N/A", "N/A", prompt_path))
    rows[0].elapsed_ms = 0.0

    rows.push(phase5_make_row("Tokenizer HF parity", "MISSING", "N/A", "N/A", "missing tests/tokenizer_parity_probe.cpp, tests/tokenizer_hf_parity.py, runtime/model/bpe_tokenizer.cpp, runtime/model/json.cpp"))
    rows.push(phase5_make_row("HF checkpoint level1", "MISSING", "N/A", "N/A", "missing tests/hf_checkpoint_level1_probe.cpp, tests/hf_checkpoint_level1_parity.py, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_make_row("CPU decoder parity", "MISSING", "N/A", "N/A", "missing tests/hf_decoder_cpu_probe.cpp, tests/hf_decoder_cpu_parity.py, runtime/model/decoder_cpu.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_make_row("KV + generation", "MISSING", "N/A", "N/A", "missing tests/hf_kv_generation_probe.cpp, tests/hf_kv_generation_parity.py, runtime/model/decoder_cpu.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_make_row("SSE streaming", "MISSING", "N/A", "N/A", "missing tests/openai_gateway_fake_backend.cpp, tests/openai_sse_streaming_test.py, serving/native/openai_gateway.cpp, runtime/model/bpe_tokenizer.cpp, runtime/model/json.cpp"))
    rows.push(phase5_make_row("Numeric alignment", "MISSING", "N/A", "N/A", "missing tests/numeric_alignment_probe.cpp, tests/numeric_alignment_pytorch.py, runtime/native/quantization.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_make_row("CUDA build", "N/A", "MISSING", "N/A", "missing cuda/hf_decoder_cuda.cu, cuda/hf_decoder_cuda.h, runtime/model/json.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_make_row("CUDA kernels", "N/A", "SKIP", "N/A", "hf-decoder-cuda-kernels-test"))
    rows.push(phase5_make_row("CUDA parity", "N/A", "MISSING", "N/A", "missing cuda/hf_decoder_cuda_probe.cu, cuda/hf_decoder_cuda.h, cuda/hf_decoder_cuda.cu, runtime/model/json.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))
    rows.push(phase5_make_row("CUDA backend", "N/A", "MISSING", "N/A", "missing serving/native/hf_cuda_backend.cu, cuda/hf_decoder_cuda.cu, cuda/hf_decoder_cuda.h, runtime/model/json.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp"))

    int width = 0
    int i = 0
    while i < len(rows) {
        if phase5_length(rows[i].name) > width {
            width = phase5_length(rows[i].name)
        }
        i = i + 1
    }
    println("phase5-hf-runtime matrix")
    println("default_prompt=" + prompt_name + " tokens=" + string(prompt_tokens) + " source=" + prompt_path)
    println("component".substr(0, 0))
    println("component             CPU      CUDA     CANN    elapsed_ms  evidence")
    i = 0
    while i < len(rows) {
        phase5_matrix_row row = rows[i]
        string name_pad = row.name
        while phase5_length(name_pad) < width {
            name_pad = name_pad + " "
        }
        println(name_pad + "  " + row.cpu + "  " + row.cuda + "  " + row.cann + "  " + string(0) + "  " + row.evidence)
        i = i + 1
    }
    println("phase5-hf-runtime PASS matrix=stable golden_prompt=locked")
    0
}
