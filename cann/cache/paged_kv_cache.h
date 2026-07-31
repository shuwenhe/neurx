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
struct kv_cache_config_2 {
  std::size_t block_count = 0;
  std::size_t block_bytes = 0;
  std::size_t tokens_per_block = 0;
  std::size_t layers = 0;
  std::size_t kv_heads = 0;
  std::size_t head_size = 0;
  std::size_t element_bytes = 0;
  KvStorageFormat format = KvStorageFormat::contiguous_nd;
  static kv_cache_config_2 fp16_transformer(std::size_t block_count,
                                        std::size_t tokens_per_block,
                                        std::size_t layers,
                                        std::size_t kv_heads,
                                        std::size_t head_size);
  static kv_cache_config_2 fp16_310p(std::size_t block_count,
                                 std::size_t tokens_per_block,
                                 std::size_t layers,
                                 std::size_t kv_heads,
                                 std::size_t head_size);
  bool has_tensor_layout() const {
    return layers != 0 || kv_heads != 0 || head_size != 0 || element_bytes != 0;
  }
};
struct kv_cache_stats {
  std::size_t total_blocks = 0;
  std::size_t used_blocks = 0;
  std::size_t free_blocks = 0;
  std::size_t active_requests = 0;
  std::size_t allocated_tokens = 0;
};
class DeviceAllocator {
 public:
  virtual ~DeviceAllocator() = default;
  virtual status allocate(void** address, std::size_t bytes) = 0;
  virtual void release(void* address) = 0;
};
class AclDeviceAllocator final : public DeviceAllocator {
 public:
  status allocate(void** address, std::size_t bytes) override;
  void release(void* address) override;
};
class PagedKvCache {
 public:
  explicit PagedKvCache(kv_cache_config_2 config, DeviceAllocator* allocator = nullptr);
  ~PagedKvCache();
  PagedKvCache(const PagedKvCache&) = delete;
  PagedKvCache& operator=(const PagedKvCache&) = delete;
  status initialize();
  status reserve(const std::string& request_id, std::size_t total_tokens);
  status resize(const std::string& request_id, std::size_t total_tokens);
  status append(const std::string& request_id, std::size_t token_count);
  bool release(const std::string& request_id);
  status retain_prefix(const std::string& request_id,
                       std::size_t prefix_tokens,
                       std::vector<uint32_t>* retained_blocks);
  status attach_retained_prefix(const std::string& request_id,
                                const std::vector<uint32_t>& retained_blocks,
                                std::size_t prefix_tokens);
  void release_retained_blocks(const std::vector<uint32_t>& retained_blocks);
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
  kv_cache_stats stats() const;
  const kv_cache_config_2& config() const { return config_; }
 private:
  struct request_allocation {
    std::vector<uint32_t> blocks;
    std::size_t tokens = 0;
  };
  status validate_config() const;
  std::size_t blocks_for(std::size_t tokens) const;
  status reserve_locked(const std::string& request_id, std::size_t total_tokens);
  void release_block_locked(uint32_t block);
  void* layer_address(bool value, std::size_t layer) const;
  void* slot_address(bool value, std::size_t layer, uint32_t block,
                     std::size_t token_offset) const;
  kv_cache_config_2 config_;
  AclDeviceAllocator default_allocator_;
  DeviceAllocator* allocator_ = nullptr;
  void* storage_ = nullptr;
  mutable std::mutex mutex_;
  std::vector<uint32_t> free_blocks_;
  std::vector<uint32_t> block_refcounts_;
  std::map<std::string, request_allocation> requests_;
};
}
