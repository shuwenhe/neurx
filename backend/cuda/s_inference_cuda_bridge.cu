#include "hf_decoder_cuda.h"
#include "../../src/runtime/model/bpe_tokenizer.h"

#include <cuda_runtime.h>

#include <algorithm>
#include <cstdint>
#include <memory>
#include <stdexcept>
#include <string>
#include <mutex>
#include <unordered_map>
#include <vector>

namespace {

using neurx::cuda::hf_cuda_kv_cache;
using neurx::cuda::hf_decoder_cuda;
using neurx::runtime::model::bpe_tokenizer;

struct generation_session {
  std::mutex mutex;
  std::unique_ptr<hf_cuda_kv_cache> cache = std::make_unique<hf_cuda_kv_cache>();
  std::vector<float> logits;
  std::vector<int32_t> generated;
  std::string output;
  std::string error;
};

std::unique_ptr<hf_decoder_cuda> g_model;
std::unique_ptr<bpe_tokenizer> g_tokenizer;
std::vector<int32_t> g_stop_tokens;
std::string g_error;
std::string g_device_name;
std::string g_pending_directory;
int g_pending_device = 0;
neurx::runtime::model::hf_config g_pending_config;
std::mutex g_runtime_mutex;
std::mutex g_model_mutex;
std::unordered_map<int, std::shared_ptr<generation_session>> g_session;
int g_next_session = 1;
constexpr int k_default_session = 0;

void set_error(const std::exception& error) { g_error = error.what(); }

bool is_stop_token(int32_t token) {
  return std::find(g_stop_tokens.begin(), g_stop_tokens.end(), token) != g_stop_tokens.end();
}

std::shared_ptr<generation_session> find_session(int session_id) {
  std::lock_guard<std::mutex> lock(g_runtime_mutex);
  auto found = g_session.find(session_id);
  return found == g_session.end() ? nullptr : found->second;
}

std::shared_ptr<generation_session> default_session() {
  std::lock_guard<std::mutex> lock(g_runtime_mutex);
  auto& session = g_session[k_default_session];
  if (!session) session = std::make_shared<generation_session>();
  return session;
}

void clear_sessions() {
  std::lock_guard<std::mutex> lock(g_runtime_mutex);
  g_session.clear();
  g_next_session = 1;
}

std::string chat_prompt(const std::string& prompt) {
  if (prompt.find("<|im_start|>") != std::string::npos) return prompt;
  return "<|im_start|>system\n"
         "You are a helpful assistant. Answer accurately and directly.\n"
         "<|im_end|>\n<|im_start|>user\n" +
         prompt + "\n<|im_end|>\n<|im_start|>assistant\n";
}

}

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
    clear_sessions();
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
    clear_sessions();
    return -1;
  }
}

extern "C" int neurx_s_cuda_config_dimensions(
    const char* model_directory, int device, int vocab_size, int hidden_size,
    int intermediate_size, int num_hidden_layers) {
  try {
    g_error.clear();
    g_pending_directory = model_directory == nullptr ? "" : model_directory;
    if (g_pending_directory.empty()) throw std::runtime_error("NEURX_MODEL_DIR is required");
    g_pending_device = device;
    g_pending_config = neurx::runtime::model::hf_config{};
    g_pending_config.architecture = neurx::runtime::model::model_architecture::base_model;
    g_pending_config.model_type = "s-configured-causal-lm";
    g_pending_config.vocab_size = vocab_size;
    g_pending_config.hidden_size = hidden_size;
    g_pending_config.intermediate_size = intermediate_size;
    g_pending_config.num_hidden_layers = num_hidden_layers;
    return 0;
  } catch (const std::exception& error) {
    set_error(error);
    return -1;
  }
}

extern "C" int neurx_s_cuda_config_attention(int num_attention_heads,
                                               int num_key_value_heads,
                                               int head_dimension,
                                               int max_position_embeddings) {
  g_pending_config.num_attention_heads = num_attention_heads;
  g_pending_config.num_key_value_heads = num_key_value_heads;
  g_pending_config.head_dimension = head_dimension;
  g_pending_config.max_position_embeddings = max_position_embeddings;
  return 0;
}

