#include "bpe_tokenizer.h"

#include "json.h"

#include <algorithm>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <string>
#include <utility>

#include <unicode/normalizer2.h>
#include <unicode/regex.h>
#include <unicode/stringpiece.h>
#include <unicode/unistr.h>

namespace neurx::runtime::model {
namespace {

std::string encode_utf8(uint32_t codepoint) {
  std::string out;
  if (codepoint <= 0x7f) {
    out.push_back(static_cast<char>(codepoint));
  } else if (codepoint <= 0x7ff) {
    out.push_back(static_cast<char>(0xc0 | (codepoint >> 6)));
    out.push_back(static_cast<char>(0x80 | (codepoint & 0x3f)));
  } else if (codepoint <= 0xffff) {
    out.push_back(static_cast<char>(0xe0 | (codepoint >> 12)));
    out.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3f)));
    out.push_back(static_cast<char>(0x80 | (codepoint & 0x3f)));
  } else {
    out.push_back(static_cast<char>(0xf0 | (codepoint >> 18)));
    out.push_back(static_cast<char>(0x80 | ((codepoint >> 12) & 0x3f)));
    out.push_back(static_cast<char>(0x80 | ((codepoint >> 6) & 0x3f)));
    out.push_back(static_cast<char>(0x80 | (codepoint & 0x3f)));
  }
  return out;
}

uint32_t decode_one_utf8(const std::string& text, std::size_t* offset) {
  const auto fail = [] { throw std::runtime_error("tokenizer vocabulary contains invalid UTF-8"); };
  if (*offset >= text.size()) fail();
  const uint8_t first = static_cast<uint8_t>(text[(*offset)++]);
  if (first < 0x80) return first;
  int continuation_count = 0;
  uint32_t value = 0;
  if ((first & 0xe0) == 0xc0) {
    continuation_count = 1;
    value = first & 0x1f;
  } else if ((first & 0xf0) == 0xe0) {
    continuation_count = 2;
    value = first & 0x0f;
  } else if ((first & 0xf8) == 0xf0) {
    continuation_count = 3;
    value = first & 0x07;
  } else {
    fail();
  }
  for (int i = 0; i < continuation_count; ++i) {
    if (*offset >= text.size()) fail();
    const uint8_t byte = static_cast<uint8_t>(text[(*offset)++]);
    if ((byte & 0xc0) != 0x80) fail();
    value = (value << 6) | (byte & 0x3f);
  }
  return value;
}

std::string pair_key(const std::string& first, const std::string& second) {
  return first + '\x1f' + second;
}

void inspect_pre_tokenizer(const json& node, std::string* split_pattern, bool* byte_level) {
  const std::string type = node.at("type").as_string();
  if (type == "Sequence") {
    for (const auto& child : node.at("pretokenizers").as_array()) {
      inspect_pre_tokenizer(child, split_pattern, byte_level);
    }
    return;
  }
  if (type == "Split") {
    if (node.contains("behavior") && node.at("behavior").as_string() != "Isolated") {
      throw std::runtime_error("only isolated Split pre-tokenizers are supported");
    }
    if (node.contains("invert") && node.at("invert").as_bool()) {
      throw std::runtime_error("inverted Split pre-tokenizers are not supported");
    }
    const json& pattern = node.at("pattern");
    if (!pattern.is_object() || !pattern.contains("Regex")) {
      throw std::runtime_error("only regex Split pre-tokenizers are supported");
    }
    *split_pattern = pattern.at("Regex").as_string();
    return;
  }
  if (type == "ByteLevel") {
    if (node.contains("add_prefix_space") && node.at("add_prefix_space").as_bool()) {
      throw std::runtime_error("ByteLevel add_prefix_space is not supported yet");
    }
    *byte_level = true;
    return;
  }
  throw std::runtime_error("unsupported pre-tokenizer component: " + type);
}

