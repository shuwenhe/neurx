#pragma once
#include "hf_model.h"
#include <string>
#include <vector>
namespace neurx::runtime::model {
struct decoder_layer_trace {
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
struct decoder_trace {
  std::vector<float> embedding;
  std::vector<decoder_layer_trace> layers;
  std::vector<float> final_hidden;
  std::vector<float> logits;
};
struct decoder_layer_kv_cache {
  std::vector<float> key;
  std::vector<float> value;
};
struct decoder_kv_cache {
  std::size_t length = 0;
  std::vector<decoder_layer_kv_cache> layers;
  void clear() {
    length = 0;
    layers.clear();
  }
};
class decoder_cpu_model {
 public:
  static decoder_cpu_model load(const std::string& directory);
  decoder_trace forward(const std::vector<int32_t>& token_ids) const;
  decoder_trace prefill(const std::vector<int32_t>& token_ids, decoder_kv_cache* cache) const;
  decoder_trace decode(int32_t token_id, decoder_kv_cache* cache) const;
  const hf_config& config() const { return config_; }
 private:
  struct linear {
    std::size_t output = 0;
    std::size_t input = 0;
    std::vector<float> weight;
    std::vector<float> bias;
  };
  struct layer {
    std::vector<float> input_norm;
    linear q, k, v, o;
    std::vector<float> post_norm;
    linear gate, up, down;
  };
  hf_config config_;
  std::vector<float> embedding_;
  std::vector<layer> layers_;
  std::vector<float> final_norm_;
  std::vector<float> lm_head_;
  decoder_trace forward_cached(const std::vector<int32_t>& token_ids,
                              decoder_kv_cache* cache) const;
};
}
