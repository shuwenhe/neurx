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
  virtual Status swiglu(const TensorView& gate, const TensorView& up,
                        const TensorView& output, Stream stream) = 0;
  virtual Status gather_last(const TensorView& hidden,
                             const TransformerBatchPlan& plan,
                             const TensorView& output, Stream stream) = 0;
};

// Runs the decoder-only transformer using an externally supplied FP16
// activation arena. Vendor-specific code only implements the primitive calls;
// layer ordering, weight mapping and KV lifecycle remain deterministic here.
Status execute_transformer(const inference::DeviceBatch& batch,
                           const Nxtrfmv2Model& model, PagedKvCache& cache,
                           TransformerPrimitiveBackend& backend);

}  // namespace neurx::cann
