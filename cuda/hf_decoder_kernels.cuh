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
  const int item = blockIdx.x * blockDim.x + threadIdx.x;
  if (item >= tokens * query_heads) return;
  const int token = item / query_heads;
  const int query_head = item % query_heads;
  const int kv_head = query_head / (query_heads / kv_heads);
  const int visible = past_tokens + token + 1;
  const float scale = rsqrtf(static_cast<float>(head_dimension));
  float maximum = -INFINITY;
  for (int source = 0; source < visible; ++source) {
    float score = 0.0F;
    for (int feature = 0; feature < head_dimension; ++feature) {
      score += query[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + feature] *
               key_cache[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + feature];
    }
    maximum = fmaxf(maximum, score * scale);
  }
  float denominator = 0.0F;
  for (int source = 0; source < visible; ++source) {
    float score = 0.0F;
    for (int feature = 0; feature < head_dimension; ++feature) {
      score += query[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + feature] *
               key_cache[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + feature];
    }
    denominator += expf(score * scale - maximum);
  }
  for (int feature = 0; feature < head_dimension; ++feature) {
    float result = 0.0F;
    for (int source = 0; source < visible; ++source) {
      float score = 0.0F;
      for (int inner = 0; inner < head_dimension; ++inner) {
        score += query[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + inner] *
                 key_cache[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + inner];
      }
      const float probability = expf(score * scale - maximum) / denominator;
      result += probability *
                value_cache[(static_cast<long long>(source) * kv_heads + kv_head) * head_dimension + feature];
    }
    output[(static_cast<long long>(token) * query_heads + query_head) * head_dimension + feature] = result;
  }
}

__global__ void swiglu_in_place(float* gate, const float* up, int count) {
  const int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < count) gate[index] = gate[index] / (1.0F + expf(-gate[index])) * up[index];
}

}  // namespace neurx::cuda::kernels
