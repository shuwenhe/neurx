#include "hf_decoder_cuda.h"
#include "hf_decoder_kernels.cuh"
#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <algorithm>
#include <stdexcept>
#include <utility>
namespace neurx::cuda {
namespace {
void check_cuda(cuda_error_t status, const char* operation) {
  if (status != cuda_success) {
    throw std::runtime_error(std::string(operation) + ": " + cuda_get_error_string(status));
  }
}
void check_cublas(cublas_status_t status, const char* operation) {
  if (status != CUBLAS_STATUS_SUCCESS) throw std::runtime_error(std::string(operation) + " failed");
}
class device_buffer {
 public:
  device_buffer() = default;
  explicit device_buffer(std::size_t bytes) { resize(bytes); }
  ~device_buffer() { if (data_) cuda_free(data_); }
  device_buffer(device_buffer&& other) noexcept
      : data_(std::exchange(other.data_, nullptr)), bytes_(std::exchange(other.bytes_, 0)) {}
  device_buffer& operator=(device_buffer&& other) noexcept {
    if (this != &other) {
      if (data_) cuda_free(data_);
      data_ = std::exchange(other.data_, nullptr);
      bytes_ = std::exchange(other.bytes_, 0);
    }
    return *this;
  }
  device_buffer(const device_buffer&) = delete;
  device_buffer& operator=(const device_buffer&) = delete;
  void resize(std::size_t bytes) {
    if (bytes == bytes_) return;
    if (data_) check_cuda(cuda_free(data_), "cudaFree");
    data_ = nullptr;
    bytes_ = 0;
    if (bytes) check_cuda(cuda_malloc(&data_, bytes), "cudaMalloc");
    bytes_ = bytes;
  }
  void* data() { return data_; }
  const void* data() const { return data_; }
  std::size_t bytes() const { return bytes_; }
 private:
  void* data_ = nullptr;
  std::size_t bytes_ = 0;
};
device_buffer load_weight(const runtime::model::hf_weight_store& store, const std::string& name) {
  const runtime::native::tensor tensor = store.load(name).to(runtime::native::d_type::float32);
  std::vector<float> host(static_cast<std::size_t>(tensor.numel()));
  tensor.copy_to_host(host.data(), host.size() * sizeof(float));
  device_buffer result(host.size() * sizeof(float));
  check_cuda(cuda_memcpy(result.data(), host.data(), result.bytes(), cuda_memcpy_host_to_device),
             "copy HF weight to CUDA");
  return result;
}
struct linear {
  int input = 0;
  int output = 0;
  device_buffer weight;
  device_buffer bias;
};
struct layer {
  device_buffer input_norm;
  linear q, k, v, o;
  device_buffer post_norm;
  linear gate, up, down;
};
void run_linear(cublas_handle_t handle, const float* input, int rows, const linear& linear,
                float* output) {
  const float alpha = 1.0F;
  const float beta = 0.0F;
  check_cublas(cublas_sgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N, linear.output, rows,
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
struct hf_cuda_kv_cache::state {
  std::size_t length = 0;
  std::size_t capacity = 0;
  std::vector<device_buffer> keys;
  std::vector<device_buffer> values;
};
hf_cuda_kv_cache::hf_cuda_kv_cache() : state_(new state) {}
hf_cuda_kv_cache::~hf_cuda_kv_cache() = default;
hf_cuda_kv_cache::hf_cuda_kv_cache(hf_cuda_kv_cache&&) noexcept = default;
hf_cuda_kv_cache& hf_cuda_kv_cache::operator=(hf_cuda_kv_cache&&) noexcept = default;
std::size_t hf_cuda_kv_cache::length() const { return state_->length; }
void hf_cuda_kv_cache::clear() {
  state_->length = 0;
}
struct hf_decoder_cuda::impl {
  runtime::model::hf_config config;
  int device = 0;
  cublas_handle_t handle = nullptr;
  device_buffer embedding;
  std::vector<layer> layers;
  device_buffer final_norm;
  device_buffer lm_head;
  impl(const std::string& directory, int device_id)
      : config(runtime::model::hf_config::from_file(directory + "/config.json")),
        device(device_id) {
    check_cuda(cuda_set_device(device), "cudaSetDevice");
    check_cublas(cublas_create(&handle), "cublasCreate");
    const auto store = runtime::model::hf_weight_store::open(directory);
    store.validate_architecture(config);
    embedding = load_weight(store, "model.embed_tokens.weight");
    const int hidden = static_cast<int>(config.hidden_size);
    const int query = static_cast<int>(config.num_attention_heads * config.head_dim());
    const int kv = static_cast<int>(config.num_key_value_heads * config.head_dim());
    const int intermediate = static_cast<int>(config.intermediate_size);
    for (int64_t index = 0; index < config.num_hidden_layers; ++index) {
      const std::string prefix = "model.layers." + std::to_string(index) + ".";
      layer layer;
      layer.input_norm = load_weight(store, prefix + "input_layernorm.weight");
      layer.post_norm = load_weight(store, prefix + "post_attention_layernorm.weight");
      const auto load_linear = [&](linear* linear, const std::string& name,
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
  ~impl() {
    if (handle) cublas_destroy(handle);
  }
  linear output_linear() const {
    linear linear;
    linear.input = static_cast<int>(config.hidden_size);
    linear.output = static_cast<int>(config.vocab_size);
    return linear;
  }
  void ensure_cache(hf_cuda_kv_cache::state* cache, std::size_t required) {
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
      device_buffer next_key(capacity * kv_width * sizeof(float));
      device_buffer next_value(capacity * kv_width * sizeof(float));
      if (cache->length) {
        const std::size_t used = cache->length * kv_width * sizeof(float);
        check_cuda(cuda_memcpy(next_key.data(), cache->keys[layer].data(), used,
                              cuda_memcpy_device_to_device), "grow CUDA K cache");
        check_cuda(cuda_memcpy(next_value.data(), cache->values[layer].data(), used,
                              cuda_memcpy_device_to_device), "grow CUDA V cache");
      }
      cache->keys[layer] = std::move(next_key);
      cache->values[layer] = std::move(next_value);
    }
    cache->capacity = capacity;
  }
  std::vector<float> forward(const std::vector<int32_t>& ids, hf_cuda_kv_cache::state* cache) {
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
    device_buffer device_ids(ids.size() * sizeof(int32_t));
    device_buffer state(static_cast<std::size_t>(tokens) * hidden * sizeof(float));
    device_buffer normalized(static_cast<std::size_t>(tokens) * hidden * sizeof(float));
    device_buffer query(static_cast<std::size_t>(tokens) * query_width * sizeof(float));
    device_buffer key(static_cast<std::size_t>(tokens) * kv_width * sizeof(float));
    device_buffer value(static_cast<std::size_t>(tokens) * kv_width * sizeof(float));
    device_buffer attention(static_cast<std::size_t>(tokens) * query_width * sizeof(float));
    device_buffer projection(static_cast<std::size_t>(tokens) * hidden * sizeof(float));
    device_buffer gate(static_cast<std::size_t>(tokens) * intermediate * sizeof(float));
    device_buffer up(static_cast<std::size_t>(tokens) * intermediate * sizeof(float));
    check_cuda(cuda_memcpy(device_ids.data(), ids.data(), device_ids.bytes(), cuda_memcpy_host_to_device),
               "copy token ids to CUDA");
    kernels::embedding<<<kernels::blocks(tokens * hidden), 256>>>(
        static_cast<const int32_t*>(device_ids.data()),
        static_cast<const float*>(embedding.data()), static_cast<float*>(state.data()),
        tokens, hidden);
    for (std::size_t index = 0; index < layers.size(); ++index) {
      const layer& layer = layers[index];
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
      check_cuda(cuda_memcpy(static_cast<char*>(cache->keys[index].data()) + offset, key.data(),
                            key.bytes(), cuda_memcpy_device_to_device), "append CUDA K cache");
      check_cuda(cuda_memcpy(static_cast<char*>(cache->values[index].data()) + offset, value.data(),
                            value.bytes(), cuda_memcpy_device_to_device), "append CUDA V cache");
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
    device_buffer logits(static_cast<std::size_t>(config.vocab_size) * sizeof(float));
    const float alpha = 1.0F;
    const float beta = 0.0F;
    const float* last_hidden = static_cast<const float*>(normalized.data()) +
                               static_cast<std::size_t>(tokens - 1) * hidden;
    check_cublas(cublas_sgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N,
                             static_cast<int>(config.vocab_size), 1, hidden, &alpha,
                             static_cast<const float*>(lm_head.data()), hidden,
                             last_hidden, hidden, &beta,
                             static_cast<float*>(logits.data()), static_cast<int>(config.vocab_size)),
                 "CUDA lm_head");
    check_cuda(cuda_get_last_error(), "CUDA HF decoder kernel launch");
    std::vector<float> host(static_cast<std::size_t>(config.vocab_size));
    check_cuda(cuda_memcpy(host.data(), logits.data(), logits.bytes(), cuda_memcpy_device_to_host),
               "copy CUDA logits to host");
    cache->length += ids.size();
    return host;
  }
};
hf_decoder_cuda::hf_decoder_cuda(const std::string& directory, int device)
    : impl_(new impl(directory, device)) {}
hf_decoder_cuda::~hf_decoder_cuda() = default;
hf_decoder_cuda::hf_decoder_cuda(hf_decoder_cuda&&) noexcept = default;
hf_decoder_cuda& hf_decoder_cuda::operator=(hf_decoder_cuda&&) noexcept = default;
const runtime::model::hf_config& hf_decoder_cuda::config() const { return impl_->config; }
std::vector<float> hf_decoder_cuda::prefill(const std::vector<int32_t>& ids,
                                          hf_cuda_kv_cache* cache) {
  if (cache == nullptr) throw std::invalid_argument("CUDA decoder KV cache is null");
  cache->clear();
  return impl_->forward(ids, cache->state_.get());
}
std::vector<float> hf_decoder_cuda::decode(int32_t token, hf_cuda_kv_cache* cache) {
  if (cache == nullptr) throw std::invalid_argument("CUDA decoder KV cache is null");
  return impl_->forward({token}, cache->state_.get());
}
int32_t hf_decoder_cuda::greedy(const std::vector<float>& logits) {
  if (logits.empty()) throw std::invalid_argument("cannot sample empty CUDA logits");
  return static_cast<int32_t>(std::max_element(logits.begin(), logits.end()) - logits.begin());
}
}
