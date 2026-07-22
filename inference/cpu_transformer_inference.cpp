#include "cpu_transformer_inference.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <limits>
#include <map>
#include <numeric>
#include <random>
#include <sstream>
#include <stdexcept>
#include <unordered_map>
#include <utility>

namespace neurx::inference::cpu {
namespace {

#pragma pack(push, 1)
struct HeaderV2 {
  char magic[8];
  uint32_t version;
  uint32_t header_bytes;
  uint64_t step;
  uint64_t optimizer_step;
  uint64_t micro_step;
  uint64_t shard;
  uint64_t line;
  uint64_t docs;
  uint64_t tokens;
  uint32_t vocab;
  uint32_t seq;
  uint32_t dim;
  uint32_t heads;
  uint32_t ffn;
  uint32_t layers;
  uint32_t micro_batch;
  uint32_t grad_accum;
  uint32_t tokenizer_kind;
  uint32_t vocab_path_bytes;
  uint32_t merges_path_bytes;
  uint64_t tokenizer_hash;
  uint64_t pending_count;
  uint64_t param_count;
};
#pragma pack(pop)

static_assert(sizeof(HeaderV2) == 140, "NXTRFMV2 header ABI changed");

uint64_t fnv1a(const std::string& text) {
  uint64_t hash = 1469598103934665603ULL;
  for (const unsigned char byte : text) {
    hash ^= byte;
    hash *= 1099511628211ULL;
  }
  return hash;
}

bool read_exact(std::ifstream& input, void* output, std::size_t bytes) {
  input.read(static_cast<char*>(output), static_cast<std::streamsize>(bytes));
  return input.good() ||
         input.gcount() == static_cast<std::streamsize>(bytes);
}

std::string read_file(const std::string& path) {
  std::ifstream input(path, std::ios::binary);
  if (!input) return {};
  std::ostringstream output;
  output << input.rdbuf();
  return output.str();
}

std::string json_unescape(const std::string& input) {
  std::string output;
  for (std::size_t i = 0; i < input.size(); ++i) {
    const char value = input[i];
    if (value != '\\' || i + 1 >= input.size()) {
      output += value;
      continue;
    }
    const char escaped = input[++i];
    if (escaped == 'n') output += '\n';
    else if (escaped == 'r') output += '\r';
    else if (escaped == 't') output += '\t';
    else if (escaped == 'b') output += '\b';
    else if (escaped == 'f') output += '\f';
    else if (escaped == '"' || escaped == '\\' || escaped == '/') output += escaped;
    else if (escaped == 'u' && i + 4 < input.size()) {
      unsigned codepoint = 0;
      bool valid = true;
      for (int digit = 0; digit < 4; ++digit) {
        const char hex = input[++i];
        codepoint *= 16;
        if (hex >= '0' && hex <= '9') codepoint += unsigned(hex - '0');
        else if (hex >= 'a' && hex <= 'f') codepoint += unsigned(hex - 'a' + 10);
        else if (hex >= 'A' && hex <= 'F') codepoint += unsigned(hex - 'A' + 10);
        else valid = false;
      }
      if (!valid) continue;
      if (codepoint < 0x80) output += char(codepoint);
      else if (codepoint < 0x800) {
        output += char(0xc0 | (codepoint >> 6));
        output += char(0x80 | (codepoint & 0x3f));
      } else {
        output += char(0xe0 | (codepoint >> 12));
        output += char(0x80 | ((codepoint >> 6) & 0x3f));
        output += char(0x80 | (codepoint & 0x3f));
      }
    }
  }
  return output;
}

bool parse_json_string(const std::string& json, std::size_t* position,
                       std::string* output) {
  std::size_t& p = *position;
  while (p < json.size() && std::isspace(static_cast<unsigned char>(json[p]))) ++p;
  if (p >= json.size() || json[p] != '"') return false;
  ++p;
  std::string raw;
  bool escaped = false;
  for (; p < json.size(); ++p) {
    const char value = json[p];
    if (!escaped && value == '"') {
      ++p;
      *output = json_unescape(raw);
      return true;
    }
    raw += value;
    if (!escaped && value == '\\') escaped = true;
    else escaped = false;
  }
  return false;
}

struct Tokenizer {
  bool bpe = false;
  int unknown = 0;
  int eos = -1;
  uint64_t fingerprint = 0;
  std::unordered_map<std::string, int> vocabulary;
  std::vector<std::string> decoder;
  std::map<std::pair<std::string, std::string>, int> merge_rank;

