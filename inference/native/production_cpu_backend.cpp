#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <nlohmann/json.hpp>
#include <omp.h>
#include <poll.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

#include <unicode/normalizer2.h>
#include <unicode/regex.h>
#include <unicode/unistr.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <csignal>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace {

using Json = nlohmann::json;

std::string read_text(const std::string& path) {
  std::ifstream input(path, std::ios::binary);
  if (!input) throw std::runtime_error("cannot open " + path);
  return std::string(std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>());
}

std::string env_string(const char* name, const char* fallback) {
  const char* value = std::getenv(name);
  return value != nullptr && *value != '\0' ? value : fallback;
}

int env_int(const char* name, int fallback) {
  const std::string text = env_string(name, "");
  if (text.empty()) return fallback;
  char* end = nullptr;
  const long value = std::strtol(text.c_str(), &end, 10);
  if (end == text.c_str() || *end != '\0' || value <= 0 ||
      value > std::numeric_limits<int>::max()) {
    return fallback;
  }
  return static_cast<int>(value);
}

uint64_t little_u64(const unsigned char* data) {
  uint64_t value = 0;
  for (int index = 7; index >= 0; --index) value = (value << 8U) | data[index];
  return value;
}

float half_to_float(uint16_t value) {
  const uint32_t sign = static_cast<uint32_t>(value & 0x8000U) << 16U;
  uint32_t exponent = (value >> 10U) & 0x1fU;
  uint32_t mantissa = value & 0x3ffU;
  uint32_t bits = 0;
  if (exponent == 0) {
    if (mantissa == 0) {
      bits = sign;
    } else {
      exponent = 127U - 15U + 1U;
      while ((mantissa & 0x400U) == 0) {
        mantissa <<= 1U;
        --exponent;
      }
      mantissa &= 0x3ffU;
      bits = sign | (exponent << 23U) | (mantissa << 13U);
    }
  } else if (exponent == 31U) {
    bits = sign | 0x7f800000U | (mantissa << 13U);
  } else {
    bits = sign | ((exponent + 127U - 15U) << 23U) | (mantissa << 13U);
  }
  float output = 0.0F;
  std::memcpy(&output, &bits, sizeof(output));
  return output;
}

struct TensorRecord {
  std::string dtype;
  std::vector<std::size_t> shape;
  std::size_t begin = 0;
  std::size_t end = 0;
};

class SafeTensorMap {
 public:
  explicit SafeTensorMap(const std::string& path) {
    fd_ = ::open(path.c_str(), O_RDONLY | O_CLOEXEC);
    if (fd_ < 0) throw std::runtime_error("cannot open SafeTensors file: " + path);
    struct stat info {};
    if (::fstat(fd_, &info) != 0 || info.st_size < 8) {
      throw std::runtime_error("invalid SafeTensors file: " + path);
    }
    size_ = static_cast<std::size_t>(info.st_size);
    mapping_ = static_cast<unsigned char*>(
        ::mmap(nullptr, size_, PROT_READ, MAP_PRIVATE, fd_, 0));
    if (mapping_ == MAP_FAILED) {
      mapping_ = nullptr;
      throw std::runtime_error("cannot mmap SafeTensors file: " + path);
    }
    const uint64_t header_size = little_u64(mapping_);
    data_start_ = 8U + static_cast<std::size_t>(header_size);
    if (header_size > size_ - 8U || data_start_ > size_) {
      throw std::runtime_error("invalid SafeTensors header length");
    }
    const Json header = Json::parse(
        reinterpret_cast<const char*>(mapping_ + 8U),
        reinterpret_cast<const char*>(mapping_ + data_start_));
    for (auto iterator = header.begin(); iterator != header.end(); ++iterator) {
      if (iterator.key() == "__metadata__") continue;
      TensorRecord record;
      record.dtype = iterator.value().at("dtype").get<std::string>();
      for (const auto& dimension : iterator.value().at("shape")) {
        record.shape.push_back(dimension.get<std::size_t>());
      }
      record.begin = iterator.value().at("data_offsets")[0].get<std::size_t>();
      record.end = iterator.value().at("data_offsets")[1].get<std::size_t>();
      if (record.begin > record.end || record.end > size_ - data_start_) {
        throw std::runtime_error("invalid tensor offset: " + iterator.key());
      }
      records_.emplace(iterator.key(), std::move(record));
    }
  }

  ~SafeTensorMap() {
    if (mapping_ != nullptr) ::munmap(mapping_, size_);
    if (fd_ >= 0) ::close(fd_);
  }

  SafeTensorMap(const SafeTensorMap&) = delete;
  SafeTensorMap& operator=(const SafeTensorMap&) = delete;

  bool contains(const std::string& name) const { return records_.count(name) != 0; }

  const TensorRecord& record(const std::string& name) const {
    const auto found = records_.find(name);
    if (found == records_.end()) throw std::runtime_error("missing tensor: " + name);
    return found->second;
  }

  const unsigned char* bytes(const TensorRecord& record) const {
    return mapping_ + data_start_ + record.begin;
  }

 private:
  int fd_ = -1;
  std::size_t size_ = 0;
  std::size_t data_start_ = 0;
  unsigned char* mapping_ = nullptr;
  std::unordered_map<std::string, TensorRecord> records_;
};

class Weight {
 public:
  Weight() = default;

