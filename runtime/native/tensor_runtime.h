#pragma once
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>
namespace neurx::runtime::native {
enum class d_type : uint8_t {
  boolean,
  uint8,
  int8,
  int16,
  int32,
  int64,
  float16,
  bfloat16,
  float32,
  float64,
};
enum class device_type : uint8_t { cpu, cuda, cann };

struct device {
  device_type type = device_type::cpu;
  int id = 0;
  bool operator==(const device& other) const { return type == other.type && id == other.id; }
  bool operator!=(const device& other) const { return !(*this == other); }
};
enum class copy_kind : uint8_t { host_to_host, host_to_device, device_to_host, device_to_device };
const char* dtype_name(d_type dtype);
std::size_t dtype_size(d_type dtype);
bool dtype_is_floating(d_type dtype);
bool dtype_is_integer(d_type dtype);
d_type promote_types(d_type lhs, d_type rhs);
const char* device_type_name(device_type type);

struct memory_ops {
  std::function<void*(int device_id, std::size_t bytes)> allocate;
  std::function<void(int device_id, void* ptr)> deallocate;
  std::function<void(int dst_device, void* dst, device src_device, const void* src,
                     std::size_t bytes, copy_kind kind)>
      copy;
  std::function<void(int device_id, void* ptr, int value, std::size_t bytes)> set;
  std::function<void(int device_id)> synchronize;
};
class memory_registry {
 public:
  static memory_registry& instance();
  void register_backend(device_type type, memory_ops ops);
  bool has_backend(device_type type) const;
  memory_ops backend(device_type type) const;
  void copy(device dst_device, void* dst, device src_device, const void* src,
            std::size_t bytes) const;
 private:
  memory_registry();
  mutable std::mutex mutex_;
  std::unordered_map<int, memory_ops> backends_;
};
class storage {
 public:
  storage(::neurx::runtime::native::device device, std::size_t bytes);
  ~storage();
  storage(const storage&) = delete;
  storage& operator=(const storage&) = delete;
  void* data() { return data_; }
  const void* data() const { return data_; }
  std::size_t bytes() const { return bytes_; }
  ::neurx::runtime::native::device device() const { return device_; }
 private:
  ::neurx::runtime::native::device device_;
  std::size_t bytes_ = 0;
  void* data_ = nullptr;
  memory_ops memory_ops_;
};
class tensor {
 public:
  tensor() = default;
  static tensor empty(std::vector<int64_t> shape, d_type dtype,
                      device device = {device_type::cpu, 0});
  static tensor zeros(std::vector<int64_t> shape, d_type dtype,
                      device device = {device_type::cpu, 0});
  bool defined() const { return static_cast<bool>(storage_); }
  d_type dtype() const { return dtype_; }
  ::neurx::runtime::native::device device() const {
    return storage_ ? storage_->device() : ::neurx::runtime::native::device{};
  }
  const std::vector<int64_t>& shape() const { return shape_; }
  const std::vector<int64_t>& strides() const { return strides_; }
  int64_t storage_offset() const { return storage_offset_; }
  int64_t numel() const;
  std::size_t nbytes() const;
  bool is_contiguous() const;
  uint64_t version() const { return version_ ? *version_ : 0; }
  void* data();
  const void* data() const;
  void copy_from_host(const void* src, std::size_t bytes);
  void copy_to_host(void* dst, std::size_t bytes) const;
  void copy_from(const tensor& src);
  tensor view(std::vector<int64_t> shape, std::vector<int64_t> strides,
              int64_t storage_offset = 0) const;
  tensor reshape(std::vector<int64_t> shape) const;
  tensor contiguous() const;
  tensor to(d_type dtype) const;
  tensor to(::neurx::runtime::native::device device) const;
  void bump_version();
 private:
  tensor(std::shared_ptr<storage> storage, d_type dtype, std::vector<int64_t> shape,
         std::vector<int64_t> strides, int64_t storage_offset,
         std::shared_ptr<uint64_t> version);
  static std::vector<int64_t> contiguous_strides(const std::vector<int64_t>& shape);
  static int64_t checked_numel(const std::vector<int64_t>& shape);
  std::shared_ptr<storage> storage_;
  d_type dtype_ = d_type::float32;
  std::vector<int64_t> shape_;
  std::vector<int64_t> strides_;
  int64_t storage_offset_ = 0;
  std::shared_ptr<uint64_t> version_;
};

struct dispatch_key {
  std::string operation;
  device_type device = device_type::cpu;
  d_type dtype = d_type::float32;
  bool operator==(const dispatch_key& other) const {
    return operation == other.operation && device == other.device && dtype == other.dtype;
  }
};

struct dispatch_key_hash {
  std::size_t operator()(const dispatch_key& key) const;
};
using kernel = std::function<tensor(const std::vector<tensor>& inputs)>;
class dispatcher {
 public:
  static dispatcher& instance();
  void register_kernel(std::string operation, device_type device, d_type dtype, kernel kernel);
  bool has_kernel(const std::string& operation, device_type device, d_type dtype) const;
  tensor execute(const std::string& operation, const std::vector<tensor>& inputs,
                 bool allow_cpu_fallback = false) const;
  void register_builtin_cpu_kernels();
 private:
  mutable std::mutex mutex_;
  std::unordered_map<dispatch_key, kernel, dispatch_key_hash> kernels_;
  bool cpu_kernels_registered_ = false;
};
}
