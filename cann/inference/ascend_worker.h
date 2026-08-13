#pragma once
#include "ascend_executor.h"
#include "logits_sampler.h"
#include "../cache/prefix_cache.h"
#include <cstdint>
#include <vector>
namespace neurx::inference {

struct worker_batch_result {
  std::vector<float> logits;
  std::vector<int32_t> next_tokens;
};
class ascend_worker {
 public:
  explicit ascend_worker(
      ascend_executor_config config,
      cann::prefix_cache_config prefix_cache_config = {});
  adapter_status initialize(int device_id);
  bool ready() const { return executor_.ready(); }
  adapter_status execute(
      const batch_2& batch, const std::vector<int32_t>& token_ids,
      const std::vector<sampling_config_2>& sampling,
      const std::vector<std::vector<int32_t>>& token_histories,
      worker_batch_result* result);
  bool release_request(const std::string& request_id) {
    return executor_.release_request(request_id);
  }
  const ascend_executor& executor() const { return executor_; }
  cann::prefix_cache_stats prefix_cache_stats() const {
    return prefix_cache_.stats();
  }
 private:
  adapter_status ensure_capacity(cann::device_buffer& buffer,
                                std::size_t bytes, const char* name);
  adapter_status ensure_capacity(cann::host_buffer& buffer,
                                std::size_t bytes, const char* name);
  ascend_executor executor_;
  cann::prefix_cache prefix_cache_;
  cann::device_buffer device_tokens_;
  cann::device_buffer device_logits_;
  cann::device_buffer device_sampled_tokens_;
  cann::host_buffer host_tokens_;
  cann::host_buffer host_logits_;
  cann::host_buffer host_sampled_tokens_;
};
}
