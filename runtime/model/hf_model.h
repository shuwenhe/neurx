#pragma once

#include "json.h"
#include "safetensors.h"

#include <map>
#include <memory>
#include <string>
#include <vector>

namespace neurx::runtime::model {

enum class ModelArchitecture { llama, qwen2 };

struct HfConfig {
  ModelArchitecture architecture = ModelArchitecture::llama;
  std::string model_type;
  int64_t vocab_size = 0;
  int64_t hidden_size = 0;
  int64_t intermediate_size = 0;
  int64_t num_hidden_layers = 0;
  int64_t num_attention_heads = 0;
  int64_t num_key_value_heads = 0;
  int64_t head_dimension = 0;
  int64_t max_position_embeddings = 0;
  double rms_norm_eps = 1.0e-6;
  double rope_theta = 10000.0;
  bool attention_bias = false;
  bool mlp_bias = false;
  bool tie_word_embeddings = false;

  int64_t head_dim() const;
  void validate() const;
  static HfConfig from_file(const std::string& path);
};

struct WeightSpec {
  std::string name;
  std::vector<int64_t> shape;
  bool optional = false;
};

std::vector<WeightSpec> expected_weights(const HfConfig& config);

class HfWeightStore {
 public:
  static HfWeightStore open(const std::string& model_directory);

  bool contains(const std::string& name) const;
  const SafeTensorInfo& info(const std::string& name) const;
  native::Tensor load(const std::string& name,
                      native::Device device = {native::DeviceType::cpu, 0}) const;
  void validate_architecture(const HfConfig& config) const;
  std::size_t size() const { return locations_.size(); }

 private:
  struct Location {
    std::shared_ptr<SafeTensorFile> file;
    SafeTensorInfo info;
  };
  std::map<std::string, Location> locations_;
};

}  // namespace neurx::runtime::model
