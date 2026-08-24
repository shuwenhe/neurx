#include "../api/device_plugin_abi.h"
#define block_idx blockIdx
#define block_dim blockDim
#define thread_idx threadIdx
#define atomic_add atomicAdd
#include "transformer_kernels.cuh"
#undef atomic_add
#undef thread_idx
#undef block_dim
#undef block_idx

#include <cuda_runtime.h>
#include <mutex>
#include <string>
#include <unordered_map>
#include <sstream>

namespace {
struct buffer_record { void* address; int bytes; bool host; };
struct context_record {
  int device = 0;
  int next = 1;
  std::unordered_map<int, buffer_record> buffer;
  std::unordered_map<int, cudaStream_t> stream;
  struct operation_record { std::string kind; std::unordered_map<std::string, std::string> attribute; };
  std::unordered_map<int, operation_record> operation;
  std::string error;
};
std::mutex state_mutex;
std::unordered_map<int, context_record> context;
int next_context = 1;
thread_local std::string global_error;

int cuda_result(context_record* state, cudaError_t result, const char* action) {
  if (result == cudaSuccess) return 0;
  std::string message = std::string(action) + ": " + cudaGetErrorString(result);
  if (state) state->error = message; else global_error = message;
  return -1;
}
context_record* get_context(int handle) {
  auto found = context.find(handle);
  return found == context.end() ? nullptr : &found->second;
}
std::unordered_map<std::string, std::string> parse_fields(const char* text) {
  std::unordered_map<std::string, std::string> result;
  std::stringstream stream(text ? text : ""); std::string item;
  while (std::getline(stream, item, ';')) {
    std::size_t equal = item.find('=');
    if (equal != std::string::npos) result[item.substr(0, equal)] = item.substr(equal + 1);
  }
  return result;
}
int integer(const std::unordered_map<std::string, std::string>& values,
            const char* key, int fallback = 0) {
  auto found = values.find(key); if (found == values.end()) return fallback;
  try { return std::stoi(found->second); } catch (...) { return fallback; }
}
float decimal(const std::unordered_map<std::string, std::string>& values,
              const char* key, float fallback) {
  auto found = values.find(key); if (found == values.end()) return fallback;
  try { return std::stof(found->second); } catch (...) { return fallback; }
}
void* address(context_record* state, const std::unordered_map<std::string, std::string>& binding,
              const char* name, bool optional = false) {
  int handle = integer(binding, name);
  if (optional && handle == 0) return nullptr;
  auto found = state->buffer.find(handle);
  return found == state->buffer.end() ? nullptr : found->second.address;
}
__global__ void rms_norm_inference(const float* input, const float* weight, float* output,
                                   int rows, int hidden, float epsilon) {
  int row = blockIdx.x * blockDim.x + threadIdx.x; if (row >= rows) return;
  float square = 0.0f; for (int i = 0; i < hidden; ++i) square += input[row * hidden + i] * input[row * hidden + i];
  float scale = rsqrtf(square / hidden + epsilon);
  for (int i = 0; i < hidden; ++i) output[row * hidden + i] = input[row * hidden + i] * scale * weight[i];
}
__global__ void add_bias(float* output, const float* bias, int rows, int columns) {
  int index = blockIdx.x * blockDim.x + threadIdx.x; if (index < rows * columns) output[index] += bias[index % columns];
}
__global__ void rope_inference(float* input, int tokens, int heads, int head_dim,
                               int start_position, float theta) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int pair_count = head_dim / 2; int total = tokens * heads * pair_count; if (index >= total) return;
  int pair = index % pair_count; int head = (index / pair_count) % heads; int token = index / (pair_count * heads);
  int column = pair * 2; float angle = float(start_position + token) / powf(theta, float(column) / head_dim);
  float cosine = cosf(angle), sine = sinf(angle); int offset = token * heads * head_dim + head * head_dim + column;
  float first = input[offset], second = input[offset + 1]; input[offset] = first * cosine - second * sine; input[offset + 1] = first * sine + second * cosine;
}
__global__ void paged_attention_decode_v1(const float* query, const float* key_cache,
    const float* value_cache, const int* block_table, float* score, float* output,
    int position, int max_sequence, int query_heads, int kv_heads, int head_dim, int block_size) {
  int head = blockIdx.x * blockDim.x + threadIdx.x; if (head >= query_heads) return;
  int kv_head = head * kv_heads / query_heads; float scale = rsqrtf(float(head_dim)); float maximum = -INFINITY;
  for (int token = 0; token <= position; ++token) {
    int physical = token; if (block_table && block_size > 0) physical = block_table[token / block_size] * block_size + token % block_size;
    float value = 0.0f; for (int column = 0; column < head_dim; ++column)
      value += query[head * head_dim + column] * key_cache[(physical * kv_heads + kv_head) * head_dim + column];
    value *= scale; score[head * max_sequence + token] = value; maximum = fmaxf(maximum, value);
  }
  float denominator = 0.0f; for (int token = 0; token <= position; ++token) denominator += expf(score[head * max_sequence + token] - maximum);
  for (int column = 0; column < head_dim; ++column) { float value = 0.0f;
    for (int token = 0; token <= position; ++token) { int physical = token; if (block_table && block_size > 0) physical = block_table[token / block_size] * block_size + token % block_size;
      float probability = expf(score[head * max_sequence + token] - maximum) / denominator;
      value += probability * value_cache[(physical * kv_heads + kv_head) * head_dim + column]; }
    output[head * head_dim + column] = value;
  }
}
int probe() { int count = 0; return cudaGetDeviceCount(&count) == cudaSuccess ? count : 0; }
int create(int device, const char*) {
  std::lock_guard<std::mutex> lock(state_mutex);
  if (cuda_result(nullptr, cudaSetDevice(device), "cudaSetDevice") != 0) return -1;
  int handle = next_context++;
  context.emplace(handle, context_record{device});
  return handle;
}
int destroy(int handle) {
  std::lock_guard<std::mutex> lock(state_mutex);
  auto found = context.find(handle);
  if (found == context.end()) return -1;
  if (!found->second.buffer.empty() || !found->second.stream.empty() ||
      !found->second.operation.empty()) return -1;
  context.erase(found);
  return 0;
}
int alloc(int handle, int bytes, const char* kind) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* state = get_context(handle);
  if (!state || bytes <= 0) return -1;
  cudaSetDevice(state->device);
  bool host = kind && std::string(kind) == "host";
  void* address = nullptr;
  cudaError_t result = host ? cudaMallocHost(&address, bytes) : cudaMalloc(&address, bytes);
  if (cuda_result(state, result, host ? "cudaMallocHost" : "cudaMalloc") != 0) return -1;
  int resource = state->next++;
  state->buffer.emplace(resource, buffer_record{address, bytes, host});
  return resource;
}
int free_buffer(int handle, int resource) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* state = get_context(handle);
  if (!state) return -1;
  auto found = state->buffer.find(resource);
  if (found == state->buffer.end()) return -1;
  cudaSetDevice(state->device);
  cudaError_t result = found->second.host ? cudaFreeHost(found->second.address)
                                          : cudaFree(found->second.address);
  if (cuda_result(state, result, "cudaFree") != 0) return -1;
  state->buffer.erase(found);
  return 0;
}
int copy_buffer(int handle, int destination, int source, int bytes, int direction) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* state = get_context(handle);
  if (!state) return -1;
  auto destination_record = state->buffer.find(destination);
  auto source_record = state->buffer.find(source);
  if (destination_record == state->buffer.end() || source_record == state->buffer.end() ||
      bytes < 0 || bytes > destination_record->second.bytes || bytes > source_record->second.bytes)
    return -1;
  cudaMemcpyKind kind = direction == 1 ? cudaMemcpyHostToDevice :
                        direction == 2 ? cudaMemcpyDeviceToHost : cudaMemcpyDeviceToDevice;
  return cuda_result(state, cudaMemcpy(destination_record->second.address,
      source_record->second.address, bytes, kind), "cudaMemcpy");
}
int stream_create(int handle, int priority) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* state = get_context(handle);
  if (!state) return -1;
  cudaSetDevice(state->device);
  cudaStream_t stream = nullptr;
  if (cuda_result(state, cudaStreamCreateWithPriority(&stream, cudaStreamNonBlocking, priority),
                  "cudaStreamCreateWithPriority") != 0) return -1;
  int resource = state->next++;
  state->stream.emplace(resource, stream);
  return resource;
}
int stream_destroy(int handle, int resource) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* state = get_context(handle);
  if (!state) return -1;
  auto found = state->stream.find(resource);
  if (found == state->stream.end()) return -1;
  if (cuda_result(state, cudaStreamDestroy(found->second), "cudaStreamDestroy") != 0) return -1;
  state->stream.erase(found);
  return 0;
}
int op_create(int handle, const char* descriptor) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* state = get_context(handle);
  if (!state || !descriptor || !*descriptor) return -1;
  auto attribute = parse_fields(descriptor);
  auto version = attribute.find("op");
  if (std::string(descriptor).rfind("v1;", 0) != 0 || version == attribute.end()) {
    state->error = "invalid v1 operator descriptor"; return -1;
  }
  const std::string& kind = version->second;
  if (kind != "embedding" && kind != "rms_norm" && kind != "linear" && kind != "rope" &&
      kind != "paged_attention" && kind != "swiglu" && kind != "residual_add") {
    state->error = "unsupported CUDA operator: " + kind; return -1;
  }
  auto dtype = attribute.find("dtype");
  if (dtype == attribute.end() || dtype->second != "float32") {
    state->error = "CUDA Device ABI v1 currently requires dtype=float32"; return -1;
  }
  int resource = state->next++;
  state->operation.emplace(resource, context_record::operation_record{kind, std::move(attribute)});
  return resource;
}
int op_destroy(int handle, int resource) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* state = get_context(handle);
  return state && state->operation.erase(resource) == 1 ? 0 : -1;
}
int op_launch(int handle, int operation, int stream_resource, const char* binding_text) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* state = get_context(handle);
  if (!state) return -1;
  auto operation_found = state->operation.find(operation);
  if (operation_found == state->operation.end()) return -1;
  cudaStream_t queue = nullptr;
  if (stream_resource != 0) { auto stream_found = state->stream.find(stream_resource); if (stream_found == state->stream.end()) return -1; queue = stream_found->second; }
  auto binding = parse_fields(binding_text);
  auto& op = operation_found->second; cudaSetDevice(state->device);
  using namespace neurx_cuda_transformer;
  if (op.kind == "embedding") {
    int tokens = integer(binding, "tokens"), hidden = integer(op.attribute, "hidden");
    auto ids = static_cast<const int*>(address(state, binding, "buffer.ids"));
    auto weight = static_cast<const float*>(address(state, binding, "buffer.weight"));
    auto output = static_cast<float*>(address(state, binding, "buffer.output"));
    if (!ids || !weight || !output || tokens <= 0 || hidden <= 0) return -1;
    embedding_fwd<<<blocks(tokens * hidden), 256, 0, queue>>>(ids, weight, output, tokens, hidden);
  } else if (op.kind == "rms_norm") {
    int rows = integer(binding, "rows"), hidden = integer(op.attribute, "hidden");
    auto input = static_cast<const float*>(address(state, binding, "buffer.input"));
    auto weight = static_cast<const float*>(address(state, binding, "buffer.weight"));
    auto output = static_cast<float*>(address(state, binding, "buffer.output"));
    if (!input || !weight || !output || rows <= 0 || hidden <= 0) return -1;
    rms_norm_inference<<<blocks(rows), 256, 0, queue>>>(input, weight, output, rows, hidden, decimal(op.attribute, "epsilon", 1e-5f));
  } else if (op.kind == "linear") {
    int rows = integer(binding, "rows"), input_size = integer(op.attribute, "input"), output_size = integer(op.attribute, "output");
    auto input = static_cast<const float*>(address(state, binding, "buffer.input"));
    auto weight = static_cast<const float*>(address(state, binding, "buffer.weight"));
    auto bias = static_cast<const float*>(address(state, binding, "buffer.bias", true));
    auto output = static_cast<float*>(address(state, binding, "buffer.output"));
    if (!input || !weight || !output || rows <= 0 || input_size <= 0 || output_size <= 0) return -1;
    gemm_fwd<<<blocks(rows * output_size), 256, 0, queue>>>(input, weight, output, rows, input_size, output_size);
    if (integer(op.attribute, "bias") != 0) { if (!bias) return -1; add_bias<<<blocks(rows * output_size), 256, 0, queue>>>(output, bias, rows, output_size); }
  } else if (op.kind == "rope") {
    int tokens = integer(binding, "tokens"), heads = integer(op.attribute, "heads"), head_dim = integer(op.attribute, "head_dim");
    auto input = static_cast<float*>(address(state, binding, "buffer.input"));
    if (!input || tokens <= 0 || heads <= 0 || head_dim <= 0) return -1;
    rope_inference<<<blocks(tokens * heads * (head_dim / 2)), 256, 0, queue>>>(input, tokens, heads, head_dim,
        integer(binding, "position"), decimal(op.attribute, "theta", 10000.0f));
  } else if (op.kind == "swiglu") {
    int elements = integer(binding, "elements");
    auto gate = static_cast<const float*>(address(state, binding, "buffer.gate")); auto up = static_cast<const float*>(address(state, binding, "buffer.up"));
    auto output = static_cast<float*>(address(state, binding, "buffer.output")); if (!gate || !up || !output || elements <= 0) return -1;
    swiglu_fwd<<<blocks(elements), 256, 0, queue>>>(gate, up, output, elements);
  } else if (op.kind == "residual_add") {
    int elements = integer(binding, "elements"); auto left = static_cast<const float*>(address(state, binding, "buffer.left"));
    auto right = static_cast<const float*>(address(state, binding, "buffer.right")); auto output = static_cast<float*>(address(state, binding, "buffer.output"));
    if (!left || !right || !output || elements <= 0) return -1; add<<<blocks(elements), 256, 0, queue>>>(left, right, output, elements);
  } else if (op.kind == "paged_attention") {
    int position = integer(binding, "position"), max_sequence = integer(binding, "max_sequence");
    int heads = integer(op.attribute, "query_heads"), kv_heads = integer(op.attribute, "kv_heads"), head_dim = integer(op.attribute, "head_dim");
    auto query = static_cast<const float*>(address(state, binding, "buffer.query")); auto key = static_cast<const float*>(address(state, binding, "buffer.key_cache"));
    auto value = static_cast<const float*>(address(state, binding, "buffer.value_cache")); auto workspace = static_cast<float*>(address(state, binding, "buffer.workspace"));
    auto block_table = static_cast<const int*>(address(state, binding, "buffer.block_table", true));
    auto output = static_cast<float*>(address(state, binding, "buffer.output"));
    int block_size = integer(binding, "block_size");
    if (!query || !key || !value || !workspace || !output || position < 0 || max_sequence <= position || heads <= 0 || kv_heads <= 0 || head_dim <= 0) return -1;
    if (block_size > 0 && !block_table) return -1;
    paged_attention_decode_v1<<<blocks(heads), 256, 0, queue>>>(query, key, value, block_table, workspace,
        output, position, max_sequence, heads, kv_heads, head_dim, block_size);
  }
  return cuda_result(state, cudaGetLastError(), "CUDA operator launch");
}
int synchronize(int handle, int stream) {
  std::lock_guard<std::mutex> lock(state_mutex);
  context_record* state = get_context(handle);
  if (!state) return -1;
  if (stream == 0) return cuda_result(state, cudaDeviceSynchronize(), "cudaDeviceSynchronize");
  auto found = state->stream.find(stream);
  return found == state->stream.end() ? -1 :
      cuda_result(state, cudaStreamSynchronize(found->second), "cudaStreamSynchronize");
}
const char* last_error(int handle) {
  context_record* state = get_context(handle);
  return state ? state->error.c_str() : global_error.c_str();
}
const neurx_device_plugin_v1 plugin = {
  NEURX_DEVICE_PLUGIN_ABI_VERSION, sizeof(neurx_device_plugin_v1), "cuda",
  probe, create, destroy, alloc, free_buffer, copy_buffer, stream_create,
  stream_destroy, op_create, op_destroy, op_launch, synchronize, last_error
};
}

extern "C" const neurx_device_plugin_v1* neurx_device_plugin_get_v1(void) {
  return &plugin;
}
