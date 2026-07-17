#include "transformer_engine.h"

#include <cstdint>

namespace neurx::cann {
namespace {

class Arena {
 public:
  Arena(void* data, std::size_t bytes)
      : current_(static_cast<unsigned char*>(data)), remaining_(bytes) {}

  TensorView tensor(std::size_t rows, std::size_t columns) {
    constexpr std::size_t alignment = 64;
    const auto address = reinterpret_cast<std::uintptr_t>(current_);
    const std::size_t padding =
        (alignment - (address % alignment)) % alignment;
    if (padding > remaining_ || rows == 0 || columns == 0 ||
        columns > (remaining_ - padding) / (rows * sizeof(uint16_t))) {
      return {};
    }
    const std::size_t bytes = rows * columns * sizeof(uint16_t);
    current_ += padding;
    remaining_ -= padding;
    TensorView result{current_, rows, columns};
    current_ += bytes;
    remaining_ -= bytes;
    return result;
  }

 private:
  unsigned char* current_ = nullptr;
  std::size_t remaining_ = 0;
};

Status stage_status(const Status& status, const std::string& stage) {
  return status.ok ? status : Status::failure(stage + ": " + status.message);
}

bool valid(const TensorView& tensor) {
  return tensor.data && tensor.rows != 0 && tensor.columns != 0;
}

}  // namespace

Status execute_transformer(const inference::DeviceBatch& batch,
                           const Nxtrfmv2Model& model, PagedKvCache& cache,
                           TransformerPrimitiveBackend& backend) {
  TransformerBatchPlan plan;
  Status status = build_transformer_batch_plan(batch, model, cache, &plan);
  if (!status.ok) return status;
  if (!batch.workspace || batch.workspace_bytes < plan.scratch_bytes) {
    return Status::failure("FP16 activation workspace requires " +
                           std::to_string(plan.scratch_bytes) + " bytes");
  }

  Arena arena(batch.workspace, batch.workspace_bytes);
  TensorView hidden = arena.tensor(plan.token_count, plan.hidden_size);
  TensorView norm = arena.tensor(plan.token_count, plan.hidden_size);
  TensorView query = arena.tensor(plan.token_count, plan.hidden_size);
  TensorView key = arena.tensor(plan.token_count, plan.hidden_size);
  TensorView value = arena.tensor(plan.token_count, plan.hidden_size);
  TensorView auxiliary = arena.tensor(plan.token_count, plan.hidden_size);
  TensorView gate = arena.tensor(plan.token_count, plan.ffn_size);
  TensorView up = arena.tensor(plan.token_count, plan.ffn_size);
  TensorView activated = arena.tensor(plan.token_count, plan.ffn_size);
  TensorView last_hidden = arena.tensor(plan.batch_size, plan.hidden_size);
  if (!valid(hidden) || !valid(norm) || !valid(query) || !valid(key) ||
      !valid(value) || !valid(auxiliary) || !valid(gate) || !valid(up) ||
      !valid(activated) || !valid(last_hidden)) {
    return Status::failure("activation workspace partitioning failed");
  }

  const DeviceWeight* embedding = model.token_embedding();
  if (!embedding) return Status::failure("token embedding weight is unavailable");
  status = backend.embedding(batch.token_ids, *embedding, hidden, batch.stream);
  if (!status.ok) return stage_status(status, "embedding");

  for (std::size_t layer = 0; layer < plan.layer_count; ++layer) {
    const auto weight = [&](LayerWeightKind kind) {
      return model.layer_weight(layer, kind);
    };
    const DeviceWeight* attention_norm = weight(LayerWeightKind::attention_norm);
    const DeviceWeight* q_weight = weight(LayerWeightKind::q_projection);
    const DeviceWeight* k_weight = weight(LayerWeightKind::k_projection);
    const DeviceWeight* v_weight = weight(LayerWeightKind::v_projection);
    const DeviceWeight* o_weight = weight(LayerWeightKind::output_projection);
    const DeviceWeight* ffn_norm = weight(LayerWeightKind::ffn_norm);
    const DeviceWeight* gate_weight = weight(LayerWeightKind::gate_projection);
    const DeviceWeight* up_weight = weight(LayerWeightKind::up_projection);
    const DeviceWeight* down_weight = weight(LayerWeightKind::down_projection);
    if (!attention_norm || !q_weight || !k_weight || !v_weight || !o_weight ||
        !ffn_norm || !gate_weight || !up_weight || !down_weight) {
      return Status::failure("layer " + std::to_string(layer) +
                             " has incomplete weights");
    }

    status = backend.rms_norm(hidden, *attention_norm, norm, batch.stream);
    if (!status.ok) return stage_status(status, "attention rmsnorm");
    status = backend.linear(norm, *q_weight, query, batch.stream);
    if (!status.ok) return stage_status(status, "q projection");
    status = backend.linear(norm, *k_weight, key, batch.stream);
    if (!status.ok) return stage_status(status, "k projection");
    status = backend.linear(norm, *v_weight, value, batch.stream);
    if (!status.ok) return stage_status(status, "v projection");
    status = backend.rope(query, key, plan, batch.stream);
    if (!status.ok) return stage_status(status, "rope");
    status = backend.store_kv(key, value, layer, plan, cache, batch.stream);
    if (!status.ok) return stage_status(status, "reshape and cache");
    status = backend.attention(query, key, value, layer, plan, cache,
                               auxiliary, batch.stream);
    if (!status.ok) return stage_status(status, "attention");
    status = backend.linear(auxiliary, *o_weight, query, batch.stream);
    if (!status.ok) return stage_status(status, "attention output projection");
    status = backend.add(hidden, query, auxiliary, batch.stream);
    if (!status.ok) return stage_status(status, "attention residual");
    status = backend.rms_norm(auxiliary, *ffn_norm, norm, batch.stream);
    if (!status.ok) return stage_status(status, "ffn rmsnorm");
    status = backend.linear(norm, *gate_weight, gate, batch.stream);
    if (!status.ok) return stage_status(status, "gate projection");
    status = backend.linear(norm, *up_weight, up, batch.stream);
    if (!status.ok) return stage_status(status, "up projection");
    status = backend.swiglu(gate, up, activated, batch.stream);
    if (!status.ok) return stage_status(status, "swiglu");
    status = backend.linear(activated, *down_weight, query, batch.stream);
    if (!status.ok) return stage_status(status, "down projection");
    status = backend.add(auxiliary, query, hidden, batch.stream);
    if (!status.ok) return stage_status(status, "ffn residual");
  }

  status = backend.gather_last(hidden, plan, last_hidden, batch.stream);
  if (!status.ok) return stage_status(status, "last-token gather");
  const DeviceWeight* lm_head = model.lm_head();
  if (!lm_head) return Status::failure("LM head weight is unavailable");
  TensorView logits{batch.logits, plan.batch_size, plan.vocabulary};
  status = backend.linear(last_hidden, *lm_head, logits, batch.stream);
  return stage_status(status, "lm head");
}

}  // namespace neurx::cann
