#pragma once

#include "hf_model.h"

#include <string>
#include <vector>

namespace neurx::runtime::model {

struct DecoderLayerTrace {
  std::vector<float> q;
  std::vector<float> k;
  std::vector<float> v;
  std::vector<float> q_rope;
  std::vector<float> k_rope;
  std::vector<float> attention_scores;
  std::vector<float> attention;
  std::vector<float> attention_output;
  std::vector<float> hidden;
};

struct DecoderTrace {
  std::vector<float> embedding;
  std::vector<DecoderLayerTrace> layers;
  std::vector<float> final_hidden;
  std::vector<float> logits;
};

struct DecoderLayerKvCache {
  std::vector<float> key;
  std::vector<float> value;
};

struct DecoderKvCache {
  std::size_t length = 0;
  std::vector<DecoderLayerKvCache> layers;
  void clear() {
    length = 0;
    layers.clear();
  }
};

class DecoderCpuModel {
 public:
  static DecoderCpuModel load(const std::string& directory);
  DecoderTrace forward(const std::vector<int32_t>& token_ids) const;
  DecoderTrace prefill(const std::vector<int32_t>& token_ids, DecoderKvCache* cache) const;
  DecoderTrace decode(int32_t token_id, DecoderKvCache* cache) const;
  const HfConfig& config() const { return config_; }

 private:
  struct Linear {
    std::size_t output = 0;
    std::size_t input = 0;
    std::vector<float> weight;
    std::vector<float> bias;
  };
  struct Layer {
    std::vector<float> input_norm;
    Linear q, k, v, o;
    std::vector<float> post_norm;
    Linear gate, up, down;
  };

  HfConfig config_;
  std::vector<float> embedding_;
  std::vector<Layer> layers_;
  std::vector<float> final_norm_;
  std::vector<float> lm_head_;

  DecoderTrace forward_cached(const std::vector<int32_t>& token_ids,
                              DecoderKvCache* cache) const;
};

}  // namespace neurx::runtime::model
