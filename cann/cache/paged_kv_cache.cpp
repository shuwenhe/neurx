#include "paged_kv_cache.h"

#include <limits>
#include <stdexcept>

namespace neurx::cann {

KvCacheConfig KvCacheConfig::fp16_transformer(
    std::size_t block_count_value, std::size_t tokens_per_block_value,
    std::size_t layers_value, std::size_t kv_heads_value,
    std::size_t head_size_value) {
  KvCacheConfig config;
  config.block_count = block_count_value;
  config.tokens_per_block = tokens_per_block_value;
  config.layers = layers_value;
  config.kv_heads = kv_heads_value;
  config.head_size = head_size_value;
  config.element_bytes = sizeof(uint16_t);
  const std::size_t dimensions[] = {
      layers_value, tokens_per_block_value, kv_heads_value, head_size_value,
      config.element_bytes};
  config.block_bytes = 2;
  for (const std::size_t value : dimensions) {
    if (value == 0 ||
        value > std::numeric_limits<std::size_t>::max() / config.block_bytes) {
      config.block_bytes = 0;
      break;
    }
    config.block_bytes *= value;
  }
  return config;
}

KvCacheConfig KvCacheConfig::fp16_310p(
    std::size_t block_count_value, std::size_t tokens_per_block_value,
    std::size_t layers_value, std::size_t kv_heads_value,
    std::size_t head_size_value) {
  KvCacheConfig config =
      fp16_transformer(block_count_value, tokens_per_block_value, layers_value,
                       kv_heads_value, head_size_value);
  config.format = KvStorageFormat::fractal_nz;
  return config;
}

Status AclDeviceAllocator::allocate(void** address, std::size_t bytes) {
  if (!address || bytes == 0) return Status::failure("invalid device allocation request");
  if (malloc_device(address, bytes) != kSuccess) {
    return Status::failure(std::string("aclrtMalloc: ") + recent_error());
  }
  return Status::success();
}

void AclDeviceAllocator::release(void* address) {
  if (address) free_device(address);
}

PagedKvCache::PagedKvCache(KvCacheConfig config, DeviceAllocator* allocator)
    : config_(config), allocator_(allocator ? allocator : &default_allocator_) {}

PagedKvCache::~PagedKvCache() {
  if (storage_) allocator_->release(storage_);
}

Status PagedKvCache::validate_config() const {
  if (config_.block_count == 0 || config_.block_bytes == 0 ||
      config_.tokens_per_block == 0) {
    return Status::failure("KV cache dimensions must be positive");
  }
  if (config_.block_count > std::numeric_limits<uint32_t>::max()) {
    return Status::failure("KV cache block count exceeds uint32 block-table capacity");
  }
  if (config_.block_bytes > std::numeric_limits<std::size_t>::max() /
                                config_.block_count) {
    return Status::failure("KV cache allocation size overflows size_t");
  }
  if (config_.has_tensor_layout()) {
    if (config_.layers == 0 || config_.kv_heads == 0 ||
        config_.head_size == 0 || config_.element_bytes == 0) {
      return Status::failure("KV tensor layout must define every dimension");
    }
    const std::size_t values[] = {
        config_.tokens_per_block, config_.layers, config_.kv_heads,
        config_.head_size, config_.element_bytes};
    std::size_t expected = 2;
    for (const std::size_t value : values) {
      if (value > std::numeric_limits<std::size_t>::max() / expected) {
        return Status::failure("KV tensor layout size overflows size_t");
      }
      expected *= value;
    }
    if (expected != config_.block_bytes) {
      return Status::failure("KV block bytes do not match tensor layout");
    }
  }
  return Status::success();
}

Status PagedKvCache::initialize() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (storage_) return Status::success();
  const Status valid = validate_config();
  if (!valid.ok) return valid;
  const Status allocated =
      allocator_->allocate(&storage_, config_.block_count * config_.block_bytes);
  if (!allocated.ok) return allocated;
  free_blocks_.reserve(config_.block_count);
  block_refcounts_.assign(config_.block_count, 0);
  // Pop from the back while preserving stable low-to-high allocation order.
  for (std::size_t index = config_.block_count; index > 0; --index) {
    free_blocks_.push_back(static_cast<uint32_t>(index - 1));
  }
  return Status::success();
}

std::size_t PagedKvCache::blocks_for(std::size_t tokens) const {
  if (tokens == 0) return 0;
  return 1 + ((tokens - 1) / config_.tokens_per_block);
}

Status PagedKvCache::reserve(const std::string& request_id,
                             std::size_t total_tokens) {
  if (request_id.empty()) return Status::failure("KV cache request id must not be empty");
  std::lock_guard<std::mutex> lock(mutex_);
  return reserve_locked(request_id, total_tokens);
}