extern "C" int neurx_s_cuda_config_finalize(const char* rms_norm_eps_text,
                                              const char* rope_theta_text,
                                              int attention_bias, int mlp_bias,
                                              int tie_word_embeddings) {
  try {
    g_error.clear();
    int count = 0;
    const cudaError_t count_status = cudaGetDeviceCount(&count);
    if (count_status != cudaSuccess || count <= 0) {
      throw std::runtime_error("no local CUDA GPU is available");
    }
    if (g_pending_device < 0 || g_pending_device >= count) {
      throw std::runtime_error("NEURX_CUDA_DEVICE is outside the local GPU range");
    }
    cudaDeviceProp properties{};
    if (cudaGetDeviceProperties(&properties, g_pending_device) != cudaSuccess) {
      throw std::runtime_error("failed to query the local CUDA GPU");
    }
    g_device_name = properties.name;
    if (rms_norm_eps_text == nullptr || rope_theta_text == nullptr) {
      throw std::runtime_error("S model configuration numeric text is missing");
    }
    g_pending_config.rms_norm_eps = std::stod(rms_norm_eps_text);
    g_pending_config.rope_theta = std::stod(rope_theta_text);
    g_pending_config.attention_bias = attention_bias != 0;
    g_pending_config.mlp_bias = mlp_bias != 0;
    g_pending_config.tie_word_embeddings = tie_word_embeddings != 0;
    g_pending_config.validate();

    g_tokenizer = std::make_unique<bpe_tokenizer>(
        bpe_tokenizer::from_directory(g_pending_directory));
    g_model = std::make_unique<hf_decoder_cuda>(
        g_pending_directory, g_pending_config, g_pending_device);
    clear_sessions();
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
    clear_sessions();
    return -1;
  }
}

extern "C" int neurx_s_cuda_session_create() {
  std::lock_guard<std::mutex> lock(g_runtime_mutex);
  if (!g_model || !g_tokenizer) { g_error = "NeurX CUDA runtime is not initialized"; return -1; }
  int session_id = g_next_session++;
  g_session.emplace(session_id, std::make_shared<generation_session>());
  return session_id;
}

extern "C" int neurx_s_cuda_session_destroy(int session_id) {
  if (session_id <= 0) return -1;
  std::lock_guard<std::mutex> lock(g_runtime_mutex);
  return g_session.erase(session_id) == 1 ? 0 : -1;
}

extern "C" const char* neurx_s_cuda_session_error(int session_id) {
  auto session = find_session(session_id);
  return session ? session->error.c_str() : g_error.c_str();
}

extern "C" int neurx_s_cuda_session_begin(int session_id, const char* prompt, int maximum_new_tokens) {
  try {
    auto session = session_id == k_default_session ? default_session() : find_session(session_id);
    if (!session) throw std::runtime_error("unknown CUDA generation session");
    std::lock_guard<std::mutex> session_lock(session->mutex);
    session->error.clear();
    if (!g_model || !g_tokenizer) {
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
    session->cache = std::make_unique<hf_cuda_kv_cache>();
    session->generated.clear();
    session->output.clear();
    std::lock_guard<std::mutex> model_lock(g_model_mutex);
    session->logits = g_model->prefill(input, session->cache.get());
    return static_cast<int>(input.size());
  } catch (const std::exception& error) {
    auto session = find_session(session_id);
    if (session) session->error = error.what(); else set_error(error);
    return -1;
  }
}

extern "C" int neurx_s_cuda_session_next(int session_id) {
  try {
    auto session = session_id == k_default_session ? default_session() : find_session(session_id);
    if (!session) throw std::runtime_error("unknown CUDA generation session");
    std::lock_guard<std::mutex> session_lock(session->mutex);
    session->error.clear();
    if (!g_model || !g_tokenizer || !session->cache || session->logits.empty()) {
      throw std::runtime_error("NeurX CUDA generation session is not ready");
    }
    const int32_t token = hf_decoder_cuda::greedy(session->logits);
    if (is_stop_token(token)) return -1;
    session->generated.push_back(token);
    std::lock_guard<std::mutex> model_lock(g_model_mutex);
    session->logits = g_model->decode(token, session->cache.get());
    return token;
  } catch (const std::exception& error) {
    auto session = find_session(session_id);
    if (session) session->error = error.what(); else set_error(error);
    return -2;
  }
}

extern "C" const char* neurx_s_cuda_session_result(int session_id) {
  try {
    auto session = session_id == k_default_session ? default_session() : find_session(session_id);
    if (!session) throw std::runtime_error("unknown CUDA generation session");
    std::lock_guard<std::mutex> session_lock(session->mutex);
    session->error.clear();
    if (!g_tokenizer) throw std::runtime_error("NeurX CUDA tokenizer is not initialized");
    session->output = g_tokenizer->decode(session->generated, true);
    return session->output.c_str();
  } catch (const std::exception& error) {
    auto session = find_session(session_id);
    if (session) { session->error = error.what(); session->output.clear(); return session->output.c_str(); }
    set_error(error); return "";
  }
}

extern "C" int neurx_s_cuda_begin(const char* prompt, int maximum_new_tokens) {
  default_session();
  return neurx_s_cuda_session_begin(k_default_session, prompt, maximum_new_tokens);
}
extern "C" int neurx_s_cuda_next() { return neurx_s_cuda_session_next(k_default_session); }
extern "C" const char* neurx_s_cuda_result() { return neurx_s_cuda_session_result(k_default_session); }
