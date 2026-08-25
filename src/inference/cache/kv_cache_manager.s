package neurx.inference.kv_cache_manager

func kv_cache_remove_int([]int values, int expected) []int {
    []int result = []int{}
    int i = 0
    for i < len(values) {
        if values[i] != expected {
            result = append(result, values[i])
        }
        i = i + 1
    }
    result
}

func kv_cache_contains_int([]int values, int expected) bool {
    int i = 0
    for i < len(values) {
        if values[i] == expected {
            return true
        }
        i = i + 1
    }
    false
}

func kv_cache_append_unique([]int values, int value) []int {
    if kv_cache_contains_int(values, value) {
        return values
    }
    append(values, value)
}

func kv_cache_find_oldest_page_from_list(paged_kv_cache cache, []int page_ids) int {
    if len(page_ids) == 0 {
        return -1
    }
    int oldest_page = page_ids[0]
    int oldest_step = cache.pages[oldest_page].last_accessed_step
    int i = 1
    for i < len(page_ids) {
        int page_id = page_ids[i]
        int step = cache.pages[page_id].last_accessed_step
        if step < oldest_step {
            oldest_step = step
            oldest_page = page_id
        }
        i = i + 1
    }
    oldest_page
}

struct page_config {
    int page_size_tokens
    int num_pages
    int token_dim
    int num_heads
}

struct cache_page {
    int page_id
    int used_tokens
    int capacity_tokens
    bool is_full
    int last_accessed_step
    []float k_data
    []float v_data
}

struct paged_kv_cache {
    []cache_page pages
    []int free_pages
    []int allocated_pages
    page_config config
    int total_allocated_tokens
}

struct kv_cache_config {
    int page_size_tokens
    int max_total_tokens
    string eviction_policy
    int num_pages
}

func new_kv_cache_config() kv_cache_config {
    kv_cache_config {
        page_size_tokens: 16,
        max_total_tokens: 1000000,
        eviction_policy: "lru",
        num_pages: 0,
    }
}

func new_paged_kv_cache(kv_cache_config cfg) paged_kv_cache {
    int num_pages = cfg.max_total_tokens / cfg.page_size_tokens
    if num_pages <= 0 {
        num_pages = 1
    }
    []cache_page pages = []cache_page{cap: num_pages}
    []int free_pages = []int{cap: num_pages}
    int i = 0
    for i < num_pages {
        pages[i] = cache_page {
            page_id: i,
            used_tokens: 0,
            capacity_tokens: cfg.page_size_tokens,
            is_full: false,
            last_accessed_step: 0,
            k_data: []float{cap: cfg.page_size_tokens * 128},
            v_data: []float{cap: cfg.page_size_tokens * 128},
        }
        free_pages[i] = i
        i = i + 1
    }
    paged_kv_cache {
        pages: pages,
        free_pages: free_pages,
        allocated_pages: []int{},
        config: page_config {
            page_size_tokens: cfg.page_size_tokens,
            num_pages: num_pages,
            token_dim: 128,
            num_heads: 32,
        },
        total_allocated_tokens: 0,
    }
}

func allocate_pages(paged_kv_cache cache, int num_tokens_needed) []int {
    int pages_needed = (num_tokens_needed + cache.config.page_size_tokens - 1) / cache.config.page_size_tokens
    if pages_needed <= 0 {
        return []int{}
    }
    []int allocated = []int{}
    []int free_pool = kv_cache_remove_int(cache.free_pages, -1)
    []int allocated_pool = kv_cache_remove_int(cache.allocated_pages, -1)
    int i = 0
    for i < pages_needed {
        int page_id = -1
        if len(free_pool) > 0 {
            page_id = free_pool[len(free_pool) - 1]
            free_pool = kv_cache_remove_int(free_pool, page_id)
        } else {
            page_id = kv_cache_find_oldest_page_from_list(cache, allocated_pool)
            if page_id >= 0 {
                allocated_pool = kv_cache_remove_int(allocated_pool, page_id)
            }
        }
        if page_id < 0 {
            break
        }
        allocated = append(allocated, page_id)
        i = i + 1
    }
    allocated
}

func free_pages(paged_kv_cache cache, []int page_ids) paged_kv_cache {
    int i = 0
    for i < len(page_ids) {
        int page_id = page_ids[i]
        if page_id >= 0 && page_id < len(cache.pages) {
            cache.total_allocated_tokens = cache.total_allocated_tokens - cache.pages[page_id].used_tokens
            if cache.total_allocated_tokens < 0 {
                cache.total_allocated_tokens = 0
            }
            cache.pages[page_id].used_tokens = 0
            cache.pages[page_id].is_full = false
            cache.pages[page_id].last_accessed_step = cache.pages[page_id].last_accessed_step + 1
            cache.free_pages = kv_cache_append_unique(kv_cache_remove_int(cache.free_pages, page_id), page_id)
            cache.allocated_pages = kv_cache_remove_int(cache.allocated_pages, page_id)
        }
        i = i + 1
    }
    compress_kv_cache(cache)
}

