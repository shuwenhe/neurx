#pragma once
#include "deepseek_v2_cuda.h"
namespace neurx::cuda {
// Text-only Qwen2.5-VL. With equal temporal/height/width text positions,
// MRoPE reduces to ordinary half-split rotary embedding. No vision encoder.
class qwen_vl_text_cuda {
public:
  explicit qwen_vl_text_cuda(const std::string &directory, int device = 0);
  ~qwen_vl_text_cuda();
  std::unique_ptr<deepseek_v2_cache> create_cache() const;
  std::vector<float> prefill(const std::vector<int32_t> &ids,
                             deepseek_v2_cache *cache);
  std::vector<float> decode(int32_t id, deepseek_v2_cache *cache);
  int context_limit() const;

private:
  struct impl;
  std::unique_ptr<impl> impl_;
};
} // namespace neurx::cuda