  bool load(bool checkpoint_uses_bpe, const std::string& vocabulary_path,
            const std::string& merges_path, uint64_t expected_fingerprint,
            uint32_t expected_size, std::string* error) {
    bpe = checkpoint_uses_bpe;
    if (!bpe) {
      if (expected_size != 256) {
        *error = "byte-level NXTRFMV2 checkpoint must have vocabulary size 256";
        return false;
      }
      decoder.resize(256);
      for (int id = 0; id < 256; ++id) decoder[id] = std::string(1, char(id));
      return true;
    }
    const std::string vocabulary_json = read_file(vocabulary_path);
    if (vocabulary_json.empty()) {
      *error = "cannot read BPE vocabulary: " + vocabulary_path;
      return false;
    }
    std::size_t position = 0;
    while (position < vocabulary_json.size()) {
      std::string token;
      if (!parse_json_string(vocabulary_json, &position, &token)) {
        ++position;
        continue;
      }
      while (position < vocabulary_json.size() &&
             std::isspace(static_cast<unsigned char>(vocabulary_json[position]))) {
        ++position;
      }
      if (position >= vocabulary_json.size() || vocabulary_json[position++] != ':') {
        continue;
      }
      while (position < vocabulary_json.size() &&
             std::isspace(static_cast<unsigned char>(vocabulary_json[position]))) {
        ++position;
      }
      char* end = nullptr;
      const long id = std::strtol(vocabulary_json.c_str() + position, &end, 10);
      if (end != vocabulary_json.c_str() + position && id >= 0 &&
          id <= std::numeric_limits<int>::max()) {
        vocabulary[token] = static_cast<int>(id);
        position = static_cast<std::size_t>(end - vocabulary_json.c_str());
      }
    }
    if (vocabulary.empty()) {
      *error = "BPE vocabulary contains no token/id entries";
      return false;
    }
    int maximum_id = 0;
    for (const auto& item : vocabulary) maximum_id = std::max(maximum_id, item.second);
    decoder.resize(static_cast<std::size_t>(maximum_id + 1));
    for (const auto& item : vocabulary) decoder[static_cast<std::size_t>(item.second)] = item.first;
    if (decoder.size() != expected_size) {
      *error = "tokenizer vocabulary size does not match checkpoint";
      return false;
    }
    for (const char* name : {"<unk>", "[UNK]", "<|endoftext|>"}) {
      const auto found = vocabulary.find(name);
      if (found != vocabulary.end()) {
        unknown = found->second;
        break;
      }
    }
    for (const char* name : {"</s>", "<eos>", "<|endoftext|>"}) {
      const auto found = vocabulary.find(name);
      if (found != vocabulary.end()) {
        eos = found->second;
        break;
      }
    }
    const std::string merge_file = read_file(merges_path);
    if (merge_file.empty()) {
      *error = "cannot read BPE merges: " + merges_path;
      return false;
    }
    std::istringstream lines(merge_file);
    std::string line;
    std::string canonical_merges;
    int rank = 0;
    while (std::getline(lines, line)) {
      canonical_merges += line;
      canonical_merges += '\n';
      if (line.empty() || line[0] == '#') continue;
      std::istringstream fields(line);
      std::string first;
      std::string second;
      if (fields >> first >> second) merge_rank[{first, second}] = rank++;
    }
    fingerprint = fnv1a(vocabulary_json + "\n" + canonical_merges);
    if (fingerprint != expected_fingerprint) {
      *error = "checkpoint tokenizer hash does not match vocabulary/merges";
      return false;
    }
    return true;
  }

