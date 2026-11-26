#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace neurx::runtime::model {
enum class MixerKind { linear_attention, full_attention };
struct FullAttentionConfig {
  uint64_t query_heads=0, kv_heads=0, head_dim=0, rotary_dim=0;
  double theta=0;
  std::vector<uint64_t> mrope_section;
};
struct DeltaNetConfig {
  uint64_t key_heads=0, value_heads=0, key_dim=0, value_dim=0, conv_kernel=0;
};
struct SparseMoeConfig {
  uint64_t experts=0, top_k=0, intermediate=0, shared_intermediate=0;
};
struct HybridStateBytes { uint64_t kv=0, recurrent=0, conv=0; };
struct HybridDecoderConfig {
  std::string model_type, text_model_type, weight_dtype;
  uint64_t hidden_size=0, vocab_size=0, max_positions=0;
  uint64_t mtp_layers=0;
  bool has_vision=false;
  double rms_epsilon=0;
  FullAttentionConfig full;
  DeltaNetConfig delta;
  SparseMoeConfig moe;
  std::vector<MixerKind> layer_types;
  static HybridDecoderConfig from_file(const std::string& path);
  static HybridDecoderConfig parse(const std::string& text);
  // FP32 KV/recurrent/raw convolution history, one session. No GPU allocation.
  HybridStateBytes state_bytes(uint64_t context) const;
};
}
