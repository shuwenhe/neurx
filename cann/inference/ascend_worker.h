#pragma once

#include "ascend_executor.h"
#include "logits_sampler.h"
#include "../cache/prefix_cache.h"

#include <cstdint>
#include <vector>

namespace neurx::inference {

struct WorkerBatchResult {
  std::vector<float> logits;
  std::vector<int32_t> next_tokens;
};

// Host-facing CANN data plane for one NPU process. The generic serving layer
// owns queues and request text; this class owns reusable transfer buffers,
// invokes AscendExecutor, copies logits back, and performs reference sampling.
class AscendWorker {
 public:
  explicit AscendWorker(
      AscendExecutorConfig config,
      cann::PrefixCacheConfig prefix_cache_config = {});

  AdapterStatus initialize(int device_id);
  bool ready() const { return executor_.ready(); }

  AdapterStatus execute(
      const Batch& batch, const std::vector<int32_t>& token_ids,
      const std::vector<SamplingConfig>& sampling,
      const std::vector<std::vector<int32_t>>& token_histories,
      WorkerBatchResult* result);

  bool release_request(const std::string& request_id) {
    return executor_.release_request(request_id);
  }
  const AscendExecutor& executor() const { return executor_; }
  cann::PrefixCacheStats prefix_cache_stats() const {
    return prefix_cache_.stats();
  }

 private:
  AdapterStatus ensure_capacity(cann::DeviceBuffer& buffer,
                                std::size_t bytes, const char* name);
  AdapterStatus ensure_capacity(cann::HostBuffer& buffer,
                                std::size_t bytes, const char* name);

  AscendExecutor executor_;
  cann::PrefixCache prefix_cache_;
  cann::DeviceBuffer device_tokens_;
  cann::DeviceBuffer device_logits_;
  cann::DeviceBuffer device_sampled_tokens_;
  cann::HostBuffer host_tokens_;
  cann::HostBuffer host_logits_;
  cann::HostBuffer host_sampled_tokens_;
};

}  // namespace neurx::inference