  Weight(const SafeTensorMap& tensors, const std::string& name) {
    const TensorRecord& record = tensors.record(name);
    shape_ = record.shape;
    std::size_t count = 1;
    for (std::size_t dimension : shape_) count *= dimension;
    const unsigned char* source = tensors.bytes(record);
    if (record.dtype == "F32") {
      if (record.end - record.begin != count * sizeof(float)) {
        throw std::runtime_error("F32 tensor size mismatch: " + name);
      }
      mapped_ = reinterpret_cast<const float*>(source);
    } else {
      owned_.resize(count);
      if (record.dtype == "F16") {
        if (record.end - record.begin != count * sizeof(uint16_t)) {
          throw std::runtime_error("F16 tensor size mismatch: " + name);
        }
        const auto* values = reinterpret_cast<const uint16_t*>(source);
        #pragma omp parallel for schedule(static)
        for (std::int64_t index = 0; index < static_cast<std::int64_t>(count); ++index) {
          owned_[static_cast<std::size_t>(index)] = half_to_float(values[index]);
        }
      } else if (record.dtype == "BF16") {
        if (record.end - record.begin != count * sizeof(uint16_t)) {
          throw std::runtime_error("BF16 tensor size mismatch: " + name);
        }
        const auto* values = reinterpret_cast<const uint16_t*>(source);
        #pragma omp parallel for schedule(static)
        for (std::int64_t index = 0; index < static_cast<std::int64_t>(count); ++index) {
          uint32_t bits = static_cast<uint32_t>(values[index]) << 16U;
          std::memcpy(&owned_[static_cast<std::size_t>(index)], &bits, sizeof(bits));
        }
      } else {
        throw std::runtime_error("unsupported tensor dtype " + record.dtype + ": " + name);
      }
    }
  }

  const float* data() const { return owned_.empty() ? mapped_ : owned_.data(); }
  const std::vector<std::size_t>& shape() const { return shape_; }
  bool defined() const { return mapped_ != nullptr || !owned_.empty(); }

 private:
  const float* mapped_ = nullptr;
  std::vector<float> owned_;
  std::vector<std::size_t> shape_;
};

std::string utf8(uint32_t codepoint) {
  std::string output;
  if (codepoint <= 0x7fU) {
    output.push_back(static_cast<char>(codepoint));
  } else if (codepoint <= 0x7ffU) {
    output.push_back(static_cast<char>(0xc0U | (codepoint >> 6U)));
    output.push_back(static_cast<char>(0x80U | (codepoint & 0x3fU)));
  } else if (codepoint <= 0xffffU) {
    output.push_back(static_cast<char>(0xe0U | (codepoint >> 12U)));
    output.push_back(static_cast<char>(0x80U | ((codepoint >> 6U) & 0x3fU)));
    output.push_back(static_cast<char>(0x80U | (codepoint & 0x3fU)));
  } else {
    output.push_back(static_cast<char>(0xf0U | (codepoint >> 18U)));
    output.push_back(static_cast<char>(0x80U | ((codepoint >> 12U) & 0x3fU)));
    output.push_back(static_cast<char>(0x80U | ((codepoint >> 6U) & 0x3fU)));
    output.push_back(static_cast<char>(0x80U | (codepoint & 0x3fU)));
  }
  return output;
}

bool next_codepoint(const std::string& value, std::size_t* offset, uint32_t* codepoint) {
  if (*offset >= value.size()) return false;
  const unsigned char first = static_cast<unsigned char>(value[*offset]);
  std::size_t count = 1;
  uint32_t result = first;
  if ((first & 0xe0U) == 0xc0U) {
    count = 2;
    result = first & 0x1fU;
  } else if ((first & 0xf0U) == 0xe0U) {
    count = 3;
    result = first & 0x0fU;
  } else if ((first & 0xf8U) == 0xf0U) {
    count = 4;
    result = first & 0x07U;
  }
  if (*offset + count > value.size()) return false;
  for (std::size_t index = 1; index < count; ++index) {
    const unsigned char next = static_cast<unsigned char>(value[*offset + index]);
    if ((next & 0xc0U) != 0x80U) return false;
    result = (result << 6U) | (next & 0x3fU);
  }
  *offset += count;
  *codepoint = result;
  return true;
}

class QwenTokenizer {
 public:
  explicit QwenTokenizer(const std::string& directory) {
    const Json root = Json::parse(read_text(directory + "/tokenizer.json"));
    const auto& vocab = root.at("model").at("vocab");
    std::size_t largest = 0;
    for (auto iterator = vocab.begin(); iterator != vocab.end(); ++iterator) {
      largest = std::max(largest, static_cast<std::size_t>(iterator.value().get<int>()));
    }
    for (const auto& token : root.at("added_tokens")) {
      largest = std::max(largest, static_cast<std::size_t>(token.at("id").get<int>()));
    }
    id_to_token_.resize(largest + 1U);
    for (auto iterator = vocab.begin(); iterator != vocab.end(); ++iterator) {
      const int id = iterator.value().get<int>();
      token_to_id_[iterator.key()] = id;
      id_to_token_[static_cast<std::size_t>(id)] = iterator.key();
    }
    for (const auto& token : root.at("added_tokens")) {
      const int id = token.at("id").get<int>();
      const std::string content = token.at("content").get<std::string>();
      token_to_id_[content] = id;
      id_to_token_[static_cast<std::size_t>(id)] = content;
      if (token.value("special", false)) {
        special_ids_.insert(id);
        special_tokens_.push_back(content);
      }
    }
    const auto& merges = root.at("model").at("merges");
    int rank = 0;
    for (const auto& merge : merges) {
      std::string left;
      std::string right;
      if (merge.is_array()) {
        left = merge.at(0).get<std::string>();
        right = merge.at(1).get<std::string>();
      } else {
        const std::string text = merge.get<std::string>();
        const std::size_t separator = text.find(' ');
        if (separator == std::string::npos) continue;
        left = text.substr(0, separator);
        right = text.substr(separator + 1U);
      }
      merge_rank_[pair_key(left, right)] = rank++;
    }
    build_byte_table();
    UErrorCode status = U_ZERO_ERROR;
    normalizer_ = icu::Normalizer2::getNFCInstance(status);
    if (U_FAILURE(status)) throw std::runtime_error("cannot initialize ICU NFC normalizer");
    const std::string pattern = root.at("pre_tokenizer").at("pretokenizers").at(0)
                                    .at("pattern").at("Regex").get<std::string>();
    regex_.reset(icu::RegexPattern::compile(icu::UnicodeString::fromUTF8(pattern), 0, status));
    if (U_FAILURE(status) || !regex_) throw std::runtime_error("cannot compile tokenizer regex");
  }

