#pragma once

#include "transformer_plan.h"

namespace neurx::cann {

struct TensorView {
  void* data = nullptr;
  std::size_t rows = 0;
  std::size_t columns = 0;
};

class TransformerPrimitiveBackend {
 public:
  virtual ~TransformerPrimitiveBackend() = default;

  virtual Status embedding(const void* token_ids, const DeviceWeight& table,
                           const TensorView& output, Stream stream) = 0;
  virtual Status rms_norm(const TensorView& input, const DeviceWeight& scale,
                          const TensorView& output, Stream stream) = 0;
  virtual Status linear(const TensorView& input, const DeviceWeight& weight,
                        const TensorView& output, Stream stream) = 0;
  virtual Status rope(const TensorView& query, const TensorView& key,
                      const TransformerBatchPlan& plan, Stream stream) = 0;
  virtual Status attention_qkv_rope(
      const TensorView& input, const DeviceWeight& norm_scale,
      const DeviceWeight& query_weight, const DeviceWeight& key_weight,
      const DeviceWeight& value_weight, const TensorView& normalized,
      const TensorView& query, const TensorView& key,
      const TensorView& value, const TransformerBatchPlan& plan,
      Stream stream) {
    Status status = rms_norm(input, norm_scale, normalized, stream);
    if (!status.ok) return status;
    status = linear(normalized, query_weight, query, stream);
    if (!status.ok) return status;
    status = linear(normalized, key_weight, key, stream);
    if (!status.ok) return status;
    status = linear(normalized, value_weight, value, stream);
    return status.ok ? rope(query, key, plan, stream) : status;
  }
  virtual Status store_kv(const TensorView& key, const TensorView& value,
                          std::size_t layer,
                          const TransformerBatchPlan& plan,
                          PagedKvCache& cache, Stream stream) = 0;
  virtual Status attention(const TensorView& query, const TensorView& key,
                           const TensorView& value, std::size_t layer,
                           const TransformerBatchPlan& plan,
                           PagedKvCache& cache, const TensorView& output,
                           Stream stream) = 0;
  virtual Status add(const TensorView& left, const TensorView& right,
                     const TensorView& output, Stream stream) = 0;
  virtual Status add_rms_norm(const TensorView& left,
                              const TensorView& right,
                              const DeviceWeight& scale,
                              const TensorView& residual,
                              const TensorView& normalized, Stream stream) {
    Status status = add(left, right, residual, stream);
    return status.ok ? rms_norm(residual, scale, normalized, stream) : status;
  }
  virtual Status swiglu(const TensorView& gate, const TensorView& up,
                        const TensorView& output, Stream stream) = 0;
  virtual Status gather_last(const TensorView& hidden,
                             const TransformerBatchPlan& plan,
                             const TensorView& output, Stream stream) = 0;
};




Status execute_transformer(const inference::DeviceBatch& batch,
                           const Nxtrfmv2Model& model, PagedKvCache& cache,
                           TransformerPrimitiveBackend& backend);

}