const icu::Normalizer2* normalizer_for(const std::string& type, UErrorCode* status) {
  if (type == "NFC") return icu::Normalizer2::getNFCInstance(*status);
  if (type == "NFD") return icu::Normalizer2::getNFDInstance(*status);
  if (type == "NFKC") return icu::Normalizer2::getNFKCInstance(*status);
  if (type == "NFKD") return icu::Normalizer2::getNFKDInstance(*status);
  return nullptr;
}

}

bpe_tokenizer bpe_tokenizer::from_tokenizer_json(const std::string& path) {
  const json root = json::parse_file(path);
  const json& model = root.at("model");
  if (model.at("type").as_string() != "BPE") {
    throw std::runtime_error("tokenizer model is not BPE");
  }

  bpe_tokenizer tokenizer;
  std::vector<int> byte_values;
  for (int value = 33; value <= 126; ++value) byte_values.push_back(value);
  for (int value = 161; value <= 172; ++value) byte_values.push_back(value);
  for (int value = 174; value <= 255; ++value) byte_values.push_back(value);
  std::vector<int> codepoints = byte_values;
  int extra = 0;
  for (int value = 0; value <= 255; ++value) {
    if (std::find(byte_values.begin(), byte_values.end(), value) == byte_values.end()) {
      byte_values.push_back(value);
      codepoints.push_back(256 + extra++);
    }
  }
  tokenizer.byte_to_symbol_.resize(256);
  for (std::size_t i = 0; i < byte_values.size(); ++i) {
    const std::string symbol = encode_utf8(static_cast<uint32_t>(codepoints[i]));
    tokenizer.byte_to_symbol_[static_cast<std::size_t>(byte_values[i])] = symbol;
    tokenizer.unicode_to_byte_[static_cast<uint32_t>(codepoints[i])] =
        static_cast<uint8_t>(byte_values[i]);
  }

  int32_t max_id = -1;
  for (const auto& [token, id_value] : model.at("vocab").as_object()) {
    const int64_t raw_id = id_value.as_int();
    if (raw_id < 0 || raw_id > std::numeric_limits<int32_t>::max()) {
      throw std::runtime_error("invalid BPE token id");
    }
    const int32_t id = static_cast<int32_t>(raw_id);
    if (!tokenizer.token_to_id_.emplace(token, id).second) {
      throw std::runtime_error("duplicate BPE token");
    }
    max_id = std::max(max_id, id);
  }

  if (root.contains("added_tokens")) {
    for (const auto& item : root.at("added_tokens").as_array()) {
      const std::string content = item.at("content").as_string();
      const int64_t raw_id = item.at("id").as_int();
      if (raw_id < 0 || raw_id > std::numeric_limits<int32_t>::max()) {
        throw std::runtime_error("added token id is invalid");
      }
      const int32_t id = static_cast<int32_t>(raw_id);
      tokenizer.token_to_id_[content] = id;
      tokenizer.special_tokens_[content] = id;
      max_id = std::max(max_id, id);
    }
  }

  tokenizer.id_to_token_.resize(static_cast<std::size_t>(max_id) + 1);
  for (const auto& [token, id] : tokenizer.token_to_id_) {
    std::string& slot = tokenizer.id_to_token_[static_cast<std::size_t>(id)];
    if (!slot.empty() && slot != token) {
      throw std::runtime_error("duplicate BPE token id");
    }
    slot = token;
  }

  int64_t rank = 0;
  for (const auto& merge_value : model.at("merges").as_array()) {
    std::string first;
    std::string second;
    if (merge_value.is_string()) {
      const std::string merge = merge_value.as_string();
      const std::size_t separator = merge.find(' ');
      if (separator == std::string::npos) {
        throw std::runtime_error("BPE merge must contain a separator");
      }
      first = merge.substr(0, separator);
      second = merge.substr(separator + 1);
    } else if (merge_value.is_array() && merge_value.as_array().size() == 2) {
      first = merge_value.as_array()[0].as_string();
      second = merge_value.as_array()[1].as_string();
    } else {
      throw std::runtime_error("BPE merge array must contain two tokens");
    }
    tokenizer.merge_rank_.emplace(pair_key(first, second), rank++);
  }

  if (model.contains("unk_token") && !model.at("unk_token").is_null()) {
    const auto it = tokenizer.token_to_id_.find(model.at("unk_token").as_string());
    if (it != tokenizer.token_to_id_.end()) tokenizer.unknown_id_ = it->second;
  }
  if (root.contains("normalizer") && !root.at("normalizer").is_null()) {
    tokenizer.normalizer_type_ = root.at("normalizer").at("type").as_string();
  }
  if (root.contains("pre_tokenizer") && !root.at("pre_tokenizer").is_null()) {
    inspect_pre_tokenizer(root.at("pre_tokenizer"), &tokenizer.split_pattern_,
                          &tokenizer.byte_level_);
  }
  return tokenizer;
}