Status PagedKvCache::reserve_locked(const std::string& request_id,
                                    std::size_t total_tokens) {
  if (!storage_) return Status::failure("KV cache is not initialized");

  RequestAllocation& allocation = requests_[request_id];
  if (total_tokens < allocation.tokens) {
    return Status::failure("KV cache cannot shrink an active request");
  }
  const std::size_t required = blocks_for(total_tokens);
  if (required < allocation.blocks.size()) {
    return Status::failure("KV cache block accounting is inconsistent");
  }
  const std::size_t additional = required - allocation.blocks.size();
  if (additional > free_blocks_.size()) {
    if (allocation.blocks.empty() && allocation.tokens == 0) requests_.erase(request_id);
    return Status::failure("KV cache is out of blocks");
  }
  for (std::size_t index = 0; index < additional; ++index) {
    const uint32_t block = free_blocks_.back();
    free_blocks_.pop_back();
    if (block_refcounts_[block] != 0) {
      return Status::failure("KV cache free-list reference count is corrupt");
    }
    block_refcounts_[block] = 1;
    allocation.blocks.push_back(block);
  }
  allocation.tokens = total_tokens;
  return Status::success();
}

Status PagedKvCache::resize(const std::string& request_id,
                            std::size_t total_tokens) {
  if (request_id.empty()) return Status::failure("KV cache request id must not be empty");
  std::lock_guard<std::mutex> lock(mutex_);
  if (!storage_) return Status::failure("KV cache is not initialized");
  const auto it = requests_.find(request_id);
  if (it == requests_.end()) {
    return total_tokens == 0 ? Status::success()
                             : Status::failure("KV cache request does not exist");
  }
  RequestAllocation& allocation = it->second;
  const std::size_t required = blocks_for(total_tokens);
  while (allocation.blocks.size() > required) {
    release_block_locked(allocation.blocks.back());
    allocation.blocks.pop_back();
  }
  allocation.tokens = total_tokens;
  if (total_tokens == 0) requests_.erase(it);
  return Status::success();
}

Status PagedKvCache::append(const std::string& request_id,
                            std::size_t token_count_to_append) {
  if (request_id.empty()) return Status::failure("KV cache request id must not be empty");
  if (token_count_to_append == 0) {
    return Status::failure("KV cache append token count must be positive");
  }
  std::lock_guard<std::mutex> lock(mutex_);
  const auto it = requests_.find(request_id);
  const std::size_t current = it == requests_.end() ? 0 : it->second.tokens;
  if (token_count_to_append >
      std::numeric_limits<std::size_t>::max() - current) {
    return Status::failure("KV cache token count overflows size_t");
  }
  return reserve_locked(request_id, current + token_count_to_append);
}

bool PagedKvCache::release(const std::string& request_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  const auto it = requests_.find(request_id);
  if (it == requests_.end()) return false;
  for (const uint32_t block : it->second.blocks) release_block_locked(block);
  requests_.erase(it);
  return true;
}

void PagedKvCache::release_block_locked(uint32_t block) {
  if (block >= block_refcounts_.size() || block_refcounts_[block] == 0) return;
  --block_refcounts_[block];
  if (block_refcounts_[block] == 0) free_blocks_.push_back(block);
}

Status PagedKvCache::retain_prefix(
    const std::string& request_id, std::size_t prefix_tokens,
    std::vector<uint32_t>* retained_blocks) {
  if (!retained_blocks) {
    return Status::failure("retained KV block output is null");
  }
  std::lock_guard<std::mutex> lock(mutex_);
  const auto it = requests_.find(request_id);
  if (!storage_ || it == requests_.end()) {
    return Status::failure("KV cache request does not exist");
  }
  if (prefix_tokens == 0 ||
      prefix_tokens % config_.tokens_per_block != 0 ||
      prefix_tokens > it->second.tokens) {
    return Status::failure(
        "retained KV prefix must contain complete allocated blocks");
  }
  const std::size_t count = prefix_tokens / config_.tokens_per_block;
  if (count > it->second.blocks.size()) {
    return Status::failure("retained KV prefix block table is too short");
  }
  for (std::size_t index = 0; index < count; ++index) {
    const uint32_t block = it->second.blocks[index];
    if (block >= block_refcounts_.size() ||
        block_refcounts_[block] == 0 ||
        block_refcounts_[block] == std::numeric_limits<uint32_t>::max()) {
      return Status::failure("KV block reference count cannot be retained");
    }
  }
  retained_blocks->assign(it->second.blocks.begin(),
                          it->second.blocks.begin() + count);
  for (const uint32_t block : *retained_blocks) ++block_refcounts_[block];
  return Status::success();
}

