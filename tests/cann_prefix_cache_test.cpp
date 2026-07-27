#include "../cann/cache/prefix_cache.h"

#include <cassert>
#include <cstdio>
#include <new>
#include <vector>

namespace {

class HostAllocator final : public neurx::cann::DeviceAllocator {
 public:
  neurx::cann::status allocate(void** address, std::size_t bytes) override {
    *address = ::operator new(bytes, std::nothrow);
    return *address ? neurx::cann::status::success()
                    : neurx::cann::status::failure("allocation failed");
  }
  void release(void* address) override { ::operator delete(address); }
};

}

int main() {
  HostAllocator allocator;
  neurx::cann::PagedKvCache kv({8, 64, 4}, &allocator);
  assert(kv.initialize().ok);
  neurx::cann::prefix_cache_config config;
  config.max_entries = 2;
  config.max_retained_blocks = 6;
  neurx::cann::PrefixCache prefixes(&kv, config);

  const std::vector<int32_t> prompt = {
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
  assert(kv.reserve("source", prompt.size()).ok);
  const auto source_blocks = kv.block_table("source");
  assert(source_blocks.size() == 3);
  assert(prefixes.insert("source", prompt).ok);
  assert(prefixes.stats().entries == 1);
  assert(prefixes.stats().retained_blocks == 3);

  assert(kv.release("source"));
  assert(kv.stats().used_blocks == 3);
  neurx::cann::prefix_cache_hit hit;
  assert(prefixes.attach_longest("target", prompt, prompt.size() - 1, &hit).ok);
  assert(hit.matched && hit.token_count == 8);
  assert(kv.token_count("target") == 8);
  const auto target_blocks = kv.block_table("target");
  assert(target_blocks.size() == 2);
  assert(target_blocks[0] == source_blocks[0]);
  assert(target_blocks[1] == source_blocks[1]);

  assert(kv.reserve("target", prompt.size()).ok);
  assert(kv.block_table("target").size() == 3);
  assert(kv.release("target"));
  prefixes.ensure_free_blocks(8);
  assert(kv.stats().free_blocks == 8);
  assert(prefixes.stats().entries == 0);
  assert(prefixes.stats().hits == 1);
  assert(prefixes.stats().evictions == 1);

  std::printf("cann-prefix-cache PASS\n");
  return 0;
}
