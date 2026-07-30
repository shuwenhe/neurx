#include "hf_decoder_cuda.h"

#include "hf_decoder_kernels.cuh"

#include <cublas_v2.h>
#include <cuda_runtime.h>

#include <algorithm>
#include <stdexcept>
#include <utility>

namespace neurx::cuda {
namespace {

void check_cuda(cudaError_t status, const char* operation) {
  if (status != cudaSuccess) {
    throw std::runtime_error(std::string(operation) + ": " + cudaGetErrorString(status));
  }
}

void check_cublas(cublasStatus_t status, const char* operation) {
  if (status != CUBLAS_STATUS_SUCCESS) throw std::runtime_error(std::string(operation) + " failed");
}

class DeviceBuffer {
 public:
  DeviceBuffer() = default;
  explicit DeviceBuffer(std::size_t bytes) { resize(bytes); }
  ~DeviceBuffer() { if (data_) cudaFree(data_); }
  DeviceBuffer(DeviceBuffer&& other) noexcept
      : data_(std::exchange(other.data_, nullptr)), bytes_(std::exchange(other.bytes_, 0)) {}
  DeviceBuffer& operator=(DeviceBuffer&& other) noexcept {
    if (this != &other) {
      if (data_) cudaFree(data_);
      data_ = std::exchange(other.data_, nullptr);
      bytes_ = std::exchange(other.bytes_, 0);
    }
    return *this;
  }
  DeviceBuffer(const DeviceBuffer&) = delete;
  DeviceBuffer& operator=(const DeviceBuffer&) = delete;
  void resize(std::size_t bytes) {
    if (bytes == bytes_) return;
    if (data_) check_cuda(cudaFree(data_), "cudaFree");
    data_ = nullptr;
    bytes_ = 0;
    if (bytes) check_cuda(cudaMalloc(&data_, bytes), "cudaMalloc");
    bytes_ = bytes;
  }
  void* data() { return data_; }
  const void* data() const { return data_; }
  std::size_t bytes() const { return bytes_; }

 private:
  void* data_ = nullptr;
  std::size_t bytes_ = 0;
};

DeviceBuffer load_weight(const runtime::model::HfWeightStore& store, const std::string& name) {
  const runtime::native::Tensor tensor = store.load(name).to(runtime::native::DType::float32);
  std::vector<float> host(static_cast<std::size_t>(tensor.numel()));
  tensor.copy_to_host(host.data(), host.size() * sizeof(float));
  DeviceBuffer result(host.size() * sizeof(float));
  check_cuda(cudaMemcpy(result.data(), host.data(), result.bytes(), cudaMemcpyHostToDevice),
             "copy HF weight to CUDA");
  return result;
}

struct Linear {
  int input = 0;
  int output = 0;
  DeviceBuffer weight;
  DeviceBuffer bias;
};

struct Layer {
  DeviceBuffer input_norm;
  Linear q, k, v, o;
  DeviceBuffer post_norm;
  Linear gate, up, down;
};

void run_linear(cublasHandle_t handle, const float* input, int rows, const Linear& linear,
                float* output) {
  const float alpha = 1.0F;
  const float beta = 0.0F;
  check_cublas(cublasSgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N, linear.output, rows,
                           linear.input, &alpha,
                           static_cast<const float*>(linear.weight.data()), linear.input,
                           input, linear.input, &beta, output, linear.output),
               "cublasSgemm");
  if (linear.bias.data()) {
    kernels::add_bias<<<kernels::blocks(rows * linear.output), 256>>>(
        output, static_cast<const float*>(linear.bias.data()), rows, linear.output);
  }
}

}

struct HfCudaKvCache::State {
  std::size_t length = 0;
  std::size_t capacity = 0;
  std::vector<DeviceBuffer> keys;
  std::vector<DeviceBuffer> values;
};

HfCudaKvCache::HfCudaKvCache() : state_(new State) {}
HfCudaKvCache::~HfCudaKvCache() = default;
HfCudaKvCache::HfCudaKvCache(HfCudaKvCache&&) noexcept = default;
HfCudaKvCache& HfCudaKvCache::operator=(HfCudaKvCache&&) noexcept = default;
std::size_t HfCudaKvCache::length() const { return state_->length; }
void HfCudaKvCache::clear() {
  state_->length = 0;
}

