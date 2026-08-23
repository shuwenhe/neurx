#pragma once
#include "../runtime/model/hf_model.h"
#include <cstdint>
#include <memory>
#include <string>
#include <vector>
namespace neurx::cuda {

struct lora_tensor_snapshot {
  std::string name;
  std::vector<int64_t> shape;
  std::vector<float> values;
};

struct lora_training_report {
  float initial_loss = 0.0F;
  float final_loss = 0.0F;
  double lora_a_grad_norm = 0.0;
  double lora_b_grad_norm = 0.0;
  double measured_a_grad_norm = 0.0;
  double measured_b_grad_norm = 0.0;
  std::string measured_tensor;
  std::size_t a_changed_index = 0;
  std::size_t b_changed_index = 0;
  float a_before = 0.0F;
  float a_after = 0.0F;
  float b_before = 0.0F;
  float b_after = 0.0F;
  std::size_t module_count = 0;
  std::size_t parameter_count = 0;
  std::vector<lora_tensor_snapshot> tensors;
};
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
  std::size_t weight_count() const;
  std::vector<float> prefill(const std::vector<int32_t>& token_ids, hf_cuda_kv_cache* cache);
  std::vector<float> prefill_all(const std::vector<int32_t>& token_ids,
                                 hf_cuda_kv_cache* cache);
  lora_training_report train_lora_two_steps(const std::vector<int32_t>& token_ids,
                                            const std::vector<int32_t>& labels,
                                            int rank, float alpha,
                                            float learning_rate);
  std::vector<float> decode(int32_t token_id, hf_cuda_kv_cache* cache);
  static int32_t greedy(const std::vector<float>& logits);
 private:
  struct impl;
  std::unique_ptr<impl> impl_;
};
}