  std::vector<int> encode(const std::string& text) const {
    if (!bpe) {
      std::vector<int> ids;
      ids.reserve(text.size());
      for (const unsigned char byte : text) ids.push_back(byte);
      return ids;
    }
    std::vector<std::string> pieces;
    for (std::size_t i = 0; i < text.size();) {
      if (std::isspace(static_cast<unsigned char>(text[i]))) {
        pieces.emplace_back(1, text[i++]);
        continue;
      }
      std::size_t end = i + 1;
      while (end < text.size() &&
             !std::isspace(static_cast<unsigned char>(text[end]))) {
        ++end;
      }
      std::vector<std::string> word;
      for (std::size_t offset = i; offset < end; ++offset) {
        word.emplace_back(1, text[offset]);
      }
      while (word.size() > 1) {
        int best_rank = std::numeric_limits<int>::max();
        int best_at = -1;
        for (std::size_t at = 0; at + 1 < word.size(); ++at) {
          const auto found = merge_rank.find({word[at], word[at + 1]});
          if (found != merge_rank.end() && found->second < best_rank) {
            best_rank = found->second;
            best_at = static_cast<int>(at);
          }
        }
        if (best_at < 0) break;
        word[static_cast<std::size_t>(best_at)] +=
            word[static_cast<std::size_t>(best_at + 1)];
        word.erase(word.begin() + best_at + 1);
      }
      pieces.insert(pieces.end(), word.begin(), word.end());
      i = end;
    }
    std::vector<int> ids;
    for (const std::string& piece : pieces) {
      const auto found = vocabulary.find(piece);
      if (found != vocabulary.end()) {
        ids.push_back(found->second);
        continue;
      }
      for (const unsigned char byte : piece) {
        const auto byte_token = vocabulary.find(std::string(1, char(byte)));
        ids.push_back(byte_token == vocabulary.end() ? unknown : byte_token->second);
      }
    }
    if (eos >= 0) ids.push_back(eos);
    return ids;
  }