struct HfDecoderCuda::Impl {
  runtime::model::HfConfig config;
  int device = 0;
  cublasHandle_t handle = nullptr;
  DeviceBuffer embedding;
  std::vector<Layer> layers;
  DeviceBuffer final_norm;
  DeviceBuffer lm_head;

  Impl(const std::string& directory, int device_id)
      : config(runtime::model::HfConfig::from_file(directory + "/config.json")),
        device(device_id) {
    check_cuda(cudaSetDevice(device), "cudaSetDevice");
    check_cublas(cublasCreate(&handle), "cublasCreate");
    const auto store = runtime::model::HfWeightStore::open(directory);
    store.validate_architecture(config);
    embedding = load_weight(store, "model.embed_tokens.weight");
    const int hidden = static_cast<int>(config.hidden_size);
    const int query = static_cast<int>(config.num_attention_heads * config.head_dim());
    const int kv = static_cast<int>(config.num_key_value_heads * config.head_dim());
    const int intermediate = static_cast<int>(config.intermediate_size);
    for (int64_t index = 0; index < config.num_hidden_layers; ++index) {
      const std::string prefix = "model.layers." + std::to_string(index) + ".";
      Layer layer;
      layer.input_norm = load_weight(store, prefix + "input_layernorm.weight");
      layer.post_norm = load_weight(store, prefix + "post_attention_layernorm.weight");
      const auto load_linear = [&](Linear* linear, const std::string& name,
                                   int output, int input) {
        linear->input = input;
        linear->output = output;
        linear->weight = load_weight(store, prefix + name + ".weight");
        if (store.contains(prefix + name + ".bias")) {
          linear->bias = load_weight(store, prefix + name + ".bias");
        }
      };
      load_linear(&layer.q, "self_attn.q_proj", query, hidden);
      load_linear(&layer.k, "self_attn.k_proj", kv, hidden);
      load_linear(&layer.v, "self_attn.v_proj", kv, hidden);
      load_linear(&layer.o, "self_attn.o_proj", hidden, query);
      load_linear(&layer.gate, "mlp.gate_proj", intermediate, hidden);
      load_linear(&layer.up, "mlp.up_proj", intermediate, hidden);
      load_linear(&layer.down, "mlp.down_proj", hidden, intermediate);
      layers.push_back(std::move(layer));
    }
    final_norm = load_weight(store, "model.norm.weight");
    lm_head = config.tie_word_embeddings ? load_weight(store, "model.embed_tokens.weight")
                                           : load_weight(store, "lm_head.weight");
  }

  ~Impl() {
    if (handle) cublasDestroy(handle);
  }

  Linear output_linear() const {
    Linear linear;
    linear.input = static_cast<int>(config.hidden_size);
    linear.output = static_cast<int>(config.vocab_size);
    return linear;
  }

  void ensure_cache(HfCudaKvCache::State* cache, std::size_t required) {
    const std::size_t layers_count = layers.size();
    const std::size_t kv_width = static_cast<std::size_t>(
        config.num_key_value_heads * config.head_dim());
    if (cache->keys.empty()) {
      cache->keys.resize(layers_count);
      cache->values.resize(layers_count);
    }
    if (cache->keys.size() != layers_count || cache->values.size() != layers_count) {
      throw std::invalid_argument("CUDA KV cache layer count mismatch");
    }
    if (required <= cache->capacity) return;
    const std::size_t capacity = std::max(required, std::max<std::size_t>(16, cache->capacity * 2));
    for (std::size_t layer = 0; layer < layers_count; ++layer) {
      DeviceBuffer next_key(capacity * kv_width * sizeof(float));
      DeviceBuffer next_value(capacity * kv_width * sizeof(float));
      if (cache->length) {
        const std::size_t used = cache->length * kv_width * sizeof(float);
        check_cuda(cudaMemcpy(next_key.data(), cache->keys[layer].data(), used,
                              cudaMemcpyDeviceToDevice), "grow CUDA K cache");
        check_cuda(cudaMemcpy(next_value.data(), cache->values[layer].data(), used,
                              cudaMemcpyDeviceToDevice), "grow CUDA V cache");
      }
      cache->keys[layer] = std::move(next_key);
      cache->values[layer] = std::move(next_value);
    }
    cache->capacity = capacity;
  }

