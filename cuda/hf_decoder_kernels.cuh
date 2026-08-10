#pragma once
#include <cuda_runtime.h>
#include <cmath>
namespace neurx::cuda::kernels {
inline int blocks(int count) { return (count + 255) / 256; }
__global__ void embedding(const int32_t* ids, const float* weight, float* output,
                          int tokens, int hidden) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < tokens * hidden) {
    output[index] = weight[static_cast<long long>(ids[index / hidden]) * hidden + index % hidden];
  }
}
__global__ void rms_norm(const float* input, const float* weight, float* output,
                         int rows, int hidden, float epsilon) {
  const int row = blockIdx.x * blockDim.x + threadIdx.x;
  if (row >= rows) return;
  float square_sum = 0.0F;
  for (int column = 0; column < hidden; ++column) {
    const float value = input[static_cast<long long>(row) * hidden + column];
    square_sum += value * value;
  }
  const float inverse = rsqrtf(square_sum / hidden + epsilon);
  for (int column = 0; column < hidden; ++column) {
    const long long index = static_cast<long long>(row) * hidden + column;
    output[index] = input[index] * inverse * weight[column];
  }
}
__global__ void add_in_place(float* target, const float* value, int count) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < count) target[index] += value[index];
}
__global__ void add_bias(float* values, const float* bias, int rows, int columns) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < rows * columns) values[index] += bias[index % columns];
}
__global__ void rope_half(float* values, int tokens, int heads, int head_dimension,
                          int position_offset, float theta) {
  const int half = head_dimension / 2;
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index >= tokens * heads * half) return;
  const int frequency = index % half;
  const int head = (index / half) % heads;
  const int token = index / (half * heads);
  const float angle = (position_offset + token) /
                      powf(theta, static_cast<float>(frequency * 2) / head_dimension);
  float* row = values + (static_cast<long long>(token) * heads + head) * head_dimension;
  const float first = row[frequency];
  const float second = row[frequency + half];
  const float cosine = cosf(angle);
  const float sine = sinf(angle);
  row[frequency] = first * cosine - second * sine;
  row[frequency + half] = second * cosine + first * sine;
}
__global__ void attention_gqa(const float* query, const float* key_cache,
                              const float* value_cache, float* output,
                              int tokens, int past_tokens, int query_heads,
                              int kv_heads, int head_dimension) {
  const int item = blockIdx.x;
  if (item >= tokens * query_heads) return;
  const int token = item / query_heads;
  const int query_head = item % query_heads;
  const int kv_head = query_head / (query_heads / kv_heads);
  const int visible = past_tokens + token + 1;
  const float scale = rsqrtf(static_cast<float>(head_dimension));
  __shared__ float reduction[256];
  __shared__ float running_maximum;
  __shared__ float denominator;
  __shared__ float previous_scale;
  __shared__ float current_weight;
  if (threadIdx.x == 0) {
    running_maximum = -INFINITY;
    denominator = 0.0F;
  }
  float accumulated = 0.0F;
  __syncthreads();
  for (int source = 0; source < visible; ++source) {
    float partial = 0.0F;
    for (int feature = threadIdx.x; feature < head_dimension; feature += blockDim.x) {
      partial += query[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + feature] *
                 key_cache[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + feature];
    }
    reduction[threadIdx.x] = partial;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride /= 2) {
      if (threadIdx.x < stride) reduction[threadIdx.x] += reduction[threadIdx.x + stride];
      __syncthreads();
    }
    if (threadIdx.x == 0) {
      const float score = reduction[0] * scale;
      const float next_maximum = fmaxf(running_maximum, score);
      previous_scale = expf(running_maximum - next_maximum);
      current_weight = expf(score - next_maximum);
      denominator = denominator * previous_scale + current_weight;
      running_maximum = next_maximum;
    }
    __syncthreads();
    if (threadIdx.x < head_dimension) {
      const float value = value_cache[
          (static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + threadIdx.x];
      accumulated = accumulated * previous_scale + current_weight * value;
    }
    __syncthreads();
  }
  if (threadIdx.x < head_dimension) {
    output[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + threadIdx.x] =
        accumulated / denominator;
  }
}
__global__ void swiglu_in_place(float* gate, const float* up, int count) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < count) gate[index] = gate[index] / (1.0F + expf(-gate[index])) * up[index];
}

__global__ void copy_values(const float* source, float* destination, int count) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < count) destination[index] = source[index];
}

