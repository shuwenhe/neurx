#pragma once
#include "transformer_plan.h"
namespace neurx::cann {

struct tensor_view {
  void* data = nullptr;
  std::size_t rows = 0;
  std::size_t columns = 0;
};
class transformer_primitive_backend {
 public:
  virtual ~transformer_primitive_backend() = default;
  virtual status embedding(const void* token_ids, const device_weight& table,
                           const tensor_view& output, stream stream) = 0;
  virtual status rms_norm(const tensor_view& input, const device_weight& scale,
                          const tensor_view& output, stream stream) = 0;
  virtual status linear(const tensor_view& input, const device_weight& weight,
                        const tensor_view& output, stream stream) = 0;
  virtual status rope(const tensor_view& query, const tensor_view& key,
                      const transformer_batch_plan& plan, stream stream) = 0;
  virtual status attention_qkv_rope(
      const tensor_view& input, const device_weight& norm_scale,
      const device_weight& query_weight, const device_weight& key_weight,
      const device_weight& value_weight, const tensor_view& normalized,
      const tensor_view& query, const tensor_view& key,
      const tensor_view& value, const transformer_batch_plan& plan,
      stream stream) {
    status status = rms_norm(input, norm_scale, normalized, stream);
    if (!status.ok) return status;
    status = linear(normalized, query_weight, query, stream);
    if (!status.ok) return status;
    status = linear(normalized, key_weight, key, stream);
    if (!status.ok) return status;
    status = linear(normalized, value_weight, value, stream);
    return status.ok ? rope(query, key, plan, stream) : status;
  }
  virtual status store_kv(const tensor_view& key, const tensor_view& value,
                          std::size_t layer,
                          const transformer_batch_plan& plan,
                          paged_kv_cache& cache, stream stream) = 0;
  virtual status attention(const tensor_view& query, const tensor_view& key,
                           const tensor_view& value, std::size_t layer,
                           const transformer_batch_plan& plan,
                           paged_kv_cache& cache, const tensor_view& output,
                           stream stream) = 0;
  virtual status add(const tensor_view& left, const tensor_view& right,
                     const tensor_view& output, stream stream) = 0;
  virtual status add_rms_norm(const tensor_view& left,
                              const tensor_view& right,
                              const device_weight& scale,
                              const tensor_view& residual,
                              const tensor_view& normalized, stream stream) {
    status status = add(left, right, residual, stream);
    return status.ok ? rms_norm(residual, scale, normalized, stream) : status;
  }
  virtual status swiglu(const tensor_view& gate, const tensor_view& up,
                        const tensor_view& output, stream stream) = 0;
  virtual status gather_last(const tensor_view& hidden,
                             const transformer_batch_plan& plan,
                             const tensor_view& output, stream stream) = 0;
};
status execute_transformer(const inference::device_batch& batch,
                           const nxtrfmv2_model& model, paged_kv_cache& cache,
                           transformer_primitive_backend& backend);
}
