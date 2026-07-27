#include "../cann/cache/paged_kv_cache.h"
#include "../cann/model/nxtrfmv2_loader.h"
#include "../cann/operators/transformer_plan.h"

#include <cassert>
#include <cmath>
#include <cstring>
#include <cstdio>
#include <fstream>
#include <new>

namespace {

class HostAllocator final : public neurx::cann::DeviceAllocator {
 public:
  neurx::cann::status allocate(void** address, std::size_t bytes) override {
    if (!address || bytes == 0) {
      return neurx::cann::status::failure("invalid test allocation");
    }
    *address = ::operator new(bytes, std::nothrow);
    return *address ? neurx::cann::status::success()
                    : neurx::cann::status::failure("test allocation failed");
  }

  void release(void* address) override { ::operator delete(address); }
};

#pragma pack(push, 1)
struct test_header_v2 {
  char magic[8];
  uint32_t version, header_bytes;
  uint64_t step, optimizer_step, micro_step, shard, line, docs, tokens;
  uint32_t vocab, seq, dim, heads, ffn, layers, micro_batch, grad_accum;
  uint32_t tokenizer_kind, vocab_path_bytes, merges_path_bytes;
  uint64_t tokenizer_hash, pending_count, param_count;
};
#pragma pack(pop)

static_assert(sizeof(test_header_v2) == 140, "test checkpoint header ABI changed");

}

