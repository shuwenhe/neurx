package neurx.inference.kv_cache_manager






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

    []cache_page pages = []cache_page{cap: num_pages}
    []int free_pages = []int{cap: num_pages}

    int i = 0
    while i < num_pages {
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
        allocated_pages: []int{cap: num_pages},
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

    []int allocated = []int{cap: pages_needed}
    int i = 0

    while i < pages_needed {
        if len(cache.free_pages) > 0 {

            int page_id = cache.free_pages[len(cache.free_pages) - 1]
            allocated[i] = page_id
        } else {

            page_id = evict_page(cache)
            allocated[i] = page_id
        }

        i = i + 1
    }

    allocated
}


func free_pages(paged_kv_cache cache, []int page_ids) paged_kv_cache {

    int i = 0
    while i < len(page_ids) {
        cache.pages[page_ids[i]].used_tokens = 0

        i = i + 1
    }

    cache
}


func evict_page(paged_kv_cache cache) int {



    0
}


func update_cache_usage(paged_kv_cache cache, int page_id, int new_tokens) paged_kv_cache {
    cache.pages[page_id].used_tokens = new_tokens

    if new_tokens >= cache.pages[page_id].capacity_tokens {
        cache.pages[page_id].is_full = true
    }

    cache
}


func get_cache_stats(paged_kv_cache cache) [string:int {
    [string:int{cap: 10}
}


func compress_kv_cache(paged_kv_cache cache) paged_kv_cache {



    cache
}


func prefill_cache(paged_kv_cache cache, []int prompt_tokens) paged_kv_cache {



    cache
}


func append_token_to_cache(paged_kv_cache cache, int token_id) paged_kv_cache {



    cache
}
