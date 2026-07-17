#pragma once

#include "../runtime/acl_runtime.h"

#include <cstdint>
#include <string>
#include <vector>

namespace neurx::cann {

enum class ModelPrecision { fp16, fp32 };

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
  DeviceBuffer storage;
};

Status inspect_nxtrfmv2(const std::string& path, ModelMetadata* metadata);
uint16_t float_to_fp16_bits(float value);

class Nxtrfmv2Model {
 public:
  Status load(const std::string& path, DeviceSession& session,
              const ModelLoadOptions& options = {});
  void reset();

  bool loaded() const { return loaded_; }
  const ModelMetadata& metadata() const { return metadata_; }
  const std::vector<DeviceWeight>& weights() const { return weights_; }

 private:
  ModelMetadata metadata_;
  std::vector<DeviceWeight> weights_;
  bool loaded_ = false;
};

}  // namespace neurx::cann
