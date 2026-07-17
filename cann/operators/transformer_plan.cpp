#include "transformer_plan.h"

#include <algorithm>
#include <limits>
#include <utility>

namespace neurx::cann {
namespace {

bool checked_add_product(std::size_t count, std::size_t width,
                         std::size_t* elements) {
  if (!elements || (count != 0 &&
                    width > (std::numeric_limits<std::size_t>::max() -
                             *elements) /
                                count)) {
    return false;
  }
  *elements += count * width;
  return true;
}

}  // namespace

Status validate_310p_model(const ModelMetadata& model,
                           const KvCacheConfig& cache) {
  if (model.hidden_size == 0 || model.attention_heads == 0 ||
      model.hidden_size % model.attention_heads != 0) {
    return Status::failure("model has an invalid attention shape");
  }
  const std::size_t head_size = model.hidden_size / model.attention_heads;
  if (head_size > 256 || head_size % 16 != 0) {
    return Status::failure(
        "Ascend310P attention head size must be <=256 and divisible by 16");
  }
  if (!cache.has_tensor_layout() || cache.element_bytes != sizeof(uint16_t)) {
    return Status::failure("Ascend310P requires an FP16 tensor-layout KV cache");
  }
  if (cache.format != KvStorageFormat::fractal_nz) {
    return Status::failure("Ascend310P KV cache must use FRACTAL_NZ storage");
  }
  if (cache.tokens_per_block == 0 || cache.tokens_per_block % 16 != 0 ||
      cache.tokens_per_block > 128) {
    return Status::failure(
        "Ascend310P KV block size must be a multiple of 16 and <=128");
  }
  if (cache.tokens_per_block > (128U * 128U) / head_size) {
    return Status::failure(
        "Ascend310P KV block size times head size exceeds hardware limit");
  }
  if (cache.layers != model.layers || cache.kv_heads != model.attention_heads ||
      cache.head_size != head_size) {
    return Status::failure("KV tensor layout does not match model dimensions");
  }
  if (model.ffn_size % 32 != 0) {
    return Status::failure("Ascend310P SwiGLU width must be divisible by 32");
  }
  return Status::success();
}

Status build_transformer_batch_plan(
    const inference::DeviceBatch& batch, const Nxtrfmv2Model& model,
    const PagedKvCache& cache, TransformerBatchPlan* plan) {
  if (!plan) return Status::failure("transformer batch plan output is null");
  if (!model.loaded()) return Status::failure("Ascend model weights are not loaded");
  if (model.precision() != ModelPrecision::fp16 &&
      model.precision() != ModelPrecision::int8_weight_only) {
    return Status::failure(
        "Ascend310P operator plugin requires FP16 or INT8 weight-only weights");
  }
  if (!batch.token_ids || !batch.logits) {
    return Status::failure("device token ids and logits buffers are required");
  }
  if (batch.schedule.items.empty() || batch.schedule.items.size() > 2000) {
    return Status::failure("Ascend310P batch size must be in [1, 2000]");
  }
  const Status compatible =
      validate_310p_model(model.metadata(), cache.config());
  if (!compatible.ok) return compatible;

  TransformerBatchPlan result;
  result.phase = batch.schedule.phase;
  result.batch_size = batch.schedule.items.size();
  result.token_count = static_cast<std::size_t>(batch.schedule.total_tokens);
  result.hidden_size = model.metadata().hidden_size;
  result.head_count = model.metadata().attention_heads;
  result.head_size = result.hidden_size / result.head_count;
  result.ffn_size = model.metadata().ffn_size;
  result.layer_count = model.metadata().layers;
  result.vocabulary = model.metadata().vocabulary;
  result.requests.reserve(result.batch_size);

  std::size_t scheduled_tokens = 0;
  for (const auto& item : batch.schedule.items) {
    if (item.request_id.empty() || item.token_count <= 0) {
      return Status::failure("batch contains an invalid request item");
    }
    RequestKvPlan request;
    request.request_id = item.request_id;
    request.sequence_tokens = cache.token_count(item.request_id);
    request.blocks = cache.block_table(item.request_id);
    if (request.sequence_tokens == 0 || request.blocks.empty()) {
      return Status::failure(item.request_id + ": KV blocks are not reserved");
    }
    const std::size_t new_tokens =
        batch.schedule.phase == inference::Phase::decode
            ? 1
            : static_cast<std::size_t>(item.token_count);
    if (new_tokens > request.sequence_tokens) {
      return Status::failure(item.request_id + ": KV token accounting underflows");
    }
    const std::size_t first_token = request.sequence_tokens - new_tokens;
    request.write_slots.reserve(new_tokens);
    for (std::size_t token = first_token; token < request.sequence_tokens; ++token) {
      const std::size_t table_index = token / cache.config().tokens_per_block;
      if (table_index >= request.blocks.size()) {
        return Status::failure(item.request_id + ": KV block table is too short");
      }
      const uint32_t block = request.blocks[table_index];
      const std::size_t offset = token % cache.config().tokens_per_block;
      const std::size_t slot =
          static_cast<std::size_t>(block) * cache.config().tokens_per_block + offset;
      if (slot > static_cast<std::size_t>(std::numeric_limits<int32_t>::max())) {
        return Status::failure("KV slot index exceeds int32 capacity");
      }
      request.write_slots.push_back(static_cast<int32_t>(slot));
    }
    scheduled_tokens += new_tokens;
    result.max_blocks_per_request =
        std::max(result.max_blocks_per_request, request.blocks.size());
    result.requests.push_back(std::move(request));
  }
  if (scheduled_tokens != result.token_count) {
    return Status::failure("batch total token count does not match work items");
  }

  // Reusable FP16 activation arena: hidden states, norm, Q/K/V, attention,
  // projections, gate/up/SwiGLU, and one logits row per request.
  std::size_t scratch_elements = 0;
  if (!checked_add_product(result.token_count, 7 * result.hidden_size,
                           &scratch_elements) ||
      !checked_add_product(result.token_count, 3 * result.ffn_size,
                           &scratch_elements) ||
      !checked_add_product(result.batch_size, result.vocabulary,
                           &scratch_elements) ||
      scratch_elements >
          std::numeric_limits<std::size_t>::max() / sizeof(uint16_t)) {
    return Status::failure("transformer activation arena size overflows size_t");
  }
  result.scratch_bytes = scratch_elements * sizeof(uint16_t);
  *plan = std::move(result);
  return Status::success();
}

Status build_paged_attention_metadata(const TransformerBatchPlan& plan,
                                      PagedAttentionMetadata* metadata) {
  if (!metadata) return Status::failure("PagedAttention metadata output is null");
  if (plan.requests.empty() || plan.max_blocks_per_request == 0) {
    return Status::failure("PagedAttention plan has no requests or blocks");
  }
  PagedAttentionMetadata result;
  result.rows = plan.phase == inference::Phase::prefill ? plan.token_count
                                                        : plan.batch_size;
  result.block_table_stride = plan.max_blocks_per_request;
  result.block_tables.assign(result.rows * result.block_table_stride, -1);
  result.context_lengths.reserve(result.rows);
  std::size_t row = 0;
  for (const auto& request : plan.requests) {
    const std::size_t rows =
        plan.phase == inference::Phase::prefill ? request.write_slots.size() : 1;
    if (request.write_slots.size() > request.sequence_tokens ||
        request.blocks.size() > result.block_table_stride) {
      return Status::failure(request.request_id +
                             ": invalid PagedAttention request metadata");
    }
    const std::size_t first = request.sequence_tokens - request.write_slots.size();
    for (std::size_t local = 0; local < rows; ++local, ++row) {
      if (row >= result.rows) {
        return Status::failure("PagedAttention metadata has too many rows");
      }
      std::copy(request.blocks.begin(), request.blocks.end(),
                result.block_tables.begin() +
                    row * result.block_table_stride);
      const std::size_t context =
          plan.phase == inference::Phase::prefill ? first + local + 1
                                                  : request.sequence_tokens;
      if (context > static_cast<std::size_t>(
                        std::numeric_limits<int32_t>::max())) {
        return Status::failure("PagedAttention context length exceeds int32");
      }
      result.context_lengths.push_back(static_cast<int32_t>(context));
    }
  }
  if (row != result.rows || result.context_lengths.size() != result.rows) {
    return Status::failure("PagedAttention metadata row count mismatch");
  }
  *metadata = std::move(result);
  return Status::success();
}

}  // namespace neurx::cann
