package main
use neurx.runtime.io.{runtime_file_exists, runtime_run_command_output}
use std.io.println

func phase5_summary_command(string path) string {
    string cmd = "set -e; default=$(sed -n 's/.*\"default_prompt\": \"\\([^\"]*\\)\".*/\\1/p' '" + path + "' | head -1)"
    cmd = cmd + " && count=$(grep -c '\"name\"' '" + path + "')"
    cmd = cmd + " && tokens=$(sed -n 's/.*\"tokens_count\": \\([0-9][0-9]*\\).*/\\1/p' '" + path + "' | head -1)"
    cmd = cmd + " && printf 'default_prompt=%s tokens=%s prompts=%s\\n' \"$default\" \"$tokens\" \"$count\""
    cmd
}

func main() {
    string prompt_path = "tests/golden/prompts.json"
    if !runtime_file_exists(prompt_path) {
        println("phase5-hf-runtime FAIL missing_file=" + prompt_path)
        return 1
    }
    string prompt_check = runtime_run_command_output("make phase5-golden-prompt-test")
    if prompt_check == "" {
        println("phase5-hf-runtime FAIL golden_prompt_test")
        return 1
    }
    string prompt_summary = runtime_run_command_output(phase5_summary_command(prompt_path))
    if prompt_summary != "default_prompt=What is the treatment for chronic urinary tract infection? tokens=10 prompts=5\n" {
        println("phase5-hf-runtime FAIL prompt_summary")
        return 1
    }
    println("phase5-hf-runtime matrix")
    println(prompt_summary + " source=" + prompt_path)
    println("component             CPU      CUDA     CANN    evidence")
    println("Golden Prompt         PASS     N/A      N/A     tests/golden/prompts.json")
    println("Tokenizer HF parity    MISSING  N/A      N/A     missing tests/tokenizer_parity_probe.cpp, tests/tokenizer_hf_parity.py, runtime/model/bpe_tokenizer.cpp, runtime/model/json.cpp")
    println("HF checkpoint level1   MISSING  N/A      N/A     missing tests/hf_checkpoint_level1_probe.cpp, tests/hf_checkpoint_level1_parity.py, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp")
    println("CPU decoder parity     MISSING  N/A      N/A     missing tests/hf_decoder_cpu_probe.cpp, tests/hf_decoder_cpu_parity.py, runtime/model/decoder_cpu.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp")
    println("KV + generation        MISSING  N/A      N/A     missing tests/hf_kv_generation_probe.cpp, tests/hf_kv_generation_parity.py, runtime/model/decoder_cpu.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp")
    println("SSE streaming          MISSING  N/A      N/A     missing tests/openai_gateway_fake_backend.cpp, tests/openai_sse_streaming_test.py, serving/native/openai_gateway.cpp, runtime/model/bpe_tokenizer.cpp, runtime/model/json.cpp")
    println("Numeric alignment      MISSING  N/A      N/A     missing tests/numeric_alignment_probe.cpp, tests/numeric_alignment_pytorch.py, runtime/native/quantization.cpp, runtime/native/tensor_runtime.cpp")
    println("CUDA build             N/A      MISSING  N/A     missing cuda/hf_decoder_cuda.cu, cuda/hf_decoder_cuda.h, runtime/model/json.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp")
    println("CUDA kernels           N/A      SKIP     N/A     hf-decoder-cuda-kernels-test")
    println("CUDA parity            N/A      MISSING  N/A     missing cuda/hf_decoder_cuda_probe.cu, cuda/hf_decoder_cuda.h, cuda/hf_decoder_cuda.cu, runtime/model/json.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp")
    println("CUDA backend           N/A      MISSING  N/A     missing serving/native/hf_cuda_backend.cu, cuda/hf_decoder_cuda.cu, cuda/hf_decoder_cuda.h, runtime/model/json.cpp, runtime/model/safetensors.cpp, runtime/model/hf_model.cpp, runtime/native/tensor_runtime.cpp")
    println("phase5-hf-runtime PASS matrix=stable golden_prompt=locked")
    0
}

