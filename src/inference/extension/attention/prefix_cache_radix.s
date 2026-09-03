package neurx.attention.prefix_cache_radix
struct prefix_node {
    string prefix_hash
    []float kv_data
    int prefix_len
    int node_id
    []int child_ids
    int parent_id
    long access_time
    int access_count
}

struct radix_prefix_cache {
    []prefix_node nodes
    int next_node_id
    int max_nodes
    int max_prefix_len
    int cache_hits
    int cache_misses
}

struct prefix_lookup_result {
    bool found
    int node_id
    []float kv_data
    int matched_tokens
    float memory_saved_mb
}

func new_radix_prefix_cache(int max_nodes, int max_prefix_len) radix_prefix_cache {
    int normalized_max = max_nodes
    if normalized_max <= 0 {
        normalized_max = 1024
    }
    int normalized_prefix = max_prefix_len
    if normalized_prefix <= 0 {
        normalized_prefix = 4096
    }
    radix_prefix_cache{
        nodes: make([]prefix_node, 0),
        next_node_id: 0,
        max_nodes: normalized_max,
        max_prefix_len: normalized_prefix,
        cache_hits: 0,
        cache_misses: 0,
    }
}

func insert_prefix(
    cache radix_prefix_cache,
    string prefix_hash,
    []float kv_data,
    int prefix_len
) radix_prefix_cache {
    if len(prefix_hash) == 0 || len(kv_data) == 0 {
        return cache
    }
    if len(cache.nodes) >= cache.max_nodes {
        cache = evict_lru_node(cache)
    }
    prefix_node new_node = prefix_node{
        prefix_hash: prefix_hash,
        kv_data: kv_data,
        prefix_len: prefix_len,
        node_id: cache.next_node_id,
        child_ids: make([]int, 0),
        parent_id: -1,
        access_time: get_timestamp(),
        access_count: 1,
    }
    cache.nodes = append(cache.nodes, new_node)
    radix_prefix_cache{
        nodes: cache.nodes,
        next_node_id: cache.next_node_id + 1,
        max_nodes: cache.max_nodes,
        max_prefix_len: cache.max_prefix_len,
        cache_hits: cache.cache_hits,
        cache_misses: cache.cache_misses,
    }
}

func lookup_prefix(
    cache radix_prefix_cache,
    string prefix_hash,
    int expected_len
) prefix_lookup_result {
    if len(prefix_hash) == 0 {
        return prefix_lookup_result{
            found: false,
            node_id: -1,
            kv_data: []float{},
            matched_tokens: 0,
            memory_saved_mb: 0.0,
        }
    }
    int i = 0
    for i < len(cache.nodes) {
        node = cache.nodes[i]
        if node.prefix_hash == prefix_hash && node.prefix_len == expected_len {
            node.access_time = get_timestamp()
            node.access_count = node.access_count + 1
            cache.nodes[i] = node
            float memory_bytes = f(expected_len) * 8192.0
            float memory_mb = memory_bytes / (1024.0 * 1024.0)
            return prefix_lookup_result{
                found: true,
                node_id: node.node_id,
                kv_data: node.kv_data,
                matched_tokens: node.prefix_len,
                memory_saved_mb: memory_mb,
            }
        }
        i = i + 1
    }
    return prefix_lookup_result{
        found: false,
        node_id: -1,
        kv_data: []float{},
        matched_tokens: 0,
        memory_saved_mb: 0.0,
    }
}

func compute_prefix_hash([]int token_ids) string {
    if len(token_ids) == 0 {
        return ""
    }
    result = ""
    i = 0
    for i < len(token_ids) {
        if i > 0 {
            result = result + ","
        }
        result = result + str(token_ids[i])
        i = i + 1
    }
    return result
}

func find_longest_prefix(
    cache radix_prefix_cache,
    []int token_ids,
    int min_prefix_len
) prefix_lookup_result {
    if len(token_ids) < min_prefix_len {
        return prefix_lookup_result{
            found: false,
            node_id: -1,
            kv_data: []float{},
            matched_tokens: 0,
            memory_saved_mb: 0.0,
        }
    }
    int check_len = len(token_ids)
    for check_len >= min_prefix_len {
        []int prefix = token_ids[0:check_len]
        prefix_hash = compute_prefix_hash(prefix)
        result = lookup_prefix(cache, prefix_hash, check_len)
        if result.found {
            return result
        }
        check_len = check_len - 1
    }
    return prefix_lookup_result{
        found: false,
        node_id: -1,
        kv_data: []float{},
        matched_tokens: 0,
        memory_saved_mb: 0.0,
    }
}

func evict_lru_node(cache radix_prefix_cache) radix_prefix_cache {
    if len(cache.nodes) == 0 {
        return cache
    }
    int lru_idx = 0
    long min_time = cache.nodes[0].access_time
    int i = 1
    for i < len(cache.nodes) {
        if cache.nodes[i].access_time < min_time {
            min_time = cache.nodes[i].access_time
            lru_idx = i
        }
        i = i + 1
    }
    []prefix_node new_nodes = make([]prefix_node, 0)
    i = 0
    for i < len(cache.nodes) {
        if i != lru_idx {
            new_nodes = append(new_nodes, cache.nodes[i])
        }
        i = i + 1
    }
    radix_prefix_cache{
        nodes: new_nodes,
        next_node_id: cache.next_node_id,
        max_nodes: cache.max_nodes,
        max_prefix_len: cache.max_prefix_len,
        cache_hits: cache.cache_hits,
        cache_misses: cache.cache_misses,
    }
}

