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

enum class DType : uint8_t {
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

enum class DeviceType : uint8_t { cpu, cuda, cann };

struct Device {
  DeviceType type = DeviceType::cpu;
  int id = 0;

  bool operator==(const Device& other) const { return type == other.type && id == other.id; }
  bool operator!=(const Device& other) const { return !(*this == other); }
};

enum class CopyKind : uint8_t { host_to_host, host_to_device, device_to_host, device_to_device };

const char* dtype_name(DType dtype);
std::size_t dtype_size(DType dtype);
bool dtype_is_floating(DType dtype);
bool dtype_is_integer(DType dtype);
DType promote_types(DType lhs, DType rhs);
const char* device_type_name(DeviceType type);

struct MemoryOps {
  std::function<void*(int device_id, std::size_t bytes)> allocate;
  std::function<void(int device_id, void* ptr)> deallocate;
  std::function<void(int dst_device, void* dst, Device src_device, const void* src,
                     std::size_t bytes, CopyKind kind)>
      copy;
  std::function<void(int device_id, void* ptr, int value, std::size_t bytes)> set;
  std::function<void(int device_id)> synchronize;
};

class MemoryRegistry {
 public:
  static MemoryRegistry& instance();

  void register_backend(DeviceType type, MemoryOps ops);
  bool has_backend(DeviceType type) const;
  MemoryOps backend(DeviceType type) const;
  void copy(Device dst_device, void* dst, Device src_device, const void* src,
            std::size_t bytes) const;

 private:
  MemoryRegistry();
  mutable std::mutex mutex_;
  std::unordered_map<int, MemoryOps> backends_;
};

class Storage {
 public:
  Storage(Device device, std::size_t bytes);
  ~Storage();
  Storage(const Storage&) = delete;
  Storage& operator=(const Storage&) = delete;

  void* data() { return data_; }
  const void* data() const { return data_; }
  std::size_t bytes() const { return bytes_; }
  Device device() const { return device_; }

 private:
  Device device_;
  std::size_t bytes_ = 0;
  void* data_ = nullptr;
  MemoryOps memory_ops_;
};

class Tensor {
 public:
  Tensor() = default;

  static Tensor empty(std::vector<int64_t> shape, DType dtype,
                      Device device = {DeviceType::cpu, 0});
  static Tensor zeros(std::vector<int64_t> shape, DType dtype,
                      Device device = {DeviceType::cpu, 0});

  bool defined() const { return static_cast<bool>(storage_); }
  DType dtype() const { return dtype_; }
  Device device() const { return storage_ ? storage_->device() : Device{}; }
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
  void copy_from(const Tensor& src);

  Tensor view(std::vector<int64_t> shape, std::vector<int64_t> strides,
              int64_t storage_offset = 0) const;
  Tensor reshape(std::vector<int64_t> shape) const;
  Tensor contiguous() const;
  Tensor to(DType dtype) const;
  Tensor to(Device device) const;
  void bump_version();

 private:
  Tensor(std::shared_ptr<Storage> storage, DType dtype, std::vector<int64_t> shape,
         std::vector<int64_t> strides, int64_t storage_offset,
         std::shared_ptr<uint64_t> version);

  static std::vector<int64_t> contiguous_strides(const std::vector<int64_t>& shape);
  static int64_t checked_numel(const std::vector<int64_t>& shape);

  std::shared_ptr<Storage> storage_;
  DType dtype_ = DType::float32;
  std::vector<int64_t> shape_;
  std::vector<int64_t> strides_;
  int64_t storage_offset_ = 0;
  std::shared_ptr<uint64_t> version_;
};

struct DispatchKey {
  std::string operation;
  DeviceType device = DeviceType::cpu;
  DType dtype = DType::float32;

  bool operator==(const DispatchKey& other) const {
    return operation == other.operation && device == other.device && dtype == other.dtype;
  }
};

struct DispatchKeyHash {
  std::size_t operator()(const DispatchKey& key) const;
};

using Kernel = std::function<Tensor(const std::vector<Tensor>& inputs)>;

class Dispatcher {
 public:
  static Dispatcher& instance();

  void register_kernel(std::string operation, DeviceType device, DType dtype, Kernel kernel);
  bool has_kernel(const std::string& operation, DeviceType device, DType dtype) const;
  Tensor execute(const std::string& operation, const std::vector<Tensor>& inputs,
                 bool allow_cpu_fallback = false) const;
  void register_builtin_cpu_kernels();

 private:
  mutable std::mutex mutex_;
  std::unordered_map<DispatchKey, Kernel, DispatchKeyHash> kernels_;
  bool cpu_kernels_registered_ = false;
};

}
