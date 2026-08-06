#pragma once
#include "../runtime/model/hf_model.h"
#include <cstdint>
#include <memory>
#include <string>
#include <vector>
namespace neurx::cuda {
class hf_decoder_cuda;
class hf_cuda_kv_cache {
 public:
  hf_cuda_kv_cache();
  ~hf_cuda_kv_cache();
  hf_cuda_kv_cache(hf_cuda_kv_cache&&) noexcept;
  hf_cuda_kv_cache& operator=(hf_cuda_kv_cache&&) noexcept;
  hf_cuda_kv_cache(const hf_cuda_kv_cache&) = delete;
  hf_cuda_kv_cache& operator=(const hf_cuda_kv_cache&) = delete;
  std::size_t length() const;
  void clear();
 private:
  struct state;
  std::unique_ptr<state> state_;
  friend class hf_decoder_cuda;
};
class hf_decoder_cuda {
 public:
  explicit hf_decoder_cuda(const std::string& model_directory, int device = 0);
  ~hf_decoder_cuda();
  hf_decoder_cuda(hf_decoder_cuda&&) noexcept;
  hf_decoder_cuda& operator=(hf_decoder_cuda&&) noexcept;
  hf_decoder_cuda(const hf_decoder_cuda&) = delete;
  hf_decoder_cuda& operator=(const hf_decoder_cuda&) = delete;
  const runtime::model::hf_config& config() const;
  std::vector<float> prefill(const std::vector<int32_t>& token_ids, hf_cuda_kv_cache* cache);
  std::vector<float> decode(int32_t token_id, hf_cuda_kv_cache* cache);
  static int32_t greedy(const std::vector<float>& logits);
 private:
  struct impl;
  std::unique_ptr<impl> impl_;
};
}
