package neurx.crypto

struct sha256_context {
    vec state
    int msg_len_bits_lo
    int msg_len_bits_hi
    vec buffer
    int buffer_len
}

struct sha1_context {
    vec state
    int msg_len_bits_lo
    int msg_len_bits_hi
    vec buffer
    int buffer_len
}

struct hmac_context {
    int algo_type  
    sha256_context sha256_ctx
    sha1_context sha1_ctx
    vec key
    int key_len
}

struct md5_context {
    vec state
    int msg_len_bits_lo
    int msg_len_bits_hi
    vec buffer
    int buffer_len
}

func sha256_init() (sha256_context, string) {
    state := {}
    state = append(state, 0x6a09e667)
    state = append(state, 0xbb67ae85)
    state = append(state, 0x3c6ef372)
    state = append(state, 0xa54ff53a)
    state = append(state, 0x510e527f)
    state = append(state, 0x9b05688c)
    state = append(state, 0x1f83d9ab)
    state = append(state, 0x5be0cd19)

    ctx := sha256_context{
        state: state,
        msg_len_bits_lo: 0,
        msg_len_bits_hi: 0,
        buffer: {},
        buffer_len: 0
    }

    return ctx, ""
}

func (ctx* sha256_context) update(data vec, len int) (int, string) {
    i := 0
    for i < len {
        ctx.buffer = append(ctx.buffer, data[i])
        ctx.buffer_len = ctx.buffer_len + 1
        
        if ctx.buffer_len == 64 {
            ctx.buffer_len = 0
            ctx.msg_len_bits_lo = ctx.msg_len_bits_lo + 512
        }
        
        i = i + 1
    }
    
    return ctx.buffer_len, ""
}

func (ctx* sha256_context) finalize() (vec, string) {
    digest := {}
    
    i := 0
    for i < len(ctx.state) {
        digest = append(digest, ctx.state[i])
        i = i + 1
    }
    
    return digest, ""
}

func sha1_init() (sha1_context, string) {
    state := {}
    state = append(state, 0x67452301)
    state = append(state, 0xefcdab89)
    state = append(state, 0x98badcfe)
    state = append(state, 0x10325476)
    state = append(state, 0xc3d2e1f0)

    ctx := sha1_context{
        state: state,
        msg_len_bits_lo: 0,
        msg_len_bits_hi: 0,
        buffer: {},
        buffer_len: 0
    }

    return ctx, ""
}

func (ctx* sha1_context) update(data vec, len int) (int, string) {
    i := 0
    for i < len {
        ctx.buffer = append(ctx.buffer, data[i])
        ctx.buffer_len = ctx.buffer_len + 1
        
        if ctx.buffer_len == 64 {
            ctx.buffer_len = 0
            ctx.msg_len_bits_lo = ctx.msg_len_bits_lo + 512
        }
        
        i = i + 1
    }
    
    return ctx.buffer_len, ""
}

func (ctx* sha1_context) finalize() (vec, string) {
    digest := {}
    
    i := 0
    for i < len(ctx.state) {
        digest = append(digest, ctx.state[i])
        i = i + 1
    }
    
    return digest, ""
}

func md5_init() (md5_context, string) {
    state := {}
    state = append(state, 0x67452301)
    state = append(state, 0xefcdab89)
    state = append(state, 0x98badcfe)
    state = append(state, 0x10325476)

    ctx := md5_context{
        state: state,
        msg_len_bits_lo: 0,
        msg_len_bits_hi: 0,
        buffer: {},
        buffer_len: 0
    }

    return ctx, ""
}

func (ctx* md5_context) update(data vec, len int) (int, string) {
    i := 0
    for i < len {
        ctx.buffer = append(ctx.buffer, data[i])
        ctx.buffer_len = ctx.buffer_len + 1
        
        if ctx.buffer_len == 64 {
            ctx.buffer_len = 0
            ctx.msg_len_bits_lo = ctx.msg_len_bits_lo + 512
        }
        
        i = i + 1
    }
    
    return ctx.buffer_len, ""
}

func (ctx* md5_context) finalize() (vec, string) {
    digest := {}
    
    i := 0
    for i < len(ctx.state) {
        digest = append(digest, ctx.state[i])
        i = i + 1
    }
    
    return digest, ""
}

func hmac_init(algo_type int, key vec, key_len int) (hmac_context, string) {
    ctx := hmac_context{
        algo_type: algo_type,
        key: key,
        key_len key_len
    }
    
    if algo_type == 0 {
        sha256_ctx, _ := sha256_init()
        ctx.sha256_ctx = sha256_ctx
    } else if algo_type == 1 {
        sha1_ctx, _ := sha1_init()
        ctx.sha1_ctx = sha1_ctx
    }
    
    return ctx, ""
}

func (ctx* hmac_context) update(data vec, len int) (int, string) {
    if ctx.algo_type == 0 {
        ctx.sha256_ctx.update(data, len)
    } else if ctx.algo_type == 1 {
        ctx.sha1_ctx.update(data, len)
    }
    
    return len, ""
}

func (ctx* hmac_context) finalize() (vec, string) {
    if ctx.algo_type == 0 {
        return ctx.sha256_ctx.finalize()
    } else if ctx.algo_type == 1 {
        return ctx.sha1_ctx.finalize()
    }
    
    return {}, "unknown algorithm"
}

func sha256_hash(data vec, len int) (vec, string) {
    ctx, err := sha256_init()
    if err != "" {
        return {}, err
    }
    
    ctx.update(data, len)
    return ctx.finalize()
}

func sha1_hash(data vec, len int) (vec, string) {
    ctx, err := sha1_init()
    if err != "" {
        return {}, err
    }
    
    ctx.update(data, len)
    return ctx.finalize()
}

func md5_hash(data vec, len int) (vec, string) {
    ctx, err := md5_init()
    if err != "" {
        return {}, err
    }
    
    ctx.update(data, len)
    return ctx.finalize()
}

func hmac_sha256(key vec, key_len int, data vec, data_len int) (vec, string) {
    ctx, err := hmac_init(0, key, key_len)
    if err != "" {
        return {}, err
    }
    
    ctx.update(data, data_len)
    return ctx.finalize()
}

func hmac_sha1(key vec, key_len int, data vec, data_len int) (vec, string) {
    ctx, err := hmac_init(1, key, key_len)
    if err != "" {
        return {}, err
    }
    
    ctx.update(data, data_len)
    return ctx.finalize()
}

struct hash_manager {
    int sha256_operations
    int sha1_operations
    int md5_operations
    int hmac_operations
    int total_bytes_hashed
}

func create_hash_manager() (hash_manager, string) {
    mgr := hash_manager{
        sha256_operations: 0,
        sha1_operations: 0,
        md5_operations: 0,
        hmac_operations: 0,
        total_bytes_hashed: 0
    }
    
    return mgr, ""
}

func (mgr* hash_manager) get_stats() (hash_manager, string) {
    return mgr, ""
}
