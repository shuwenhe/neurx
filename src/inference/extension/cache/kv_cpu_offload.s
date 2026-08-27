package neurx.cache.kv_cpu_offload

use std.slices
use std.option.option
use std.result.result
use std.map.map


    gpu,
    cpu,
    disk,
}

struct cache_config {
    max_gpu_memory_mb: int
    max_cpu_memory_mb: int
    offload_threshold_mb: int
    enable_pinned_memory: bool
    enable_compression: bool
}

struct kv_cache_stats {
    gpu_used_mb: int
    cpu_used_mb: int
    disk_used_mb: int
    offload_count: int
    restore_count: int
    avg_offload_time_ms: float
    avg_restore_time_ms: float
}

struct cache_metadata {
    sequence_id: int
    layer_id: int
    token_position: int
    device: device_type
    gpu_offset: int
    cpu_offset: int
    size_bytes: int
    compressed: bool
}

struct kv_cache_entry {
    key: vec[float]
    value: vec[float]
    metadata: cache_metadata
}

struct kv_cache_pool {
    gpu_cache: map[int, kv_cache_entry]
    cpu_cache: map[int, kv_cache_entry]
    metadata_map: map[int, cache_metadata]
    config: cache_config
    stats: kv_cache_stats
}

func kv_cache_pool::new(cache_config config) kv_cache_pool {
    kv_cache_pool {
        gpu_cache: map[int, kv_cache_entry](),
        cpu_cache: map[int, kv_cache_entry](),
        metadata_map: map[int, cache_metadata](),
        config: config,
        stats: kv_cache_stats {
            gpu_used_mb: 0,
            cpu_used_mb: 0,
            disk_used_mb: 0,
            offload_count: 0,
            restore_count: 0,
            avg_offload_time_ms: 0.0,
            avg_restore_time_ms: 0.0,
        },
    }
}

func calculate_entry_size(*vec[float] k, *vec[float] v) int {
    (k.len() + v.len()) * 4
}

func (kv_cache_pool* pool) put_kv(
    sequence_id: int,
    layer_id: int,
    token_position: int,
    key: *vec[float],
    value: *vec[float]
) ((), error) {
    cache_key := sequence_id * 1000000 + layer_id * 1000 + token_position
    entry_size := calculate_entry_size(key, value)

    metadata := cache_metadata {
        sequence_id: sequence_id,
        layer_id: layer_id,
        token_position: token_position,
        device: device_type::gpu,
        gpu_offset: 0,
        cpu_offset: 0,
        size_bytes: entry_size,
        compressed: false,
    }

    gpu_budget_exceeded := pool.stats.gpu_used_mb + (entry_size / 1024 / 1024) > pool.config.max_gpu_memory_mb

    if gpu_budget_exceeded {
        pool.try_offload_to_cpu()
    }

    entry := kv_cache_entry {
        key: key,
        value: value,
        metadata: metadata,
    }

    pool.gpu_cache.insert(cache_key, entry)
    pool.metadata_map.insert(cache_key, metadata)
    pool.stats.gpu_used_mb = pool.stats.gpu_used_mb + (entry_size / 1024 / 1024)

    ((, ""))
}

func (kv_cache_pool* pool) get_kv(
    sequence_id: int,
    layer_id: int,
    token_position: int
) (kv_cache_entry, error) {
    cache_key := sequence_id * 1000000 + layer_id * 1000 + token_position

    if pool.gpu_cache.contains(cache_key) {
        switch pool.gpu_cache.get(cache_key) {
            option::some(entry) : {
                (entry, "")
            },
            option::none : {
                (0, error { code: "CACHE_MISS", message: "Entry not found in GPU cache" })
            },
        }
    } else if pool.cpu_cache.contains(cache_key) {
        pool.restore_from_cpu(cache_key)

        switch pool.gpu_cache.get(cache_key) {
            option::some(entry) : {
                (entry, "")
            },
            option::none : {
                (0, error { code: "RESTORE_FAILED", message: "Failed to restore from CPU" })
            },
        }
    } else {
        (0, error { code: "CACHE_MISS", message: "Entry not found" })
    }
}