bpe_tokenizer bpe_tokenizer::from_directory(const std::string& directory) {
  std::string path = directory;
  if (!path.empty() && path.back() != '/') path.push_back('/');
  path += "tokenizer.json";
  return from_tokenizer_json(path);
}

std::string bpe_tokenizer::normalize(const std::string& text) const {
  if (normalizer_type_.empty()) return text;
  UErrorCode status = U_ZERO_ERROR;
  const icu::Normalizer2* normalizer = normalizer_for(normalizer_type_, &status);
  if (U_FAILURE(status) || normalizer == nullptr) {
    throw std::runtime_error("unsupported tokenizer normalizer: " + normalizer_type_);
  }
  const icu::UnicodeString input = icu::UnicodeString::fromUTF8(text);
  icu::UnicodeString output;
  normalizer->normalize(input, output, status);
  if (U_FAILURE(status)) throw std::runtime_error("ICU normalization failed");
  std::string encoded;
  output.toUTF8String(encoded);
  return encoded;
}

std::vector<std::string> bpe_tokenizer::pretokenize(const std::string& text) const {
  if (split_pattern_.empty()) return {text};
  UErrorCode status = U_ZERO_ERROR;
  const icu::UnicodeString pattern = icu::UnicodeString::fromUTF8(split_pattern_);
  std::unique_ptr<icu::RegexPattern> compiled(icu::RegexPattern::compile(pattern, 0, status));
  if (U_FAILURE(status) || !compiled) {
    throw std::runtime_error("cannot compile tokenizer Split regex");
  }
  const icu::UnicodeString input = icu::UnicodeString::fromUTF8(text);
  std::unique_ptr<icu::RegexMatcher> matcher(compiled->matcher(input, status));
  if (U_FAILURE(status) || !matcher) {
    throw std::runtime_error("cannot create tokenizer Split matcher");
  }
  std::vector<std::string> pieces;
  int32_t cursor = 0;
  while (matcher->find(status)) {
    if (U_FAILURE(status)) throw std::runtime_error("tokenizer Split regex failed");
    if (matcher->start(status) > cursor) {
      std::string gap;
      input.tempSubStringBetween(cursor, matcher->start(status)).toUTF8String(gap);
      pieces.push_back(std::move(gap));
    }
    std::string piece;
    matcher->group(status).toUTF8String(piece);
    pieces.push_back(std::move(piece));
    cursor = matcher->end(status);
  }
  if (U_FAILURE(status)) throw std::runtime_error("tokenizer Split regex failed");
  if (cursor < input.length()) {
    std::string tail;
    input.tempSubString(cursor).toUTF8String(tail);
    pieces.push_back(std::move(tail));
  }
  return pieces;
}

std::vector<std::string> bpe_tokenizer::byte_symbols(const std::string& bytes) const {
  std::vector<std::string> symbols;
  symbols.reserve(bytes.size());
  for (const unsigned char byte : bytes) {
    symbols.push_back(byte_to_symbol_[byte]);
  }
  return symbols;
}