  std::vector<int32_t> encode(const std::string& text) {
    std::vector<int32_t> ids;
    std::size_t offset = 0;
    while (offset < text.size()) {
      const std::string* matched = nullptr;
      for (const std::string& token : special_tokens_) {
        if (text.compare(offset, token.size(), token) == 0 &&
            (matched == nullptr || token.size() > matched->size())) {
          matched = &token;
        }
      }
      if (matched != nullptr) {
        ids.push_back(token_to_id_.at(*matched));
        offset += matched->size();
        continue;
      }
      std::size_t next = text.size();
      for (const std::string& token : special_tokens_) {
        const std::size_t candidate = text.find(token, offset);
        if (candidate != std::string::npos) next = std::min(next, candidate);
      }
      encode_ordinary(text.substr(offset, next - offset), &ids);
      offset = next;
    }
    return ids;
  }

  std::string decode(const std::vector<int32_t>& ids, bool skip_special = true) const {
    std::string symbols;
    for (int32_t id : ids) {
      if (id < 0 || static_cast<std::size_t>(id) >= id_to_token_.size()) continue;
      if (skip_special && special_ids_.count(id) != 0) continue;
      symbols += id_to_token_[static_cast<std::size_t>(id)];
    }
    std::string output;
    std::size_t offset = 0;
    while (offset < symbols.size()) {
      const std::size_t start = offset;
      uint32_t codepoint = 0;
      if (!next_codepoint(symbols, &offset, &codepoint)) {
        output.push_back(symbols[start]);
        offset = start + 1U;
        continue;
      }
      const auto found = unicode_to_byte_.find(codepoint);
      if (found != unicode_to_byte_.end()) {
        output.push_back(static_cast<char>(found->second));
      } else {
        output.append(symbols, start, offset - start);
      }
    }
    return output;
  }

 private:
  static std::string pair_key(const std::string& left, const std::string& right) {
    return left + '\0' + right;
  }

  void build_byte_table() {
    std::vector<int> bytes;
    for (int value = 33; value <= 126; ++value) bytes.push_back(value);
    for (int value = 161; value <= 172; ++value) bytes.push_back(value);
    for (int value = 174; value <= 255; ++value) bytes.push_back(value);
    std::vector<int> codepoints = bytes;
    int extra = 0;
    for (int value = 0; value <= 255; ++value) {
      if (std::find(bytes.begin(), bytes.end(), value) == bytes.end()) {
        bytes.push_back(value);
        codepoints.push_back(256 + extra++);
      }
    }
    byte_to_symbol_.resize(256);
    for (std::size_t index = 0; index < bytes.size(); ++index) {
      byte_to_symbol_[static_cast<std::size_t>(bytes[index])] =
          utf8(static_cast<uint32_t>(codepoints[index]));
      unicode_to_byte_[static_cast<uint32_t>(codepoints[index])] =
          static_cast<unsigned char>(bytes[index]);
    }
  }

  std::vector<std::string> bpe(const std::string& piece) {
    const auto cached = bpe_cache_.find(piece);
    if (cached != bpe_cache_.end()) return cached->second;
    std::vector<std::string> symbols;
    symbols.reserve(piece.size());
    for (unsigned char value : piece) symbols.push_back(byte_to_symbol_[value]);
    while (symbols.size() > 1U) {
      int best_rank = std::numeric_limits<int>::max();
      std::string best_left;
      std::string best_right;
      for (std::size_t index = 0; index + 1U < symbols.size(); ++index) {
        const auto found = merge_rank_.find(pair_key(symbols[index], symbols[index + 1U]));
        if (found != merge_rank_.end() && found->second < best_rank) {
          best_rank = found->second;
          best_left = symbols[index];
          best_right = symbols[index + 1U];
        }
      }
      if (best_rank == std::numeric_limits<int>::max()) break;
      std::vector<std::string> merged;
      merged.reserve(symbols.size());
      for (std::size_t index = 0; index < symbols.size();) {
        if (index + 1U < symbols.size() && symbols[index] == best_left &&
            symbols[index + 1U] == best_right) {
          merged.push_back(best_left + best_right);
          index += 2U;
        } else {
          merged.push_back(symbols[index++]);
        }
      }
      symbols.swap(merged);
    }
    if (bpe_cache_.size() < 65536U) bpe_cache_.emplace(piece, symbols);
    return symbols;
  }

