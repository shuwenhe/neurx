#include "tensor_runtime.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <utility>

namespace neurx::runtime::native {
namespace {

void* cpu_allocate(int, std::size_t bytes) {
  if (bytes == 0) return nullptr;
  void* pointer = std::malloc(bytes);
  if (!pointer) throw std::bad_alloc();
  return pointer;
}

void cpu_deallocate(int, void* pointer) { std::free(pointer); }

void cpu_copy(int, void* destination, device source_device, const void* source,
              std::size_t bytes, copy_kind) {
  if (source_device.type != device_type::cpu) {
    throw std::runtime_error("CPU tensor backend cannot copy directly from non-CPU memory");
  }
  if (bytes != 0) std::memcpy(destination, source, bytes);
}

void cpu_set(int, void* pointer, int value, std::size_t bytes) {
  if (bytes != 0) std::memset(pointer, value, bytes);
}

void cpu_synchronize(int) {}

float half_to_float(uint16_t half) {
  const uint32_t sign = static_cast<uint32_t>(half & 0x8000U) << 16;
  uint32_t exponent = (half >> 10) & 0x1fU;
  uint32_t mantissa = half & 0x03ffU;
  uint32_t bits = 0;
  if (exponent == 0) {
    if (mantissa == 0) {
      bits = sign;
    } else {
      exponent = 1;
      while ((mantissa & 0x0400U) == 0) {
        mantissa <<= 1;
        --exponent;
      }
      mantissa &= 0x03ffU;
      bits = sign | ((exponent + 112U) << 23) | (mantissa << 13);
    }
  } else if (exponent == 31) {
    bits = sign | 0x7f800000U | (mantissa << 13);
  } else {
    bits = sign | ((exponent + 112U) << 23) | (mantissa << 13);
  }
  float value;
  std::memcpy(&value, &bits, sizeof(value));
  return value;
}

uint16_t float_to_half(float value) {
  uint32_t bits;
  std::memcpy(&bits, &value, sizeof(bits));
  const uint32_t sign = (bits >> 16) & 0x8000U;
  const int exponent = static_cast<int>((bits >> 23) & 0xffU) - 127 + 15;
  const uint32_t mantissa = bits & 0x7fffffU;
  if (exponent <= 0) {
    if (exponent < -10) return static_cast<uint16_t>(sign);
    const uint32_t shifted = (mantissa | 0x800000U) >> (1 - exponent);
    return static_cast<uint16_t>(sign | ((shifted + 0x1000U) >> 13));
  }
  if (exponent >= 31) {
    return static_cast<uint16_t>(sign | 0x7c00U | (mantissa ? 0x0200U : 0));
  }
  return static_cast<uint16_t>(sign | (static_cast<uint32_t>(exponent) << 10) |
                               ((mantissa + 0x1000U) >> 13));
}

double read_number(const void* data, d_type dtype, int64_t index) {
  switch (dtype) {
    case d_type::boolean: return static_cast<const uint8_t*>(data)[index] != 0;
    case d_type::uint8: return static_cast<const uint8_t*>(data)[index];
    case d_type::int8: return static_cast<const int8_t*>(data)[index];
    case d_type::int16: return static_cast<const int16_t*>(data)[index];
    case d_type::int32: return static_cast<const int32_t*>(data)[index];
    case d_type::int64: return static_cast<double>(static_cast<const int64_t*>(data)[index]);
    case d_type::float16: return half_to_float(static_cast<const uint16_t*>(data)[index]);
    case d_type::bfloat16: {
      const uint32_t bits = static_cast<uint32_t>(static_cast<const uint16_t*>(data)[index]) << 16;
      float value;
      std::memcpy(&value, &bits, sizeof(value));
      return value;
    }
    case d_type::float32: return static_cast<const float*>(data)[index];
    case d_type::float64: return static_cast<const double*>(data)[index];
  }
  throw std::runtime_error("unsupported tensor dtype");
}

void write_number(void* data, d_type dtype, int64_t index, double value) {
  switch (dtype) {
    case d_type::boolean: static_cast<uint8_t*>(data)[index] = value != 0.0; return;
    case d_type::uint8: static_cast<uint8_t*>(data)[index] = static_cast<uint8_t>(value); return;
    case d_type::int8: static_cast<int8_t*>(data)[index] = static_cast<int8_t>(value); return;
    case d_type::int16: static_cast<int16_t*>(data)[index] = static_cast<int16_t>(value); return;
    case d_type::int32: static_cast<int32_t*>(data)[index] = static_cast<int32_t>(value); return;
    case d_type::int64: static_cast<int64_t*>(data)[index] = static_cast<int64_t>(value); return;
    case d_type::float16: static_cast<uint16_t*>(data)[index] = float_to_half(static_cast<float>(value)); return;
    case d_type::bfloat16: {
      float converted = static_cast<float>(value);
      uint32_t bits;
      std::memcpy(&bits, &converted, sizeof(bits));
      static_cast<uint16_t*>(data)[index] = static_cast<uint16_t>(bits >> 16);
      return;
    }
    case d_type::float32: static_cast<float*>(data)[index] = static_cast<float>(value); return;
    case d_type::float64: static_cast<double*>(data)[index] = value; return;
  }
  throw std::runtime_error("unsupported tensor dtype");
}

}

const char* dtype_name(d_type dtype) {
  static const char* names[] = {"BOOL", "U8", "I8", "I16", "I32", "I64", "F16", "BF16", "F32", "F64"};
  return names[static_cast<unsigned>(dtype)];
}

std::size_t dtype_size(d_type dtype) {
  switch (dtype) {
    case d_type::boolean:
    case d_type::uint8:
    case d_type::int8: return 1;
    case d_type::int16:
    case d_type::float16:
    case d_type::bfloat16: return 2;
    case d_type::int32:
    case d_type::float32: return 4;
    case d_type::int64:
    case d_type::float64: return 8;
  }
  throw std::runtime_error("invalid tensor dtype");
}

bool dtype_is_floating(d_type dtype) {
  return dtype == d_type::float16 || dtype == d_type::bfloat16 ||
         dtype == d_type::float32 || dtype == d_type::float64;
}

bool dtype_is_integer(d_type dtype) {
  return dtype == d_type::uint8 || dtype == d_type::int8 || dtype == d_type::int16 ||
         dtype == d_type::int32 || dtype == d_type::int64;
}

d_type promote_types(d_type lhs, d_type rhs) {
  if (lhs == rhs) return lhs;
  if (lhs == d_type::float64 || rhs == d_type::float64) return d_type::float64;
  if (dtype_is_floating(lhs) || dtype_is_floating(rhs)) return d_type::float32;
  return d_type::int64;
}

const char* device_type_name(device_type type) {
  switch (type) {
    case device_type::cpu: return "cpu";
    case device_type::cuda: return "cuda";
    case device_type::cann: return "cann";
  }
  return "unknown";
}

memory_registry::memory_registry() {
  register_backend(device_type::cpu, memory_ops{cpu_allocate, cpu_deallocate, cpu_copy,
                                                 cpu_set, cpu_synchronize});
}

memory_registry& memory_registry::instance() {
  static memory_registry registry;
  return registry;
}

void memory_registry::register_backend(device_type type, memory_ops ops) {
  std::lock_guard<std::mutex> lock(mutex_);
  backends_[static_cast<int>(type)] = std::move(ops);
}

bool memory_registry::has_backend(device_type type) const {
  std::lock_guard<std::mutex> lock(mutex_);
  return backends_.find(static_cast<int>(type)) != backends_.end();
}

memory_ops memory_registry::backend(device_type type) const {
  std::lock_guard<std::mutex> lock(mutex_);
  const auto it = backends_.find(static_cast<int>(type));
  if (it == backends_.end()) throw std::runtime_error("tensor memory backend is not registered");
  return it->second;
}

void memory_registry::copy(device destination_device, void* destination, device source_device,
                           const void* source, std::size_t bytes) const {
  if (destination_device.type == device_type::cpu) {
    if (source_device.type != device_type::cpu) {
      backend(source_device.type).copy(destination_device.id, destination, source_device, source,
                                       bytes, copy_kind::device_to_host);
    } else if (bytes != 0) {
      std::memcpy(destination, source, bytes);
    }
    return;
  }
  const copy_kind kind = source_device.type == device_type::cpu
                             ? copy_kind::host_to_device
                             : copy_kind::device_to_device;
  backend(destination_device.type).copy(destination_device.id, destination, source_device, source,
                                        bytes, kind);
}

storage::storage(::neurx::runtime::native::device value_device, std::size_t bytes)
    : device_(value_device), bytes_(bytes), memory_ops_(memory_registry::instance().backend(value_device.type)) {
  data_ = memory_ops_.allocate(device_.id, bytes_);
}

storage::~storage() {
  if (data_) memory_ops_.deallocate(device_.id, data_);
}

tensor::tensor(std::shared_ptr<storage> storage_value, d_type dtype_value,
               std::vector<int64_t> shape_value, std::vector<int64_t> strides_value,
               int64_t offset, std::shared_ptr<uint64_t> version)
    : storage_(std::move(storage_value)), dtype_(dtype_value), shape_(std::move(shape_value)),
      strides_(std::move(strides_value)), storage_offset_(offset), version_(std::move(version)) {}

int64_t tensor::checked_numel(const std::vector<int64_t>& shape) {
  int64_t result = 1;
  for (int64_t dimension : shape) {
    if (dimension < 0 || (dimension != 0 && result > std::numeric_limits<int64_t>::max() / dimension))
      throw std::overflow_error("invalid tensor shape");
    result *= dimension;
  }
  return result;
}

std::vector<int64_t> tensor::contiguous_strides(const std::vector<int64_t>& shape) {
  std::vector<int64_t> strides(shape.size(), 1);
  int64_t stride = 1;
  for (std::size_t index = shape.size(); index-- > 0;) {
    strides[index] = stride;
    stride *= shape[index];
  }
  return strides;
}

tensor tensor::empty(std::vector<int64_t> shape, d_type dtype,
                     ::neurx::runtime::native::device value_device) {
  const int64_t elements = checked_numel(shape);
  const std::size_t bytes = static_cast<std::size_t>(elements) * dtype_size(dtype);
  return tensor(std::make_shared<storage>(value_device, bytes), dtype, shape,
                contiguous_strides(shape), 0, std::make_shared<uint64_t>(0));
}

tensor tensor::zeros(std::vector<int64_t> shape, d_type dtype,
                     ::neurx::runtime::native::device value_device) {
  tensor result = empty(std::move(shape), dtype, value_device);
  memory_registry::instance().backend(value_device.type).set(value_device.id, result.data(), 0,
                                                              result.nbytes());
  return result;
}

int64_t tensor::numel() const { return checked_numel(shape_); }
std::size_t tensor::nbytes() const { return static_cast<std::size_t>(numel()) * dtype_size(dtype_); }

bool tensor::is_contiguous() const { return strides_ == contiguous_strides(shape_); }

void* tensor::data() {
  if (!storage_) return nullptr;
  return static_cast<uint8_t*>(storage_->data()) + static_cast<std::size_t>(storage_offset_) * dtype_size(dtype_);
}

const void* tensor::data() const {
  if (!storage_) return nullptr;
  return static_cast<const uint8_t*>(storage_->data()) + static_cast<std::size_t>(storage_offset_) * dtype_size(dtype_);
}

void tensor::copy_from_host(const void* source, std::size_t bytes) {
  if (bytes != nbytes()) throw std::invalid_argument("tensor host copy size mismatch");
  memory_registry::instance().copy(device(), data(), {device_type::cpu, 0}, source, bytes);
  bump_version();
}

void tensor::copy_to_host(void* destination, std::size_t bytes) const {
  if (bytes != nbytes()) throw std::invalid_argument("tensor host copy size mismatch");
  memory_registry::instance().copy({device_type::cpu, 0}, destination, device(), data(), bytes);
}

void tensor::copy_from(const tensor& source) {
  if (shape_ != source.shape_ || dtype_ != source.dtype_) throw std::invalid_argument("tensor copy mismatch");
  memory_registry::instance().copy(device(), data(), source.device(), source.data(), nbytes());
  bump_version();
}

tensor tensor::view(std::vector<int64_t> shape, std::vector<int64_t> strides, int64_t offset) const {
  if (checked_numel(shape) != numel()) throw std::invalid_argument("tensor view element count mismatch");
  return tensor(storage_, dtype_, std::move(shape), std::move(strides), storage_offset_ + offset, version_);
}

tensor tensor::reshape(std::vector<int64_t> shape) const {
  if (checked_numel(shape) != numel()) throw std::invalid_argument("tensor reshape element count mismatch");
  if (!is_contiguous()) return contiguous().reshape(std::move(shape));
  return tensor(storage_, dtype_, shape, contiguous_strides(shape), storage_offset_, version_);
}

tensor tensor::contiguous() const {
  if (is_contiguous()) return *this;
  throw std::runtime_error("non-contiguous tensor materialization is not implemented");
}

tensor tensor::to(d_type target_dtype) const {
  if (target_dtype == dtype_) return *this;
  tensor cpu_source = device().type == device_type::cpu
                          ? *this
                          : to(::neurx::runtime::native::device{device_type::cpu, 0});
  tensor result = empty(shape_, target_dtype, {device_type::cpu, 0});
  for (int64_t index = 0; index < numel(); ++index) {
    write_number(result.data(), target_dtype, index, read_number(cpu_source.data(), dtype_, index));
  }
  return device().type == device_type::cpu ? result : result.to(device());
}

tensor tensor::to(::neurx::runtime::native::device target_device) const {
  if (target_device == device()) return *this;
  tensor result = empty(shape_, dtype_, target_device);
  memory_registry::instance().copy(target_device, result.data(), device(), data(), nbytes());
  return result;
}

void tensor::bump_version() {
  if (version_) ++*version_;
}

std::size_t dispatch_key_hash::operator()(const dispatch_key& key) const {
  return std::hash<std::string>{}(key.operation) ^
         (static_cast<std::size_t>(key.device) << 1) ^ (static_cast<std::size_t>(key.dtype) << 8);
}

dispatcher& dispatcher::instance() { static dispatcher value; return value; }

void dispatcher::register_kernel(std::string operation, device_type device_value, d_type dtype_value,
                                 kernel function) {
  std::lock_guard<std::mutex> lock(mutex_);
  kernels_[dispatch_key{std::move(operation), device_value, dtype_value}] = std::move(function);
}

bool dispatcher::has_kernel(const std::string& operation, device_type device_value,
                            d_type dtype_value) const {
  std::lock_guard<std::mutex> lock(mutex_);
  return kernels_.find(dispatch_key{operation, device_value, dtype_value}) != kernels_.end();
}

tensor dispatcher::execute(const std::string& operation, const std::vector<tensor>& inputs,
                           bool) const {
  if (inputs.empty()) throw std::invalid_argument("dispatcher requires an input tensor");
  std::lock_guard<std::mutex> lock(mutex_);
  const auto it = kernels_.find(dispatch_key{operation, inputs[0].device().type, inputs[0].dtype()});
  if (it == kernels_.end()) throw std::runtime_error("tensor kernel is not registered: " + operation);
  return it->second(inputs);
}

void dispatcher::register_builtin_cpu_kernels() { cpu_kernels_registered_ = true; }

}
