#pragma once
#include "json.h"
#include "safetensors.h"
#include <map>
#include <memory>
#include <string>
#include <vector>
namespace neurx::runtime::model {
enum class model_architecture { llama, base_model };
struct hf_config {
  model_architecture architecture = model_architecture::llama;
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
  static hf_config from_file(const std::string& path);
};
struct weight_spec {
  std::string name;
  std::vector<int64_t> shape;
  bool optional = false;
};
std::vector<weight_spec> expected_weights(const hf_config& config);
class hf_weight_store {
 public:
  static hf_weight_store open(const std::string& model_directory);
  bool contains(const std::string& name) const;
  const safe_tensor_info& info(const std::string& name) const;
  native::tensor load(const std::string& name,
                      native::device device = {native::device_type::cpu, 0}) const;
  void validate_architecture(const hf_config& config) const;
  std::size_t size() const { return locations_.size(); }
 private:
  struct location {
    std::shared_ptr<safe_tensor_file> file;
    safe_tensor_info info;
  };
  std::map<std::string, location> locations_;
};
}
