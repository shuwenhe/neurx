#pragma once
#include "../runtime/acl_runtime.h"
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>
namespace neurx::cann {
enum class ModelPrecision { fp16, fp32, int8_weight_only };
enum class WeightStorage { fp16, fp32, int8_per_channel };
struct model_metadata {
  uint64_t step = 0;
  uint64_t tokenizer_hash = 0;
  uint32_t tokenizer_kind = 0;
  uint32_t vocabulary = 0;
  uint32_t max_sequence = 0;
  uint32_t hidden_size = 0;
  uint32_t attention_heads = 0;
  uint32_t ffn_size = 0;
  uint32_t layers = 0;
  uint64_t parameter_tensors = 0;
};
struct model_load_options {
  ModelPrecision precision = ModelPrecision::fp16;
  uint64_t expected_tokenizer_hash = 0;
};
struct device_weight {
  std::string name;
  uint64_t elements = 0;
  uint64_t rows = 0;
  uint64_t columns = 0;
  WeightStorage type = WeightStorage::fp16;
  DeviceBuffer storage;
  DeviceBuffer scales;
  bool quantized() const { return type == WeightStorage::int8_per_channel; }
};
enum class LayerWeightKind : std::size_t {
  attention_norm = 0,
  q_projection = 1,
  k_projection = 2,
  v_projection = 3,
  output_projection = 4,
  ffn_norm = 5,
  gate_projection = 6,
  up_projection = 7,
  down_projection = 8,
};
status inspect_nxtrfmv2(const std::string& path, model_metadata* metadata);
uint16_t float_to_fp16_bits(float value);
status quantize_int8_per_channel(const float* input, std::size_t rows,
                                 std::size_t columns, int8_t* output,
                                 uint16_t* scales);
class Nxtrfmv2Model {
 public:
  status load(const std::string& path, DeviceSession& session,
              const model_load_options& options = {});
  void reset();
  bool loaded() const { return loaded_; }
  ModelPrecision precision() const { return precision_; }
  const model_metadata& metadata() const { return metadata_; }
  const std::vector<device_weight>& weights() const { return weights_; }
  const device_weight* token_embedding() const;
  const device_weight* layer_weight(std::size_t layer,
                                   LayerWeightKind kind) const;
  const device_weight* lm_head() const;
 private:
  model_metadata metadata_;
  std::vector<device_weight> weights_;
  ModelPrecision precision_ = ModelPrecision::fp16;
  bool loaded_ = false;
};
}