  void encode_ordinary(const std::string& input, std::vector<int32_t>* ids) {
    if (input.empty()) return;
    UErrorCode status = U_ZERO_ERROR;
    const icu::UnicodeString source = icu::UnicodeString::fromUTF8(input);
    icu::UnicodeString normalized;
    normalizer_->normalize(source, normalized, status);
    if (U_FAILURE(status)) throw std::runtime_error("tokenizer NFC normalization failed");
    std::unique_ptr<icu::RegexMatcher> matcher(regex_->matcher(normalized, status));
    if (U_FAILURE(status) || !matcher) throw std::runtime_error("tokenizer regex matcher failed");
    while (matcher->find(status)) {
      std::string piece;
      matcher->group(status).toUTF8String(piece);
      for (const std::string& token : bpe(piece)) {
        const auto found = token_to_id_.find(token);
        if (found == token_to_id_.end()) {
          throw std::runtime_error("tokenizer vocabulary miss");
        }
        ids->push_back(found->second);
      }
    }
    if (U_FAILURE(status)) throw std::runtime_error("tokenizer regex execution failed");
  }

  std::unordered_map<std::string, int32_t> token_to_id_;
  std::vector<std::string> id_to_token_;
  std::unordered_map<std::string, int> merge_rank_;
  std::unordered_map<std::string, std::vector<std::string>> bpe_cache_;
  std::unordered_set<int32_t> special_ids_;
  std::vector<std::string> special_tokens_;
  std::vector<std::string> byte_to_symbol_;
  std::unordered_map<uint32_t, unsigned char> unicode_to_byte_;
  const icu::Normalizer2* normalizer_ = nullptr;
  std::unique_ptr<icu::RegexPattern> regex_;
};

struct ModelConfig {
  int vocab = 0;
  int hidden = 0;
  int intermediate = 0;
  int layers = 0;
  int query_heads = 0;
  int kv_heads = 0;
  int head_dim = 0;
  int max_positions = 0;
  float epsilon = 1.0e-6F;
  float rope_theta = 10000.0F;
  bool tied_embeddings = false;
  std::vector<int32_t> eos_ids;
};

ModelConfig load_config(const std::string& directory) {
  const Json root = Json::parse(read_text(directory + "/config.json"));
  ModelConfig config;
  config.vocab = root.at("vocab_size").get<int>();
  config.hidden = root.at("hidden_size").get<int>();
  config.intermediate = root.at("intermediate_size").get<int>();
  config.layers = root.at("num_hidden_layers").get<int>();
  config.query_heads = root.at("num_attention_heads").get<int>();
  config.kv_heads = root.at("num_key_value_heads").get<int>();
  config.head_dim = root.contains("head_dim") ? root.at("head_dim").get<int>()
                                                : config.hidden / config.query_heads;
  config.max_positions = root.at("max_position_embeddings").get<int>();
  config.epsilon = root.value("rms_norm_eps", 1.0e-6F);
  if (root.contains("rope_parameters")) {
    config.rope_theta = root.at("rope_parameters").value("rope_theta", 10000.0F);
  } else {
    config.rope_theta = root.value("rope_theta", 10000.0F);
  }
  config.tied_embeddings = root.value("tie_word_embeddings", false);
  Json generation;
  const std::string generation_path = directory + "/generation_config.json";
  std::ifstream generation_file(generation_path);
  if (generation_file) generation_file >> generation;
  const Json* eos = nullptr;
  if (!generation.is_null() && generation.contains("eos_token_id")) {
    eos = &generation.at("eos_token_id");
  } else if (root.contains("eos_token_id")) {
    eos = &root.at("eos_token_id");
  }
  if (eos != nullptr && eos->is_array()) {
    for (const auto& value : *eos) config.eos_ids.push_back(value.get<int32_t>());
  } else if (eos != nullptr && eos->is_number_integer()) {
    config.eos_ids.push_back(eos->get<int32_t>());
  }
  if (config.vocab <= 0 || config.hidden <= 0 || config.intermediate <= 0 ||
      config.layers <= 0 || config.query_heads <= 0 || config.kv_heads <= 0 ||
      config.head_dim <= 0 || config.query_heads % config.kv_heads != 0) {
    throw std::runtime_error("unsupported model dimensions");
  }
  return config;
}

struct Linear {
  int input = 0;
  int output = 0;
  Weight weight;
  Weight bias;
};

struct Layer {
  Weight input_norm;
  Linear query;
  Linear key;
  Linear value;
  Linear output;
  Weight post_norm;
  Linear gate;
  Linear up;
  Linear down;
};

struct KvCache {
  std::size_t length = 0;
  std::vector<std::vector<float>> keys;
  std::vector<std::vector<float>> values;

  void clear() {
    length = 0;
    for (auto& value : keys) value.clear();
    for (auto& value : values) value.clear();
  }

  void truncate(std::size_t tokens, std::size_t width) {
    if (tokens > length) throw std::runtime_error("cannot extend cache by truncation");
    length = tokens;
    for (auto& value : keys) value.resize(tokens * width);
    for (auto& value : values) value.resize(tokens * width);
  }
};

