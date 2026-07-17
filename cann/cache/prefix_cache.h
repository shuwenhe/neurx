#pragma once

#include "paged_kv_cache.h"

#include <cstddef>
#include <cstdint>
#include <list>
#include <mutex>
#include <string>
#include <vector>

namespace neurx::cann {

struct PrefixCacheConfig {
  std::size_t max_entries = 256;
  std::size_t max_retained_blocks = 128;
};

struct PrefixCacheStats {
  std::size_t entries = 0;
  std::size_t retained_blocks = 0;
  uint64_t lookups = 0;
  uint64_t hits = 0;
  uint64_t evictions = 0;
};

struct PrefixCacheHit {
  bool matched = false;
  std::size_t token_count = 0;
};

// Retains immutable, complete KV blocks and aliases them into new requests.
// Partial blocks are deliberately excluded because subsequent decode writes
// would otherwise modify KV state shared by multiple requests.
class PrefixCache {
 public:
  PrefixCache(PagedKvCache* cache, PrefixCacheConfig config = {});
  ~PrefixCache();
  PrefixCache(const PrefixCache&) = delete;
  PrefixCache& operator=(const PrefixCache&) = delete;

  Status insert(const std::string& request_id,
                const std::vector<int32_t>& tokens);
  Status attach_longest(const std::string& request_id,
                        const std::vector<int32_t>& tokens,
                        std::size_t maximum_prefix_tokens,
                        PrefixCacheHit* hit);
  void ensure_free_blocks(std::size_t required_free_blocks);
  void clear();
  PrefixCacheStats stats() const;

 private:
  struct Entry {
    std::vector<int32_t> tokens;
    std::vector<uint32_t> blocks;
  };

  using Entries = std::list<Entry>;
  void evict_lru_locked();

  PagedKvCache* cache_ = nullptr;
  PrefixCacheConfig config_;
  mutable std::mutex mutex_;
  Entries entries_;
  std::size_t retained_blocks_ = 0;
  uint64_t lookups_ = 0;
  uint64_t hits_ = 0;
  uint64_t evictions_ = 0;
};

}  // namespace neurx::cann
