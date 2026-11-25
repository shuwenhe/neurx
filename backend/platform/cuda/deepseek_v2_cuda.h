#pragma once
#include <cstdint>
#include <memory>
#include <string>
#include <vector>
namespace neurx::cuda {
class deepseek_v2_cache {
public:
  ~deepseek_v2_cache();
  std::size_t length() const;

private:
  struct state;
  std::unique_ptr<state> state_;
  explicit deepseek_v2_cache(std::unique_ptr<state> state);
  friend class deepseek_v2_cuda;
};
// Correctness-first BF16 checkpoint/FP32 activation decoder with bounded GPU
// weight residency. Host mmap pages back experts that do not fit in device RAM.
class deepseek_v2_cuda {
public:
  explicit deepseek_v2_cuda(const std::string &directory, int device = 0);
  ~deepseek_v2_cuda();
  std::unique_ptr<deepseek_v2_cache> create_cache() const;
  std::vector<float> prefill(const std::vector<int32_t> &ids,
                             deepseek_v2_cache *cache);
  std::vector<float> decode(int32_t id, deepseek_v2_cache *cache);
  int context_limit() const;
  int bos_token_id() const;
  int eos_token_id() const;

private:
  struct impl;
  std::unique_ptr<impl> impl_;
};
} // namespace neurx::cuda
