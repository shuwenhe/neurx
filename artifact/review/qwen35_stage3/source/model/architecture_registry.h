#pragma once
#include "hybrid_config.h"
#include "mapped_weight_store.h"
#include <map>

namespace neurx::runtime::model {
enum class WeightRole { executed_text, excluded_vision, excluded_mtp };
struct WeightManifest {
  uint64_t text=0, vision=0, mtp=0;
  std::map<std::string,WeightRole> roles;
};
class ModelAdapter {
 public:
  const HybridDecoderConfig& config() const { return config_; }
  // Metadata support is deliberately distinct from executable decoder support.
  bool runtime_supported() const { return false; }
  WeightManifest validate(const MappedWeightStore& store) const;
  // Configuration+headers only. NOT a hash/integrity check of weight payloads.
  std::string metadata_identity(const MappedWeightStore& store) const;
 private:
  HybridDecoderConfig config_;
  std::string config_json_;
  friend class ArchitectureRegistry;
};
class ArchitectureRegistry {
 public:
  // New metadata adapter only; does not replace/modify legacy decoder factories.
  static ModelAdapter resolve(const std::string& directory);
};
}
