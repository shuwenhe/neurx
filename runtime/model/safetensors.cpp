#include "safetensors.h"

#include "json.h"

#include <cstring>
#include <fstream>
#include <limits>
#include <stdexcept>

namespace neurx::runtime::model {
namespace {

native::d_type parse_dtype(const std::string& name) {
  if (name == "BOOL") return native::d_type::boolean;
  if (name == "U8") return native::d_type::uint8;
  if (name == "I8") return native::d_type::int8;
  if (name == "I16") return native::d_type::int16;
  if (name == "I32") return native::d_type::int32;
  if (name == "I64") return native::d_type::int64;
  if (name == "F16") return native::d_type::float16;
  if (name == "BF16") return native::d_type::bfloat16;
  if (name == "F32") return native::d_type::float32;
  if (name == "F64") return native::d_type::float64;
  throw std::runtime_error("unsupported safetensors dtype: " + name);
}

uint64_t checked_product(const std::vector<int64_t>& shape) {
  uint64_t product = 1;
  for (int64_t dimension : shape) {
    if (dimension < 0 || (dimension != 0 && product > std::numeric_limits<uint64_t>::max() /
                                                     static_cast<uint64_t>(dimension))) {
      throw std::runtime_error("invalid safetensors shape");
    }
    product *= static_cast<uint64_t>(dimension);
  }
  return product;
}

}

safe_tensor_file safe_tensor_file::open(const std::string& path) {
  safe_tensor_file result;
  result.path_ = path;
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input) throw std::runtime_error("cannot open safetensors file: " + path);
  const std::streamsize size = input.tellg();
  if (size < 8) throw std::runtime_error("safetensors file is truncated: " + path);
  input.seekg(0);
  result.bytes_.resize(static_cast<std::size_t>(size));
  if (!input.read(reinterpret_cast<char*>(result.bytes_.data()), size)) {
    throw std::runtime_error("cannot read safetensors file: " + path);
  }
  uint64_t header_size = 0;
  for (int index = 0; index < 8; ++index) {
    header_size |= static_cast<uint64_t>(result.bytes_[static_cast<std::size_t>(index)]) << (8 * index);
  }
  if (header_size > result.bytes_.size() - 8) throw std::runtime_error("invalid safetensors header size");
  result.data_start_ = 8 + header_size;
  const std::string header(reinterpret_cast<const char*>(result.bytes_.data() + 8),
                           static_cast<std::size_t>(header_size));
  const json root = json::parse(header);
  for (const auto& [name, value] : root.as_object()) {
    if (name == "__metadata__") {
      for (const auto& [key, item] : value.as_object()) result.metadata_[key] = item.as_string();
      continue;
    }
    safe_tensor_info info;
    info.dtype = parse_dtype(value.at("dtype").as_string());
    for (const auto& dimension : value.at("shape").as_array()) info.shape.push_back(dimension.as_int());
    const auto& offsets = value.at("data_offsets").as_array();
    if (offsets.size() != 2) throw std::runtime_error("invalid safetensors data_offsets");
    info.begin = static_cast<uint64_t>(offsets[0].as_int());
    info.end = static_cast<uint64_t>(offsets[1].as_int());
    if (info.end < info.begin || result.data_start_ + info.end > result.bytes_.size()) {
      throw std::runtime_error("safetensors tensor range is outside file: " + name);
    }
    const uint64_t expected = checked_product(info.shape) * native::dtype_size(info.dtype);
    if (info.end - info.begin != expected) throw std::runtime_error("safetensors tensor byte size mismatch: " + name);
    result.tensors_.emplace(name, std::move(info));
  }
  return result;
}

bool safe_tensor_file::contains(const std::string& name) const { return tensors_.find(name) != tensors_.end(); }

native::tensor safe_tensor_file::load(const std::string& name, native::device target_device) const {
  const auto it = tensors_.find(name);
  if (it == tensors_.end()) throw std::out_of_range("safetensors tensor not found: " + name);
  const safe_tensor_info& info = it->second;
  native::tensor cpu = native::tensor::empty(info.shape, info.dtype, {native::device_type::cpu, 0});
  cpu.copy_from_host(bytes_.data() + data_start_ + info.begin,
                     static_cast<std::size_t>(info.end - info.begin));
  return target_device.type == native::device_type::cpu ? cpu : cpu.to(target_device);
}

}
