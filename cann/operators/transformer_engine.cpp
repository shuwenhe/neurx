#include "transformer_engine.h"

#include <cstdint>

namespace neurx::cann {
namespace {

class Arena {
 public:
  Arena(void* data, std::size_t bytes)
      : current_(static_cast<unsigned char*>(data)), remaining_(bytes) {}

  tensor_view tensor(std::size_t rows, std::size_t columns) {
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
    tensor_view result{current_, rows, columns};
    current_ += bytes;
    remaining_ -= bytes;
    return result;
  }

 private:
  unsigned char* current_ = nullptr;
  std::size_t remaining_ = 0;
};

status stage_status(const status& status, const std::string& stage) {
  return status.ok ? status : status::failure(stage + ": " + status.message);
}

bool valid(const tensor_view& tensor) {
  return tensor.data && tensor.rows != 0 && tensor.columns != 0;
}

}

status execute_transformer(const inference::device_batch& batch,
                           const Nxtrfmv2Model& model, PagedKvCache& cache,
                           TransformerPrimitiveBackend& backend) {
  transformer_batch_plan plan;
  status status = build_transformer_batch_plan(batch, model, cache, &plan);
  if (!status.ok) return status;
  if (!batch.workspace || batch.workspace_bytes < plan.scratch_bytes) {
    return status::failure("FP16 activation workspace requires " +
                           std::to_string(plan.scratch_bytes) + " bytes");
  }

  Arena arena(batch.workspace, batch.workspace_bytes);
  tensor_view hidden = arena.tensor(plan.token_count, plan.hidden_size);
  tensor_view norm = arena.tensor(plan.token_count, plan.hidden_size);
  tensor_view query = arena.tensor(plan.token_count, plan.hidden_size);
  tensor_view key = arena.tensor(plan.token_count, plan.hidden_size);
  tensor_view value = arena.tensor(plan.token_count, plan.hidden_size);
  tensor_view auxiliary = arena.tensor(plan.token_count, plan.hidden_size);
  tensor_view gate = arena.tensor(plan.token_count, plan.ffn_size);
  tensor_view up = arena.tensor(plan.token_count, plan.ffn_size);
  tensor_view activated = arena.tensor(plan.token_count, plan.ffn_size);
  tensor_view last_hidden = arena.tensor(plan.batch_size, plan.hidden_size);
  if (!valid(hidden) || !valid(norm) || !valid(query) || !valid(key) ||
      !valid(value) || !valid(auxiliary) || !valid(gate) || !valid(up) ||
      !valid(activated) || !valid(last_hidden)) {
    return status::failure("activation workspace partitioning failed");
  }

  const device_weight* embedding = model.token_embedding();
  if (!embedding) return status::failure("token embedding weight is unavailable");
  status = backend.embedding(batch.token_ids, *embedding, hidden, batch.stream);
  if (!status.ok) return stage_status(status, "embedding");

  for (std::size_t layer = 0; layer < plan.layer_count; ++layer) {
    const auto weight = [&](LayerWeightKind kind) {
      return model.layer_weight(layer, kind);
    };
    const device_weight* attention_norm = weight(LayerWeightKind::attention_norm);
    const device_weight* q_weight = weight(LayerWeightKind::q_projection);
    const device_weight* k_weight = weight(LayerWeightKind::k_projection);
    const device_weight* v_weight = weight(LayerWeightKind::v_projection);
    const device_weight* o_weight = weight(LayerWeightKind::output_projection);
    const device_weight* ffn_norm = weight(LayerWeightKind::ffn_norm);
    const device_weight* gate_weight = weight(LayerWeightKind::gate_projection);
    const device_weight* up_weight = weight(LayerWeightKind::up_projection);
    const device_weight* down_weight = weight(LayerWeightKind::down_projection);
    if (!attention_norm || !q_weight || !k_weight || !v_weight || !o_weight ||
        !ffn_norm || !gate_weight || !up_weight || !down_weight) {
      return status::failure("layer " + std::to_string(layer) +
                             " has incomplete weights");
    }

    status = backend.attention_qkv_rope(
        hidden, *attention_norm, *q_weight, *k_weight, *v_weight, norm,
        query, key, value, plan, batch.stream);
    if (!status.ok) {
      return stage_status(status, "attention rmsnorm/qkv/rope");
    }
    status = backend.store_kv(key, value, layer, plan, cache, batch.stream);
    if (!status.ok) return stage_status(status, "reshape and cache");
    status = backend.attention(query, key, value, layer, plan, cache,
                               auxiliary, batch.stream);
    if (!status.ok) return stage_status(status, "attention");
    status = backend.linear(auxiliary, *o_weight, query, batch.stream);
    if (!status.ok) return stage_status(status, "attention output projection");
    status = backend.add_rms_norm(hidden, query, *ffn_norm, auxiliary, norm,
                                  batch.stream);
    if (!status.ok) {
      return stage_status(status, "attention residual and ffn rmsnorm");
    }
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
  const device_weight* lm_head = model.lm_head();
  if (!lm_head) return status::failure("LM head weight is unavailable");
  tensor_view logits{batch.logits, plan.batch_size, plan.vocabulary};
  status = backend.linear(last_hidden, *lm_head, logits, batch.stream);
  return stage_status(status, "lm head");
}

}
