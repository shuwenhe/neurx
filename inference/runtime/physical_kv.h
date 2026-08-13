#pragma once
#include <cstdint>
#include <map>
#include <mutex>
#include <stdexcept>
#include <string>
#include <vector>
namespace neurx::inference {

struct physical_kv_allocation {
  std::vector<int32_t> block_table;
  std::vector<uintptr_t> device_addresses;
};
class physical_kv_pool {
 public:
  physical_kv_pool(std::size_t blocks, std::size_t block_tokens)
      : block_tokens_(block_tokens), addresses_(blocks), references_(blocks) {
    if (blocks == 0 || block_tokens == 0) throw std::invalid_argument("physical KV dimensions must be positive");
  }
  void bind(std::size_t block, uintptr_t device_address) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (block >= addresses_.size() || device_address == 0) throw std::out_of_range("invalid physical KV binding");
    if (references_[block] != 0) throw std::logic_error("cannot rebind an allocated physical KV block");
    addresses_[block] = device_address;
  }
  physical_kv_allocation allocate(const std::string& request_id, std::size_t tokens) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (request_id.empty() || allocations_.count(request_id) || tokens == 0) {
      throw std::invalid_argument("invalid or duplicate physical KV allocation");
    }
    const std::size_t needed = (tokens + block_tokens_ - 1) / block_tokens_;
    std::vector<int32_t> table;
    for (std::size_t block = 0; block < references_.size() && table.size() < needed; ++block) {
      if (references_[block] == 0 && addresses_[block] != 0) table.push_back(static_cast<int32_t>(block));
    }
    if (table.size() != needed) throw std::runtime_error("physical KV capacity exhausted");
    for (const int32_t block : table) ++references_[static_cast<std::size_t>(block)];
    allocations_.emplace(request_id, table);
    return describe_locked(table);
  }
  physical_kv_allocation share_prefix(const std::string& source, const std::string& target,
                                      std::size_t prefix_tokens) {
    std::lock_guard<std::mutex> lock(mutex_);
    const auto source_allocation = allocations_.find(source);
    if (source_allocation == allocations_.end() || target.empty() || allocations_.count(target) ||
        prefix_tokens == 0) throw std::invalid_argument("invalid physical KV prefix share");
    const std::size_t needed = (prefix_tokens + block_tokens_ - 1) / block_tokens_;
    if (needed > source_allocation->second.size()) throw std::out_of_range("prefix exceeds source KV allocation");
    std::vector<int32_t> table(source_allocation->second.begin(), source_allocation->second.begin() + needed);
    for (const int32_t block : table) ++references_[static_cast<std::size_t>(block)];
    allocations_.emplace(target, table);
    return describe_locked(table);
  }
  void release(const std::string& request_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    const auto allocation = allocations_.find(request_id);
    if (allocation == allocations_.end()) return;
    for (const int32_t block : allocation->second) {
      std::size_t index = static_cast<std::size_t>(block);
      if (references_[index] == 0) throw std::logic_error("physical KV reference count underflow");
      --references_[index];
    }
    allocations_.erase(allocation);
  }
  std::size_t free_blocks() const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::size_t free = 0;
    for (std::size_t i = 0; i < references_.size(); ++i) {
      if (references_[i] == 0 && addresses_[i] != 0) ++free;
    }
    return free;
  }
  uint32_t reference_count(std::size_t block) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (block >= references_.size()) throw std::out_of_range("physical KV block index");
    return references_[block];
  }
 private:
  physical_kv_allocation describe_locked(const std::vector<int32_t>& table) const {
    physical_kv_allocation result;
    result.block_table = table;
    for (const int32_t block : table) result.device_addresses.push_back(addresses_[static_cast<std::size_t>(block)]);
    return result;
  }
  std::size_t block_tokens_;
  std::vector<uintptr_t> addresses_;
  std::vector<uint32_t> references_;
  std::map<std::string, std::vector<int32_t>> allocations_;
  mutable std::mutex mutex_;
};
}
