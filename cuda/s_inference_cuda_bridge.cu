#include "hf_decoder_cuda.h"
#include "../runtime/model/bpe_tokenizer.h"

#include <cuda_runtime.h>

#include <algorithm>
#include <cstdint>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using neurx::cuda::hf_cuda_kv_cache;
using neurx::cuda::hf_decoder_cuda;
using neurx::runtime::model::bpe_tokenizer;

std::unique_ptr<hf_decoder_cuda> g_model;
std::unique_ptr<bpe_tokenizer> g_tokenizer;
std::unique_ptr<hf_cuda_kv_cache> g_cache;
std::vector<float> g_logits;
std::vector<int32_t> g_generated;
std::vector<int32_t> g_stop_tokens;
std::string g_output;
std::string g_error;
std::string g_device_name;

void set_error(const std::exception& error) { g_error = error.what(); }

bool is_stop_token(int32_t token) {
  return std::find(g_stop_tokens.begin(), g_stop_tokens.end(), token) != g_stop_tokens.end();
}

std::string chat_prompt(const std::string& prompt) {
  if (prompt.find("<|im_start|>") != std::string::npos) return prompt;
  return "<|im_start|>system\n"
         "You are a helpful assistant. Answer accurately and directly.\n"
         "<|im_end|>\n<|im_start|>user\n" +
         prompt + "\n<|im_end|>\n<|im_start|>assistant\n";
}

}  // namespace

extern "C" int neurx_s_cuda_device_count() {
  int count = 0;
  return cudaGetDeviceCount(&count) == cudaSuccess ? count : 0;
}

extern "C" const char* neurx_s_cuda_device_name() { return g_device_name.c_str(); }

extern "C" const char* neurx_s_cuda_last_error() { return g_error.c_str(); }

extern "C" int neurx_s_cuda_initialize(const char* model_directory, int device) {
  try {
    g_error.clear();
    int count = 0;
    const cudaError_t count_status = cudaGetDeviceCount(&count);
    if (count_status != cudaSuccess || count <= 0) {
      throw std::runtime_error("no local CUDA GPU is available");
    }
    if (device < 0 || device >= count) {
      throw std::runtime_error("NEURX_CUDA_DEVICE is outside the local GPU range");
    }
    cudaDeviceProp properties{};
    if (cudaGetDeviceProperties(&properties, device) != cudaSuccess) {
      throw std::runtime_error("failed to query the local CUDA GPU");
    }
    g_device_name = properties.name;
    const std::string directory = model_directory == nullptr ? "" : model_directory;
    if (directory.empty()) throw std::runtime_error("NEURX_MODEL_DIR is required");

    g_tokenizer = std::make_unique<bpe_tokenizer>(bpe_tokenizer::from_directory(directory));
    g_model = std::make_unique<hf_decoder_cuda>(directory, device);
    g_cache = std::make_unique<hf_cuda_kv_cache>();
    g_stop_tokens.clear();
    for (const char* marker : {"<|endoftext|>", "<|im_end|>"}) {
      const int32_t id = g_tokenizer->token_id(marker);
      if (id >= 0) g_stop_tokens.push_back(id);
    }
    if (g_stop_tokens.empty()) throw std::runtime_error("Qwen stop tokens are missing");
    return 0;
  } catch (const std::exception& error) {
    set_error(error);
    g_model.reset();
    g_tokenizer.reset();
    g_cache.reset();
    return -1;
  }
}

extern "C" int neurx_s_cuda_begin(const char* prompt, int maximum_new_tokens) {
  try {
    g_error.clear();
    if (!g_model || !g_tokenizer || !g_cache) {
      throw std::runtime_error("NeurX CUDA runtime is not initialized");
    }
    if (maximum_new_tokens <= 0) throw std::runtime_error("max_new_tokens must be positive");
    std::vector<int32_t> input = g_tokenizer->encode(
        chat_prompt(prompt == nullptr ? "" : prompt), true);
    const std::size_t context =
        static_cast<std::size_t>(g_model->config().max_position_embeddings);
    const std::size_t reserve = std::min<std::size_t>(maximum_new_tokens, context - 1);
    if (input.size() + reserve > context) {
      input.erase(input.begin(), input.begin() + (input.size() + reserve - context));
    }
    if (input.empty()) throw std::runtime_error("prompt tokenization produced no tokens");
    g_cache = std::make_unique<hf_cuda_kv_cache>();
    g_generated.clear();
    g_output.clear();
    g_logits = g_model->prefill(input, g_cache.get());
    return static_cast<int>(input.size());
  } catch (const std::exception& error) {
    set_error(error);
    return -1;
  }
}

extern "C" int neurx_s_cuda_next() {
  try {
    g_error.clear();
    if (!g_model || !g_tokenizer || !g_cache || g_logits.empty()) {
      throw std::runtime_error("NeurX CUDA generation session is not ready");
    }
    const int32_t token = hf_decoder_cuda::greedy(g_logits);
    if (is_stop_token(token)) return -1;
    g_generated.push_back(token);
    g_logits = g_model->decode(token, g_cache.get());
    return token;
  } catch (const std::exception& error) {
    set_error(error);
    return -2;
  }
}

extern "C" const char* neurx_s_cuda_result() {
  try {
    g_error.clear();
    if (!g_tokenizer) throw std::runtime_error("NeurX CUDA tokenizer is not initialized");
    g_output = g_tokenizer->decode(g_generated, true);
    return g_output.c_str();
  } catch (const std::exception& error) {
    set_error(error);
    g_output.clear();
    return g_output.c_str();
  }
}
