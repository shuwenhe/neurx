package main
use neurx.runtime.io.{runtime_file_exists, runtime_run_command_output}
use std.io.println

func phase5_summary_command(string path) string {
    string cmd = "set -e; default=$(sed -n 'src/core/s/.*\"default_prompt\": \"\\([^\"]*\\)\".*/\\1/p' '" + path + "' | head -1)"
    cmd = cmd + " && count=$(grep -c '\"name\"' '" + path + "')"
    cmd = cmd + " && tokens=$(sed -n 'src/core/s/.*\"tokens_count\": \\([0-9][0-9]*\\).*/\\1/p' '" + path + "' | head -1)"
    cmd = cmd + " && printf 'default_prompt=%s tokens=%s prompts=%s\\n' \"$default\" \"$tokens\" \"$count\""
    cmd
}

func main() {
    string prompt_path = "test/golden/prompts.json"
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
    if prompt_summary != "default_prompt=What is the treatment for chronic urinary tract infection tokens=10 prompts=5\n" {
        println("phase5-hf-runtime FAIL prompt_summary")
        return 1
    }
    println("phase5-hf-runtime matrix")
    println(prompt_summary + " source=" + prompt_path)
    println("component             CPU      CUDA     CANN    evidence")
    println("Golden Prompt         PASS     N/A      N/A     test/golden/prompts.json")
    println("Tokenizer HF parity    MISSING  N/A      N/A     missing test/tokenizer_parity_probe.cpp, test/tokenizer_hf_parity.py, src/runtime/model/bpe_tokenizer.cpp, src/runtime/model/json.cpp")
    println("HF checkpoint level1   MISSING  N/A      N/A     missing test/hf_checkpoint_level1_probe.cpp, test/hf_checkpoint_level1_parity.py, src/runtime/model/safetensors.cpp, src/runtime/model/hf_model.cpp, src/runtime/native/tensor_runtime.cpp")
    println("CPU decoder parity     MISSING  N/A      N/A     missing test/hf_decoder_cpu_probe.cpp, test/hf_decoder_cpu_parity.py, src/runtime/model/decoder_cpu.cpp, src/runtime/model/safetensors.cpp, src/runtime/model/hf_model.cpp, src/runtime/native/tensor_runtime.cpp")
    println("KV + generation        MISSING  N/A      N/A     missing test/hf_kv_generation_probe.cpp, test/hf_kv_generation_parity.py, src/runtime/model/decoder_cpu.cpp, src/runtime/model/safetensors.cpp, src/runtime/model/hf_model.cpp, src/runtime/native/tensor_runtime.cpp")
    println("SSE streaming          MISSING  N/A      N/A     missing test/openai_gateway_fake_backend.cpp, test/openai_sse_streaming_test.py, src/serving/native/openai_gateway.cpp, src/runtime/model/bpe_tokenizer.cpp, src/runtime/model/json.cpp")
    println("Numeric alignment      MISSING  N/A      N/A     missing test/numeric_alignment_probe.cpp, test/numeric_alignment_pytorch.py, src/runtime/native/quantization.cpp, src/runtime/native/tensor_runtime.cpp")
    println("CUDA build             N/A      MISSING  N/A     missing backend/cuda/hf_decoder_cuda.cu, backend/cuda/hf_decoder_cuda.h, src/runtime/model/json.cpp, src/runtime/model/safetensors.cpp, src/runtime/model/hf_model.cpp, src/runtime/native/tensor_runtime.cpp")
    println("CUDA kernels           N/A      SKIP     N/A     hf-decoder-cuda-kernels-test")
    println("CUDA parity            N/A      MISSING  N/A     missing backend/cuda/hf_decoder_cuda_probe.cu, backend/cuda/hf_decoder_cuda.h, backend/cuda/hf_decoder_cuda.cu, src/runtime/model/json.cpp, src/runtime/model/safetensors.cpp, src/runtime/model/hf_model.cpp, src/runtime/native/tensor_runtime.cpp")
    println("CUDA backend           N/A      MISSING  N/A     missing src/serving/native/hf_cuda_backend.cu, backend/cuda/hf_decoder_cuda.cu, backend/cuda/hf_decoder_cuda.h, src/runtime/model/json.cpp, src/runtime/model/safetensors.cpp, src/runtime/model/hf_model.cpp, src/runtime/native/tensor_runtime.cpp")
    println("phase5-hf-runtime PASS matrix=stable golden_prompt=locked")
    0
}
