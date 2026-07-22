#pragma once

#include "../../inference/runtime/backends/backend_adapter.h"

#include <cstddef>
#include <cstdint>
#include <vector>

namespace neurx::inference {

struct SamplingConfig {
  float temperature = 1.0F;
  int top_k = 0;
  float top_p = 1.0F;
  float repetition_penalty = 1.0F;
  uint64_t seed = 0;
};

AdapterStatus sample_logits(const float* logits, std::size_t vocabulary,
                            const SamplingConfig& config,
                            const std::vector<int32_t>& token_history,
                            int32_t* token);

bool supports_atb_device_sampling(const SamplingConfig& config,
                                  std::size_t vocabulary);

}
