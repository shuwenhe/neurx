#include "nxtrfmv2_loader.h"

#include <algorithm>
#include <cstring>
#include <fstream>
#include <limits>
#include <sstream>
#include <vector>

namespace neurx::cann {
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

constexpr uint64_t kMaxPathBytes = 1ULL << 20;
constexpr uint64_t kMaxPendingTokens = 1ULL << 28;
constexpr std::size_t kTransferElements = 1U << 20;

bool read_exact(std::ifstream& input, void* destination, std::size_t bytes) {
  input.read(static_cast<char*>(destination), static_cast<std::streamsize>(bytes));
  return input.good() || input.gcount() == static_cast<std::streamsize>(bytes);
}

Status read_header(std::ifstream& input, HeaderV2* header) {
  if (!header || !read_exact(input, header, sizeof(*header))) {
    return Status::failure("cannot read NXTRFMV2 checkpoint header");
  }
  if (std::memcmp(header->magic, "NXTRFMV2", 8) != 0 ||
      header->version != 2 || header->header_bytes != sizeof(*header)) {
    return Status::failure("unsupported checkpoint format; expected NXTRFMV2 version 2");
  }
  if (header->vocab == 0 || header->seq == 0 || header->dim == 0 ||
      header->heads == 0 || header->ffn == 0 || header->layers == 0 ||
      header->param_count == 0 || header->dim % header->heads != 0) {
    return Status::failure("NXTRFMV2 model dimensions are invalid");
  }
  const uint64_t expected_parameters =
      2 + static_cast<uint64_t>(header->layers) * 9;
  if (header->param_count != expected_parameters) {
    return Status::failure("NXTRFMV2 parameter tensor count does not match model layers");
  }
  if (header->vocab_path_bytes > kMaxPathBytes ||
      header->merges_path_bytes > kMaxPathBytes ||
      header->pending_count > kMaxPendingTokens) {
    return Status::failure("NXTRFMV2 metadata exceeds safety limits");
  }
  return Status::success();
}

ModelMetadata metadata_from(const HeaderV2& header) {
  return {header.step,
          header.tokenizer_hash,
          header.tokenizer_kind,
          header.vocab,
          header.seq,
          header.dim,
          header.heads,
          header.ffn,
          header.layers,
          header.param_count};
}

std::string weight_name(uint64_t index, const HeaderV2& header) {
  if (index == 0) return "token_embedding";
  const uint64_t tensors_per_layer = 9;
  const uint64_t layer_tensors = static_cast<uint64_t>(header.layers) * tensors_per_layer;
  if (index <= layer_tensors) {
    static const char* names[tensors_per_layer] = {
        "attention_norm", "q_proj", "k_proj", "v_proj", "o_proj",
        "ffn_norm", "gate_proj", "up_proj", "down_proj"};
    const uint64_t local = index - 1;
    return "layers." + std::to_string(local / tensors_per_layer) + "." +
           names[local % tensors_per_layer];
  }
  if (index == layer_tensors + 1) return "lm_head";
  return "tensor." + std::to_string(index);
}

uint64_t expected_weight_elements(uint64_t index, const HeaderV2& header) {
  const uint64_t dim = header.dim;
  if (index == 0) return static_cast<uint64_t>(header.vocab) * dim;
  const uint64_t layer_tensors = static_cast<uint64_t>(header.layers) * 9;
  if (index <= layer_tensors) {
    const uint64_t within_layer = (index - 1) % 9;
    if (within_layer == 0 || within_layer == 5) return dim;
    if (within_layer >= 6) return dim * header.ffn;
    return dim * dim;
  }
  return dim * header.vocab;
}

Status skip_training_state(std::ifstream& input, uint64_t elements) {
  constexpr uint64_t state_copies = 3;
  if (elements > static_cast<uint64_t>(std::numeric_limits<std::streamoff>::max()) /
                     (sizeof(float) * state_copies)) {
    return Status::failure("NXTRFMV2 optimizer-state offset overflows streamoff");
  }
  input.seekg(static_cast<std::streamoff>(elements * sizeof(float) * state_copies),
              std::ios::cur);
  return input ? Status::success()
               : Status::failure("NXTRFMV2 optimizer state is truncated");
}

}  // namespace