__global__ void add_values_in_place(float* target, const float* value, int count) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < count) target[index] += value[index];
}

__global__ void scale_values(float* values, int count, float scale) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < count) values[index] *= scale;
}

__global__ void rms_norm_backward(const float* input, const float* weight,
                                  const float* gradient_output, float* gradient_input,
                                  int rows, int hidden, float epsilon) {
  const int row = blockIdx.x * blockDim.x + threadIdx.x;
  if (row >= rows) return;
  float square_sum = 0.0F;
  float dot = 0.0F;
  for (int column = 0; column < hidden; ++column) {
    const long long index = static_cast<long long>(row) * hidden + column;
    square_sum += input[index] * input[index];
    dot += gradient_output[index] * weight[column] * input[index];
  }
  const float inverse = rsqrtf(square_sum / hidden + epsilon);
  for (int column = 0; column < hidden; ++column) {
    const long long index = static_cast<long long>(row) * hidden + column;
    gradient_input[index] = gradient_output[index] * weight[column] * inverse -
                            input[index] * inverse * inverse * inverse * dot / hidden;
  }
}

__global__ void swiglu_backward(const float* gate, const float* up,
                                const float* gradient_output, float* gradient_gate,
                                float* gradient_up, int count) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index >= count) return;
  const float sigmoid = 1.0F / (1.0F + expf(-gate[index]));
  gradient_gate[index] = gradient_output[index] * up[index] *
                         (sigmoid + gate[index] * sigmoid * (1.0F - sigmoid));
  gradient_up[index] = gradient_output[index] * gate[index] * sigmoid;
}

__global__ void rope_half_backward(float* values, int tokens, int heads,
                                   int head_dimension, int position_offset, float theta) {
  const int half = head_dimension / 2;
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index >= tokens * heads * half) return;
  const int frequency = index % half;
  const int head = (index / half) % heads;
  const int token = index / (half * heads);
  const float angle = (position_offset + token) /
                      powf(theta, static_cast<float>(frequency * 2) / head_dimension);
  float* row = values + (static_cast<long long>(token) * heads + head) * head_dimension;
  const float first = row[frequency];
  const float second = row[frequency + half];
  const float cosine = cosf(angle);
  const float sine = -sinf(angle);
  row[frequency] = first * cosine - second * sine;
  row[frequency + half] = second * cosine + first * sine;
}

__global__ void shifted_cross_entropy_backward(const float* logits, const int32_t* labels,
                                               float* loss, float* gradient_logits,
                                               int tokens, int vocab, int supervised) {
  const int row = blockIdx.x;
  if (row >= tokens) return;
  const int32_t label = row + 1 < tokens ? labels[row + 1] : -100;
  if (label < 0) {
    for (int column = threadIdx.x; column < vocab; column += blockDim.x) {
      gradient_logits[static_cast<long long>(row) * vocab + column] = 0.0F;
    }
    return;
  }
  __shared__ float reduction[256];
  float local_maximum = -INFINITY;
  for (int column = threadIdx.x; column < vocab; column += blockDim.x) {
    local_maximum = fmaxf(local_maximum, logits[static_cast<long long>(row) * vocab + column]);
  }
  reduction[threadIdx.x] = local_maximum;
  __syncthreads();
  for (int stride = blockDim.x / 2; stride > 0; stride /= 2) {
    if (threadIdx.x < stride) reduction[threadIdx.x] = fmaxf(reduction[threadIdx.x], reduction[threadIdx.x + stride]);
    __syncthreads();
  }
  const float maximum = reduction[0];
  float local_sum = 0.0F;
  for (int column = threadIdx.x; column < vocab; column += blockDim.x) {
    local_sum += expf(logits[static_cast<long long>(row) * vocab + column] - maximum);
  }
  reduction[threadIdx.x] = local_sum;
  __syncthreads();
  for (int stride = blockDim.x / 2; stride > 0; stride /= 2) {
    if (threadIdx.x < stride) reduction[threadIdx.x] += reduction[threadIdx.x + stride];
    __syncthreads();
  }
  const float denominator = reduction[0];
  if (threadIdx.x == 0) {
    atomicAdd(loss, (logf(denominator) + maximum -
                     logits[static_cast<long long>(row) * vocab + label]) / supervised);
  }
  for (int column = threadIdx.x; column < vocab; column += blockDim.x) {
    const float probability = expf(logits[static_cast<long long>(row) * vocab + column] - maximum) /
                              denominator;
    gradient_logits[static_cast<long long>(row) * vocab + column] =
        (probability - (column == label ? 1.0F : 0.0F)) / supervised;
  }
}

