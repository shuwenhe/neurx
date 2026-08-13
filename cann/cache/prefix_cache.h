#pragma once
#include "paged_kv_cache.h"
#include <cstddef>
#include <cstdint>
#include <list>
#include <mutex>
#include <string>
#include <vector>
namespace neurx::cann {

struct prefix_cache_config {
  std::size_t max_entries = 256;
  std::size_t max_retained_blocks = 128;
};

struct prefix_cache_stats {
  std::size_t entries = 0;
  std::size_t retained_blocks = 0;
  uint64_t lookups = 0;
  uint64_t hits = 0;
  uint64_t evictions = 0;
};

struct prefix_cache_hit {
  bool matched = false;
  std::size_t token_count = 0;
};
class prefix_cache {
 public:
  prefix_cache(paged_kv_cache* cache, prefix_cache_config config = {});
  ~prefix_cache();
  prefix_cache(const prefix_cache&) = delete;
  prefix_cache& operator=(const prefix_cache&) = delete;
  status insert(const std::string& request_id,
                const std::vector<int32_t>& tokens);
  status attach_longest(const std::string& request_id,
                        const std::vector<int32_t>& tokens,
                        std::size_t maximum_prefix_tokens,
                        prefix_cache_hit* hit);
  void ensure_free_blocks(std::size_t required_free_blocks);
  void clear();
  prefix_cache_stats stats() const;
 private:
  struct entry {
    std::vector<int32_t> tokens;
    std::vector<uint32_t> blocks;
  };
  using entries = std::list<entry>;
  void evict_lru_locked();
  paged_kv_cache* cache_ = nullptr;
  prefix_cache_config config_;
  mutable std::mutex mutex_;
  entries entries_;
  std::size_t retained_blocks_ = 0;
  uint64_t lookups_ = 0;
  uint64_t hits_ = 0;
  uint64_t evictions_ = 0;
};
}
