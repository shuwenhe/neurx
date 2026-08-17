package neurx.inference.kv_cache_optimize

struct kv_cache_config {
    int page_size_tokens
    int max_pages
    int token_dim
    bool enable_prefix_caching
    bool enable_page_fusion
    float cache_hit_threshold
    string eviction_policy
}

struct kv_cache_page {
    int page_id
    int used_tokens
    int max_tokens
    []float key_data
    []float value_data
    int last_accessed_step
    int access_count
}

struct kv_cache_statistics {
    int total_pages
    int active_pages
    int free_pages
    float cache_hit_rate
    float memory_utilization
    int total_tokens_cached
    int total_evictions
    float avg_page_age
}

struct kv_cache_optimizer {
    []kv_cache_page pages
    kv_cache_config config
    kv_cache_statistics stats
    []int free_page_list
    []int lru_order
    int current_step
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    string output = ""
    int n = value
    string sign = ""
    if n < 0 {
        sign = "-"
        n = 0 - n
    }
    string digits = "0123456789"
    string tmp = ""
    while n > 0 {
        int digit = n - (n / 10) * 10
        tmp = string_slice(digits, digit, digit + 1) + tmp
        n = n / 10
    }
    sign + tmp
}

func string_slice(string text, int start, int end) string {
    string result = ""
    int i = start
    while i < end && i < len(text) {
        result = result + string_char(text[i])
        i = i + 1
    }
    result
}

func string_char(int code) string {
    if code == 10 { return "\n" }
    if code == 32 { return " " }
    ""
}

func create_default_kv_config() kv_cache_config {
    kv_cache_config{
        page_size_tokens: 16,
        max_pages: 256,
        token_dim: 896,
        enable_prefix_caching: true,
        enable_page_fusion: true,
        cache_hit_threshold: 0.7,
        eviction_policy: "lru"
    }
}

func create_kv_cache_optimizer(kv_cache_config config) kv_cache_optimizer {
    kv_cache_optimizer opt = kv_cache_optimizer{
        pages: []kv_cache_page{cap: config.max_pages},
        config: config,
        stats: kv_cache_statistics{
            total_pages: 0,
            active_pages: 0,
            free_pages: config.max_pages,
            cache_hit_rate: 0.0,
            memory_utilization: 0.0,
            total_tokens_cached: 0,
            total_evictions: 0,
            avg_page_age: 0.0
        },
        free_page_list: []int{cap: config.max_pages},
        lru_order: []int{cap: config.max_pages},
        current_step: 0
    }

    int i = 0
    while i < config.max_pages {
        opt.free_page_list = append(opt.free_page_list, i)
        i = i + 1
    }

    opt
}

func allocate_kv_page(kv_cache_optimizer* opt) int {
    if len(opt.free_page_list) == 0 {
        return -1
    }

    int page_id = opt.free_page_list[len(opt.free_page_list) - 1]
    opt.free_page_list = opt.free_page_list[0 : len(opt.free_page_list) - 1]

    kv_cache_page page = kv_cache_page{
        page_id: page_id,
        used_tokens: 0,
        max_tokens: opt.config.page_size_tokens,
        key_data: []float{cap: opt.config.page_size_tokens * opt.config.token_dim},
        value_data: []float{cap: opt.config.page_size_tokens * opt.config.token_dim},
        last_accessed_step: opt.current_step,
        access_count: 0
    }

    if page_id < len(opt.pages) {
        opt.pages[page_id] = page
    } else {
        opt.pages = append(opt.pages, page)
    }

    opt.stats.active_pages = opt.stats.active_pages + 1
    opt.stats.free_pages = len(opt.free_page_list)

    page_id
}

func free_kv_page(kv_cache_optimizer* opt, int page_id) bool {
    if page_id < 0 || page_id >= len(opt.pages) {
        return false
    }

    opt.free_page_list = append(opt.free_page_list, page_id)
    opt.stats.active_pages = opt.stats.active_pages - 1
    opt.stats.free_pages = len(opt.free_page_list)
    opt.stats.total_evictions = opt.stats.total_evictions + 1

    true
}

