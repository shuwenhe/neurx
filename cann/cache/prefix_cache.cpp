#include "prefix_cache.h"

#include <algorithm>

namespace neurx::cann {

PrefixCache::PrefixCache(PagedKvCache* cache, PrefixCacheConfig config)
    : cache_(cache), config_(config) {}

PrefixCache::~PrefixCache() { clear(); }

Status PrefixCache::insert(const std::string& request_id,
                           const std::vector<int32_t>& tokens) {
  if (!cache_) return Status::failure("prefix cache has no KV cache");
  if (config_.max_entries == 0 || config_.max_retained_blocks == 0) {
    return Status::success();
  }
  const std::size_t block_tokens = cache_->config().tokens_per_block;
  const std::size_t cached_tokens =
      (tokens.size() / block_tokens) * block_tokens;
  if (cached_tokens == 0) return Status::success();
  const std::size_t block_count = cached_tokens / block_tokens;
  if (block_count > config_.max_retained_blocks) return Status::success();

  std::vector<int32_t> key(tokens.begin(), tokens.begin() + cached_tokens);
  std::lock_guard<std::mutex> lock(mutex_);
  for (auto entry = entries_.begin(); entry != entries_.end(); ++entry) {
    if (entry->tokens == key) {
      entries_.splice(entries_.begin(), entries_, entry);
      return Status::success();
    }
  }

  std::vector<uint32_t> retained;
  Status status = cache_->retain_prefix(request_id, cached_tokens, &retained);
  if (!status.ok) return status;
  retained_blocks_ += retained.size();
  entries_.push_front({std::move(key), std::move(retained)});
  while (entries_.size() > config_.max_entries ||
         retained_blocks_ > config_.max_retained_blocks) {
    evict_lru_locked();
  }
  return Status::success();
}

Status PrefixCache::attach_longest(
    const std::string& request_id, const std::vector<int32_t>& tokens,
    std::size_t maximum_prefix_tokens, PrefixCacheHit* hit) {
  if (!hit) return Status::failure("prefix cache hit output is null");
  *hit = {};
  if (!cache_) return Status::failure("prefix cache has no KV cache");
  std::lock_guard<std::mutex> lock(mutex_);
  ++lookups_;
  auto best = entries_.end();
  std::size_t best_tokens = 0;
  const std::size_t block_tokens = cache_->config().tokens_per_block;
  maximum_prefix_tokens =
      (maximum_prefix_tokens / block_tokens) * block_tokens;
  for (auto entry = entries_.begin(); entry != entries_.end(); ++entry) {
    const std::size_t candidate_tokens =
        std::min(entry->tokens.size(), maximum_prefix_tokens);
    if (candidate_tokens <= best_tokens || candidate_tokens > tokens.size()) {
      continue;
    }
    if (std::equal(entry->tokens.begin(),
                   entry->tokens.begin() + candidate_tokens,
                   tokens.begin())) {
      best = entry;
      best_tokens = candidate_tokens;
    }
  }
  if (best == entries_.end()) return Status::success();
  const std::size_t best_blocks = best_tokens / block_tokens;
  const std::vector<uint32_t> blocks(best->blocks.begin(),
                                     best->blocks.begin() + best_blocks);
  Status status = cache_->attach_retained_prefix(
      request_id, blocks, best_tokens);
  if (!status.ok) return status;
  entries_.splice(entries_.begin(), entries_, best);
  ++hits_;
  hit->matched = true;
  hit->token_count = best_tokens;
  return Status::success();
}

void PrefixCache::evict_lru_locked() {
  if (entries_.empty()) return;
  Entry& entry = entries_.back();
  cache_->release_retained_blocks(entry.blocks);
  retained_blocks_ -= entry.blocks.size();
  entries_.pop_back();
  ++evictions_;
}

void PrefixCache::ensure_free_blocks(std::size_t required_free_blocks) {
  std::lock_guard<std::mutex> lock(mutex_);
  while (!entries_.empty() &&
         cache_->stats().free_blocks < required_free_blocks) {
    evict_lru_locked();
  }
}

void PrefixCache::clear() {
  std::lock_guard<std::mutex> lock(mutex_);
  while (!entries_.empty()) {
    Entry& entry = entries_.back();
    if (cache_) cache_->release_retained_blocks(entry.blocks);
    entries_.pop_back();
  }
  retained_blocks_ = 0;
}

PrefixCacheStats PrefixCache::stats() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return {entries_.size(), retained_blocks_, lookups_, hits_, evictions_};
}

}  // namespace neurx::cann