int main() {
  HostAllocator allocator;
  neurx::cann::PagedKvCache cache({4, 64, 4}, &allocator);
  assert(cache.initialize().ok);
  assert(cache.initialize().ok);

  assert(cache.reserve("request-a", 5).ok);
  auto table = cache.block_table("request-a");
  assert(table.size() == 2 && table[0] == 0 && table[1] == 1);
  assert(cache.token_count("request-a") == 5);
  assert(cache.append("request-a", 4).ok);
  assert(cache.block_table("request-a").size() == 3);
  assert(cache.block_address(0) != nullptr);
  assert(cache.block_address(4) == nullptr);

  const auto exhausted = cache.reserve("request-b", 8);
  assert(!exhausted.ok && cache.block_table("request-b").empty());
  auto stats = cache.stats();
  assert(stats.used_blocks == 3 && stats.free_blocks == 1);
  assert(stats.active_requests == 1 && stats.allocated_tokens == 9);

  assert(cache.release("request-a"));
  assert(!cache.release("request-a"));
  assert(cache.reserve("request-b", 8).ok);
  stats = cache.stats();
  assert(stats.used_blocks == 2 && stats.free_blocks == 2);
  assert(stats.active_requests == 1 && stats.allocated_tokens == 8);

  const auto tensor_config =
      neurx::cann::kv_cache_config_2::fp16_transformer(2, 16, 2, 2, 4);
  neurx::cann::PagedKvCache tensor_cache(tensor_config, &allocator);
  assert(tensor_cache.initialize().ok);
  auto* key0 = static_cast<unsigned char*>(tensor_cache.key_layer_address(0));
  auto* key1 = static_cast<unsigned char*>(tensor_cache.key_layer_address(1));
  auto* value0 = static_cast<unsigned char*>(tensor_cache.value_layer_address(0));
  assert(key0 != nullptr && key1 - key0 == 512);
  assert(value0 - key0 == 1024);
  assert(tensor_cache.block_tensor_bytes() == 256);
  assert(tensor_cache.layer_tensor_bytes() == 512);
  assert(static_cast<unsigned char*>(
             tensor_cache.key_slot_address(1, 1, 3)) -
             key0 ==
         816);

  neurx::cann::model_metadata compatible_model;
  compatible_model.vocabulary = 128;
  compatible_model.hidden_size = 256;
  compatible_model.attention_heads = 2;
  compatible_model.ffn_size = 512;
  compatible_model.layers = 2;
  const auto compatible_config =
      neurx::cann::kv_cache_config_2::fp16_310p(2, 16, 2, 2, 128);
  assert(neurx::cann::validate_310p_model(compatible_model, compatible_config).ok);
  compatible_model.hidden_size = 260;
  assert(!neurx::cann::validate_310p_model(compatible_model, compatible_config).ok);

  neurx::cann::transformer_batch_plan prefill_plan;
  prefill_plan.phase = neurx::inference::Phase::prefill;
  prefill_plan.batch_size = 2;
  prefill_plan.token_count = 3;
  prefill_plan.max_blocks_per_request = 2;
  prefill_plan.requests = {
      {"a", 5, {0, 1}, {3, 4}},
      {"b", 1, {2}, {32}},
  };
  neurx::cann::paged_attention_metadata attention_metadata;
  assert(neurx::cann::build_paged_attention_metadata(
             prefill_plan, &attention_metadata)
             .ok);
  assert(attention_metadata.rows == 3);
  assert((attention_metadata.context_lengths == std::vector<int32_t>{4, 5, 1}));
  assert((attention_metadata.block_tables ==
          std::vector<int32_t>{0, 1, 0, 1, 2, -1}));

  prefill_plan.phase = neurx::inference::Phase::decode;
  prefill_plan.batch_size = 2;
  prefill_plan.token_count = 2;
  assert(neurx::cann::build_paged_attention_metadata(
             prefill_plan, &attention_metadata)
             .ok);
  assert((attention_metadata.context_lengths == std::vector<int32_t>{5, 1}));

  assert(neurx::cann::float_to_fp16_bits(0.0F) == 0x0000);
  assert(neurx::cann::float_to_fp16_bits(1.0F) == 0x3c00);
  assert(neurx::cann::float_to_fp16_bits(-2.0F) == 0xc000);
  assert(neurx::cann::float_to_fp16_bits(65504.0F) == 0x7bff);
  const float quant_input[] = {1.0F, -2.0F, 0.0F, 4.0F, -1.0F, 2.0F};
  int8_t quant_output[6] = {};
  uint16_t quant_scales[2] = {};
  assert(neurx::cann::quantize_int8_per_channel(
             quant_input, 3, 2, quant_output, quant_scales)
             .ok);
  assert(quant_output[0] == 127 && quant_output[1] == 0);
  assert(quant_output[2] == -127 && quant_output[3] == -64);
  assert(quant_output[4] == 127 && quant_output[5] == 64);
  assert(quant_scales[0] != 0 && quant_scales[1] != 0);
  const float invalid_quant_input[] = {NAN};
  assert(!neurx::cann::quantize_int8_per_channel(
              invalid_quant_input, 1, 1, quant_output, quant_scales)
              .ok);

  const char* checkpoint = "/tmp/neurx_nxtrfmv2_loader_test.ckpt";
  test_header_v2 header{};
  std::memcpy(header.magic, "NXTRFMV2", 8);
  header.version = 2;
  header.header_bytes = sizeof(header);
  header.step = 42;
  header.vocab = 128;
  header.seq = 64;
  header.dim = 32;
  header.heads = 4;
  header.ffn = 96;
  header.layers = 2;
  header.tokenizer_hash = 1234;
  header.param_count = 20;
  {
    std::ofstream output(checkpoint, std::ios::binary | std::ios::trunc);
    output.write(reinterpret_cast<const char*>(&header), sizeof(header));
    assert(output.good());
  }
  neurx::cann::model_metadata metadata;
  assert(neurx::cann::inspect_nxtrfmv2(checkpoint, &metadata).ok);
  assert(metadata.step == 42 && metadata.vocabulary == 128);
  assert(metadata.hidden_size == 32 && metadata.layers == 2);
  assert(metadata.parameter_tensors == 20 && metadata.tokenizer_hash == 1234);
  std::remove(checkpoint);

  std::printf("cann-paged-kv-cache PASS blocks=%zu used=%zu free=%zu\n",
              stats.total_blocks, stats.used_blocks, stats.free_blocks);
  return 0;
}
