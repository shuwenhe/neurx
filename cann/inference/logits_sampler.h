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

// CPU reference sampler used by the first Ascend worker implementation. Keeping
// this independent from ACL makes its policy deterministic and testable on
// development hosts. A device-side sampler can replace it without changing the
// worker API.
AdapterStatus sample_logits(const float* logits, std::size_t vocabulary,
                            const SamplingConfig& config,
                            const std::vector<int32_t>& token_history,
                            int32_t* token);

}  // namespace neurx::inference
