#include "hf_model.h"

#include <filesystem>
#include <stdexcept>
#include <unordered_map>

namespace neurx::runtime::model {
namespace {

int64_t optional_int(const json& value, const std::string& key, int64_t fallback) {
  return value.contains(key) ? value.at(key).as_int() : fallback;
}

double optional_number(const json& value, const std::string& key, double fallback) {
  return value.contains(key) ? value.at(key).as_number() : fallback;
}

bool optional_bool(const json& value, const std::string& key, bool fallback) {
  return value.contains(key) ? value.at(key).as_bool() : fallback;
}

std::vector<int64_t> shape(std::initializer_list<int64_t> dimensions) {
  return std::vector<int64_t>(dimensions);
}

}  // namespace

int64_t hf_config::head_dim() const {
  return head_dimension > 0 ? head_dimension : hidden_size / num_attention_heads;
}

void hf_config::validate() const {
  if (architecture != model_architecture::base_model || model_type != "qwen2") {
    throw std::runtime_error("only Qwen2ForCausalLM checkpoints are supported");
  }
  if (vocab_size <= 0 || hidden_size <= 0 || intermediate_size <= 0 ||
      num_hidden_layers <= 0 || num_attention_heads <= 0 || num_key_value_heads <= 0 ||
      max_position_embeddings <= 0) {
    throw std::runtime_error("HF model configuration contains non-positive dimensions");
  }
  if (hidden_size % num_attention_heads != 0 ||
      num_attention_heads % num_key_value_heads != 0 || head_dim() <= 0) {
    throw std::runtime_error("HF model attention dimensions are inconsistent");
  }
}

hf_config hf_config::from_file(const std::string& path) {
  const json root = json::parse_file(path);
  hf_config config;
  config.model_type = root.at("model_type").as_string();
  if (config.model_type == "qwen2") config.architecture = model_architecture::base_model;
  config.vocab_size = root.at("vocab_size").as_int();
  config.hidden_size = root.at("hidden_size").as_int();
  config.intermediate_size = root.at("intermediate_size").as_int();
  config.num_hidden_layers = root.at("num_hidden_layers").as_int();
  config.num_attention_heads = root.at("num_attention_heads").as_int();
  config.num_key_value_heads = optional_int(root, "num_key_value_heads", config.num_attention_heads);
  config.head_dimension = optional_int(root, "head_dim", 0);
  config.max_position_embeddings = root.at("max_position_embeddings").as_int();
  config.rms_norm_eps = optional_number(root, "rms_norm_eps", 1.0e-6);
  config.rope_theta = optional_number(root, "rope_theta", 10000.0);
  config.attention_bias = optional_bool(root, "attention_bias", true);
  config.mlp_bias = optional_bool(root, "mlp_bias", false);
  config.tie_word_embeddings = optional_bool(root, "tie_word_embeddings", false);
  config.validate();
  return config;
}

std::vector<weight_spec> expected_weights(const hf_config& config) {
  const int64_t hidden = config.hidden_size;
  const int64_t query = config.num_attention_heads * config.head_dim();
  const int64_t kv = config.num_key_value_heads * config.head_dim();
  std::vector<weight_spec> specs;
  specs.push_back({"model.embed_tokens.weight", shape({config.vocab_size, hidden}), false});
  for (int64_t layer = 0; layer < config.num_hidden_layers; ++layer) {
    const std::string prefix = "model.layers." + std::to_string(layer) + ".";
    specs.push_back({prefix + "input_layernorm.weight", shape({hidden}), false});
    specs.push_back({prefix + "post_attention_layernorm.weight", shape({hidden}), false});
    specs.push_back({prefix + "self_attn.q_proj.weight", shape({query, hidden}), false});
    specs.push_back({prefix + "self_attn.k_proj.weight", shape({kv, hidden}), false});
    specs.push_back({prefix + "self_attn.v_proj.weight", shape({kv, hidden}), false});
    specs.push_back({prefix + "self_attn.o_proj.weight", shape({hidden, query}), false});
    specs.push_back({prefix + "self_attn.q_proj.bias", shape({query}), true});
    specs.push_back({prefix + "self_attn.k_proj.bias", shape({kv}), true});
    specs.push_back({prefix + "self_attn.v_proj.bias", shape({kv}), true});
    specs.push_back({prefix + "self_attn.o_proj.bias", shape({hidden}), true});
    specs.push_back({prefix + "mlp.gate_proj.weight", shape({config.intermediate_size, hidden}), false});
    specs.push_back({prefix + "mlp.up_proj.weight", shape({config.intermediate_size, hidden}), false});
    specs.push_back({prefix + "mlp.down_proj.weight", shape({hidden, config.intermediate_size}), false});
  }
  specs.push_back({"model.norm.weight", shape({hidden}), false});
  specs.push_back({"lm_head.weight", shape({config.vocab_size, hidden}), config.tie_word_embeddings});
  return specs;
}

hf_weight_store hf_weight_store::open(const std::string& model_directory) {
  hf_weight_store store;
  const std::filesystem::path directory(model_directory);
  std::vector<std::filesystem::path> files;
  const auto single = directory / "model.safetensors";
  const auto index_path = directory / "model.safetensors.index.json";
  if (std::filesystem::exists(single)) {
    files.push_back(single);
  } else if (std::filesystem::exists(index_path)) {
    const json index = json::parse_file(index_path.string());
    std::map<std::string, bool> unique;
    for (const auto& [_, file] : index.at("weight_map").as_object()) unique[file.as_string()] = true;
    for (const auto& [file, _] : unique) files.push_back(directory / file);
  } else {
    throw std::runtime_error("model directory has no safetensors checkpoint: " + model_directory);
  }
  for (const auto& path : files) {
    auto file = std::make_shared<safe_tensor_file>(safe_tensor_file::open(path.string()));
    for (const auto& [name, info] : file->tensors()) {
      if (!store.locations_.emplace(name, location{file, info}).second) {
        throw std::runtime_error("duplicate tensor across safetensors shards: " + name);
      }
    }
  }
  return store;
}

bool hf_weight_store::contains(const std::string& name) const { return locations_.find(name) != locations_.end(); }

const safe_tensor_info& hf_weight_store::info(const std::string& name) const {
  const auto it = locations_.find(name);
  if (it == locations_.end()) throw std::out_of_range("HF tensor not found: " + name);
  return it->second.info;
}

native::tensor hf_weight_store::load(const std::string& name, native::device target_device) const {
  const auto it = locations_.find(name);
  if (it == locations_.end()) throw std::out_of_range("HF tensor not found: " + name);
  return it->second.file->load(name, target_device);
}

void hf_weight_store::validate_architecture(const hf_config& config) const {
  for (const auto& spec : expected_weights(config)) {
    if (!contains(spec.name)) {
      if (spec.optional) continue;
      throw std::runtime_error("required HF tensor is missing: " + spec.name);
    }
    if (info(spec.name).shape != spec.shape) throw std::runtime_error("HF tensor shape mismatch: " + spec.name);
  }
}

}  // namespace neurx::runtime::model