func find_lru_page(kv_cache_optimizer opt) int {
    if len(opt.pages) == 0 {
        return -1
    }

    int lru_page = 0
    int min_step = opt.pages[0].last_accessed_step

    int i = 1
    while i < len(opt.pages) {
        if opt.pages[i].last_accessed_step < min_step && opt.pages[i].used_tokens > 0 {
            min_step = opt.pages[i].last_accessed_step
            lru_page = i
        }
        i = i + 1
    }

    lru_page
}

func evict_page_if_needed(kv_cache_optimizer* opt) bool {
    if opt.stats.free_pages > 0 {
        return true
    }

    if opt.config.eviction_policy == "lru" {
        int lru_page = find_lru_page(*opt)
        if lru_page >= 0 {
            return free_kv_page(opt, lru_page)
        }
    }

    false
}

func add_kv_tokens(
    kv_cache_optimizer* opt,
    []float key_tokens,
    []float value_tokens
) bool {
    if len(key_tokens) == 0 {
        return true
    }

    if !evict_page_if_needed(opt) {
        return false
    }

    int page_id = allocate_kv_page(opt)
    if page_id < 0 {
        return false
    }

    int num_tokens = len(key_tokens) / opt.config.token_dim
    if num_tokens > opt.config.page_size_tokens {
        num_tokens = opt.config.page_size_tokens
    }

    opt.pages[page_id].used_tokens = num_tokens
    opt.pages[page_id].access_count = 1
    opt.stats.total_tokens_cached = opt.stats.total_tokens_cached + num_tokens

    true
}

func access_kv_page(kv_cache_optimizer* opt, int page_id) bool {
    if page_id < 0 || page_id >= len(opt.pages) {
        return false
    }

    opt.pages[page_id].last_accessed_step = opt.current_step
    opt.pages[page_id].access_count = opt.pages[page_id].access_count + 1

    true
}

func update_cache_statistics(kv_cache_optimizer* opt) {
    opt.stats.total_pages = len(opt.pages)

    int total_tokens = 0
    int total_age = 0

    int i = 0
    while i < len(opt.pages) {
        if opt.pages[i].used_tokens > 0 {
            total_tokens = total_tokens + opt.pages[i].used_tokens
            int age = opt.current_step - opt.pages[i].last_accessed_step
            total_age = total_age + age
        }
        i = i + 1
    }

    if opt.stats.active_pages > 0 {
        opt.stats.avg_page_age = float(total_age) / float(opt.stats.active_pages)
    }

    opt.stats.total_tokens_cached = total_tokens

    int max_tokens = opt.config.max_pages * opt.config.page_size_tokens
    if max_tokens > 0 {
        opt.stats.memory_utilization = float(total_tokens) / float(max_tokens)
    }
}

func estimate_memory_usage(kv_cache_optimizer opt) int {
    int bytes_per_token = opt.config.token_dim * 2
    int total_bytes = opt.stats.total_tokens_cached * bytes_per_token
    total_bytes / 1024 / 1024
}

func optimize_cache_layout(kv_cache_optimizer* opt) {
    update_cache_statistics(opt)

    if opt.stats.memory_utilization > 0.9 {
        println("⚠️  Cache approaching capacity: " + float_to_string(opt.stats.memory_utilization) + "%")

        int pages_to_evict = (opt.stats.active_pages / 4)

        int i = 0
        while i < pages_to_evict && i < len(opt.pages) {
            if opt.pages[i].used_tokens > 0 {
                free_kv_page(opt, i)
            }
            i = i + 1
        }
    }

    if opt.config.enable_page_fusion && opt.stats.active_pages > opt.config.max_pages / 2 {
        println("ℹ️  Enabling page fusion optimization")
    }
}