class ProductionCpuModel {
 public:
  explicit ProductionCpuModel(const std::string& directory)
      : config_(load_config(directory)), tensors_(directory + "/model.safetensors"),
        embedding_(tensors_, "model.embed_tokens.weight") {
    const int query_width = config_.query_heads * config_.head_dim;
    const int kv_width = config_.kv_heads * config_.head_dim;
    for (int index = 0; index < config_.layers; ++index) {
      const std::string prefix = "model.layers." + std::to_string(index) + ".";
      Layer layer;
      layer.input_norm = Weight(tensors_, prefix + "input_layernorm.weight");
      layer.post_norm = Weight(tensors_, prefix + "post_attention_layernorm.weight");
      layer.query = linear(prefix + "self_attn.q_proj", query_width, config_.hidden);
      layer.key = linear(prefix + "self_attn.k_proj", kv_width, config_.hidden);
      layer.value = linear(prefix + "self_attn.v_proj", kv_width, config_.hidden);
      layer.output = linear(prefix + "self_attn.o_proj", config_.hidden, query_width);
      layer.gate = linear(prefix + "mlp.gate_proj", config_.intermediate, config_.hidden);
      layer.up = linear(prefix + "mlp.up_proj", config_.intermediate, config_.hidden);
      layer.down = linear(prefix + "mlp.down_proj", config_.hidden, config_.intermediate);
      layers_.push_back(std::move(layer));
    }
    final_norm_ = Weight(tensors_, "model.norm.weight");
    lm_head_ = config_.tied_embeddings ? Weight() : Weight(tensors_, "lm_head.weight");
  }

  const ModelConfig& config() const { return config_; }

  std::vector<float> extend(const std::vector<int32_t>& ids, KvCache* cache) const {
    if (cache == nullptr || ids.empty()) throw std::runtime_error("empty model extension");
    if (cache->length + ids.size() > static_cast<std::size_t>(config_.max_positions)) {
      throw std::runtime_error("context exceeds max_position_embeddings");
    }
    if (cache->keys.empty()) {
      cache->keys.resize(layers_.size());
      cache->values.resize(layers_.size());
    }
    const int rows = static_cast<int>(ids.size());
    const int hidden = config_.hidden;
    const int query_width = config_.query_heads * config_.head_dim;
    const int kv_width = config_.kv_heads * config_.head_dim;
    const std::size_t past = cache->length;
    for (int32_t token : ids) {
      if (token < 0 || token >= config_.vocab) {
        throw std::runtime_error("token id is outside the model vocabulary");
      }
    }
    std::vector<float> state(static_cast<std::size_t>(rows) * hidden);
    #pragma omp parallel for schedule(static)
    for (std::int64_t task = 0; task < static_cast<std::int64_t>(state.size()); ++task) {
      const int row = static_cast<int>(task / hidden);
      const int column = static_cast<int>(task % hidden);
      const int32_t token = ids[static_cast<std::size_t>(row)];
      state[static_cast<std::size_t>(task)] =
          embedding_.data()[static_cast<std::size_t>(token) * hidden + column];
    }
    std::vector<float> normalized(static_cast<std::size_t>(rows) * hidden);
    std::vector<float> query(static_cast<std::size_t>(rows) * query_width);
    std::vector<float> key(static_cast<std::size_t>(rows) * kv_width);
    std::vector<float> value(static_cast<std::size_t>(rows) * kv_width);
    std::vector<float> attention(static_cast<std::size_t>(rows) * query_width);
    std::vector<float> projection(static_cast<std::size_t>(rows) * hidden);
    std::vector<float> gate(static_cast<std::size_t>(rows) * config_.intermediate);
    std::vector<float> up(static_cast<std::size_t>(rows) * config_.intermediate);
    for (std::size_t index = 0; index < layers_.size(); ++index) {
      const Layer& layer = layers_[index];
      rms_norm(state, layer.input_norm, rows, hidden, &normalized);
      matmul(normalized, rows, layer.query, &query);
      matmul(normalized, rows, layer.key, &key);
      matmul(normalized, rows, layer.value, &value);
      rope(&query, rows, config_.query_heads, past);
      rope(&key, rows, config_.kv_heads, past);
      auto& cached_key = cache->keys[index];
      auto& cached_value = cache->values[index];
      cached_key.resize((past + ids.size()) * static_cast<std::size_t>(kv_width));
      cached_value.resize((past + ids.size()) * static_cast<std::size_t>(kv_width));
      std::copy(key.begin(), key.end(), cached_key.begin() + past * kv_width);
      std::copy(value.begin(), value.end(), cached_value.begin() + past * kv_width);
      attend(query, cached_key, cached_value, rows, past, &attention);
      matmul(attention, rows, layer.output, &projection);
      add(&state, projection);
      rms_norm(state, layer.post_norm, rows, hidden, &normalized);
      matmul(normalized, rows, layer.gate, &gate);
      matmul(normalized, rows, layer.up, &up);
      swiglu(&gate, up);
      matmul(gate, rows, layer.down, &projection);
      add(&state, projection);
    }
    rms_norm(state, final_norm_, rows, hidden, &normalized);
    const float* last = normalized.data() + static_cast<std::size_t>(rows - 1) * hidden;
    const float* output_weight = config_.tied_embeddings ? embedding_.data() : lm_head_.data();
    std::vector<float> logits(static_cast<std::size_t>(config_.vocab));
    #pragma omp parallel for schedule(static)
    for (int token = 0; token < config_.vocab; ++token) {
      const float* weight = output_weight + static_cast<std::size_t>(token) * hidden;
      float sum = 0.0F;
      #pragma omp simd reduction(+:sum)
      for (int column = 0; column < hidden; ++column) sum += last[column] * weight[column];
      logits[static_cast<std::size_t>(token)] = sum;
    }
    cache->length += ids.size();
    return logits;
  }