  std::vector<float> forward(const std::vector<int32_t>& ids, HfCudaKvCache::State* cache) {
    if (ids.empty()) throw std::invalid_argument("CUDA decoder requires at least one token");
    if (cache == nullptr) throw std::invalid_argument("CUDA decoder KV cache is null");
    const int tokens = static_cast<int>(ids.size());
    const int past = static_cast<int>(cache->length);
    if (cache->length + ids.size() > static_cast<std::size_t>(config.max_position_embeddings)) {
      throw std::invalid_argument("CUDA decoder context exceeds max_position_embeddings");
    }
    for (int32_t id : ids) {
      if (id < 0 || id >= config.vocab_size) throw std::out_of_range("CUDA decoder token id is invalid");
    }
    ensure_cache(cache, cache->length + ids.size());
    const int hidden = static_cast<int>(config.hidden_size);
    const int head_dimension = static_cast<int>(config.head_dim());
    const int query_heads = static_cast<int>(config.num_attention_heads);
    const int kv_heads = static_cast<int>(config.num_key_value_heads);
    const int query_width = query_heads * head_dimension;
    const int kv_width = kv_heads * head_dimension;
    const int intermediate = static_cast<int>(config.intermediate_size);
    DeviceBuffer device_ids(ids.size() * sizeof(int32_t));
    DeviceBuffer state(static_cast<std::size_t>(tokens) * hidden * sizeof(float));
    DeviceBuffer normalized(static_cast<std::size_t>(tokens) * hidden * sizeof(float));
    DeviceBuffer query(static_cast<std::size_t>(tokens) * query_width * sizeof(float));
    DeviceBuffer key(static_cast<std::size_t>(tokens) * kv_width * sizeof(float));
    DeviceBuffer value(static_cast<std::size_t>(tokens) * kv_width * sizeof(float));
    DeviceBuffer attention(static_cast<std::size_t>(tokens) * query_width * sizeof(float));
    DeviceBuffer projection(static_cast<std::size_t>(tokens) * hidden * sizeof(float));
    DeviceBuffer gate(static_cast<std::size_t>(tokens) * intermediate * sizeof(float));
    DeviceBuffer up(static_cast<std::size_t>(tokens) * intermediate * sizeof(float));
    check_cuda(cudaMemcpy(device_ids.data(), ids.data(), device_ids.bytes(), cudaMemcpyHostToDevice),
               "copy token ids to CUDA");
    kernels::embedding<<<kernels::blocks(tokens * hidden), 256>>>(
        static_cast<const int32_t*>(device_ids.data()),
        static_cast<const float*>(embedding.data()), static_cast<float*>(state.data()),
        tokens, hidden);
    for (std::size_t index = 0; index < layers.size(); ++index) {
      const Layer& layer = layers[index];
      kernels::rms_norm<<<kernels::blocks(tokens), 256>>>(
          static_cast<const float*>(state.data()),
          static_cast<const float*>(layer.input_norm.data()),
          static_cast<float*>(normalized.data()), tokens, hidden,
          static_cast<float>(config.rms_norm_eps));
      run_linear(handle, static_cast<const float*>(normalized.data()), tokens, layer.q,
                 static_cast<float*>(query.data()));
      run_linear(handle, static_cast<const float*>(normalized.data()), tokens, layer.k,
                 static_cast<float*>(key.data()));
      run_linear(handle, static_cast<const float*>(normalized.data()), tokens, layer.v,
                 static_cast<float*>(value.data()));
      kernels::rope_half<<<kernels::blocks(tokens * query_heads * (head_dimension / 2)), 256>>>(
          static_cast<float*>(query.data()), tokens, query_heads, head_dimension, past,
          static_cast<float>(config.rope_theta));
      kernels::rope_half<<<kernels::blocks(tokens * kv_heads * (head_dimension / 2)), 256>>>(
          static_cast<float*>(key.data()), tokens, kv_heads, head_dimension, past,
          static_cast<float>(config.rope_theta));
      const std::size_t offset = cache->length * static_cast<std::size_t>(kv_width) * sizeof(float);
      check_cuda(cudaMemcpy(static_cast<char*>(cache->keys[index].data()) + offset, key.data(),
                            key.bytes(), cudaMemcpyDeviceToDevice), "append CUDA K cache");
      check_cuda(cudaMemcpy(static_cast<char*>(cache->values[index].data()) + offset, value.data(),
                            value.bytes(), cudaMemcpyDeviceToDevice), "append CUDA V cache");
      kernels::attention_gqa<<<kernels::blocks(tokens * query_heads), 256>>>(
          static_cast<const float*>(query.data()),
          static_cast<const float*>(cache->keys[index].data()),
          static_cast<const float*>(cache->values[index].data()),
          static_cast<float*>(attention.data()), tokens, past, query_heads, kv_heads,
          head_dimension);
      run_linear(handle, static_cast<const float*>(attention.data()), tokens, layer.o,
                 static_cast<float*>(projection.data()));
      kernels::add_in_place<<<kernels::blocks(tokens * hidden), 256>>>(
          static_cast<float*>(state.data()), static_cast<const float*>(projection.data()),
          tokens * hidden);
      kernels::rms_norm<<<kernels::blocks(tokens), 256>>>(
          static_cast<const float*>(state.data()),
          static_cast<const float*>(layer.post_norm.data()),
          static_cast<float*>(normalized.data()), tokens, hidden,
          static_cast<float>(config.rms_norm_eps));
      run_linear(handle, static_cast<const float*>(normalized.data()), tokens, layer.gate,
                 static_cast<float*>(gate.data()));
      run_linear(handle, static_cast<const float*>(normalized.data()), tokens, layer.up,
                 static_cast<float*>(up.data()));
      kernels::swiglu_in_place<<<kernels::blocks(tokens * intermediate), 256>>>(
          static_cast<float*>(gate.data()), static_cast<const float*>(up.data()),
          tokens * intermediate);
      run_linear(handle, static_cast<const float*>(gate.data()), tokens, layer.down,
                 static_cast<float*>(projection.data()));
      kernels::add_in_place<<<kernels::blocks(tokens * hidden), 256>>>(
          static_cast<float*>(state.data()), static_cast<const float*>(projection.data()),
          tokens * hidden);
    }
    kernels::rms_norm<<<kernels::blocks(tokens), 256>>>(
        static_cast<const float*>(state.data()), static_cast<const float*>(final_norm.data()),
        static_cast<float*>(normalized.data()), tokens, hidden,
        static_cast<float>(config.rms_norm_eps));
    DeviceBuffer logits(static_cast<std::size_t>(config.vocab_size) * sizeof(float));
    const float alpha = 1.0F;
    const float beta = 0.0F;
    const float* last_hidden = static_cast<const float*>(normalized.data()) +
                               static_cast<std::size_t>(tokens - 1) * hidden;
    check_cublas(cublasSgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N,
                             static_cast<int>(config.vocab_size), 1, hidden, &alpha,
                             static_cast<const float*>(lm_head.data()), hidden,
                             last_hidden, hidden, &beta,
                             static_cast<float*>(logits.data()), static_cast<int>(config.vocab_size)),
                 "CUDA lm_head");
    check_cuda(cudaGetLastError(), "CUDA HF decoder kernel launch");
    std::vector<float> host(static_cast<std::size_t>(config.vocab_size));
    check_cuda(cudaMemcpy(host.data(), logits.data(), logits.bytes(), cudaMemcpyDeviceToHost),
               "copy CUDA logits to host");
    cache->length += ids.size();
    return host;
  }
};

