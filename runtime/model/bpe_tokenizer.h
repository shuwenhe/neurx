#pragma once
#include <cstdint>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>
namespace neurx::runtime::model {
class BpeTokenizer {
 public:
  static BpeTokenizer from_tokenizer_json(const std::string& path);
  static BpeTokenizer from_directory(const std::string& directory);
  std::vector<int32_t> encode(const std::string& text, bool allow_special = true) const;
  std::string decode(const std::vector<int32_t>& ids, bool skip_special = false) const;
  std::size_t vocab_size() const { return id_to_token_.size(); }
  int32_t token_id(const std::string& token) const;
 private:
  std::vector<std::string> bpe(const std::string& piece) const;
  std::vector<std::string> byte_symbols(const std::string& bytes) const;
  std::string normalize(const std::string& text) const;
  std::vector<std::string> pretokenize(const std::string& text) const;
  std::unordered_map<std::string, int32_t> token_to_id_;
  std::vector<std::string> id_to_token_;
  std::unordered_map<std::string, int64_t> merge_rank_;
  std::map<std::string, int32_t> special_tokens_;
  std::unordered_map<uint32_t, uint8_t> unicode_to_byte_;
  std::vector<std::string> byte_to_symbol_;
  std::string normalizer_type_;
  std::string split_pattern_;
  bool byte_level_ = false;
  int32_t unknown_id_ = -1;
};
}