func reset_cache(kv_cache_optimizer* opt) {
    opt.pages = []kv_cache_page{cap: opt.config.max_pages}
    opt.free_page_list = []int{cap: opt.config.max_pages}
    opt.lru_order = []int{cap: opt.config.max_pages}
    opt.current_step = 0
    opt.stats.active_pages = 0
    opt.stats.free_pages = opt.config.max_pages
    opt.stats.total_tokens_cached = 0
    opt.stats.total_evictions = 0

    int i = 0
    while i < opt.config.max_pages {
        opt.free_page_list = append(opt.free_page_list, i)
        i = i + 1
    }
}

func float_to_string(float value) string {
    int int_part = int(value * 100.0)
    string result = int_to_string(int_part / 100) + "."
    int frac = int_part - (int_part / 100) * 100
    if frac < 10 {
        result = result + "0"
    }
    result + int_to_string(frac)
}

func print_cache_statistics(kv_cache_optimizer opt) {
    println("")
    println("╔════════════════════════════════════════════════════════════╗")
    println("║         KV Cache Optimization Statistics                   ║")
    println("╚════════════════════════════════════════════════════════════╝")
    println("")

    println("Cache Configuration:")
    println("  Page Size: " + int_to_string(opt.config.page_size_tokens) + " tokens")
    println("  Max Pages: " + int_to_string(opt.config.max_pages))
    println("  Token Dimension: " + int_to_string(opt.config.token_dim))
    println("  Eviction Policy: " + opt.config.eviction_policy)
    println("")

    println("Cache Statistics:")
    println("  Total Pages: " + int_to_string(opt.stats.total_pages))
    println("  Active Pages: " + int_to_string(opt.stats.active_pages))
    println("  Free Pages: " + int_to_string(opt.stats.free_pages))
    println("  Total Tokens Cached: " + int_to_string(opt.stats.total_tokens_cached))
    println("  Memory Usage: " + int_to_string(estimate_memory_usage(opt)) + " MB")
    println("  Memory Utilization: " + float_to_string(opt.stats.memory_utilization) + "%")
    println("  Average Page Age: " + float_to_string(opt.stats.avg_page_age) + " steps")
    println("  Total Evictions: " + int_to_string(opt.stats.total_evictions))
    println("")
}

func main() {
    println("")
    println("╔════════════════════════════════════════════════════════════╗")
    println("║        KV Cache Optimization Module                        ║")
    println("╚════════════════════════════════════════════════════════════╝")
    println("")

    kv_cache_config config = create_default_kv_config()
    kv_cache_optimizer* opt = &(create_kv_cache_optimizer(config))

    println("Step 1: Allocating KV cache pages")
    println("─────────────────────────────────────────────────────────────")

    int pages_to_allocate = 32
    int i = 0
    while i < pages_to_allocate {
        int page_id = allocate_kv_page(opt)
        if page_id >= 0 {
            println("  ✓ Allocated page " + int_to_string(page_id))
        }
        i = i + 1
    }

    println("")
    println("Step 2: Simulating token caching")
    println("─────────────────────────────────────────────────────────────")

    []float dummy_keys = []float{cap: 1024}
    []float dummy_values = []float{cap: 1024}

    int j = 0
    while j < 10 {
        if add_kv_tokens(opt, dummy_keys, dummy_values) {
            println("  ✓ Added KV tokens for sequence " + int_to_string(j))
        }
        opt.current_step = opt.current_step + 1
        j = j + 1
    }

    println("")
    println("Step 3: Updating cache statistics and optimizing")
    println("─────────────────────────────────────────────────────────────")

    optimize_cache_layout(opt)
    update_cache_statistics(opt)

    println("")
    print_cache_statistics(*opt)

    println("Step 4: Memory Analysis")
    println("─────────────────────────────────────────────────────────────")

    int memory_mb = estimate_memory_usage(*opt)
    println("  Total Memory: " + int_to_string(memory_mb) + " MB")
    println("  Per Token: ~" + int_to_string(config.token_dim * 2 / 1024) + " KB")
    println("")
}