Status PagedKvCache::attach_retained_prefix(
    const std::string& request_id,
    const std::vector<uint32_t>& retained_blocks,
    std::size_t prefix_tokens) {
  if (request_id.empty() || retained_blocks.empty() || prefix_tokens == 0) {
    return Status::failure("retained KV prefix attachment is invalid");
  }
  std::lock_guard<std::mutex> lock(mutex_);
  if (!storage_) return Status::failure("KV cache is not initialized");
  if (requests_.count(request_id)) {
    return Status::failure("KV cache request already has an allocation");
  }
  if (prefix_tokens % config_.tokens_per_block != 0 ||
      retained_blocks.size() != prefix_tokens / config_.tokens_per_block) {
    return Status::failure("retained KV prefix shape is inconsistent");
  }
  for (const uint32_t block : retained_blocks) {
    if (block >= block_refcounts_.size() ||
        block_refcounts_[block] == 0 ||
        block_refcounts_[block] == std::numeric_limits<uint32_t>::max()) {
      return Status::failure("retained KV prefix references an invalid block");
    }
  }
  RequestAllocation allocation;
  allocation.blocks = retained_blocks;
  allocation.tokens = prefix_tokens;
  for (const uint32_t block : retained_blocks) ++block_refcounts_[block];
  requests_.emplace(request_id, std::move(allocation));
  return Status::success();
}

void PagedKvCache::release_retained_blocks(
    const std::vector<uint32_t>& retained_blocks) {
  std::lock_guard<std::mutex> lock(mutex_);
  for (const uint32_t block : retained_blocks) release_block_locked(block);
}

std::vector<uint32_t> PagedKvCache::block_table(
    const std::string& request_id) const {
  std::lock_guard<std::mutex> lock(mutex_);
  const auto it = requests_.find(request_id);
  if (it == requests_.end()) return {};
  return it->second.blocks;
}

std::size_t PagedKvCache::token_count(const std::string& request_id) const {
  std::lock_guard<std::mutex> lock(mutex_);
  const auto it = requests_.find(request_id);
  return it == requests_.end() ? 0 : it->second.tokens;
}

void* PagedKvCache::block_address(uint32_t block) const {
  std::lock_guard<std::mutex> lock(mutex_);
  if (!storage_ || config_.has_tensor_layout() ||
      block >= config_.block_count) {
    return nullptr;
  }
  auto* base = static_cast<unsigned char*>(storage_);
  return base + static_cast<std::size_t>(block) * config_.block_bytes;
}

std::size_t PagedKvCache::block_tensor_bytes() const {
  if (!config_.has_tensor_layout()) return 0;
  return config_.tokens_per_block * config_.kv_heads * config_.head_size *
         config_.element_bytes;
}

std::size_t PagedKvCache::layer_tensor_bytes() const {
  return config_.block_count * block_tensor_bytes();
}

void* PagedKvCache::layer_address(bool value, std::size_t layer) const {
  std::lock_guard<std::mutex> lock(mutex_);
  if (!storage_ || !config_.has_tensor_layout() || layer >= config_.layers) {
    return nullptr;
  }
  const std::size_t tensor_bytes = layer_tensor_bytes();
  const std::size_t tensor_index = (value ? config_.layers : 0) + layer;
  return static_cast<unsigned char*>(storage_) + tensor_index * tensor_bytes;
}

void* PagedKvCache::key_layer_address(std::size_t layer) const {
  return layer_address(false, layer);
}

void* PagedKvCache::value_layer_address(std::size_t layer) const {
  return layer_address(true, layer);
}

void* PagedKvCache::slot_address(bool value, std::size_t layer,
                                 uint32_t block,
                                 std::size_t token_offset) const {
  std::lock_guard<std::mutex> lock(mutex_);
  if (!storage_ || !config_.has_tensor_layout() || layer >= config_.layers ||
      block >= config_.block_count ||
      token_offset >= config_.tokens_per_block ||
      config_.format == KvStorageFormat::fractal_nz) {
    return nullptr;
  }
  const std::size_t tensor_bytes = layer_tensor_bytes();
  const std::size_t tensor_index = (value ? config_.layers : 0) + layer;
  const std::size_t block_offset =
      static_cast<std::size_t>(block) * block_tensor_bytes();
  const std::size_t token_bytes =
      config_.kv_heads * config_.head_size * config_.element_bytes;
  return static_cast<unsigned char*>(storage_) + tensor_index * tensor_bytes +
         block_offset + token_offset * token_bytes;
}

void* PagedKvCache::key_slot_address(std::size_t layer, uint32_t block,
                                     std::size_t token_offset) const {
  return slot_address(false, layer, block, token_offset);
}

void* PagedKvCache::value_slot_address(std::size_t layer, uint32_t block,
                                       std::size_t token_offset) const {
  return slot_address(true, layer, block, token_offset);
}

KvCacheStats PagedKvCache::stats() const {
  std::lock_guard<std::mutex> lock(mutex_);
  KvCacheStats result;
  result.total_blocks = config_.block_count;
  result.free_blocks = free_blocks_.size();
  result.used_blocks = result.total_blocks - result.free_blocks;
  result.active_requests = requests_.size();
  for (const auto& item : requests_) result.allocated_tokens += item.second.tokens;
  return result;
}

}  // namespace neurx::cann