HfDecoderCuda::HfDecoderCuda(const std::string& directory, int device)
    : impl_(new Impl(directory, device)) {}
HfDecoderCuda::~HfDecoderCuda() = default;
HfDecoderCuda::HfDecoderCuda(HfDecoderCuda&&) noexcept = default;
HfDecoderCuda& HfDecoderCuda::operator=(HfDecoderCuda&&) noexcept = default;
const runtime::model::HfConfig& HfDecoderCuda::config() const { return impl_->config; }

std::vector<float> HfDecoderCuda::prefill(const std::vector<int32_t>& ids,
                                          HfCudaKvCache* cache) {
  if (cache == nullptr) throw std::invalid_argument("CUDA decoder KV cache is null");
  cache->clear();
  return impl_->forward(ids, cache->state_.get());
}

std::vector<float> HfDecoderCuda::decode(int32_t token, HfCudaKvCache* cache) {
  if (cache == nullptr) throw std::invalid_argument("CUDA decoder KV cache is null");
  return impl_->forward({token}, cache->state_.get());
}

int32_t HfDecoderCuda::greedy(const std::vector<float>& logits) {
  if (logits.empty()) throw std::invalid_argument("cannot sample empty CUDA logits");
  return static_cast<int32_t>(std::max_element(logits.begin(), logits.end()) - logits.begin());
}

}
