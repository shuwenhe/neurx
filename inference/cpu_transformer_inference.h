#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace neurx::inference::cpu {

struct ModelInfo {
  uint64_t step = 0;
  uint32_t vocabulary = 0;
  uint32_t context_length = 0;
  uint32_t hidden_size = 0;
  uint32_t heads = 0;
  uint32_t ffn_size = 0;
  uint32_t layers = 0;
  bool bpe_tokenizer = false;
};

struct GenerationConfig {
  int max_new_tokens = 64;
  float temperature = 0.0F;
  int top_k = 0;
  float top_p = 1.0F;
  float repetition_penalty = 1.0F;
  uint64_t seed = 1337;
};

class Transformer {
 public:
  Transformer();
  ~Transformer();
  Transformer(Transformer&&) noexcept;
  Transformer& operator=(Transformer&&) noexcept;
  Transformer(const Transformer&) = delete;
  Transformer& operator=(const Transformer&) = delete;

  bool load(const std::string& checkpoint_path,
            const std::string& vocabulary_path,
            const std::string& merges_path,
            std::string* error);
  std::vector<int> encode(const std::string& text) const;
  std::string decode(const std::vector<int>& token_ids) const;
  std::vector<float> forward_last(const std::vector<int>& token_ids) const;
  std::vector<int> generate_ids(const std::vector<int>& prompt_ids,
                                const GenerationConfig& config) const;
  std::string generate(const std::string& prompt,
                       const GenerationConfig& config) const;
  const ModelInfo& info() const;
  int eos_token_id() const;

 private:
  struct Impl;
  Impl* impl_;
};

std::string resolve_checkpoint_path(const std::string& input);

}
