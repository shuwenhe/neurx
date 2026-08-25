package attention


    standard
    flash_attention
    dsa
    paged_attention
    sparse_attention
}

struct attention_config {
    int num_heads
    int head_dim
    bool use_flash_attention
    bool use_paged_kv_cache
    bool use_sparse_patterns
    string precision
    int max_seq_length
    bool enable_cache
}

struct attention_backend {
    attention_backend_type backend_type
    string backend_name
    bool initialized
    attention_config config
    map[string, string] metadata
}

struct attention_forward_request {
    string request_id
    int batch_size
    int seq_length
    int num_heads
    int head_dim
    bool use_cache
    int cache_seq_length
}

struct attention_forward_result {
    bool success
    string error_msg
    int64 computation_time_us
    int flops
}

struct key_value_cache {
    string cache_id
    string dtype
    vec[int64] shape
    bool is_paged
    int num_pages
    int page_size
    int64 bytes_allocated
}

func new_attention_config(int num_heads, int head_dim) attention_config {
    attention_config {
        num_heads: num_heads,
        head_dim: head_dim,
        use_flash_attention: true,
        use_paged_kv_cache: false,
        use_sparse_patterns: false,
        precision: "float16",
        max_seq_length: 4096,
        enable_cache: true,
    }
}

func new_attention_backend(attention_backend_type backend_type, attention_config config) attention_backend {
    backend_name := ""
    switch backend_type {
        attention_backend_type::standard : backend_name = "standard",
        attention_backend_type::flash_attention : backend_name = "flash_attention",
        attention_backend_type::dsa : backend_name = "dsa",
        attention_backend_type::paged_attention : backend_name = "paged_attention",
        attention_backend_type::sparse_attention : backend_name = "sparse_attention",
    }

    attention_backend {
        backend_type: backend_type,
        backend_name: backend_name,
        initialized: false,
        config: config,
        metadata: map[string, string]{},
    }
}

func (attention_backend* backend) initialize() bool {
    if backend.initialized {
        false
    }

    backend.initialized = true
    true
}

func (attention_backend* backend) finalize() bool {
    if !backend.initialized {
        false
    }

    backend.initialized = false
    true
}

func (attention_backend* backend) is_initialized() bool {
    backend.initialized
}

func (attention_backend* backend) get_backend_name() string {
    backend.backend_name
}

func (attention_backend* backend) get_num_heads() int {
    backend.config.num_heads
}

func (attention_backend* backend) get_head_dim() int {
    backend.config.head_dim
}

func (attention_backend* backend) supports_cache() bool {
    backend.config.enable_cache
}

func (attention_backend* backend) supports_flash_attention() bool {
    backend.config.use_flash_attention
}

func (attention_backend* backend) forward(attention_forward_request req) attention_forward_result {
    if !backend.initialized {
        attention_forward_result {
            success: false,
            error_msg: "backend not initialized",
            computation_time_us: 0,
            flops: 0,
        }
    }

    attention_forward_result {
        success: true,
        error_msg: "",
        computation_time_us: 0,
        flops: 0,
    }
}

func (attention_backend* backend) set_metadata(string key, string value) () {
    backend.metadata[key] = value
}

func (attention_backend* backend) get_metadata(string key) string {
    if key in backend.metadata {
        backend.metadata[key]
    }

    ""
}

func new_kv_cache(string cache_id, string dtype, vec[int64] shape, bool is_paged) key_value_cache {
    cache := key_value_cache {
        cache_id: cache_id,
        dtype: dtype,
        shape: shape,
        is_paged: is_paged,
        num_pages: 0,
        page_size: 0,
        bytes_allocated: 0,
    }

    if is_paged {
        cache.page_size = 4096
        total_elements := 1
        i := 0
        for i < shape.len() {
            total_elements = total_elements * shape[i]
            i = i + 1
        }
        cache.num_pages = (total_elements + cache.page_size - 1) / cache.page_size
        cache.bytes_allocated = total_elements * 2
    }

    cache
}

func (key_value_cache* cache) get_cache_id() string {
    cache.cache_id
}

func (key_value_cache* cache) get_num_pages() int {
    cache.num_pages
}

func (key_value_cache* cache) get_bytes_allocated() int64 {
    cache.bytes_allocated
}

func (key_value_cache* cache) is_paged() bool {
    cache.is_paged
}