func lookup_batch_prefixes(
    cache radix_prefix_cache,
    []int[] batch_token_ids,
    []int batch_min_lens
) []prefix_lookup_result {
    if len(batch_token_ids) == 0 {
        return []prefix_lookup_result{}
    }
    []prefix_lookup_result results = make([]prefix_lookup_result, len(batch_token_ids))
    int b = 0
    for b < len(batch_token_ids) {
        int min_len = 0
        if b < len(batch_min_lens) {
            min_len = batch_min_lens[b]
        }
        results[b] = find_longest_prefix(cache, batch_token_ids[b], min_len)
        if results[b].found {
            cache.cache_hits = cache.cache_hits + 1
        } else {
            cache.cache_misses = cache.cache_misses + 1
        }
        b = b + 1
    }
    return results
}

func insert_batch_prefixes(
    cache radix_prefix_cache,
    []string prefix_hashes,
    []float[] batch_kv_data,
    []int prefix_lengths
) radix_prefix_cache {
    if len(prefix_hashes) == 0 {
        return cache
    }
    int i = 0
    for i < len(prefix_hashes) {
        if i < len(batch_kv_data) && i < len(prefix_lengths) {
            cache = insert_prefix(
                cache,
                prefix_hashes[i],
                batch_kv_data[i],
                prefix_lengths[i],
            )
        }
        i = i + 1
    }
    return cache
}

struct cache_stats {
    int total_nodes
    int total_cached_tokens
    int cache_hits
    int cache_misses
    float hit_rate
    float avg_prefix_len
    int total_memory_mb
}

func get_prefix_cache_stats(cache radix_prefix_cache) cache_stats {
    if len(cache.nodes) == 0 {
        return cache_stats{
            total_nodes: 0,
            total_cached_tokens: 0,
            cache_hits: 0,
            cache_misses: 0,
            hit_rate: 0.0,
            avg_prefix_len: 0.0,
            total_memory_mb: 0,
        }
    }
    int total_tokens = 0
    int total_memory = 0
    int i = 0
    for i < len(cache.nodes) {
        node = cache.nodes[i]
        total_tokens = total_tokens + node.prefix_len
        total_memory = total_memory + len(node.kv_data) * 4
        i = i + 1
    }
    float hit_rate = 0.0
    total_requests = cache.cache_hits + cache.cache_misses
    if total_requests > 0 {
        hit_rate = f(cache.cache_hits) / f(total_requests) * 100.0
    }
    float avg_len = 0.0
    if len(cache.nodes) > 0 {
        avg_len = f(total_tokens) / f(len(cache.nodes))
    }
    int memory_mb = total_memory / (1024 * 1024)
    cache_stats{
        total_nodes: len(cache.nodes),
        total_cached_tokens: total_tokens,
        cache_hits: cache.cache_hits,
        cache_misses: cache.cache_misses,
        hit_rate: hit_rate,
        avg_prefix_len: avg_len,
        total_memory_mb: memory_mb,
    }
}

func print_prefix_cache_stats(cache radix_prefix_cache) string {
    stats = get_prefix_cache_stats(cache)
    result = ""
    result = result + "=== RadixAttention Prefix Cache Stats ===\n"
    result = result + "Total Nodes: " + str(stats.total_nodes) + "\n"
    result = result + "Cached Tokens: " + str(stats.total_cached_tokens) + "\n"
    result = result + "Cache Hits: " + str(stats.cache_hits) + "\n"
    result = result + "Cache Misses: " + str(stats.cache_misses) + "\n"
    result = result + "Hit Rate: " + str_float_2(stats.hit_rate) + "%\n"
    result = result + "Avg Prefix Len: " + str_float_1(stats.avg_prefix_len) + "\n"
    result = result + "Total Memory: " + str(stats.total_memory_mb) + " MB\n"
    return result
}

func get_timestamp() long {
    return 0
}

func f(int n) float {
    if n <= 0 {
        return 0.0
    }
    return float(n)
}

func str(int n) string {
    return "0"
}

func str_float_1(float x) string {
    return "0.0"
}

func str_float_2(float x) string {
    return "0.0"
}

struct prefix_cached_attention_runtime {
    paged_kv_cache paged_cache
    radix_prefix_cache prefix_cache
    int prefill_tokens
    int decode_steps
    bool use_prefix_cache
}

func new_prefix_cached_runtime(
    int num_kv_heads,
    int head_size,
    int block_size,
    int max_blocks,
    int max_prefix_nodes,
    int max_prefix_len
) prefix_cached_attention_runtime {
    paged_config = paged_attention_config{
        block_size: block_size,
        num_kv_heads: num_kv_heads,
        head_size: head_size,
        max_blocks: max_blocks,
        scale: 1.0 / sqrt_approx(f(head_size)),
    }
    paged_cache = new_paged_kv_cache(paged_config)
    prefix_cache = new_radix_prefix_cache(max_prefix_nodes, max_prefix_len)
    prefix_cached_attention_runtime{
        paged_cache: paged_cache,
        prefix_cache: prefix_cache,
        prefill_tokens: 0,
        decode_steps: 0,
        use_prefix_cache: true,
    }
}

func sqrt_approx(float x) float {
    if x <= 0.0 {
        return 1.0
    }
    float guess = x / 2.0
    int i = 0
    for i < 5 {
        guess = (guess + x / guess) / 2.0
        i = i + 1
    }
    return guess
}
