#pragma once

#include "../runtime/acl_runtime.h"

#include <cstddef>
#include <cstdint>
#include <map>
#include <mutex>
#include <string>
#include <vector>

namespace neurx::cann {

enum class KvStorageFormat { contiguous_nd, fractal_nz };

struct KvCacheConfig {
  std::size_t block_count = 0;
  std::size_t block_bytes = 0;
  std::size_t tokens_per_block = 0;
  std::size_t layers = 0;
  std::size_t kv_heads = 0;
  std::size_t head_size = 0;
  std::size_t element_bytes = 0;
  KvStorageFormat format = KvStorageFormat::contiguous_nd;

  static KvCacheConfig fp16_transformer(std::size_t block_count,
                                        std::size_t tokens_per_block,
                                        std::size_t layers,
                                        std::size_t kv_heads,
                                        std::size_t head_size);
  static KvCacheConfig fp16_310p(std::size_t block_count,
                                 std::size_t tokens_per_block,
                                 std::size_t layers,
                                 std::size_t kv_heads,
                                 std::size_t head_size);
  bool has_tensor_layout() const {
    return layers != 0 || kv_heads != 0 || head_size != 0 || element_bytes != 0;
  }
};

struct KvCacheStats {
  std::size_t total_blocks = 0;
  std::size_t used_blocks = 0;
  std::size_t free_blocks = 0;
  std::size_t active_requests = 0;
  std::size_t allocated_tokens = 0;
};

class DeviceAllocator {
 public:
  virtual ~DeviceAllocator() = default;
  virtual Status allocate(void** address, std::size_t bytes) = 0;
  virtual void release(void* address) = 0;
};

class AclDeviceAllocator final : public DeviceAllocator {
 public:
  Status allocate(void** address, std::size_t bytes) override;
  void release(void* address) override;
};

// Owns one contiguous device allocation and deterministic request-to-block
// metadata. Tensor layout within each block is owned by the attention kernels.
class PagedKvCache {
 public:
  explicit PagedKvCache(KvCacheConfig config, DeviceAllocator* allocator = nullptr);
  ~PagedKvCache();
  PagedKvCache(const PagedKvCache&) = delete;
  PagedKvCache& operator=(const PagedKvCache&) = delete;

  Status initialize();
  Status reserve(const std::string& request_id, std::size_t total_tokens);
  Status resize(const std::string& request_id, std::size_t total_tokens);
  Status append(const std::string& request_id, std::size_t token_count);
  bool release(const std::string& request_id);

  std::vector<uint32_t> block_table(const std::string& request_id) const;
  std::size_t token_count(const std::string& request_id) const;
  void* block_address(uint32_t block) const;
  void* key_layer_address(std::size_t layer) const;
  void* value_layer_address(std::size_t layer) const;
  void* key_slot_address(std::size_t layer, uint32_t block,
                         std::size_t token_offset) const;
  void* value_slot_address(std::size_t layer, uint32_t block,
                           std::size_t token_offset) const;
  std::size_t layer_tensor_bytes() const;
  std::size_t block_tensor_bytes() const;
  KvCacheStats stats() const;
  const KvCacheConfig& config() const { return config_; }

 private:
  struct RequestAllocation {
    std::vector<uint32_t> blocks;
    std::size_t tokens = 0;
  };

  Status validate_config() const;
  std::size_t blocks_for(std::size_t tokens) const;
  Status reserve_locked(const std::string& request_id, std::size_t total_tokens);
  void* layer_address(bool value, std::size_t layer) const;
  void* slot_address(bool value, std::size_t layer, uint32_t block,
                     std::size_t token_offset) const;

  KvCacheConfig config_;
  AclDeviceAllocator default_allocator_;
  DeviceAllocator* allocator_ = nullptr;
  void* storage_ = nullptr;
  mutable std::mutex mutex_;
  std::vector<uint32_t> free_blocks_;
  std::map<std::string, RequestAllocation> requests_;
};

}  // namespace neurx::cann