func (kv_cache_pool* pool) try_offload_to_cpu() ((), error) {
    gpu_entries := pool.gpu_cache

    oldest_key := 0
    oldest_pos := 999999

    for key in gpu_entries.keys() {
        switch pool.metadata_map.get(key) {
            option::some(meta) : {
                if meta.token_position < oldest_pos {
                    oldest_key = key
                    oldest_pos = meta.token_position
                }
            },
            option::none : {},
        }
    }

    if oldest_key != 0 {
        switch pool.gpu_cache.get(oldest_key) {
            option::some(entry) : {
                pool.cpu_cache.insert(oldest_key, entry)
                pool.gpu_cache.remove(oldest_key)

                entry_size := entry.metadata.size_bytes
                pool.stats.gpu_used_mb = pool.stats.gpu_used_mb - (entry_size / 1024 / 1024)
                pool.stats.cpu_used_mb = pool.stats.cpu_used_mb + (entry_size / 1024 / 1024)
                pool.stats.offload_count = pool.stats.offload_count + 1

                ((, ""))
            },
            option::none : {
                (0, error { code: "OFFLOAD_FAILED", message: "Failed to offload entry" })
            },
        }
    } else {
        (0, error { code: "NO_ENTRY_TO_OFFLOAD", message: "No entry to offload" })
    }
}

func (kv_cache_pool* pool) restore_from_cpu(int cache_key) ((), error) {
    switch pool.cpu_cache.get(cache_key) {
        option::some(entry) : {
            pool.gpu_cache.insert(cache_key, entry)
            pool.cpu_cache.remove(cache_key)

            entry_size := entry.metadata.size_bytes
            pool.stats.cpu_used_mb = pool.stats.cpu_used_mb - (entry_size / 1024 / 1024)
            pool.stats.gpu_used_mb = pool.stats.gpu_used_mb + (entry_size / 1024 / 1024)
            pool.stats.restore_count = pool.stats.restore_count + 1

            ((, ""))
        },
        option::none : {
            (0, error { code: "RESTORE_FAILED", message: "Entry not found in CPU cache" })
        },
    }
}

func (pool* pool) get_stats() kv_cache_stats {
    pool.stats
}

func (pool* pool) get_memory_usage_percent() float {
    total_used := pool.stats.gpu_used_mb + pool.stats.cpu_used_mb
    total_available := pool.config.max_gpu_memory_mb + pool.config.max_cpu_memory_mb

    (total_used as float) / (total_available as float) * 100.0
}

func (pool* pool) get_cache_hit_rate() float {
    total_accesses := pool.stats.offload_count + pool.stats.restore_count

    if total_accesses == 0 {
        return 0.0
    }

    (pool.stats.restore_count as float) / (total_accesses as float)
}

func (kv_cache_pool* pool) clear_sequence_cache(int sequence_id) ((), error) {
    keys_to_remove := vec[int]()

    for key in pool.gpu_cache.keys() {
        key_seq_id := key / 1000000
        if key_seq_id == sequence_id {
            keys_to_remove.push(key)
        }
    }

    i := 0
    for i < keys_to_remove.len() {
        key := keys_to_remove[i]

        switch pool.gpu_cache.get(key) {
            option::some(entry) : {
                entry_size := entry.metadata.size_bytes
                pool.stats.gpu_used_mb = pool.stats.gpu_used_mb - (entry_size / 1024 / 1024)
                pool.gpu_cache.remove(key)
            },
            option::none : {},
        }

        i = i + 1
    }

    ((, ""))
}

func (kv_cache_pool* pool) clear_all() ((), error) {
    pool.gpu_cache = map[int, kv_cache_entry]()
    pool.cpu_cache = map[int, kv_cache_entry]()
    pool.metadata_map = map[int, cache_metadata]()

    pool.stats.gpu_used_mb = 0
    pool.stats.cpu_used_mb = 0

    ((, ""))
}

struct error {
    code: string
    message: string
}

func main() {
    config := cache_config {
        max_gpu_memory_mb: 4096,
        max_cpu_memory_mb: 16384,
        offload_threshold_mb: 3072,
        enable_pinned_memory: true,
        enable_compression: false,
    }

    pool := kv_cache_pool::new(config)

    key := vec[float]()
    value := vec[float]()

    i := 0
    for i < 1024 {
        key.push(0.1)
        value.push(0.2)
        i = i + 1
    }

    switch pool.put_kv(0, 0, 0, key, value) {
        ((, "")) : {
            ""
        },
        (0, err) : {
            ""
        },
    }

    stats := pool.get_stats()
    usage := pool.get_memory_usage_percent()
    hit_rate := pool.get_cache_hit_rate()
}