  std::string decode(const std::vector<int>& ids) const {
    std::string output;
    for (const int id : ids) {
      if (id == eos) break;
      if (id >= 0 && static_cast<std::size_t>(id) < decoder.size()) {
        output += decoder[static_cast<std::size_t>(id)];
      }
    }
    return output;
  }
};

struct Layer {
  std::vector<float> attention_norm;
  std::vector<float> query;
  std::vector<float> key;
  std::vector<float> value;
  std::vector<float> output;
  std::vector<float> ffn_norm;
  std::vector<float> gate;
  std::vector<float> up;
  std::vector<float> down;
};

std::vector<float> matrix_multiply(const std::vector<float>& left,
                                   const std::vector<float>& right,
                                   int rows, int shared, int columns) {
  std::vector<float> result(static_cast<std::size_t>(rows) * columns, 0.0F);
  for (int row = 0; row < rows; ++row) {
    for (int inner = 0; inner < shared; ++inner) {
      const float value = left[static_cast<std::size_t>(row) * shared + inner];
      for (int column = 0; column < columns; ++column) {
        result[static_cast<std::size_t>(row) * columns + column] +=
            value * right[static_cast<std::size_t>(inner) * columns + column];
      }
    }
  }
  return result;
}

std::vector<float> rms_norm(const std::vector<float>& input,
                            const std::vector<float>& scale, int rows,
                            int dimensions) {
  std::vector<float> output(input.size());
  for (int row = 0; row < rows; ++row) {
    double sum_squares = 0.0;
    for (int column = 0; column < dimensions; ++column) {
      const float value = input[static_cast<std::size_t>(row) * dimensions + column];
      sum_squares += double(value) * value;
    }
    const float inverse =
        1.0F / std::sqrt(static_cast<float>(sum_squares / dimensions) + 1.0e-5F);
    for (int column = 0; column < dimensions; ++column) {
      const std::size_t index = static_cast<std::size_t>(row) * dimensions + column;
      output[index] = input[index] * inverse * scale[static_cast<std::size_t>(column)];
    }
  }
  return output;
}

void apply_rope(std::vector<float>* values, int tokens, int dimensions,
                int heads) {
  const int head_size = dimensions / heads;
  for (int position = 0; position < tokens; ++position) {
    for (int head = 0; head < heads; ++head) {
      for (int offset = 0; offset + 1 < head_size; offset += 2) {
        const float angle =
            position / std::pow(10000.0F, float(offset) / head_size);
        const float cosine = std::cos(angle);
        const float sine = std::sin(angle);
        const std::size_t index =
            static_cast<std::size_t>(position) * dimensions +
            head * head_size + offset;
        const float first = (*values)[index];
        const float second = (*values)[index + 1];
        (*values)[index] = first * cosine - second * sine;
        (*values)[index + 1] = first * sine + second * cosine;
      }
    }
  }
}

std::vector<float> causal_attention(const std::vector<float>& query,
                                    const std::vector<float>& key,
                                    const std::vector<float>& value, int tokens,
                                    int dimensions, int heads) {
  const int head_size = dimensions / heads;
  const float scale = 1.0F / std::sqrt(float(head_size));
  std::vector<float> context(static_cast<std::size_t>(tokens) * dimensions, 0.0F);
  std::vector<float> scores(static_cast<std::size_t>(tokens));
  for (int head = 0; head < heads; ++head) {
    for (int row = 0; row < tokens; ++row) {
      float maximum = -std::numeric_limits<float>::infinity();
      for (int column = 0; column <= row; ++column) {
        float score = 0.0F;
        for (int offset = 0; offset < head_size; ++offset) {
          score +=
              query[static_cast<std::size_t>(row) * dimensions +
                    head * head_size + offset] *
              key[static_cast<std::size_t>(column) * dimensions +
                  head * head_size + offset];
        }
        scores[static_cast<std::size_t>(column)] = score * scale;
        maximum = std::max(maximum, score * scale);
      }
      float denominator = 0.0F;
      for (int column = 0; column <= row; ++column) {
        scores[static_cast<std::size_t>(column)] =
            std::exp(scores[static_cast<std::size_t>(column)] - maximum);
        denominator += scores[static_cast<std::size_t>(column)];
      }
      for (int offset = 0; offset < head_size; ++offset) {
        float result = 0.0F;
        for (int column = 0; column <= row; ++column) {
          result += scores[static_cast<std::size_t>(column)] / denominator *
                    value[static_cast<std::size_t>(column) * dimensions +
                          head * head_size + offset];
        }
        context[static_cast<std::size_t>(row) * dimensions +
                head * head_size + offset] = result;
      }
    }
  }
  return context;
}

bool read_parameter(std::ifstream& input, std::size_t expected,
                    std::vector<float>* output, std::string* error) {
  uint64_t elements = 0;
  if (!read_exact(input, &elements, sizeof(elements)) || elements != expected) {
    *error = "NXTRFMV2 parameter shape does not match model metadata";
    return false;
  }
  output->resize(expected);
  if (!read_exact(input, output->data(), expected * sizeof(float))) {
    *error = "NXTRFMV2 weight data is truncated";
    return false;
  }
  const uint64_t optimizer_bytes = elements * sizeof(float) * 3ULL;
  if (optimizer_bytes >
      static_cast<uint64_t>(std::numeric_limits<std::streamoff>::max())) {
    *error = "NXTRFMV2 optimizer state offset overflows";
    return false;
  }
  input.seekg(static_cast<std::streamoff>(optimizer_bytes), std::ios::cur);
  if (!input) {
    *error = "NXTRFMV2 optimizer state is truncated";
    return false;
  }
  return true;
}

int sample_token(std::vector<float> logits, const std::vector<int>& history,
                 const GenerationConfig& config, std::mt19937_64* generator) {
  if (config.repetition_penalty > 0.0F &&
      config.repetition_penalty != 1.0F) {
    std::vector<bool> seen(logits.size(), false);
    for (const int token : history) {
      if (token < 0 || static_cast<std::size_t>(token) >= logits.size() ||
          seen[static_cast<std::size_t>(token)]) {
        continue;
      }
      seen[static_cast<std::size_t>(token)] = true;
      float& value = logits[static_cast<std::size_t>(token)];
      value = value < 0.0F ? value * config.repetition_penalty
                           : value / config.repetition_penalty;
    }
  }
  if (config.temperature <= 0.0F) {
    return static_cast<int>(
        std::max_element(logits.begin(), logits.end()) - logits.begin());
  }
  std::vector<int> order(logits.size());
  std::iota(order.begin(), order.end(), 0);
  std::sort(order.begin(), order.end(), [&](int left, int right) {
    return logits[static_cast<std::size_t>(left)] >
           logits[static_cast<std::size_t>(right)];
  });
  if (config.top_k > 0 && static_cast<std::size_t>(config.top_k) < order.size()) {
    order.resize(static_cast<std::size_t>(config.top_k));
  }
  const float maximum = logits[static_cast<std::size_t>(order.front())] /
                        config.temperature;
  std::vector<double> probabilities(order.size());
  double denominator = 0.0;
  for (std::size_t i = 0; i < order.size(); ++i) {
    probabilities[i] =
        std::exp(double(logits[static_cast<std::size_t>(order[i])] /
                        config.temperature - maximum));
    denominator += probabilities[i];
  }
  if (config.top_p > 0.0F && config.top_p < 1.0F) {
    double cumulative = 0.0;
    std::size_t keep = 0;
    for (; keep < probabilities.size(); ++keep) {
      cumulative += probabilities[keep] / denominator;
      if (cumulative >= config.top_p) {
        ++keep;
        break;
      }
    }
    order.resize(std::max<std::size_t>(1, keep));
    probabilities.resize(order.size());
  }
  std::discrete_distribution<std::size_t> distribution(probabilities.begin(),
                                                        probabilities.end());
  return order[distribution(*generator)];
}

}

struct Transformer::Impl {
  ModelInfo info;
  Tokenizer tokenizer;
  std::vector<float> embedding;
  std::vector<Layer> layers;
  std::vector<float> lm_head;
};

Transformer::Transformer() : impl_(new Impl()) {}
Transformer::~Transformer() { delete impl_; }
Transformer::Transformer(Transformer&& other) noexcept : impl_(other.impl_) {
  other.impl_ = nullptr;
}
Transformer& Transformer::operator=(Transformer&& other) noexcept {
  if (this != &other) {
    delete impl_;
    impl_ = other.impl_;
    other.impl_ = nullptr;
  }
  return *this;
}

std::string resolve_checkpoint_path(const std::string& input) {
  namespace fs = std::filesystem;
  std::error_code error;
  if (fs::is_regular_file(input, error)) return input;
  if (!fs::is_directory(input, error)) return input;
  const fs::path directory(input);
  const fs::path direct = directory / "transformer_v2.ckpt";
  if (fs::is_regular_file(direct, error)) return direct.string();
  const fs::path latest = directory / "latest_checkpoint.txt";
  std::ifstream pointer(latest);
  std::string path;
  if (pointer && std::getline(pointer, path) && !path.empty()) {
    if (fs::is_regular_file(path, error)) return path;
    const fs::path relative = directory / path;
    if (fs::is_regular_file(relative, error)) return relative.string();
  }
  return direct.string();
}

bool Transformer::load(const std::string& checkpoint_path,
                       const std::string& vocabulary_path,
                       const std::string& merges_path, std::string* error) {
  std::string local_error;
  if (!error) error = &local_error;
  *error = "";
  Impl loaded;
  const std::string resolved = resolve_checkpoint_path(checkpoint_path);
  std::ifstream input(resolved, std::ios::binary);
  if (!input) {
    *error = "cannot open checkpoint: " + resolved;
    return false;
  }
  HeaderV2 header{};
  if (!read_exact(input, &header, sizeof(header)) ||
      std::memcmp(header.magic, "NXTRFMV2", 8) != 0 ||
      header.version != 2 || header.header_bytes != sizeof(header)) {
    *error = "unsupported checkpoint format; expected NXTRFMV2 version 2";
    return false;
  }
  if (header.vocab == 0 || header.seq < 2 || header.dim == 0 ||
      header.heads == 0 || header.ffn == 0 || header.layers == 0 ||
      header.dim % header.heads != 0 ||
      (header.dim / header.heads) % 2 != 0 ||
      header.param_count != 2ULL + uint64_t(header.layers) * 9ULL) {
    *error = "NXTRFMV2 model metadata is invalid";
    return false;
  }
  constexpr uint64_t kMaximumMetadataBytes = 1ULL << 20;
  if (header.vocab_path_bytes > kMaximumMetadataBytes ||
      header.merges_path_bytes > kMaximumMetadataBytes ||
      header.pending_count > (1ULL << 28)) {
    *error = "NXTRFMV2 metadata exceeds safety limits";
    return false;
  }
  std::string saved_vocabulary(header.vocab_path_bytes, '\0');
  std::string saved_merges(header.merges_path_bytes, '\0');
  if ((header.vocab_path_bytes &&
       !read_exact(input, saved_vocabulary.data(), saved_vocabulary.size())) ||
      (header.merges_path_bytes &&
       !read_exact(input, saved_merges.data(), saved_merges.size()))) {
    *error = "NXTRFMV2 tokenizer metadata is truncated";
    return false;
  }
  const uint64_t pending_bytes = header.pending_count * sizeof(int32_t);
  input.seekg(static_cast<std::streamoff>(pending_bytes), std::ios::cur);
  if (!input) {
    *error = "NXTRFMV2 pending-token state is truncated";
    return false;
  }
  const std::string effective_vocabulary =
      vocabulary_path.empty() ? saved_vocabulary : vocabulary_path;
  const std::string effective_merges =
      merges_path.empty() ? saved_merges : merges_path;
  if (!loaded.tokenizer.load(header.tokenizer_kind != 0, effective_vocabulary,
                             effective_merges, header.tokenizer_hash,
                             header.vocab, error)) {
    return false;
  }
  loaded.info = {header.step, header.vocab, header.seq, header.dim,
                 header.heads, header.ffn, header.layers,
                 header.tokenizer_kind != 0};
  const std::size_t dimensions = header.dim;
  const std::size_t ffn = header.ffn;
  if (!read_parameter(input, std::size_t(header.vocab) * dimensions,
                      &loaded.embedding, error)) {
    return false;
  }
  loaded.layers.resize(header.layers);
  for (Layer& layer : loaded.layers) {
    if (!read_parameter(input, dimensions, &layer.attention_norm, error) ||
        !read_parameter(input, dimensions * dimensions, &layer.query, error) ||
        !read_parameter(input, dimensions * dimensions, &layer.key, error) ||
        !read_parameter(input, dimensions * dimensions, &layer.value, error) ||
        !read_parameter(input, dimensions * dimensions, &layer.output, error) ||
        !read_parameter(input, dimensions, &layer.ffn_norm, error) ||
        !read_parameter(input, dimensions * ffn, &layer.gate, error) ||
        !read_parameter(input, dimensions * ffn, &layer.up, error) ||
        !read_parameter(input, ffn * dimensions, &layer.down, error)) {
      return false;
    }
  }
  if (!read_parameter(input, dimensions * header.vocab, &loaded.lm_head,
                      error)) {
    return false;
  }
  if (input.peek() != std::ifstream::traits_type::eof()) {
    *error = "NXTRFMV2 checkpoint contains unexpected trailing data";
    return false;
  }
  *impl_ = std::move(loaded);
  return true;
}

std::vector<int> Transformer::encode(const std::string& text) const {
  return impl_->tokenizer.encode(text);
}

std::string Transformer::decode(const std::vector<int>& token_ids) const {
  return impl_->tokenizer.decode(token_ids);
}

std::vector<float> Transformer::forward_last(
    const std::vector<int>& token_ids) const {
  if (impl_->info.vocabulary == 0) {
    throw std::runtime_error("model is not loaded");
  }
  if (token_ids.empty()) throw std::invalid_argument("prompt token list is empty");
  if (token_ids.size() > impl_->info.context_length) {
    throw std::invalid_argument("prompt exceeds model context length");
  }
  const int tokens = static_cast<int>(token_ids.size());
  const int dimensions = static_cast<int>(impl_->info.hidden_size);
  const int ffn = static_cast<int>(impl_->info.ffn_size);
  std::vector<float> hidden(static_cast<std::size_t>(tokens) * dimensions);
  for (int row = 0; row < tokens; ++row) {
    const int token = token_ids[static_cast<std::size_t>(row)];
    if (token < 0 || static_cast<uint32_t>(token) >= impl_->info.vocabulary) {
      throw std::invalid_argument("token id is outside model vocabulary");
    }
    std::copy_n(impl_->embedding.begin() +
                    static_cast<std::size_t>(token) * dimensions,
                dimensions,
                hidden.begin() + static_cast<std::size_t>(row) * dimensions);
  }
  for (const Layer& layer : impl_->layers) {
    const std::vector<float> normalized =
        rms_norm(hidden, layer.attention_norm, tokens, dimensions);
    std::vector<float> query =
        matrix_multiply(normalized, layer.query, tokens, dimensions, dimensions);
    std::vector<float> key =
        matrix_multiply(normalized, layer.key, tokens, dimensions, dimensions);
    const std::vector<float> value =
        matrix_multiply(normalized, layer.value, tokens, dimensions, dimensions);
    apply_rope(&query, tokens, dimensions, static_cast<int>(impl_->info.heads));
    apply_rope(&key, tokens, dimensions, static_cast<int>(impl_->info.heads));
    const std::vector<float> context =
        causal_attention(query, key, value, tokens, dimensions,
                         static_cast<int>(impl_->info.heads));
    const std::vector<float> attention_output =
        matrix_multiply(context, layer.output, tokens, dimensions, dimensions);
    for (std::size_t i = 0; i < hidden.size(); ++i) hidden[i] += attention_output[i];
    const std::vector<float> ffn_input =
        rms_norm(hidden, layer.ffn_norm, tokens, dimensions);
    const std::vector<float> gate =
        matrix_multiply(ffn_input, layer.gate, tokens, dimensions, ffn);
    const std::vector<float> up =
        matrix_multiply(ffn_input, layer.up, tokens, dimensions, ffn);
    std::vector<float> activated(gate.size());
    for (std::size_t i = 0; i < gate.size(); ++i) {
      const float sigmoid = 1.0F / (1.0F + std::exp(-gate[i]));
      activated[i] = gate[i] * sigmoid * up[i];
    }
    const std::vector<float> ffn_output =
        matrix_multiply(activated, layer.down, tokens, ffn, dimensions);
    for (std::size_t i = 0; i < hidden.size(); ++i) hidden[i] += ffn_output[i];
  }
  std::vector<float> last(hidden.end() - dimensions, hidden.end());
  return matrix_multiply(last, impl_->lm_head, 1, dimensions,
                         static_cast<int>(impl_->info.vocabulary));
}

std::vector<int> Transformer::generate_ids(
    const std::vector<int>& prompt_ids, const GenerationConfig& config) const {
  if (config.max_new_tokens < 0) {
    throw std::invalid_argument("max_new_tokens must not be negative");
  }
  if (config.temperature < 0.0F || config.top_k < 0 ||
      config.top_p <= 0.0F || config.top_p > 1.0F ||
      config.repetition_penalty <= 0.0F) {
    throw std::invalid_argument("invalid sampling configuration");
  }
  std::vector<int> context = prompt_ids;
  if (context.empty()) context.push_back(impl_->tokenizer.unknown);
  if (context.size() >= impl_->info.context_length) {
    context.erase(context.begin(),
                  context.end() - (impl_->info.context_length - 1));
  }
  std::vector<int> generated;
  generated.reserve(static_cast<std::size_t>(config.max_new_tokens));
  std::mt19937_64 generator(config.seed);
  for (int step = 0; step < config.max_new_tokens &&
                     context.size() < impl_->info.context_length;
       ++step) {
    const std::vector<float> logits = forward_last(context);
    const int token = sample_token(logits, context, config, &generator);
    if (token == impl_->tokenizer.eos) break;
    generated.push_back(token);
    context.push_back(token);
  }
  return generated;
}

std::string Transformer::generate(const std::string& prompt,
                                  const GenerationConfig& config) const {
  std::vector<int> prompt_ids = encode(prompt);
  if (impl_->tokenizer.eos >= 0 && !prompt_ids.empty() &&
      prompt_ids.back() == impl_->tokenizer.eos) {
    prompt_ids.pop_back();
  }
  return decode(generate_ids(prompt_ids, config));
}

const ModelInfo& Transformer::info() const { return impl_->info; }
int Transformer::eos_token_id() const { return impl_->tokenizer.eos; }

}