 private:
  Linear linear(const std::string& name, int output, int input) const {
    Linear result;
    result.input = input;
    result.output = output;
    result.weight = Weight(tensors_, name + ".weight");
    if (tensors_.contains(name + ".bias")) result.bias = Weight(tensors_, name + ".bias");
    const auto& shape = result.weight.shape();
    if (shape.size() != 2U || shape[0] != static_cast<std::size_t>(output) ||
        shape[1] != static_cast<std::size_t>(input)) {
      throw std::runtime_error("linear weight shape mismatch: " + name);
    }
    return result;
  }

  static void matmul(const std::vector<float>& input, int rows, const Linear& linear,
                     std::vector<float>* output) {
    output->resize(static_cast<std::size_t>(rows) * linear.output);
    const float* weight = linear.weight.data();
    const float* bias = linear.bias.defined() ? linear.bias.data() : nullptr;
    const std::int64_t tasks = static_cast<std::int64_t>(rows) * linear.output;
    #pragma omp parallel for schedule(static)
    for (std::int64_t task = 0; task < tasks; ++task) {
      const int row = static_cast<int>(task / linear.output);
      const int column = static_cast<int>(task % linear.output);
      const float* source = input.data() + static_cast<std::size_t>(row) * linear.input;
      const float* weights = weight + static_cast<std::size_t>(column) * linear.input;
      float sum = bias == nullptr ? 0.0F : bias[column];
      #pragma omp simd reduction(+:sum)
      for (int inner = 0; inner < linear.input; ++inner) sum += source[inner] * weights[inner];
      (*output)[static_cast<std::size_t>(task)] = sum;
    }
  }

  void rms_norm(const std::vector<float>& input, const Weight& weight, int rows, int width,
                std::vector<float>* output) const {
    output->resize(input.size());
    #pragma omp parallel for schedule(static)
    for (int row = 0; row < rows; ++row) {
      const float* source = input.data() + static_cast<std::size_t>(row) * width;
      float square_sum = 0.0F;
      #pragma omp simd reduction(+:square_sum)
      for (int column = 0; column < width; ++column) {
        square_sum += source[column] * source[column];
      }
      const float inverse = 1.0F / std::sqrt(square_sum / width + config_.epsilon);
      float* target = output->data() + static_cast<std::size_t>(row) * width;
      #pragma omp simd
      for (int column = 0; column < width; ++column) {
        target[column] = source[column] * inverse * weight.data()[column];
      }
    }
  }

  void rope(std::vector<float>* values, int rows, int heads, std::size_t past) const {
    const int half = config_.head_dim / 2;
    const std::int64_t tasks = static_cast<std::int64_t>(rows) * heads * half;
    #pragma omp parallel for schedule(static)
    for (std::int64_t task = 0; task < tasks; ++task) {
      const int frequency = static_cast<int>(task % half);
      const int head = static_cast<int>((task / half) % heads);
      const int row = static_cast<int>(task / (static_cast<std::int64_t>(half) * heads));
      const float angle = static_cast<float>(past + static_cast<std::size_t>(row)) /
          std::pow(config_.rope_theta,
                   static_cast<float>(frequency * 2) / config_.head_dim);
      float* current = values->data() +
          (static_cast<std::size_t>(row) * heads + head) * config_.head_dim;
      const float first = current[frequency];
      const float second = current[frequency + half];
      const float cosine = std::cos(angle);
      const float sine = std::sin(angle);
      current[frequency] = first * cosine - second * sine;
      current[frequency + half] = second * cosine + first * sine;
    }
  }

  void attend(const std::vector<float>& query, const std::vector<float>& keys,
              const std::vector<float>& values, int rows, std::size_t past,
              std::vector<float>* output) const {
    const int head = config_.head_dim;
    const int query_heads = config_.query_heads;
    const int kv_heads = config_.kv_heads;
    const float scale = 1.0F / std::sqrt(static_cast<float>(head));
    output->assign(static_cast<std::size_t>(rows) * query_heads * head, 0.0F);
    #pragma omp parallel
    {
      std::vector<float> scores(past + static_cast<std::size_t>(rows));
      #pragma omp for schedule(static)
      for (int task = 0; task < rows * query_heads; ++task) {
        const int row = task / query_heads;
        const int query_head = task % query_heads;
        const int kv_head = query_head / (query_heads / kv_heads);
        const std::size_t visible = past + static_cast<std::size_t>(row) + 1U;
        const float* q = query.data() +
            (static_cast<std::size_t>(row) * query_heads + query_head) * head;
        float maximum = -std::numeric_limits<float>::infinity();
        for (std::size_t source = 0; source < visible; ++source) {
          const float* k = keys.data() + (source * kv_heads + kv_head) * head;
          float score = 0.0F;
          #pragma omp simd reduction(+:score)
          for (int feature = 0; feature < head; ++feature) score += q[feature] * k[feature];
          scores[source] = score * scale;
          maximum = std::max(maximum, scores[source]);
        }
        float denominator = 0.0F;
        for (std::size_t source = 0; source < visible; ++source) {
          scores[source] = std::exp(scores[source] - maximum);
          denominator += scores[source];
        }
        float* target = output->data() +
            (static_cast<std::size_t>(row) * query_heads + query_head) * head;
        for (std::size_t source = 0; source < visible; ++source) {
          const float probability = scores[source] / denominator;
          const float* value = values.data() + (source * kv_heads + kv_head) * head;
          #pragma omp simd
          for (int feature = 0; feature < head; ++feature) {
            target[feature] += probability * value[feature];
          }
        }
      }
    }
  }

