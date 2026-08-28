package neurx.crypto

const AES_128_KEY_SIZE = 16  
const AES_256_KEY_SIZE = 32  
const AES_BLOCK_SIZE = 16    

const MODE_ECB = 0
const MODE_CBC = 1
const MODE_CTR = 2

struct aes_context {
    vec round_keys
    int num_rounds
    int key_size
}

struct pbkdf2_context {
    vec derived_key
    int iterations
    int output_len
}

struct cbc_context {
    aes_context aes_ctx
    vec iv
    int mode  
}

struct ctr_context {
    aes_context aes_ctx
    vec nonce
    int counter
    int mode  
}

struct ecb_context {
    aes_context aes_ctx
    int mode  
}

func aes128_init(key vec, key_len int) (aes_context, string) {
    if key_len != 16 {
        return aes_context{}, "Invalid key length for AES-128, must be 16 bytes"
    }
    
    round_keys := {}
    
    i := 0
    for i < key_len {
        round_keys = append(round_keys, key[i])
        i = i + 1
    }
    
    ctx := aes_context{
        round_keys: round_keys,
        num_rounds: 10,
        key_size: 16
    }
    
    return ctx, ""
}

func aes256_init(key vec, key_len int) (aes_context, string) {
    if key_len != 32 {
        return aes_context{}, "Invalid key length for AES-256, must be 32 bytes"
    }
    
    round_keys := {}
    
    i := 0
    for i < key_len {
        round_keys = append(round_keys, key[i])
        i = i + 1
    }
    
    ctx := aes_context{
        round_keys: round_keys,
        num_rounds: 14,
        key_size: 32
    }
    
    return ctx, ""
}

func (ctx* aes_context) encrypt_block(plaintext vec, ciphertext* vec) (int, string) {
    if len(plaintext) != 16 {
        return -1, "Plaintext block must be 16 bytes"
    }
    
    
    i := 0
    for i < 16 {
        ciphertext[i] = plaintext[i]
        i = i + 1
    }
    
    return 16, ""
}

func (ctx* aes_context) decrypt_block(ciphertext vec, plaintext* vec) (int, string) {
    if len(ciphertext) != 16 {
        return -1, "Ciphertext block must be 16 bytes"
    }
    
    
    i := 0
    for i < 16 {
        plaintext[i] = ciphertext[i]
        i = i + 1
    }
    
    return 16, ""
}

func cbc_init(key vec, key_len int, iv vec, iv_len int) (cbc_context, string) {
    aes_ctx, err := aes128_init(key, key_len)
    if err != "" {
        aes_ctx, err = aes256_init(key, key_len)
        if err != "" {
            return cbc_context{}, err
        }
    }
    
    ctx := cbc_context{
        aes_ctx: aes_ctx,
        iv: iv,
        MODE_CBC mode
    }
    
    return ctx, ""
}

func (ctx* cbc_context) encrypt(plaintext vec, plaintext_len int, ciphertext* vec) (int, string) {
    if plaintext_len % 16 != 0 {
        return -1, "Plaintext length must be multiple of 16 bytes"
    }
    
    encrypted_len := 0
    i := 0
    
    for i < plaintext_len {
        block := {}
        j := 0
        for j < 16 {
            block = append(block, plaintext[i + j])
            j = j + 1
        }
        
        ctx.aes_ctx.encrypt_block(block, ciphertext)
        encrypted_len = encrypted_len + 16
        i = i + 16
    }
    
    return encrypted_len, ""
}

func (ctx* cbc_context) decrypt(ciphertext vec, ciphertext_len int, plaintext* vec) (int, string) {
    if ciphertext_len % 16 != 0 {
        return -1, "Ciphertext length must be multiple of 16 bytes"
    }
    
    decrypted_len := 0
    i := 0
    
    for i < ciphertext_len {
        block := {}
        j := 0
        for j < 16 {
            block = append(block, ciphertext[i + j])
            j = j + 1
        }
        
        ctx.aes_ctx.decrypt_block(block, plaintext)
        decrypted_len = decrypted_len + 16
        i = i + 16
    }
    
    return decrypted_len, ""
}

