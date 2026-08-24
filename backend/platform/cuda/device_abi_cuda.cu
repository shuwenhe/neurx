#include "../api/device_plugin_abi.h"

#include <cuda_runtime.h>
#include <cuda_fp16.h>
#include <cuda_bf16.h>
#include <cublasLt.h>
#include <mutex>
#include <string>
#include <unordered_map>
#include <sstream>

namespace {
struct buffer_record { void* address; int bytes; bool host; };
struct context_record {
  int device = 0;
  int next = 1;
  cublasLtHandle_t cublas_lt = nullptr;
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

int cublas_result(context_record* state, cublasStatus_t result, const char* action) {
  if (result == CUBLAS_STATUS_SUCCESS) return 0;
  std::string message = std::string(action) + ": cuBLAS status " + std::to_string(static_cast<int>(result));
  if (state) state->error = message; else global_error = message;
  return -1;
}

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
inline int blocks(int elements) { return (elements + 255) / 256; }
template <typename T> __device__ float value_to_float(T value);
template <> __device__ float value_to_float<float>(float value) { return value; }
template <> __device__ float value_to_float<__half>(__half value) { return __half2float(value); }
template <> __device__ float value_to_float<__nv_bfloat16>(__nv_bfloat16 value) { return __bfloat162float(value); }
template <typename T> __device__ T float_to_value(float value);
template <> __device__ float float_to_value<float>(float value) { return value; }
template <> __device__ __half float_to_value<__half>(float value) { return __float2half_rn(value); }
template <> __device__ __nv_bfloat16 float_to_value<__nv_bfloat16>(float value) { return __float2bfloat16_rn(value); }

template <typename T> __global__ void embedding_typed(const int* ids, const T* weight, T* output, int tokens, int hidden) {
  int index = blockIdx.x * blockDim.x + threadIdx.x; if (index < tokens * hidden) output[index] = weight[ids[index / hidden] * hidden + index % hidden];
}
template <typename T> __global__ void rms_norm_typed(const T* input, const T* weight, T* output, int rows, int hidden, float epsilon) {
  int row = blockIdx.x * blockDim.x + threadIdx.x; if (row >= rows) return; float square = 0.0f;
  for (int i = 0; i < hidden; ++i) { float value = value_to_float(input[row * hidden + i]); square += value * value; }
  float scale = rsqrtf(square / hidden + epsilon);
  for (int i = 0; i < hidden; ++i) output[row * hidden + i] = float_to_value<T>(value_to_float(input[row * hidden + i]) * scale * value_to_float(weight[i]));
}
template <typename T> __global__ void rope_typed(T* input, int tokens, int heads, int head_dim, int start_position, float theta) {
  int index = blockIdx.x * blockDim.x + threadIdx.x; int pairs = head_dim / 2; if (index >= tokens * heads * pairs) return;
  int pair = index % pairs, head = (index / pairs) % heads, token = index / (pairs * heads), column = pair * 2;
  float angle = float(start_position + token) / powf(theta, float(column) / head_dim), cosine = cosf(angle), sine = sinf(angle);
  int offset = token * heads * head_dim + head * head_dim + column; float first = value_to_float(input[offset]), second = value_to_float(input[offset + 1]);
  input[offset] = float_to_value<T>(first * cosine - second * sine); input[offset + 1] = float_to_value<T>(first * sine + second * cosine);
}
template <typename T> __global__ void swiglu_typed(const T* gate, const T* up, T* output, int elements) {
  int index = blockIdx.x * blockDim.x + threadIdx.x; if (index >= elements) return; float g = value_to_float(gate[index]);
  output[index] = float_to_value<T>(g / (1.0f + expf(-g)) * value_to_float(up[index]));
}
template <typename T> __global__ void residual_add_typed(const T* left, const T* right, T* output, int elements) {
  int index = blockIdx.x * blockDim.x + threadIdx.x; if (index < elements) output[index] = float_to_value<T>(value_to_float(left[index]) + value_to_float(right[index]));
}
template <typename T> __global__ void paged_attention_typed(const T* query, const T* key_cache, const T* value_cache,
    const int* block_table, float* score, T* output, int position, int max_sequence, int query_heads, int kv_heads, int head_dim, int block_size) {
  int head = blockIdx.x * blockDim.x + threadIdx.x; if (head >= query_heads) return; int kv_head = head * kv_heads / query_heads;
  float scale = rsqrtf(float(head_dim)), maximum = -INFINITY;
  for (int token = 0; token <= position; ++token) { int physical = block_table && block_size > 0 ? block_table[token / block_size] * block_size + token % block_size : token; float value = 0.0f;
    for (int column = 0; column < head_dim; ++column) value += value_to_float(query[head * head_dim + column]) * value_to_float(key_cache[(physical * kv_heads + kv_head) * head_dim + column]);
    value *= scale; score[head * max_sequence + token] = value; maximum = fmaxf(maximum, value); }
  float denominator = 0.0f; for (int token = 0; token <= position; ++token) denominator += expf(score[head * max_sequence + token] - maximum);
  for (int column = 0; column < head_dim; ++column) { float value = 0.0f; for (int token = 0; token <= position; ++token) {
      int physical = block_table && block_size > 0 ? block_table[token / block_size] * block_size + token % block_size : token;
      value += expf(score[head * max_sequence + token] - maximum) / denominator * value_to_float(value_cache[(physical * kv_heads + kv_head) * head_dim + column]); }
    output[head * head_dim + column] = float_to_value<T>(value); }
}

cudaDataType_t cuda_dtype(const std::string& dtype) {
  if (dtype == "fp16") return CUDA_R_16F;
  if (dtype == "bf16") return CUDA_R_16BF;
  return CUDA_R_32F;
}

int cublaslt_linear(context_record* state, cudaStream_t stream, const std::string& dtype,
                    const void* input, const void* weight, const void* bias, void* output,
                    int rows, int input_size, int output_size) {
  cudaDataType_t data_type = cuda_dtype(dtype); float alpha = 1.0f, beta = 0.0f;
  cublasLtMatmulDesc_t operation = nullptr; cublasLtMatrixLayout_t input_layout = nullptr, weight_layout = nullptr, output_layout = nullptr;
  cublasStatus_t status = cublasLtMatmulDescCreate(&operation, CUBLAS_COMPUTE_32F, CUDA_R_32F);
  if (status == CUBLAS_STATUS_SUCCESS) status = cublasLtMatrixLayoutCreate(&input_layout, data_type, rows, input_size, input_size);
  if (status == CUBLAS_STATUS_SUCCESS) status = cublasLtMatrixLayoutCreate(&weight_layout, data_type, input_size, output_size, output_size);
  if (status == CUBLAS_STATUS_SUCCESS) status = cublasLtMatrixLayoutCreate(&output_layout, data_type, rows, output_size, output_size);
  cublasLtOrder_t order = CUBLASLT_ORDER_ROW;
  if (status == CUBLAS_STATUS_SUCCESS) status = cublasLtMatrixLayoutSetAttribute(input_layout, CUBLASLT_MATRIX_LAYOUT_ORDER, &order, sizeof(order));
  if (status == CUBLAS_STATUS_SUCCESS) status = cublasLtMatrixLayoutSetAttribute(weight_layout, CUBLASLT_MATRIX_LAYOUT_ORDER, &order, sizeof(order));
  if (status == CUBLAS_STATUS_SUCCESS) status = cublasLtMatrixLayoutSetAttribute(output_layout, CUBLASLT_MATRIX_LAYOUT_ORDER, &order, sizeof(order));
  if (status == CUBLAS_STATUS_SUCCESS && bias) {
    cublasLtEpilogue_t epilogue = CUBLASLT_EPILOGUE_BIAS;
    status = cublasLtMatmulDescSetAttribute(operation, CUBLASLT_MATMUL_DESC_EPILOGUE, &epilogue, sizeof(epilogue));
    if (status == CUBLAS_STATUS_SUCCESS) status = cublasLtMatmulDescSetAttribute(operation, CUBLASLT_MATMUL_DESC_BIAS_POINTER, &bias, sizeof(bias));
  }
  if (status == CUBLAS_STATUS_SUCCESS) status = cublasLtMatmul(state->cublas_lt, operation, &alpha, input, input_layout,
      weight, weight_layout, &beta, output, output_layout, output, output_layout, nullptr, nullptr, 0, stream);
  if (output_layout) cublasLtMatrixLayoutDestroy(output_layout); if (weight_layout) cublasLtMatrixLayoutDestroy(weight_layout);
  if (input_layout) cublasLtMatrixLayoutDestroy(input_layout); if (operation) cublasLtMatmulDescDestroy(operation);
  return cublas_result(state, status, "cublasLtMatmul");
}
int probe() { int count = 0; return cudaGetDeviceCount(&count) == cudaSuccess ? count : 0; }
int create(int device, const char*) {
  std::lock_guard<std::mutex> lock(state_mutex);
  if (cuda_result(nullptr, cudaSetDevice(device), "cudaSetDevice") != 0) return -1;
  cublasLtHandle_t cublas_lt = nullptr;
  if (cublas_result(nullptr, cublasLtCreate(&cublas_lt), "cublasLtCreate") != 0) return -1;
  int handle = next_context++;
  context_record record; record.device = device; record.cublas_lt = cublas_lt;
  context.emplace(handle, std::move(record));
  return handle;
}
int destroy(int handle) {
  std::lock_guard<std::mutex> lock(state_mutex);
  auto found = context.find(handle);
  if (found == context.end()) return -1;
  if (!found->second.buffer.empty() || !found->second.stream.empty() ||
      !found->second.operation.empty()) return -1;
  cublasLtDestroy(found->second.cublas_lt); context.erase(found);
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
  if (dtype == attribute.end() || (dtype->second != "float32" && dtype->second != "fp32" && dtype->second != "fp16" && dtype->second != "bf16")) {
    state->error = "CUDA Device ABI v1 requires fp32, fp16, or bf16"; return -1;
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
  const std::string dtype = op.attribute["dtype"] == "fp32" ? "float32" : op.attribute["dtype"];
  if (op.kind == "embedding") {
    int tokens = integer(binding, "tokens"), hidden = integer(op.attribute, "hidden");
    auto ids = static_cast<const int*>(address(state, binding, "buffer.ids"));
    void* weight = address(state, binding, "buffer.weight"); void* output = address(state, binding, "buffer.output");
    if (!ids || !weight || !output || tokens <= 0 || hidden <= 0) return -1;
    if (dtype == "fp16") embedding_typed<<<blocks(tokens * hidden), 256, 0, queue>>>(ids, static_cast<const __half*>(weight), static_cast<__half*>(output), tokens, hidden);
    else if (dtype == "bf16") embedding_typed<<<blocks(tokens * hidden), 256, 0, queue>>>(ids, static_cast<const __nv_bfloat16*>(weight), static_cast<__nv_bfloat16*>(output), tokens, hidden);
    else embedding_typed<<<blocks(tokens * hidden), 256, 0, queue>>>(ids, static_cast<const float*>(weight), static_cast<float*>(output), tokens, hidden);
  } else if (op.kind == "rms_norm") {
    int rows = integer(binding, "rows"), hidden = integer(op.attribute, "hidden");
    void* input = address(state, binding, "buffer.input"); void* weight = address(state, binding, "buffer.weight"); void* output = address(state, binding, "buffer.output");
    if (!input || !weight || !output || rows <= 0 || hidden <= 0) return -1;
    float epsilon = decimal(op.attribute, "epsilon", 1e-5f);
    if (dtype == "fp16") rms_norm_typed<<<blocks(rows), 256, 0, queue>>>(static_cast<const __half*>(input), static_cast<const __half*>(weight), static_cast<__half*>(output), rows, hidden, epsilon);
    else if (dtype == "bf16") rms_norm_typed<<<blocks(rows), 256, 0, queue>>>(static_cast<const __nv_bfloat16*>(input), static_cast<const __nv_bfloat16*>(weight), static_cast<__nv_bfloat16*>(output), rows, hidden, epsilon);
    else rms_norm_typed<<<blocks(rows), 256, 0, queue>>>(static_cast<const float*>(input), static_cast<const float*>(weight), static_cast<float*>(output), rows, hidden, epsilon);
  } else if (op.kind == "linear") {
    int rows = integer(binding, "rows"), input_size = integer(op.attribute, "input"), output_size = integer(op.attribute, "output");
    void* input = address(state, binding, "buffer.input"); void* weight = address(state, binding, "buffer.weight");
    void* bias = address(state, binding, "buffer.bias", true); void* output = address(state, binding, "buffer.output");
    if (!input || !weight || !output || rows <= 0 || input_size <= 0 || output_size <= 0) return -1;
    if (integer(op.attribute, "bias") != 0 && !bias) return -1;
    if (cublaslt_linear(state, queue, dtype, input, weight, bias, output, rows, input_size, output_size) != 0) return -1;
  } else if (op.kind == "rope") {
    int tokens = integer(binding, "tokens"), heads = integer(op.attribute, "heads"), head_dim = integer(op.attribute, "head_dim");
    void* input = address(state, binding, "buffer.input");
    if (!input || tokens <= 0 || heads <= 0 || head_dim <= 0) return -1;
    int total = tokens * heads * (head_dim / 2), position = integer(binding, "position"); float theta = decimal(op.attribute, "theta", 10000.0f);
    if (dtype == "fp16") rope_typed<<<blocks(total), 256, 0, queue>>>(static_cast<__half*>(input), tokens, heads, head_dim, position, theta);
    else if (dtype == "bf16") rope_typed<<<blocks(total), 256, 0, queue>>>(static_cast<__nv_bfloat16*>(input), tokens, heads, head_dim, position, theta);
    else rope_typed<<<blocks(total), 256, 0, queue>>>(static_cast<float*>(input), tokens, heads, head_dim, position, theta);
  } else if (op.kind == "swiglu") {
    int elements = integer(binding, "elements");
    void* gate = address(state, binding, "buffer.gate"); void* up = address(state, binding, "buffer.up"); void* output = address(state, binding, "buffer.output");
    if (!gate || !up || !output || elements <= 0) return -1;
    if (dtype == "fp16") swiglu_typed<<<blocks(elements), 256, 0, queue>>>(static_cast<const __half*>(gate), static_cast<const __half*>(up), static_cast<__half*>(output), elements);
    else if (dtype == "bf16") swiglu_typed<<<blocks(elements), 256, 0, queue>>>(static_cast<const __nv_bfloat16*>(gate), static_cast<const __nv_bfloat16*>(up), static_cast<__nv_bfloat16*>(output), elements);
    else swiglu_typed<<<blocks(elements), 256, 0, queue>>>(static_cast<const float*>(gate), static_cast<const float*>(up), static_cast<float*>(output), elements);
  } else if (op.kind == "residual_add") {
    int elements = integer(binding, "elements"); void* left = address(state, binding, "buffer.left");
    void* right = address(state, binding, "buffer.right"); void* output = address(state, binding, "buffer.output");
    if (!left || !right || !output || elements <= 0) return -1;
    if (dtype == "fp16") residual_add_typed<<<blocks(elements), 256, 0, queue>>>(static_cast<const __half*>(left), static_cast<const __half*>(right), static_cast<__half*>(output), elements);
    else if (dtype == "bf16") residual_add_typed<<<blocks(elements), 256, 0, queue>>>(static_cast<const __nv_bfloat16*>(left), static_cast<const __nv_bfloat16*>(right), static_cast<__nv_bfloat16*>(output), elements);
    else residual_add_typed<<<blocks(elements), 256, 0, queue>>>(static_cast<const float*>(left), static_cast<const float*>(right), static_cast<float*>(output), elements);
  } else if (op.kind == "paged_attention") {
    int position = integer(binding, "position"), max_sequence = integer(binding, "max_sequence");
    int heads = integer(op.attribute, "query_heads"), kv_heads = integer(op.attribute, "kv_heads"), head_dim = integer(op.attribute, "head_dim");
    void* query = address(state, binding, "buffer.query"); void* key = address(state, binding, "buffer.key_cache");
    void* value = address(state, binding, "buffer.value_cache"); auto workspace = static_cast<float*>(address(state, binding, "buffer.workspace"));
    auto block_table = static_cast<const int*>(address(state, binding, "buffer.block_table", true));
    void* output = address(state, binding, "buffer.output");
    int block_size = integer(binding, "block_size");
    if (!query || !key || !value || !workspace || !output || position < 0 || max_sequence <= position || heads <= 0 || kv_heads <= 0 || head_dim <= 0) return -1;
    if (block_size > 0 && !block_table) return -1;
    if (dtype == "fp16") paged_attention_typed<<<blocks(heads), 256, 0, queue>>>(static_cast<const __half*>(query), static_cast<const __half*>(key), static_cast<const __half*>(value), block_table, workspace, static_cast<__half*>(output), position, max_sequence, heads, kv_heads, head_dim, block_size);
    else if (dtype == "bf16") paged_attention_typed<<<blocks(heads), 256, 0, queue>>>(static_cast<const __nv_bfloat16*>(query), static_cast<const __nv_bfloat16*>(key), static_cast<const __nv_bfloat16*>(value), block_table, workspace, static_cast<__nv_bfloat16*>(output), position, max_sequence, heads, kv_heads, head_dim, block_size);
    else paged_attention_typed<<<blocks(heads), 256, 0, queue>>>(static_cast<const float*>(query), static_cast<const float*>(key), static_cast<const float*>(value), block_table, workspace, static_cast<float*>(output), position, max_sequence, heads, kv_heads, head_dim, block_size);
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