__global__ void attention_gqa_backward(const float* query, const float* key,
                                       const float* value, const float* gradient_output,
                                       float* gradient_query, float* gradient_key,
                                       float* gradient_value, int tokens, int query_heads,
                                       int kv_heads, int head_dimension) {
  const int item = blockIdx.x;
  if (item >= tokens * query_heads) return;
  const int token = item / query_heads;
  const int query_head = item % query_heads;
  const int kv_head = query_head / (query_heads / kv_heads);
  const int visible = token + 1;
  const float scale = rsqrtf(static_cast<float>(head_dimension));
  extern __shared__ float workspace[];
  float* probabilities = workspace;
  float* probability_gradients = probabilities + tokens;
  float* reduction = probability_gradients + tokens;
  for (int source = 0; source < visible; ++source) {
    float partial = 0.0F;
    for (int feature = threadIdx.x; feature < head_dimension; feature += blockDim.x) {
      partial += query[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + feature] *
                 key[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + feature];
    }
    reduction[threadIdx.x] = partial;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride /= 2) {
      if (threadIdx.x < stride) reduction[threadIdx.x] += reduction[threadIdx.x + stride];
      __syncthreads();
    }
    if (threadIdx.x == 0) probabilities[source] = reduction[0] * scale;
    __syncthreads();
  }
  if (threadIdx.x == 0) {
    float maximum = -INFINITY;
    for (int source = 0; source < visible; ++source) maximum = fmaxf(maximum, probabilities[source]);
    float denominator = 0.0F;
    for (int source = 0; source < visible; ++source) denominator += expf(probabilities[source] - maximum);
    for (int source = 0; source < visible; ++source) probabilities[source] = expf(probabilities[source] - maximum) / denominator;
  }
  __syncthreads();
  for (int source = 0; source < visible; ++source) {
    for (int feature = threadIdx.x; feature < head_dimension; feature += blockDim.x) {
      atomicAdd(&gradient_value[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + feature],
                probabilities[source] *
                    gradient_output[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + feature]);
    }
    float partial = 0.0F;
    for (int feature = threadIdx.x; feature < head_dimension; feature += blockDim.x) {
      partial += gradient_output[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + feature] *
                 value[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + feature];
    }
    reduction[threadIdx.x] = partial;
    __syncthreads();
    for (int stride = blockDim.x / 2; stride > 0; stride /= 2) {
      if (threadIdx.x < stride) reduction[threadIdx.x] += reduction[threadIdx.x + stride];
      __syncthreads();
    }
    if (threadIdx.x == 0) probability_gradients[source] = reduction[0];
    __syncthreads();
  }
  if (threadIdx.x == 0) {
    float dot = 0.0F;
    for (int source = 0; source < visible; ++source) dot += probabilities[source] * probability_gradients[source];
    for (int source = 0; source < visible; ++source) {
      probability_gradients[source] = probabilities[source] * (probability_gradients[source] - dot) * scale;
    }
  }
  __syncthreads();
  for (int feature = threadIdx.x; feature < head_dimension; feature += blockDim.x) {
    float query_gradient = 0.0F;
    for (int source = 0; source < visible; ++source) {
      const float score_gradient = probability_gradients[source];
      query_gradient += score_gradient *
          key[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + feature];
      atomicAdd(&gradient_key[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + feature],
                score_gradient * query[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + feature]);
    }
    gradient_query[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + feature] = query_gradient;
  }
}

__global__ void adam_update(float* parameter, const float* gradient, float* first_moment,
                            float* second_moment, int count, int step, float learning_rate) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index >= count) return;
  constexpr float beta1 = 0.9F;
  constexpr float beta2 = 0.999F;
  first_moment[index] = beta1 * first_moment[index] + (1.0F - beta1) * gradient[index];
  second_moment[index] = beta2 * second_moment[index] +
                         (1.0F - beta2) * gradient[index] * gradient[index];
  const float corrected_first = first_moment[index] / (1.0F - powf(beta1, step));
  const float corrected_second = second_moment[index] / (1.0F - powf(beta2, step));
  parameter[index] -= learning_rate * corrected_first / (sqrtf(corrected_second) + 1.0e-8F);
}
}
