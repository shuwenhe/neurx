#pragma once

#include "../../inference/runtime/backends/backend_adapter.h"
#include "../cache/paged_kv_cache.h"
#include "../model/nxtrfmv2_loader.h"

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace neurx::cann {

struct RequestKvPlan {
  std::string request_id;
  std::size_t sequence_tokens = 0;
  std::vector<uint32_t> blocks;
  std::vector<int32_t> write_slots;
};

struct TransformerBatchPlan {
  inference::Phase phase = inference::Phase::prefill;
  std::size_t batch_size = 0;
  std::size_t token_count = 0;
  std::size_t hidden_size = 0;
  std::size_t head_count = 0;
  std::size_t head_size = 0;
  std::size_t ffn_size = 0;
  std::size_t layer_count = 0;
  std::size_t vocabulary = 0;
  std::size_t max_blocks_per_request = 0;
  std::size_t scratch_bytes = 0;
  std::vector<RequestKvPlan> requests;
};

struct PagedAttentionMetadata {
  std::size_t rows = 0;
  std::size_t block_table_stride = 0;
  std::vector<int32_t> block_tables;
  std::vector<int32_t> context_lengths;
};

Status validate_310p_model(const ModelMetadata& model,
                           const KvCacheConfig& cache);
Status build_transformer_batch_plan(
    const inference::DeviceBatch& batch, const Nxtrfmv2Model& model,
    const PagedKvCache& cache, TransformerBatchPlan* plan);
Status build_paged_attention_metadata(const TransformerBatchPlan& plan,
                                      PagedAttentionMetadata* metadata);

}