func evict_page(paged_kv_cache cache) int {
    if len(cache.allocated_pages) == 0 {
        if len(cache.free_pages) > 0 {
            return cache.free_pages[0]
        }
        return -1
    }
    int oldest_page = cache.allocated_pages[0]
    int oldest_step = cache.pages[oldest_page].last_accessed_step
    int i = 1
    for i < len(cache.allocated_pages) {
        int page_id = cache.allocated_pages[i]
        int step = cache.pages[page_id].last_accessed_step
        if step < oldest_step {
            oldest_step = step
            oldest_page = page_id
        }
        i = i + 1
    }
    oldest_page
}

func update_cache_usage(paged_kv_cache cache, int page_id, int new_tokens) paged_kv_cache {
    if page_id < 0 || page_id >= len(cache.pages) {
        return cache
    }
    int normalized_tokens = new_tokens
    if normalized_tokens < 0 {
        normalized_tokens = 0
    }
    cache.pages[page_id].used_tokens = normalized_tokens
    cache.pages[page_id].is_full = normalized_tokens >= cache.pages[page_id].capacity_tokens
    cache.pages[page_id].last_accessed_step = cache.pages[page_id].last_accessed_step + 1
    cache
}

func get_cache_stats(paged_kv_cache cache) map[string]int {
    map[string]int stats
    stats["total_pages"] = len(cache.pages)
    stats["free_pages"] = len(cache.free_pages)
    stats["allocated_pages"] = len(cache.allocated_pages)
    stats["total_allocated_tokens"] = cache.total_allocated_tokens
    stats["page_size_tokens"] = cache.config.page_size_tokens
    stats["num_heads"] = cache.config.num_heads
    stats["token_dim"] = cache.config.token_dim
    stats
}

func compress_kv_cache(paged_kv_cache cache) paged_kv_cache {
    []int rebuilt_free = []int{}
    []int rebuilt_allocated = []int{}
    int total_tokens = 0
    int i = 0
    for i < len(cache.pages) {
        int used_tokens = cache.pages[i].used_tokens
        if used_tokens < 0 {
            used_tokens = 0
        }
        if used_tokens > cache.pages[i].capacity_tokens {
            used_tokens = cache.pages[i].capacity_tokens
        }
        cache.pages[i].used_tokens = used_tokens
        cache.pages[i].is_full = used_tokens >= cache.pages[i].capacity_tokens
        if used_tokens > 0 {
            rebuilt_allocated = append(rebuilt_allocated, i)
            total_tokens = total_tokens + used_tokens
        } else {
            rebuilt_free = append(rebuilt_free, i)
        }
        i = i + 1
    }
    cache.free_pages = rebuilt_free
    cache.allocated_pages = rebuilt_allocated
    cache.total_allocated_tokens = total_tokens
    cache
}

func prefill_cache(paged_kv_cache cache, []int prompt_tokens) paged_kv_cache {
    int tokens_remaining = len(prompt_tokens)
    if tokens_remaining <= 0 {
        return compress_kv_cache(cache)
    }
    []int page_ids = allocate_pages(cache, tokens_remaining)
    int i = 0
    for i < len(page_ids) && tokens_remaining > 0 {
        int page_id = page_ids[i]
        int write_tokens = tokens_remaining
        if write_tokens > cache.pages[page_id].capacity_tokens {
            write_tokens = cache.pages[page_id].capacity_tokens
        }
        cache.pages[page_id].used_tokens = write_tokens
        cache.pages[page_id].is_full = write_tokens >= cache.pages[page_id].capacity_tokens
        cache.pages[page_id].last_accessed_step = cache.pages[page_id].last_accessed_step + 1
        tokens_remaining = tokens_remaining - write_tokens
        i = i + 1
    }
    compress_kv_cache(cache)
}

func append_token_to_cache(paged_kv_cache cache, int token_id) paged_kv_cache {
    int target_page = -1
    if len(cache.allocated_pages) > 0 {
        target_page = cache.allocated_pages[len(cache.allocated_pages) - 1]
        if cache.pages[target_page].used_tokens >= cache.pages[target_page].capacity_tokens {
            target_page = -1
        }
    }
    if target_page < 0 {
        []int page_ids = allocate_pages(cache, 1)
        if len(page_ids) > 0 {
            target_page = page_ids[0]
        }
    }
    if target_page < 0 {
        return cache
    }
    cache.pages[target_page].used_tokens = cache.pages[target_page].used_tokens + 1
    cache.pages[target_page].is_full = cache.pages[target_page].used_tokens >= cache.pages[target_page].capacity_tokens
    cache.pages[target_page].last_accessed_step = cache.pages[target_page].last_accessed_step + 1
    compress_kv_cache(cache)
}
