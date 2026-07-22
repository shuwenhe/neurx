#pragma once

#include "../runtime/acl_runtime.h"

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace neurx::cann {

enum class ModelPrecision { fp16, fp32, int8_weight_only };

enum class WeightStorage { fp16, fp32, int8_per_channel };

struct ModelMetadata {
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

struct ModelLoadOptions {
  ModelPrecision precision = ModelPrecision::fp16;
  uint64_t expected_tokenizer_hash = 0;
};

struct DeviceWeight {
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

Status inspect_nxtrfmv2(const std::string& path, ModelMetadata* metadata);
uint16_t float_to_fp16_bits(float value);

Status quantize_int8_per_channel(const float* input, std::size_t rows,
                                 std::size_t columns, int8_t* output,
                                 uint16_t* scales);

class Nxtrfmv2Model {
 public:
  Status load(const std::string& path, DeviceSession& session,
              const ModelLoadOptions& options = {});
  void reset();

  bool loaded() const { return loaded_; }
  ModelPrecision precision() const { return precision_; }
  const ModelMetadata& metadata() const { return metadata_; }
  const std::vector<DeviceWeight>& weights() const { return weights_; }
  const DeviceWeight* token_embedding() const;
  const DeviceWeight* layer_weight(std::size_t layer,
                                   LayerWeightKind kind) const;
  const DeviceWeight* lm_head() const;

 private:
  ModelMetadata metadata_;
  std::vector<DeviceWeight> weights_;
  ModelPrecision precision_ = ModelPrecision::fp16;
  bool loaded_ = false;
};

}
