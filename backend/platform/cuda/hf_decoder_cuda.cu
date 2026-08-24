#include "hf_decoder_cuda.h"
#include "hf_decoder_kernels.cuh"
#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
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
class device_buffer {
 public:
  device_buffer() = default;
  explicit device_buffer(std::size_t bytes) { resize(bytes); }
  ~device_buffer() { if (data_) cudaFree(data_); }
  device_buffer(device_buffer&& other) noexcept
      : data_(std::exchange(other.data_, nullptr)), bytes_(std::exchange(other.bytes_, 0)) {}
  device_buffer& operator=(device_buffer&& other) noexcept {
    if (this != &other) {
      if (data_) cudaFree(data_);
      data_ = std::exchange(other.data_, nullptr);
      bytes_ = std::exchange(other.bytes_, 0);
    }
    return *this;
  }
  device_buffer(const device_buffer&) = delete;
  device_buffer& operator=(const device_buffer&) = delete;
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
device_buffer load_weight(const runtime::model::hf_weight_store& store, const std::string& name) {
  const runtime::native::tensor tensor = store.load(name).to(runtime::native::d_type::float32);
  std::vector<float> host(static_cast<std::size_t>(tensor.numel()));
  tensor.copy_to_host(host.data(), host.size() * sizeof(float));
  device_buffer result(host.size() * sizeof(float));
  check_cuda(cudaMemcpy(result.data(), host.data(), result.bytes(), cudaMemcpyHostToDevice),
             "copy HF weight to CUDA");
  return result;
}
struct linear {
  int input = 0;
  int output = 0;
  device_buffer weight;
  device_buffer bias;
};
struct lora_adapter {
  std::string name;
  int input = 0;
  int output = 0;
  int rank = 0;
  float scaling = 1.0F;
  device_buffer a, b, grad_a, grad_b, first_a, first_b, second_a, second_b;
};
struct layer {
  device_buffer input_norm;
  linear q, k, v, o;
  device_buffer post_norm;
  linear gate, up, down;
  lora_adapter lora_q, lora_k, lora_v, lora_o;
};
struct training_layer_cache {
  device_buffer x, normalized_attention, query, key, value, attention;
  device_buffer residual, normalized_mlp, gate, up, swiglu, hidden;
  training_layer_cache(int tokens, int hidden_size, int query_width, int kv_width,
                       int intermediate) {
    const auto allocate = [](device_buffer* buffer, std::size_t count) {
      buffer->resize(count * sizeof(float));
    };
    allocate(&x, static_cast<std::size_t>(tokens) * hidden_size);
    allocate(&normalized_attention, static_cast<std::size_t>(tokens) * hidden_size);
    allocate(&query, static_cast<std::size_t>(tokens) * query_width);
    allocate(&key, static_cast<std::size_t>(tokens) * kv_width);
    allocate(&value, static_cast<std::size_t>(tokens) * kv_width);
    allocate(&attention, static_cast<std::size_t>(tokens) * query_width);
    allocate(&residual, static_cast<std::size_t>(tokens) * hidden_size);
    allocate(&normalized_mlp, static_cast<std::size_t>(tokens) * hidden_size);
    allocate(&gate, static_cast<std::size_t>(tokens) * intermediate);
    allocate(&up, static_cast<std::size_t>(tokens) * intermediate);
    allocate(&swiglu, static_cast<std::size_t>(tokens) * intermediate);
    allocate(&hidden, static_cast<std::size_t>(tokens) * hidden_size);
  }
  training_layer_cache(training_layer_cache&&) noexcept = default;
  training_layer_cache& operator=(training_layer_cache&&) noexcept = default;
  training_layer_cache(const training_layer_cache&) = delete;
  training_layer_cache& operator=(const training_layer_cache&) = delete;
};
void run_linear(cublasHandle_t handle, const float* input, int rows, const linear& linear,
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
void run_backward_input(cublasHandle_t handle, const float* gradient_output, int rows,
                        const float* weight, int input, int output, float* gradient_input) {
  const float alpha = 1.0F;
  const float beta = 0.0F;
  check_cublas(cublasSgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N, input, rows, output,
                           &alpha, weight, input, gradient_output, output, &beta,
                           gradient_input, input), "cublasSgemm backward input");
}
void initialize_lora(lora_adapter* adapter, const std::string& name, int input, int output,
                     int rank, float alpha, uint32_t seed) {
  adapter->name = name;
  adapter->input = input;
  adapter->output = output;
  adapter->rank = rank;
  adapter->scaling = alpha / rank;
  const std::size_t a_count = static_cast<std::size_t>(rank) * input;
  const std::size_t b_count = static_cast<std::size_t>(output) * rank;
  adapter->a.resize(a_count * sizeof(float));
  adapter->b.resize(b_count * sizeof(float));
  adapter->grad_a.resize(a_count * sizeof(float));
  adapter->grad_b.resize(b_count * sizeof(float));
  adapter->first_a.resize(a_count * sizeof(float));
  adapter->first_b.resize(b_count * sizeof(float));
  adapter->second_a.resize(a_count * sizeof(float));
  adapter->second_b.resize(b_count * sizeof(float));
  std::vector<float> host(a_count);
  const float bound = 1.0F / std::sqrt(static_cast<float>(input));
  uint32_t state = seed == 0 ? 1U : seed;
  for (std::size_t index = 0; index < host.size(); ++index) {
    state = state * 1664525U + 1013904223U;
    const float unit = static_cast<float>((state >> 8) & 0x00ffffffU) / 16777215.0F;
    host[index] = (unit * 2.0F - 1.0F) * bound;
  }
  check_cuda(cudaMemcpy(adapter->a.data(), host.data(), adapter->a.bytes(), cudaMemcpyHostToDevice),
             "initialize LoRA A");
  check_cuda(cudaMemset(adapter->b.data(), 0, adapter->b.bytes()), "initialize LoRA B");
  check_cuda(cudaMemset(adapter->grad_a.data(), 0, adapter->grad_a.bytes()), "zero LoRA A grad");
  check_cuda(cudaMemset(adapter->grad_b.data(), 0, adapter->grad_b.bytes()), "zero LoRA B grad");
  check_cuda(cudaMemset(adapter->first_a.data(), 0, adapter->first_a.bytes()), "zero LoRA A first moment");
  check_cuda(cudaMemset(adapter->first_b.data(), 0, adapter->first_b.bytes()), "zero LoRA B first moment");
  check_cuda(cudaMemset(adapter->second_a.data(), 0, adapter->second_a.bytes()), "zero LoRA A second moment");
  check_cuda(cudaMemset(adapter->second_b.data(), 0, adapter->second_b.bytes()), "zero LoRA B second moment");
}
void run_lora_forward(cublasHandle_t handle, const float* input, int rows,
                      const lora_adapter& adapter, float* output, device_buffer* hidden) {
  hidden->resize(static_cast<std::size_t>(rows) * adapter.rank * sizeof(float));
  const float one = 1.0F;
  const float zero = 0.0F;
  check_cublas(cublasSgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N, adapter.rank, rows,
                           adapter.input, &one, static_cast<const float*>(adapter.a.data()),
                           adapter.input, input, adapter.input, &zero,
                           static_cast<float*>(hidden->data()), adapter.rank),
               "cublasSgemm LoRA A forward");
  check_cublas(cublasSgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N, adapter.output, rows,
                           adapter.rank, &adapter.scaling,
                           static_cast<const float*>(adapter.b.data()), adapter.rank,
                           static_cast<const float*>(hidden->data()), adapter.rank, &one,
                           output, adapter.output), "cublasSgemm LoRA B forward");
}
void run_linear_lora_backward(cublasHandle_t handle, const float* input,
                              const linear& base, lora_adapter* adapter,
                              const float* gradient_output, int rows,
                              float* gradient_input, device_buffer* hidden,
                              device_buffer* gradient_hidden) {
  run_backward_input(handle, gradient_output, rows,
                     static_cast<const float*>(base.weight.data()),
                     base.input, base.output, gradient_input);
  hidden->resize(static_cast<std::size_t>(rows) * adapter->rank * sizeof(float));
  gradient_hidden->resize(static_cast<std::size_t>(rows) * adapter->rank * sizeof(float));
  const float one = 1.0F;
  const float zero = 0.0F;
  check_cublas(cublasSgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N, adapter->rank, rows,
                           adapter->input, &one, static_cast<const float*>(adapter->a.data()),
                           adapter->input, input, adapter->input, &zero,
                           static_cast<float*>(hidden->data()), adapter->rank),
               "cublasSgemm LoRA backward recompute");
  check_cublas(cublasSgemm(handle, CUBLAS_OP_N, CUBLAS_OP_T, adapter->rank,
                           adapter->output, rows, &adapter->scaling,
                           static_cast<const float*>(hidden->data()), adapter->rank,
                           gradient_output, adapter->output, &zero,
                           static_cast<float*>(adapter->grad_b.data()), adapter->rank),
               "cublasSgemm LoRA B gradient");
  check_cublas(cublasSgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N, adapter->rank, rows,
                           adapter->output, &adapter->scaling,
                           static_cast<const float*>(adapter->b.data()), adapter->rank,
                           gradient_output, adapter->output, &zero,
                           static_cast<float*>(gradient_hidden->data()), adapter->rank),
               "cublasSgemm LoRA hidden gradient");
  check_cublas(cublasSgemm(handle, CUBLAS_OP_N, CUBLAS_OP_T, adapter->input,
                           adapter->rank, rows, &one, input, adapter->input,
                           static_cast<const float*>(gradient_hidden->data()), adapter->rank,
                           &zero, static_cast<float*>(adapter->grad_a.data()), adapter->input),
               "cublasSgemm LoRA A gradient");
  check_cublas(cublasSgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N, adapter->input, rows,
                           adapter->rank, &one, static_cast<const float*>(adapter->a.data()),
                           adapter->input, static_cast<const float*>(gradient_hidden->data()),
                           adapter->rank, &one, gradient_input, adapter->input),
               "cublasSgemm LoRA input gradient");
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
  std::size_t weight_count = 0;
  int device = 0;
  cublasHandle_t handle = nullptr;
  device_buffer embedding;
  std::vector<layer> layers;
  device_buffer final_norm;
  device_buffer lm_head;
  impl(const std::string& directory, int device_id)
      : impl(directory, runtime::model::hf_config::from_file(directory + "/config.json"),
             device_id) {}
  impl(const std::string& directory, const runtime::model::hf_config& parsed_config,
       int device_id)
      : config(parsed_config), device(device_id) {
    config.validate();
    check_cuda(cudaSetDevice(device), "cudaSetDevice");
    check_cublas(cublasCreate(&handle), "cublasCreate");
    const auto store = runtime::model::hf_weight_store::open(directory);
    store.validate_architecture(config);
    weight_count = store.size();
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
    if (!config.tie_word_embeddings) lm_head = load_weight(store, "lm_head.weight");
  }
  const float* output_weight() const {
    return static_cast<const float*>(
        config.tie_word_embeddings ? embedding.data() : lm_head.data());
  }
  std::vector<lora_adapter*> adapters() {
    std::vector<lora_adapter*> result;
    result.reserve(layers.size() * 4);
    for (auto& item : layers) {
      result.push_back(&item.lora_q);
      result.push_back(&item.lora_k);
      result.push_back(&item.lora_v);
      result.push_back(&item.lora_o);
    }
    return result;
  }
  void initialize_adapters(int rank, float alpha) {
    const int hidden = static_cast<int>(config.hidden_size);
    const int query = static_cast<int>(config.num_attention_heads * config.head_dim());
    const int kv = static_cast<int>(config.num_key_value_heads * config.head_dim());
    uint32_t seed = 42;
    for (std::size_t index = 0; index < layers.size(); ++index) {
      const std::string prefix = "base_model.model.model.layers." + std::to_string(index) +
                                 ".self_attn.";
      initialize_lora(&layers[index].lora_q, prefix + "q_proj", hidden, query,
                      rank, alpha, seed++);
      initialize_lora(&layers[index].lora_k, prefix + "k_proj", hidden, kv,
                      rank, alpha, seed++);
      initialize_lora(&layers[index].lora_v, prefix + "v_proj", hidden, kv,
                      rank, alpha, seed++);
      initialize_lora(&layers[index].lora_o, prefix + "o_proj", query, hidden,
                      rank, alpha, seed++);
    }
  }
  double adapter_gradient_norm(bool matrix_a) {
    double sum = 0.0;
    for (lora_adapter* adapter : adapters()) {
      const int count = matrix_a ? adapter->rank * adapter->input
                                 : adapter->output * adapter->rank;
      const float* gradient = static_cast<const float*>(
          matrix_a ? adapter->grad_a.data() : adapter->grad_b.data());
      float norm = 0.0F;
      check_cublas(cublasSnrm2(handle, count, gradient, 1, &norm),
                   "cublasSnrm2 LoRA gradient");
      sum += static_cast<double>(norm) * norm;
    }
    return std::sqrt(sum);
  }
  double gradient_norm(const lora_adapter& adapter, bool matrix_a) {
    const int count = matrix_a ? adapter.rank * adapter.input
                               : adapter.output * adapter.rank;
    const float* gradient = static_cast<const float*>(
        matrix_a ? adapter.grad_a.data() : adapter.grad_b.data());
    float norm = 0.0F;
    check_cublas(cublasSnrm2(handle, count, gradient, 1, &norm),
                 "cublasSnrm2 measured LoRA gradient");
    return norm;
  }
  void update_adapters(int step, float learning_rate) {
    for (lora_adapter* adapter : adapters()) {
      const int a_count = adapter->rank * adapter->input;
      const int b_count = adapter->output * adapter->rank;
      kernels::adam_update<<<kernels::blocks(a_count), 256>>>(
          static_cast<float*>(adapter->a.data()),
          static_cast<const float*>(adapter->grad_a.data()),
          static_cast<float*>(adapter->first_a.data()),
          static_cast<float*>(adapter->second_a.data()), a_count, step, learning_rate);
      kernels::adam_update<<<kernels::blocks(b_count), 256>>>(
          static_cast<float*>(adapter->b.data()),
          static_cast<const float*>(adapter->grad_b.data()),
          static_cast<float*>(adapter->first_b.data()),
          static_cast<float*>(adapter->second_b.data()), b_count, step, learning_rate);
    }
    check_cuda(cudaGetLastError(), "LoRA Adam kernel launch");
    check_cuda(cudaDeviceSynchronize(), "LoRA Adam synchronize");
  }
  float forward_backward_lora(const std::vector<int32_t>& ids,
                              const std::vector<int32_t>& labels) {
    const int tokens = static_cast<int>(ids.size());
    const int hidden = static_cast<int>(config.hidden_size);
    const int head_dimension = static_cast<int>(config.head_dim());
    const int query_heads = static_cast<int>(config.num_attention_heads);
    const int kv_heads = static_cast<int>(config.num_key_value_heads);
    const int query_width = query_heads * head_dimension;
    const int kv_width = kv_heads * head_dimension;
    const int intermediate = static_cast<int>(config.intermediate_size);
    const int vocab = static_cast<int>(config.vocab_size);
    const int td = tokens * hidden;
    const int tq = tokens * query_width;
    const int tkv = tokens * kv_width;
    const int tf = tokens * intermediate;
    int supervised = 0;
    for (int token = 1; token < tokens; ++token) {
      if (labels[token] >= 0) ++supervised;
    }
    if (supervised == 0) throw std::invalid_argument("LoRA training batch has no supervised labels");

    std::vector<training_layer_cache> cache;
    cache.reserve(layers.size());
    for (std::size_t index = 0; index < layers.size(); ++index) {
      cache.emplace_back(tokens, hidden, query_width, kv_width, intermediate);
    }
    device_buffer device_ids(ids.size() * sizeof(int32_t));
    device_buffer device_labels(labels.size() * sizeof(int32_t));
    device_buffer state(static_cast<std::size_t>(td) * sizeof(float));
    device_buffer projection(static_cast<std::size_t>(td) * sizeof(float));
    device_buffer down(static_cast<std::size_t>(td) * sizeof(float));
    device_buffer lora_hidden;
    check_cuda(cudaMemcpy(device_ids.data(), ids.data(), device_ids.bytes(), cudaMemcpyHostToDevice),
               "copy LoRA training ids");
    check_cuda(cudaMemcpy(device_labels.data(), labels.data(), device_labels.bytes(), cudaMemcpyHostToDevice),
               "copy LoRA training labels");
    kernels::embedding<<<kernels::blocks(td), 256>>>(
        static_cast<const int32_t*>(device_ids.data()),
        static_cast<const float*>(embedding.data()), static_cast<float*>(state.data()),
        tokens, hidden);
    for (std::size_t index = 0; index < layers.size(); ++index) {
      layer& current = layers[index];
      training_layer_cache& current_cache = cache[index];
      kernels::copy_values<<<kernels::blocks(td), 256>>>(
          static_cast<const float*>(state.data()), static_cast<float*>(current_cache.x.data()), td);
      kernels::rms_norm<<<kernels::blocks(tokens), 256>>>(
          static_cast<const float*>(current_cache.x.data()),
          static_cast<const float*>(current.input_norm.data()),
          static_cast<float*>(current_cache.normalized_attention.data()), tokens, hidden,
          static_cast<float>(config.rms_norm_eps));
      run_linear(handle, static_cast<const float*>(current_cache.normalized_attention.data()),
                 tokens, current.q, static_cast<float*>(current_cache.query.data()));
      run_lora_forward(handle, static_cast<const float*>(current_cache.normalized_attention.data()),
                       tokens, current.lora_q, static_cast<float*>(current_cache.query.data()),
                       &lora_hidden);
      run_linear(handle, static_cast<const float*>(current_cache.normalized_attention.data()),
                 tokens, current.k, static_cast<float*>(current_cache.key.data()));
      run_lora_forward(handle, static_cast<const float*>(current_cache.normalized_attention.data()),
                       tokens, current.lora_k, static_cast<float*>(current_cache.key.data()),
                       &lora_hidden);
      run_linear(handle, static_cast<const float*>(current_cache.normalized_attention.data()),
                 tokens, current.v, static_cast<float*>(current_cache.value.data()));
      run_lora_forward(handle, static_cast<const float*>(current_cache.normalized_attention.data()),
                       tokens, current.lora_v, static_cast<float*>(current_cache.value.data()),
                       &lora_hidden);
      kernels::rope_half<<<kernels::blocks(tokens * query_heads * (head_dimension / 2)), 256>>>(
          static_cast<float*>(current_cache.query.data()), tokens, query_heads,
          head_dimension, 0, static_cast<float>(config.rope_theta));
      kernels::rope_half<<<kernels::blocks(tokens * kv_heads * (head_dimension / 2)), 256>>>(
          static_cast<float*>(current_cache.key.data()), tokens, kv_heads,
          head_dimension, 0, static_cast<float>(config.rope_theta));
      kernels::attention_gqa<<<tokens * query_heads, 256>>>(
          static_cast<const float*>(current_cache.query.data()),
          static_cast<const float*>(current_cache.key.data()),
          static_cast<const float*>(current_cache.value.data()),
          static_cast<float*>(current_cache.attention.data()), tokens, 0,
          query_heads, kv_heads, head_dimension);
      run_linear(handle, static_cast<const float*>(current_cache.attention.data()),
                 tokens, current.o, static_cast<float*>(projection.data()));
      run_lora_forward(handle, static_cast<const float*>(current_cache.attention.data()),
                       tokens, current.lora_o, static_cast<float*>(projection.data()),
                       &lora_hidden);
      kernels::copy_values<<<kernels::blocks(td), 256>>>(
          static_cast<const float*>(current_cache.x.data()),
          static_cast<float*>(current_cache.residual.data()), td);
      kernels::add_values_in_place<<<kernels::blocks(td), 256>>>(
          static_cast<float*>(current_cache.residual.data()),
          static_cast<const float*>(projection.data()), td);
      kernels::rms_norm<<<kernels::blocks(tokens), 256>>>(
          static_cast<const float*>(current_cache.residual.data()),
          static_cast<const float*>(current.post_norm.data()),
          static_cast<float*>(current_cache.normalized_mlp.data()), tokens, hidden,
          static_cast<float>(config.rms_norm_eps));
      run_linear(handle, static_cast<const float*>(current_cache.normalized_mlp.data()),
                 tokens, current.gate, static_cast<float*>(current_cache.gate.data()));
      run_linear(handle, static_cast<const float*>(current_cache.normalized_mlp.data()),
                 tokens, current.up, static_cast<float*>(current_cache.up.data()));
      kernels::copy_values<<<kernels::blocks(tf), 256>>>(
          static_cast<const float*>(current_cache.gate.data()),
          static_cast<float*>(current_cache.swiglu.data()), tf);
      kernels::swiglu_in_place<<<kernels::blocks(tf), 256>>>(
          static_cast<float*>(current_cache.swiglu.data()),
          static_cast<const float*>(current_cache.up.data()), tf);
      run_linear(handle, static_cast<const float*>(current_cache.swiglu.data()),
                 tokens, current.down, static_cast<float*>(down.data()));
      kernels::copy_values<<<kernels::blocks(td), 256>>>(
          static_cast<const float*>(current_cache.residual.data()),
          static_cast<float*>(current_cache.hidden.data()), td);
      kernels::add_values_in_place<<<kernels::blocks(td), 256>>>(
          static_cast<float*>(current_cache.hidden.data()),
          static_cast<const float*>(down.data()), td);
      kernels::copy_values<<<kernels::blocks(td), 256>>>(
          static_cast<const float*>(current_cache.hidden.data()),
          static_cast<float*>(state.data()), td);
    }

    device_buffer final_normalized(static_cast<std::size_t>(td) * sizeof(float));
    kernels::rms_norm<<<kernels::blocks(tokens), 256>>>(
        static_cast<const float*>(state.data()), static_cast<const float*>(final_norm.data()),
        static_cast<float*>(final_normalized.data()), tokens, hidden,
        static_cast<float>(config.rms_norm_eps));
    device_buffer logits(static_cast<std::size_t>(tokens) * vocab * sizeof(float));
    const float one = 1.0F;
    const float zero = 0.0F;
    check_cublas(cublasSgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N, vocab, tokens, hidden,
                             &one, output_weight(), hidden,
                             static_cast<const float*>(final_normalized.data()), hidden,
                             &zero, static_cast<float*>(logits.data()), vocab),
                 "LoRA training lm_head");
    device_buffer gradient_logits(logits.bytes());
    device_buffer loss(sizeof(float));
    check_cuda(cudaMemset(loss.data(), 0, sizeof(float)), "zero LoRA loss");
    kernels::shifted_cross_entropy_backward<<<tokens, 256>>>(
        static_cast<const float*>(logits.data()),
        static_cast<const int32_t*>(device_labels.data()), static_cast<float*>(loss.data()),
        static_cast<float*>(gradient_logits.data()), tokens, vocab, supervised);

    device_buffer upstream(static_cast<std::size_t>(td) * sizeof(float));
    run_backward_input(handle, static_cast<const float*>(gradient_logits.data()), tokens,
                       output_weight(), hidden, vocab,
                       static_cast<float*>(upstream.data()));
    device_buffer normalized_gradient(static_cast<std::size_t>(td) * sizeof(float));
    kernels::rms_norm_backward<<<kernels::blocks(tokens), 256>>>(
        static_cast<const float*>(state.data()), static_cast<const float*>(final_norm.data()),
        static_cast<const float*>(upstream.data()),
        static_cast<float*>(normalized_gradient.data()), tokens, hidden,
        static_cast<float>(config.rms_norm_eps));
    std::swap(upstream, normalized_gradient);

    device_buffer gradient_residual(static_cast<std::size_t>(td) * sizeof(float));
    device_buffer gradient_swiglu(static_cast<std::size_t>(tf) * sizeof(float));
    device_buffer gradient_gate(static_cast<std::size_t>(tf) * sizeof(float));
    device_buffer gradient_up(static_cast<std::size_t>(tf) * sizeof(float));
    device_buffer gradient_normalized_mlp(static_cast<std::size_t>(td) * sizeof(float));
    device_buffer scratch_td(static_cast<std::size_t>(td) * sizeof(float));
    device_buffer gradient_attention(static_cast<std::size_t>(tq) * sizeof(float));
    device_buffer gradient_query(static_cast<std::size_t>(tq) * sizeof(float));
    device_buffer gradient_key(static_cast<std::size_t>(tkv) * sizeof(float));
    device_buffer gradient_value(static_cast<std::size_t>(tkv) * sizeof(float));
    device_buffer gradient_normalized_attention(static_cast<std::size_t>(td) * sizeof(float));
    device_buffer lora_gradient_hidden;
    for (std::size_t reverse = layers.size(); reverse-- > 0;) {
      layer& current = layers[reverse];
      training_layer_cache& current_cache = cache[reverse];
      kernels::copy_values<<<kernels::blocks(td), 256>>>(
          static_cast<const float*>(upstream.data()),
          static_cast<float*>(gradient_residual.data()), td);
      run_backward_input(handle, static_cast<const float*>(upstream.data()), tokens,
                         static_cast<const float*>(current.down.weight.data()),
                         intermediate, hidden, static_cast<float*>(gradient_swiglu.data()));
      kernels::swiglu_backward<<<kernels::blocks(tf), 256>>>(
          static_cast<const float*>(current_cache.gate.data()),
          static_cast<const float*>(current_cache.up.data()),
          static_cast<const float*>(gradient_swiglu.data()),
          static_cast<float*>(gradient_gate.data()),
          static_cast<float*>(gradient_up.data()), tf);
      run_backward_input(handle, static_cast<const float*>(gradient_gate.data()), tokens,
                         static_cast<const float*>(current.gate.weight.data()),
                         hidden, intermediate,
                         static_cast<float*>(gradient_normalized_mlp.data()));
      run_backward_input(handle, static_cast<const float*>(gradient_up.data()), tokens,
                         static_cast<const float*>(current.up.weight.data()),
                         hidden, intermediate, static_cast<float*>(scratch_td.data()));
      kernels::add_values_in_place<<<kernels::blocks(td), 256>>>(
          static_cast<float*>(gradient_normalized_mlp.data()),
          static_cast<const float*>(scratch_td.data()), td);
      kernels::rms_norm_backward<<<kernels::blocks(tokens), 256>>>(
          static_cast<const float*>(current_cache.residual.data()),
          static_cast<const float*>(current.post_norm.data()),
          static_cast<const float*>(gradient_normalized_mlp.data()),
          static_cast<float*>(scratch_td.data()), tokens, hidden,
          static_cast<float>(config.rms_norm_eps));
      kernels::add_values_in_place<<<kernels::blocks(td), 256>>>(
          static_cast<float*>(gradient_residual.data()),
          static_cast<const float*>(scratch_td.data()), td);
      run_linear_lora_backward(
          handle, static_cast<const float*>(current_cache.attention.data()), current.o,
          &current.lora_o, static_cast<const float*>(gradient_residual.data()), tokens,
          static_cast<float*>(gradient_attention.data()), &lora_hidden,
          &lora_gradient_hidden);
      check_cuda(cudaMemset(gradient_query.data(), 0, gradient_query.bytes()), "zero query gradient");
      check_cuda(cudaMemset(gradient_key.data(), 0, gradient_key.bytes()), "zero key gradient");
      check_cuda(cudaMemset(gradient_value.data(), 0, gradient_value.bytes()), "zero value gradient");
      const std::size_t attention_shared = static_cast<std::size_t>(2 * tokens + 256) * sizeof(float);
      kernels::attention_gqa_backward<<<tokens * query_heads, 256, attention_shared>>>(
          static_cast<const float*>(current_cache.query.data()),
          static_cast<const float*>(current_cache.key.data()),
          static_cast<const float*>(current_cache.value.data()),
          static_cast<const float*>(gradient_attention.data()),
          static_cast<float*>(gradient_query.data()),
          static_cast<float*>(gradient_key.data()),
          static_cast<float*>(gradient_value.data()), tokens, query_heads, kv_heads,
          head_dimension);
      kernels::rope_half_backward<<<kernels::blocks(tokens * query_heads * (head_dimension / 2)), 256>>>(
          static_cast<float*>(gradient_query.data()), tokens, query_heads,
          head_dimension, 0, static_cast<float>(config.rope_theta));
      kernels::rope_half_backward<<<kernels::blocks(tokens * kv_heads * (head_dimension / 2)), 256>>>(
          static_cast<float*>(gradient_key.data()), tokens, kv_heads,
          head_dimension, 0, static_cast<float>(config.rope_theta));
      run_linear_lora_backward(
          handle, static_cast<const float*>(current_cache.normalized_attention.data()), current.q,
          &current.lora_q, static_cast<const float*>(gradient_query.data()), tokens,
          static_cast<float*>(gradient_normalized_attention.data()), &lora_hidden,
          &lora_gradient_hidden);
      run_linear_lora_backward(
          handle, static_cast<const float*>(current_cache.normalized_attention.data()), current.k,
          &current.lora_k, static_cast<const float*>(gradient_key.data()), tokens,
          static_cast<float*>(scratch_td.data()), &lora_hidden, &lora_gradient_hidden);
      kernels::add_values_in_place<<<kernels::blocks(td), 256>>>(
          static_cast<float*>(gradient_normalized_attention.data()),
          static_cast<const float*>(scratch_td.data()), td);
      run_linear_lora_backward(
          handle, static_cast<const float*>(current_cache.normalized_attention.data()), current.v,
          &current.lora_v, static_cast<const float*>(gradient_value.data()), tokens,
          static_cast<float*>(scratch_td.data()), &lora_hidden, &lora_gradient_hidden);
      kernels::add_values_in_place<<<kernels::blocks(td), 256>>>(
          static_cast<float*>(gradient_normalized_attention.data()),
          static_cast<const float*>(scratch_td.data()), td);
      kernels::rms_norm_backward<<<kernels::blocks(tokens), 256>>>(
          static_cast<const float*>(current_cache.x.data()),
          static_cast<const float*>(current.input_norm.data()),
          static_cast<const float*>(gradient_normalized_attention.data()),
          static_cast<float*>(scratch_td.data()), tokens, hidden,
          static_cast<float>(config.rms_norm_eps));
      kernels::add_values_in_place<<<kernels::blocks(td), 256>>>(
          static_cast<float*>(scratch_td.data()),
          static_cast<const float*>(gradient_residual.data()), td);
      kernels::copy_values<<<kernels::blocks(td), 256>>>(
          static_cast<const float*>(scratch_td.data()), static_cast<float*>(upstream.data()), td);
    }
    check_cuda(cudaGetLastError(), "LoRA backward kernel launch");
    check_cuda(cudaDeviceSynchronize(), "LoRA forward/backward synchronize");
    float host_loss = 0.0F;
    check_cuda(cudaMemcpy(&host_loss, loss.data(), sizeof(float), cudaMemcpyDeviceToHost),
               "copy LoRA loss");
    if (!std::isfinite(host_loss) || host_loss <= 0.0F) {
      throw std::runtime_error("LoRA backward produced invalid loss");
    }
    return host_loss;
  }
  lora_training_report train_lora_two_steps(const std::vector<int32_t>& ids,
                                            const std::vector<int32_t>& labels,
                                            int rank, float alpha,
                                            float learning_rate) {
    if (ids.size() != labels.size() || ids.size() < 2) {
      throw std::invalid_argument("LoRA ids/labels are invalid");
    }
    if (rank <= 0 || !std::isfinite(alpha) || alpha <= 0.0F ||
        !std::isfinite(learning_rate) || learning_rate <= 0.0F) {
      throw std::invalid_argument("LoRA optimizer configuration is invalid");
    }
    initialize_adapters(rank, alpha);
    lora_training_report report;
    auto all = adapters();
    report.module_count = all.size();
    for (lora_adapter* adapter : all) {
      report.parameter_count += static_cast<std::size_t>(adapter->rank) * adapter->input +
                                static_cast<std::size_t>(adapter->output) * adapter->rank;
    }
    lora_adapter& measured = *all.front();
    report.measured_tensor = measured.name;
    std::vector<float> initial_a(static_cast<std::size_t>(measured.rank) * measured.input);
    std::vector<float> initial_b(static_cast<std::size_t>(measured.output) * measured.rank);
    check_cuda(cudaMemcpy(initial_a.data(), measured.a.data(), measured.a.bytes(),
                          cudaMemcpyDeviceToHost), "copy initial LoRA A tensor");
    check_cuda(cudaMemcpy(initial_b.data(), measured.b.data(), measured.b.bytes(),
                          cudaMemcpyDeviceToHost), "copy initial LoRA B tensor");
    report.initial_loss = forward_backward_lora(ids, labels);
    update_adapters(1, learning_rate);
    report.final_loss = forward_backward_lora(ids, labels);
    report.lora_a_grad_norm = adapter_gradient_norm(true);
    report.lora_b_grad_norm = adapter_gradient_norm(false);
    report.measured_a_grad_norm = gradient_norm(measured, true);
    report.measured_b_grad_norm = gradient_norm(measured, false);
    if (!std::isfinite(report.lora_a_grad_norm) || report.lora_a_grad_norm <= 0.0 ||
        !std::isfinite(report.lora_b_grad_norm) || report.lora_b_grad_norm <= 0.0 ||
        !std::isfinite(report.measured_a_grad_norm) || report.measured_a_grad_norm <= 0.0 ||
        !std::isfinite(report.measured_b_grad_norm) || report.measured_b_grad_norm <= 0.0) {
      throw std::runtime_error("LoRA A/B gradient norms are not finite and non-zero");
    }
    update_adapters(2, learning_rate);
    std::vector<float> final_a(initial_a.size());
    std::vector<float> final_b(initial_b.size());
    check_cuda(cudaMemcpy(final_a.data(), measured.a.data(), measured.a.bytes(),
                          cudaMemcpyDeviceToHost), "copy final LoRA A tensor");
    check_cuda(cudaMemcpy(final_b.data(), measured.b.data(), measured.b.bytes(),
                          cudaMemcpyDeviceToHost), "copy final LoRA B tensor");
    float largest_a_change = 0.0F;
    float largest_b_change = 0.0F;
    for (std::size_t index = 0; index < initial_a.size(); ++index) {
      const float change = std::fabs(final_a[index] - initial_a[index]);
      if (change > largest_a_change) {
        largest_a_change = change;
        report.a_changed_index = index;
      }
    }
    for (std::size_t index = 0; index < initial_b.size(); ++index) {
      const float change = std::fabs(final_b[index] - initial_b[index]);
      if (change > largest_b_change) {
        largest_b_change = change;
        report.b_changed_index = index;
      }
    }
    report.a_before = initial_a[report.a_changed_index];
    report.a_after = final_a[report.a_changed_index];
    report.b_before = initial_b[report.b_changed_index];
    report.b_after = final_b[report.b_changed_index];
    if (!(largest_a_change > 0.0F) || !(largest_b_change > 0.0F)) {
      throw std::runtime_error("LoRA optimizer did not change measured A/B values");
    }
    report.tensors.reserve(all.size() * 2);
    for (lora_adapter* adapter : all) {
      lora_tensor_snapshot a_snapshot;
      a_snapshot.name = adapter->name + ".lora_A.weight";
      a_snapshot.shape = {adapter->rank, adapter->input};
      a_snapshot.values.resize(static_cast<std::size_t>(adapter->rank) * adapter->input);
      check_cuda(cudaMemcpy(a_snapshot.values.data(), adapter->a.data(), adapter->a.bytes(),
                            cudaMemcpyDeviceToHost), "copy LoRA A checkpoint tensor");
      report.tensors.push_back(std::move(a_snapshot));
      lora_tensor_snapshot b_snapshot;
      b_snapshot.name = adapter->name + ".lora_B.weight";
      b_snapshot.shape = {adapter->output, adapter->rank};
      b_snapshot.values.resize(static_cast<std::size_t>(adapter->output) * adapter->rank);
      check_cuda(cudaMemcpy(b_snapshot.values.data(), adapter->b.data(), adapter->b.bytes(),
                            cudaMemcpyDeviceToHost), "copy LoRA B checkpoint tensor");
      report.tensors.push_back(std::move(b_snapshot));
    }
    return report;
  }
  ~impl() {
    if (handle) cublasDestroy(handle);
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
  std::vector<float> forward(const std::vector<int32_t>& ids, hf_cuda_kv_cache::state* cache,
                             bool return_all_logits) {
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
    check_cuda(cudaMemcpy(device_ids.data(), ids.data(), device_ids.bytes(), cudaMemcpyHostToDevice),
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
      check_cuda(cudaMemcpy(static_cast<char*>(cache->keys[index].data()) + offset, key.data(),
                            key.bytes(), cudaMemcpyDeviceToDevice), "append CUDA K cache");
      check_cuda(cudaMemcpy(static_cast<char*>(cache->values[index].data()) + offset, value.data(),
                            value.bytes(), cudaMemcpyDeviceToDevice), "append CUDA V cache");
      kernels::attention_gqa<<<tokens * query_heads, 256>>>(
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
    const int output_rows = return_all_logits ? tokens : 1;
    device_buffer logits(static_cast<std::size_t>(output_rows) * config.vocab_size * sizeof(float));
    const float alpha = 1.0F;
    const float beta = 0.0F;
    const float* output_hidden = static_cast<const float*>(normalized.data());
    if (!return_all_logits) {
      output_hidden += static_cast<std::size_t>(tokens - 1) * hidden;
    }
    check_cublas(cublasSgemm(handle, CUBLAS_OP_T, CUBLAS_OP_N,
                             static_cast<int>(config.vocab_size), output_rows, hidden, &alpha,
                             output_weight(), hidden,
                             output_hidden, hidden, &beta,
                             static_cast<float*>(logits.data()), static_cast<int>(config.vocab_size)),
                 "CUDA lm_head");
    check_cuda(cudaGetLastError(), "CUDA HF decoder kernel launch");
    std::vector<float> host(static_cast<std::size_t>(output_rows) * config.vocab_size);
    check_cuda(cudaMemcpy(host.data(), logits.data(), logits.bytes(), cudaMemcpyDeviceToHost),
               "copy CUDA logits to host");
    cache->length += ids.size();
    return host;
  }
};
hf_decoder_cuda::hf_decoder_cuda(const std::string& directory, int device)
    : impl_(new impl(directory, device)) {}
hf_decoder_cuda::hf_decoder_cuda(const std::string& directory,
                                 const runtime::model::hf_config& config, int device)
    : impl_(new impl(directory, config, device)) {}
hf_decoder_cuda::~hf_decoder_cuda() = default;
hf_decoder_cuda::hf_decoder_cuda(hf_decoder_cuda&&) noexcept = default;
hf_decoder_cuda& hf_decoder_cuda::operator=(hf_decoder_cuda&&) noexcept = default;
const runtime::model::hf_config& hf_decoder_cuda::config() const { return impl_->config; }
std::size_t hf_decoder_cuda::weight_count() const { return impl_->weight_count; }
std::vector<float> hf_decoder_cuda::prefill(const std::vector<int32_t>& ids,
                                          hf_cuda_kv_cache* cache) {
  if (cache == nullptr) throw std::invalid_argument("CUDA decoder KV cache is null");
  cache->clear();
  return impl_->forward(ids, cache->state_.get(), false);
}
std::vector<float> hf_decoder_cuda::prefill_all(const std::vector<int32_t>& ids,
                                               hf_cuda_kv_cache* cache) {
  if (cache == nullptr) throw std::invalid_argument("CUDA decoder KV cache is null");
  cache->clear();
  return impl_->forward(ids, cache->state_.get(), true);
}
lora_training_report hf_decoder_cuda::train_lora_two_steps(
    const std::vector<int32_t>& token_ids, const std::vector<int32_t>& labels,
    int rank, float alpha, float learning_rate) {
  return impl_->train_lora_two_steps(token_ids, labels, rank, alpha, learning_rate);
}
std::vector<float> hf_decoder_cuda::decode(int32_t token, hf_cuda_kv_cache* cache) {
  if (cache == nullptr) throw std::invalid_argument("CUDA decoder KV cache is null");
  return impl_->forward({token}, cache->state_.get(), false);
}
int32_t hf_decoder_cuda::greedy(const std::vector<float>& logits) {
  if (logits.empty()) throw std::invalid_argument("cannot sample empty CUDA logits");
  return static_cast<int32_t>(std::max_element(logits.begin(), logits.end()) - logits.begin());
}
}