  static void add(std::vector<float>* target, const std::vector<float>& value) {
    #pragma omp parallel for simd schedule(static)
    for (std::int64_t index = 0; index < static_cast<std::int64_t>(target->size()); ++index) {
      (*target)[static_cast<std::size_t>(index)] += value[static_cast<std::size_t>(index)];
    }
  }

  static void swiglu(std::vector<float>* gate, const std::vector<float>& up) {
    #pragma omp parallel for simd schedule(static)
    for (std::int64_t index = 0; index < static_cast<std::int64_t>(gate->size()); ++index) {
      float& value = (*gate)[static_cast<std::size_t>(index)];
      value = value / (1.0F + std::exp(-value)) * up[static_cast<std::size_t>(index)];
    }
  }

  ModelConfig config_;
  SafeTensorMap tensors_;
  Weight embedding_;
  std::vector<Layer> layers_;
  Weight final_norm_;
  Weight lm_head_;
};

bool is_eos(const ModelConfig& config, int32_t token) {
  return std::find(config.eos_ids.begin(), config.eos_ids.end(), token) != config.eos_ids.end();
}

int32_t greedy(const std::vector<float>& logits) {
  return static_cast<int32_t>(std::max_element(logits.begin(), logits.end()) - logits.begin());
}

class InferenceSession {
 public:
  explicit InferenceSession(const std::string& directory)
      : tokenizer_(directory), model_(directory) {}

  void reset() {
    cache_.clear();
    cache_ids_.clear();
  }

  std::string generate(const std::string& prompt, int maximum) {
    const auto started = std::chrono::steady_clock::now();
    const std::vector<int32_t> prompt_ids = tokenizer_.encode(prompt);
    std::size_t common = 0;
    while (common < prompt_ids.size() && common < cache_ids_.size() &&
           prompt_ids[common] == cache_ids_[common]) {
      ++common;
    }
    if (common == prompt_ids.size() && common > 0) --common;
    const std::size_t kv_width = static_cast<std::size_t>(
        model_.config().kv_heads * model_.config().head_dim);
    if (common < cache_.length) cache_.truncate(common, kv_width);
    cache_ids_.resize(common);
    std::vector<int32_t> suffix(prompt_ids.begin() + static_cast<std::ptrdiff_t>(common),
                                prompt_ids.end());
    std::vector<float> logits = model_.extend(suffix, &cache_);
    cache_ids_.insert(cache_ids_.end(), suffix.begin(), suffix.end());
    std::vector<int32_t> generated;
    for (int index = 0; index < maximum; ++index) {
      const int32_t token = greedy(logits);
      if (is_eos(model_.config(), token)) break;
      generated.push_back(token);
      logits = model_.extend({token}, &cache_);
      cache_ids_.push_back(token);
    }
    const double elapsed = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - started).count();
    std::cerr << "[NeurX S] prompt_tokens=" << prompt_ids.size()
              << " reused_tokens=" << common
              << " generated_tokens=" << generated.size()
              << " elapsed=" << elapsed << "s\n";
    return tokenizer_.decode(generated);
  }

  std::vector<int32_t> tokenize(const std::string& text) { return tokenizer_.encode(text); }
  std::string decode(const std::vector<int32_t>& ids) const { return tokenizer_.decode(ids); }

 private:
  QwenTokenizer tokenizer_;
  ProductionCpuModel model_;
  KvCache cache_;
  std::vector<int32_t> cache_ids_;
};

std::atomic<bool> running{true};

void stop_server(int) { running.store(false); }

bool send_all(int fd, const std::string& text) {
  std::size_t offset = 0;
  while (offset < text.size()) {
    const ssize_t count = ::send(fd, text.data() + offset, text.size() - offset, MSG_NOSIGNAL);
    if (count <= 0) return false;
    offset += static_cast<std::size_t>(count);
  }
  return true;
}

struct Request {
  std::string method;
  std::string path;
  std::string headers;
  std::string body;
};

bool read_request(int fd, Request* request) {
  std::string data;
  std::size_t expected = std::numeric_limits<std::size_t>::max();
  while (data.size() <= (8U << 20U)) {
    const std::size_t separator = data.find("\r\n\r\n");
    if (separator != std::string::npos) {
      std::size_t length = 0;
      const std::size_t marker = data.find("Content-Length:");
      if (marker != std::string::npos && marker < separator) {
        length = static_cast<std::size_t>(std::strtoull(data.c_str() + marker + 15U, nullptr, 10));
      }
      expected = separator + 4U + length;
      if (data.size() >= expected) break;
    }
    char buffer[8192];
    const ssize_t count = ::recv(fd, buffer, sizeof(buffer), 0);
    if (count <= 0) return false;
    data.append(buffer, static_cast<std::size_t>(count));
  }
  const std::size_t first_space = data.find(' ');
  const std::size_t second_space = data.find(' ', first_space + 1U);
  const std::size_t separator = data.find("\r\n\r\n");
  if (first_space == std::string::npos || second_space == std::string::npos ||
      separator == std::string::npos || expected == std::numeric_limits<std::size_t>::max()) {
    return false;
  }
  request->method = data.substr(0, first_space);
  request->path = data.substr(first_space + 1U, second_space - first_space - 1U);
  request->headers = data.substr(0, separator);
  request->body = data.substr(separator + 4U, expected - separator - 4U);
  return true;
}