std::vector<std::string> bpe_tokenizer::bpe(const std::string& piece) const {
  std::vector<std::string> tokens = byte_level_ ? byte_symbols(piece) : std::vector<std::string>{piece};
  while (tokens.size() > 1) {
    int64_t best_rank = std::numeric_limits<int64_t>::max();
    std::string best_first;
    std::string best_second;
    for (std::size_t i = 0; i + 1 < tokens.size(); ++i) {
      const auto it = merge_rank_.find(pair_key(tokens[i], tokens[i + 1]));
      if (it != merge_rank_.end() && it->second < best_rank) {
        best_rank = it->second;
        best_first = tokens[i];
        best_second = tokens[i + 1];
      }
    }
    if (best_rank == std::numeric_limits<int64_t>::max()) break;
    std::vector<std::string> merged;
    merged.reserve(tokens.size());
    for (std::size_t i = 0; i < tokens.size();) {
      if (i + 1 < tokens.size() && tokens[i] == best_first && tokens[i + 1] == best_second) {
        merged.push_back(tokens[i] + tokens[i + 1]);
        i += 2;
      } else {
        merged.push_back(tokens[i]);
        ++i;
      }
    }
    tokens = std::move(merged);
  }
  return tokens;
}

std::vector<int32_t> bpe_tokenizer::encode(const std::string& text, bool allow_special) const {
  const std::string normalized = normalize(text);
  std::vector<int32_t> ids;
  auto encode_plain = [&](const std::string& plain) {
    for (const auto& piece : pretokenize(plain)) {
      for (const auto& token : bpe(piece)) {
        const auto it = token_to_id_.find(token);
        if (it != token_to_id_.end()) {
          ids.push_back(it->second);
        } else if (unknown_id_ >= 0) {
          ids.push_back(unknown_id_);
        } else {
          throw std::runtime_error("BPE vocabulary cannot encode byte sequence");
        }
      }
    }
  };

  if (!allow_special || special_tokens_.empty()) {
    encode_plain(normalized);
    return ids;
  }
  std::size_t cursor = 0;
  while (cursor < normalized.size()) {
    std::size_t best_position = std::string::npos;
    std::size_t best_length = 0;
    int32_t best_id = -1;
    for (const auto& [token, id] : special_tokens_) {
      const std::size_t position = normalized.find(token, cursor);
      if (position < best_position ||
          (position == best_position && token.size() > best_length)) {
        best_position = position;
        best_length = token.size();
        best_id = id;
      }
    }
    if (best_position == std::string::npos) {
      encode_plain(normalized.substr(cursor));
      break;
    }
    if (best_position > cursor) encode_plain(normalized.substr(cursor, best_position - cursor));
    ids.push_back(best_id);
    cursor = best_position + best_length;
  }
  return ids;
}

std::string bpe_tokenizer::decode(const std::vector<int32_t>& ids, bool skip_special) const {
  std::string output;
  for (const int32_t id : ids) {
    if (id < 0 || static_cast<std::size_t>(id) >= id_to_token_.size() ||
        id_to_token_[static_cast<std::size_t>(id)].empty()) {
      throw std::runtime_error("BPE token id is outside the vocabulary");
    }
    const std::string& token = id_to_token_[static_cast<std::size_t>(id)];
    const auto special = special_tokens_.find(token);
    if (special != special_tokens_.end()) {
      if (!skip_special) output += token;
      continue;
    }
    std::size_t offset = 0;
    while (offset < token.size()) {
      const uint32_t codepoint = decode_one_utf8(token, &offset);
      const auto byte = unicode_to_byte_.find(codepoint);
      if (byte == unicode_to_byte_.end()) {
        throw std::runtime_error("BPE token is not byte-level encoded");
      }
      output.push_back(static_cast<char>(byte->second));
    }
  }
  return output;
}

int32_t bpe_tokenizer::token_id(const std::string& token) const {
  const auto it = token_to_id_.find(token);
  return it == token_to_id_.end() ? -1 : it->second;
}

}