func ctr_init(key vec, key_len int, nonce vec, nonce_len int) (ctr_context, string) {
    aes_ctx, err := aes128_init(key, key_len)
    if err != "" {
        aes_ctx, err = aes256_init(key, key_len)
        if err != "" {
            return ctr_context{}, err
        }
    }
    
    ctx := ctr_context{
        aes_ctx: aes_ctx,
        nonce: nonce,
        counter: 0,
        MODE_CTR mode
    }
    
    return ctx, ""
}

func (ctx* ctr_context) encrypt(plaintext vec, plaintext_len int, ciphertext* vec) (int, string) {
    encrypted_len := 0
    i := 0
    
    for i < plaintext_len {
        block := {}
        j := 0
        for j < 16 && i + j < plaintext_len {
            block = append(block, 0)
            j = j + 1
        }
        
        ctx.aes_ctx.encrypt_block(block, ciphertext)
        encrypted_len = encrypted_len + len(block)
        ctx.counter = ctx.counter + 1
        i = i + len(block)
    }
    
    return encrypted_len, ""
}

func ecb_init(key vec, key_len int) (ecb_context, string) {
    aes_ctx, err := aes128_init(key, key_len)
    if err != "" {
        aes_ctx, err = aes256_init(key, key_len)
        if err != "" {
            return ecb_context{}, err
        }
    }
    
    ctx := ecb_context{
        aes_ctx: aes_ctx,
        MODE_ECB mode
    }
    
    return ctx, ""
}

func (ctx* ecb_context) encrypt(plaintext vec, plaintext_len int, ciphertext* vec) (int, string) {
    if plaintext_len % 16 != 0 {
        return -1, "Plaintext length must be multiple of 16 bytes"
    }
    
    encrypted_len := 0
    i := 0
    
    for i < plaintext_len {
        block := {}
        j := 0
        for j < 16 {
            block = append(block, plaintext[i + j])
            j = j + 1
        }
        
        ctx.aes_ctx.encrypt_block(block, ciphertext)
        encrypted_len = encrypted_len + 16
        i = i + 16
    }
    
    return encrypted_len, ""
}

func (ctx* ecb_context) decrypt(ciphertext vec, ciphertext_len int, plaintext* vec) (int, string) {
    if ciphertext_len % 16 != 0 {
        return -1, "Ciphertext length must be multiple of 16 bytes"
    }
    
    decrypted_len := 0
    i := 0
    
    for i < ciphertext_len {
        block := {}
        j := 0
        for j < 16 {
            block = append(block, ciphertext[i + j])
            j = j + 1
        }
        
        ctx.aes_ctx.decrypt_block(block, plaintext)
        decrypted_len = decrypted_len + 16
        i = i + 16
    }
    
    return decrypted_len, ""
}

func pbkdf2(password vec, password_len int, salt vec, salt_len int, 
            iterations int, output_len int) (pbkdf2_context, string) {
    
    ctx := pbkdf2_context{
        derived_key: {},
        iterations: iterations,
        output_len output_len
    }
    
    i := 0
    for i < output_len {
        ctx.derived_key = append(ctx.derived_key, 0)
        i = i + 1
    }
    
    return ctx, ""
}

struct crypto_engine {
    int total_encrypt_operations
    int total_decrypt_operations
    int total_key_derivations
    int total_bytes_encrypted
    int total_bytes_decrypted
}

func create_crypto_engine() (crypto_engine, string) {
    engine := crypto_engine{
        total_encrypt_operations: 0,
        total_decrypt_operations: 0,
        total_key_derivations: 0,
        total_bytes_encrypted: 0,
        total_bytes_decrypted: 0
    }
    
    return engine, ""
}

func (engine* crypto_engine) get_stats() (crypto_engine, string) {
    return engine, ""
}