int header_int(const std::string& headers, const std::string& name, int fallback) {
  const std::size_t marker = headers.find(name + ":");
  if (marker == std::string::npos) return fallback;
  const char* start = headers.c_str() + marker + name.size() + 1U;
  while (*start == ' ' || *start == '\t') ++start;
  const long value = std::strtol(start, nullptr, 10);
  return value > 0 && value <= 4096 ? static_cast<int>(value) : fallback;
}

void respond(int fd, int code, const char* status, const char* type, const std::string& body) {
  send_all(fd, "HTTP/1.1 " + std::to_string(code) + " " + status +
                   "\r\nContent-Type: " + type +
                   "\r\nContent-Length: " + std::to_string(body.size()) +
                   "\r\nConnection: close\r\n\r\n" + body);
}

int serve(const std::string& directory, const std::string& host, int port) {
  const int threads = env_int("NEURX_CPU_THREADS", std::max(1, omp_get_num_procs() / 2));
  omp_set_dynamic(0);
  omp_set_num_threads(threads);
  std::cerr << "[NeurX S] loading model=" << directory << " threads=" << threads << "\n";
  InferenceSession session(directory);
  const int listener = ::socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (listener < 0) throw std::runtime_error("cannot create inference socket");
  int reuse = 1;
  ::setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
  sockaddr_in address {};
  address.sin_family = AF_INET;
  address.sin_port = htons(static_cast<uint16_t>(port));
  if (::inet_pton(AF_INET, host.c_str(), &address.sin_addr) != 1 ||
      ::bind(listener, reinterpret_cast<const sockaddr*>(&address), sizeof(address)) != 0 ||
      ::listen(listener, 64) != 0) {
    ::close(listener);
    throw std::runtime_error("cannot listen on " + host + ":" + std::to_string(port));
  }
  std::signal(SIGINT, stop_server);
  std::signal(SIGTERM, stop_server);
  const std::string ready_file = env_string("NEURX_S_READY_FILE", "");
  if (!ready_file.empty()) {
    std::ofstream ready(ready_file, std::ios::trunc);
    ready << "ready\n";
  }
  std::cerr << "[NeurX S] ready=http://" << host << ':' << port << "\n";
  while (running.load()) {
    pollfd event {listener, POLLIN, 0};
    const int polled = ::poll(&event, 1, 500);
    if (polled == 0 || (polled < 0 && errno == EINTR)) continue;
    if (polled < 0) break;
    const int client = ::accept4(listener, nullptr, nullptr, SOCK_CLOEXEC);
    if (client < 0) {
      if (errno == EINTR) continue;
      break;
    }
    try {
      Request request;
      if (!read_request(client, &request)) {
        respond(client, 400, "Bad Request", "application/json", "{\"error\":\"bad request\"}");
      } else if (request.method == "GET" && request.path == "/health") {
        respond(client, 200, "OK", "application/json",
                "{\"status\":\"ok\",\"backend\":\"neurx-s-cpu\"}");
      } else if (request.method == "POST" && request.path == "/reset") {
        session.reset();
        respond(client, 200, "OK", "application/json", "{\"status\":\"reset\"}");
      } else if (request.method == "POST" && request.path == "/v1/generate") {
        const int maximum = header_int(request.headers, "X-Max-New-Tokens", 128);
        respond(client, 200, "OK", "text/plain; charset=utf-8",
                session.generate(request.body, maximum));
      } else {
        respond(client, 404, "Not Found", "application/json", "{\"error\":\"not found\"}");
      }
    } catch (const std::exception& error) {
      std::cerr << "[NeurX S] request_error=" << error.what() << '\n';
      respond(client, 500, "Internal Server Error", "text/plain; charset=utf-8", error.what());
    }
    ::close(client);
  }
  ::close(listener);
  if (!ready_file.empty()) std::remove(ready_file.c_str());
  return 0;
}

}  // namespace

int main(int argc, char** argv) {
  try {
    const std::string directory = env_string("NEURX_MODEL_DIR", "/home/shuwen/shuwen/posttrain");
    if (argc >= 2 && std::string(argv[1]) == "--tokenize") {
      if (argc < 3) return 2;
      QwenTokenizer tokenizer(directory);
      const auto ids = tokenizer.encode(argv[2]);
      std::cout << "ids";
      for (int32_t id : ids) std::cout << ' ' << id;
      std::cout << '\n';
      return 0;
    }
    if (argc >= 2 && std::string(argv[1]) == "--decode") {
      QwenTokenizer tokenizer(directory);
      std::vector<int32_t> ids;
      for (int index = 2; index < argc; ++index) ids.push_back(std::stoi(argv[index]));
      std::cout << tokenizer.decode(ids) << '\n';
      return 0;
    }
    return serve(directory, env_string("NEURX_S_HOST", "127.0.0.1"),
                 env_int("NEURX_S_PORT", 18082));
  } catch (const std::exception& error) {
    std::cerr << "error: " << error.what() << '\n';
    return 1;
  }
}
