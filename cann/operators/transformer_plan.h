#pragma once
#include "../../inference/runtime/backends/backend_adapter.h"
#include "../cache/paged_kv_cache.h"
#include "../model/nxtrfmv2_loader.h"
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>
namespace neurx::cann {
struct request_kv_plan {
  std::string request_id;
  std::size_t sequence_tokens = 0;
  std::vector<uint32_t> blocks;
  std::vector<int32_t> write_slots;
};
struct transformer_batch_plan {
  inference::phase phase = inference::phase::prefill;
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
  std::vector<request_kv_plan> requests;
};
struct paged_attention_metadata {
  std::size_t rows = 0;
  std::size_t block_table_stride = 0;
  std::vector<int32_t> block_tables;
  std::vector<int32_t> context_lengths;
};
status validate_310p_model(const model_metadata& model,
                           const kv_cache_config_2& cache);
status build_transformer_batch_plan(
    const inference::device_batch& batch, const nxtrfmv2_model& model,
    const paged_kv_cache& cache, transformer_batch_plan* plan);
status build_paged_attention_metadata(const transformer_batch_plan& plan,
                                      paged_attention_metadata* metadata);
}