Status inspect_nxtrfmv2(const std::string& path, ModelMetadata* metadata) {
  if (!metadata) return Status::failure("model metadata output is null");
  std::ifstream input(path, std::ios::binary);
  if (!input) return Status::failure("cannot open checkpoint: " + path);
  HeaderV2 header{};
  const Status status = read_header(input, &header);
  if (!status.ok) return status;
  *metadata = metadata_from(header);
  return Status::success();
}

uint16_t float_to_fp16_bits(float value) {
  uint32_t bits = 0;
  std::memcpy(&bits, &value, sizeof(bits));
  const uint32_t sign = (bits >> 16) & 0x8000U;
  const uint32_t exponent = (bits >> 23) & 0xffU;
  uint32_t mantissa = bits & 0x7fffffU;

  if (exponent == 0xffU) {
    return static_cast<uint16_t>(sign | (mantissa ? 0x7e00U : 0x7c00U));
  }
  const int32_t half_exponent = static_cast<int32_t>(exponent) - 127 + 15;
  if (half_exponent >= 31) return static_cast<uint16_t>(sign | 0x7c00U);
  if (half_exponent <= 0) {
    if (half_exponent < -10) return static_cast<uint16_t>(sign);
    mantissa |= 0x800000U;
    const uint32_t shift = static_cast<uint32_t>(14 - half_exponent);
    uint32_t half_mantissa = mantissa >> shift;
    const uint32_t remainder = mantissa & ((1U << shift) - 1U);
    const uint32_t halfway = 1U << (shift - 1U);
    if (remainder > halfway || (remainder == halfway && (half_mantissa & 1U))) {
      ++half_mantissa;
    }
    return static_cast<uint16_t>(sign | half_mantissa);
  }

  uint32_t half_mantissa = mantissa >> 13;
  const uint32_t remainder = mantissa & 0x1fffU;
  if (remainder > 0x1000U || (remainder == 0x1000U && (half_mantissa & 1U))) {
    ++half_mantissa;
    if (half_mantissa == 0x400U) {
      half_mantissa = 0;
      if (half_exponent + 1 >= 31) return static_cast<uint16_t>(sign | 0x7c00U);
      return static_cast<uint16_t>(sign |
                                   (static_cast<uint32_t>(half_exponent + 1) << 10));
    }
  }
  return static_cast<uint16_t>(sign |
                               (static_cast<uint32_t>(half_exponent) << 10) |
                               half_mantissa);
}

