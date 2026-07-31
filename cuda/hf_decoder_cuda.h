#pragma once
#include "../runtime/model/hf_model.h"
#include <cstdint>
#include <memory>
#include <string>
#include <vector>
namespace neurx::cuda {
class HfDecoderCuda;
class HfCudaKvCache {
 public:
  HfCudaKvCache();
  ~HfCudaKvCache();
  HfCudaKvCache(HfCudaKvCache&&) noexcept;
  HfCudaKvCache& operator=(HfCudaKvCache&&) noexcept;
  HfCudaKvCache(const HfCudaKvCache&) = delete;
  HfCudaKvCache& operator=(const HfCudaKvCache&) = delete;
  std::size_t length() const;
  void clear();
 private:
  struct State;
  std::unique_ptr<State> state_;
  friend class HfDecoderCuda;
};
class HfDecoderCuda {
 public:
  explicit HfDecoderCuda(const std::string& model_directory, int device = 0);
  ~HfDecoderCuda();
  HfDecoderCuda(HfDecoderCuda&&) noexcept;
  HfDecoderCuda& operator=(HfDecoderCuda&&) noexcept;
  HfDecoderCuda(const HfDecoderCuda&) = delete;
  HfDecoderCuda& operator=(const HfDecoderCuda&) = delete;
  const runtime::model::HfConfig& config() const;
  std::vector<float> prefill(const std::vector<int32_t>& token_ids, HfCudaKvCache* cache);
  std::vector<float> decode(int32_t token_id, HfCudaKvCache* cache);
  static int32_t greedy(const std::vector<float>& logits);
 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
}