Status Nxtrfmv2Model::load(const std::string& path, DeviceSession& session,
                           const ModelLoadOptions& options) {
  reset();
  if (!session.ready()) return Status::failure("CANN device session is not initialized");
  if (set_current_context(session.context()) != kSuccess) {
    return Status::failure(std::string("aclrtSetCurrentContext: ") + recent_error());
  }

  std::ifstream input(path, std::ios::binary);
  if (!input) return Status::failure("cannot open checkpoint: " + path);
  HeaderV2 header{};
  Status status = read_header(input, &header);
  if (!status.ok) return status;
  if (options.expected_tokenizer_hash != 0 &&
      header.tokenizer_hash != options.expected_tokenizer_hash) {
    return Status::failure("checkpoint tokenizer hash does not match configured tokenizer");
  }
  metadata_ = metadata_from(header);

  const uint64_t metadata_bytes =
      static_cast<uint64_t>(header.vocab_path_bytes) + header.merges_path_bytes +
      header.pending_count * sizeof(int32_t);
  if (metadata_bytes >
      static_cast<uint64_t>(std::numeric_limits<std::streamoff>::max())) {
    return Status::failure("NXTRFMV2 metadata offset overflows streamoff");
  }
  input.seekg(static_cast<std::streamoff>(metadata_bytes), std::ios::cur);
  if (!input) return Status::failure("NXTRFMV2 metadata is truncated");

  std::vector<float> fp32(kTransferElements);
  std::vector<uint16_t> fp16;
  if (options.precision == ModelPrecision::fp16) fp16.resize(kTransferElements);
  weights_.reserve(static_cast<std::size_t>(header.param_count));

  for (uint64_t index = 0; index < header.param_count; ++index) {
    uint64_t elements = 0;
    if (!read_exact(input, &elements, sizeof(elements)) || elements == 0) {
      reset();
      return Status::failure("NXTRFMV2 weight block header is invalid");
    }
    if (elements != expected_weight_elements(index, header)) {
      reset();
      return Status::failure(weight_name(index, header) +
                             ": checkpoint tensor shape is inconsistent");
    }
    const std::size_t element_bytes =
        options.precision == ModelPrecision::fp16 ? sizeof(uint16_t) : sizeof(float);
    if (elements > std::numeric_limits<std::size_t>::max() / element_bytes) {
      reset();
      return Status::failure("NXTRFMV2 weight allocation overflows size_t");
    }

    DeviceWeight weight;
    weight.name = weight_name(index, header);
    weight.elements = elements;
    status = weight.storage.allocate(static_cast<std::size_t>(elements) * element_bytes);
    if (!status.ok) {
      reset();
      return Status::failure(weight.name + ": " + status.message);
    }

    uint64_t copied = 0;
    while (copied < elements) {
      const std::size_t chunk = static_cast<std::size_t>(
          std::min<uint64_t>(kTransferElements, elements - copied));
      if (!read_exact(input, fp32.data(), chunk * sizeof(float))) {
        reset();
        return Status::failure(weight.name + ": checkpoint weight data is truncated");
      }
      const void* source = fp32.data();
      if (options.precision == ModelPrecision::fp16) {
        for (std::size_t item = 0; item < chunk; ++item) {
          fp16[item] = float_to_fp16_bits(fp32[item]);
        }
        source = fp16.data();
      }
      auto* destination = static_cast<unsigned char*>(weight.storage.data()) +
                          static_cast<std::size_t>(copied) * element_bytes;
      const std::size_t bytes = chunk * element_bytes;
      if (memcpy_async(destination, bytes, source, bytes,
                       MemcpyKind::host_to_device, session.stream()) != kSuccess) {
        reset();
        return Status::failure(weight.name + ": aclrtMemcpyAsync failed: " +
                               recent_error());
      }
      status = session.synchronize();
      if (!status.ok) {
        reset();
        return Status::failure(weight.name + ": " + status.message);
      }
      copied += chunk;
    }
    status = skip_training_state(input, elements);
    if (!status.ok) {
      reset();
      return Status::failure(weight.name + ": " + status.message);
    }
    weights_.push_back(std::move(weight));
  }
  loaded_ = true;
  precision_ = options.precision;
  return Status::success();
}

void Nxtrfmv2Model::reset() {
  weights_.clear();
  metadata_ = {};
  precision_ = ModelPrecision::fp16;
  loaded_ = false;
}

const DeviceWeight* Nxtrfmv2Model::token_embedding() const {
  return loaded_ && !weights_.empty() ? &weights_.front() : nullptr;
}

const DeviceWeight* Nxtrfmv2Model::layer_weight(
    std::size_t layer, LayerWeightKind kind) const {
  if (!loaded_ || layer >= metadata_.layers) return nullptr;
  constexpr std::size_t tensors_per_layer = 9;
  const std::size_t index =
      1 + layer * tensors_per_layer + static_cast<std::size_t>(kind);
  return index < weights_.size() ? &weights_[index] : nullptr;
}

const DeviceWeight* Nxtrfmv2Model::lm_head() const {
  return loaded_ && !weights_.empty() ? &weights_.back() : nullptr;
}

}  // namespace neurx::cann
