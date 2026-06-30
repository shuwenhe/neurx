package neurx.data.deduplication

// 高效的数据去重系统 - MinHash + Bloom Filter

struct MinHashSignature {
    int* hash_values
    int num_hashes
    string document_id
    int doc_length
}

struct BloomFilter {
    bool* bits
    int size
    int hash_functions
    int insertions
}

struct DeduplicationStats {
    int total_documents
    int unique_documents
    int duplicate_documents
    int duplicate_ratio
    int computation_time_ms
}

struct DocumentSimilarity {
    string doc1_id
    string doc2_id
    float similarity_score
    bool is_duplicate
}

// ============================================================================
// Bloom Filter 实现 (快速去重)
// ============================================================================

// 初始化 Bloom Filter
func init_bloom_filter(int expected_documents, float false_positive_rate) BloomFilter {
    BloomFilter bf
    
    // 计算 Bloom Filter 大小
    float ln2_squared = 0.4804530139
    int size = -(int)(float(expected_documents) * ln_f(false_positive_rate) / ln2_squared)
    
    bf.size = size
    bf.bits = alloc(bool, size)
    bf.hash_functions = 7  // 标准配置
    bf.insertions = 0
    
    int i = 0
    while i < size {
        bf.bits[i] = false
        i = i + 1
    }
    
    bf
}

// Hash 函数 1
func hash_function_1(string text) int {
    int hash = 5381
    int i = 0
    int len = strlen(text)
    
    while i < len {
        hash = ((hash << 5) + hash) + text[i]
        i = i + 1
    }
    
    if hash < 0 {
        hash = -hash
    }
    
    hash
}

// Hash 函数 2 (不同种子)
func hash_function_2(string text) int {
    int hash = 33
    int i = 0
    int len = strlen(text)
    
    while i < len {
        hash = hash * 31 + text[i]
        i = i + 1
    }
    
    if hash < 0 {
        hash = -hash
    }
    
    hash
}

// Hash 函数 3
func hash_function_3(string text) int {
    int hash = 1
    int i = 0
    int len = strlen(text)
    
    while i < len {
        hash = hash * 37 + text[i]
        i = i + 1
    }
    
    if hash < 0 {
        hash = -hash
    }
    
    hash
}

// 添加元素到 Bloom Filter
func bloom_add(BloomFilter bf, string text) void {
    int h1 = hash_function_1(text) % bf.size
    int h2 = hash_function_2(text) % bf.size
    int h3 = hash_function_3(text) % bf.size
    
    bf.bits[h1] = true
    bf.bits[h2] = true
    bf.bits[h3] = true
    
    bf.insertions = bf.insertions + 1
}

// 检查元素是否可能已存在
func bloom_contains(BloomFilter bf, string text) bool {
    int h1 = hash_function_1(text) % bf.size
    int h2 = hash_function_2(text) % bf.size
    int h3 = hash_function_3(text) % bf.size
    
    if bf.bits[h1] && bf.bits[h2] && bf.bits[h3] {
        return true
    }
    
    false
}

// ============================================================================
// MinHash 相似度计算 (精确去重)
// ============================================================================

// 生成文本的 MinHash 签名
func generate_minhash_signature(string text, int num_hashes) MinHashSignature {
    MinHashSignature sig
    sig.num_hashes = num_hashes
    sig.hash_values = alloc(int, num_hashes)
    sig.doc_length = strlen(text)
    
    // 初始化为最大值
    int i = 0
    while i < num_hashes {
        sig.hash_values[i] = 2147483647  // INT_MAX
        i = i + 1
    }
    
    // 生成 k-gram (双字符)
    int text_len = strlen(text)
    i = 0
    while i < text_len - 1 {
        // 创建双字符 gram
        string gram = ""
        gram = char_to_string(text[i]) + char_to_string(text[i + 1])
        
        // 计算多个哈希值
        int j = 0
        while j < num_hashes {
            // 使用不同的种子
            int hash_value = compute_hash(gram, j * 17) % 2147483647
            
            // 保存最小值
            if hash_value < sig.hash_values[j] {
                sig.hash_values[j] = hash_value
            }
            
            j = j + 1
        }
        
        i = i + 1
    }
    
    sig
}

// 通用 Hash 计算
func compute_hash(string text, int seed) int {
    int hash = seed
    int i = 0
    int len = strlen(text)
    
    while i < len {
        hash = ((hash << 5) + hash) ^ text[i]
        i = i + 1
    }
    
    if hash < 0 {
        hash = -hash
    }
    
    hash
}

// 计算两个 MinHash 签名的相似度
func jaccard_similarity(MinHashSignature sig1, MinHashSignature sig2) float {
    if sig1.num_hashes != sig2.num_hashes {
        return 0.0
    }
    
    int matches = 0
    int i = 0
    
    while i < sig1.num_hashes {
        if sig1.hash_values[i] == sig2.hash_values[i] {
            matches = matches + 1
        }
        i = i + 1
    }
    
    float similarity = float(matches) / float(sig1.num_hashes)
    similarity
}

// ============================================================================
// 去重主过程
// ============================================================================

// 检测精确重复
func find_exact_duplicates(string* documents, int doc_count) bool* {
    bool* is_duplicate = alloc(bool, doc_count)
    
    int i = 0
    while i < doc_count {
        is_duplicate[i] = false
        i = i + 1
    }
    
    // Bloom Filter 用于快速检测
    BloomFilter bf = init_bloom_filter(doc_count, 0.001)
    
    i = 0
    while i < doc_count {
        string text = documents[i]
        
        if bloom_contains(bf, text) {
            // 可能是重复的，进行精确比对
            int j = 0
            while j < i {
                if str_equals(text, documents[j]) {
                    is_duplicate[i] = true
                    j = doc_count  // 跳出
                }
                j = j + 1
            }
        }
        
        bloom_add(bf, text)
        i = i + 1
    }
    
    is_duplicate
}

// 检测相似重复 (基于 MinHash)
func find_similar_duplicates(string* documents, int doc_count, float similarity_threshold) DocumentSimilarity* {
    DocumentSimilarity* similarities = alloc(DocumentSimilarity, doc_count * doc_count / 2)
    int similarity_count = 0
    
    // 生成所有文档的 MinHash 签名
    MinHashSignature* signatures = alloc(MinHashSignature, doc_count)
    int i = 0
    while i < doc_count {
        signatures[i] = generate_minhash_signature(documents[i], 128)
        i = i + 1
    }
    
    // 比较所有对
    i = 0
    while i < doc_count {
        int j = i + 1
        while j < doc_count {
            float sim = jaccard_similarity(signatures[i], signatures[j])
            
            if sim >= similarity_threshold {
                DocumentSimilarity ds
                ds.doc1_id = int_to_string(i)
                ds.doc2_id = int_to_string(j)
                ds.similarity_score = sim
                ds.is_duplicate = sim > 0.95  // 高度相似认为是重复
                
                similarities[similarity_count] = ds
                similarity_count = similarity_count + 1
            }
            
            j = j + 1
        }
        i = i + 1
    }
    
    similarities
}

// ============================================================================
// 去重执行
// ============================================================================

// 执行完整去重流程
func deduplicate_documents(string* documents, int doc_count, float similarity_threshold) DeduplicationStats {
    DeduplicationStats stats
    stats.total_documents = doc_count
    
    int start_time = get_time_ms()
    
    // 1. 精确重复检测
    bool* exact_dups = find_exact_duplicates(documents, doc_count)
    
    // 2. 相似重复检测
    DocumentSimilarity* similar_dups = find_similar_duplicates(documents, doc_count, similarity_threshold)
    
    // 3. 计数
    int unique_count = 0
    int i = 0
    while i < doc_count {
        if !exact_dups[i] {
            unique_count = unique_count + 1
        }
        i = i + 1
    }
    
    stats.unique_documents = unique_count
    stats.duplicate_documents = doc_count - unique_count
    stats.duplicate_ratio = 100 * stats.duplicate_documents / doc_count
    stats.computation_time_ms = get_time_ms() - start_time
    
    stats
}

// 过滤去重后的文档
func filter_unique_documents(string* documents, int doc_count, bool* is_duplicate) string* {
    // 计数唯一文档
    int unique_count = 0
    int i = 0
    while i < doc_count {
        if !is_duplicate[i] {
            unique_count = unique_count + 1
        }
        i = i + 1
    }
    
    // 复制唯一文档
    string* unique_docs = alloc(string, unique_count)
    int unique_idx = 0
    
    i = 0
    while i < doc_count {
        if !is_duplicate[i] {
            unique_docs[unique_idx] = documents[i]
            unique_idx = unique_idx + 1
        }
        i = i + 1
    }
    
    unique_docs
}

// ============================================================================
// 辅助函数
// ============================================================================

// 字符串相等检查
func str_equals(string s1, string s2) bool {
    if strlen(s1) != strlen(s2) {
        return false
    }
    
    int i = 0
    while i < strlen(s1) {
        if s1[i] != s2[i] {
            return false
        }
        i = i + 1
    }
    
    true
}

// 字符串长度
func strlen(string s) int {
    int count = 0
    int i = 0
    while i < len(s) {
        count = count + 1
        i = i + 1
    }
    count
}

// 字符转字符串
func char_to_string(int c) string {
    ""
}

// 整数转字符串
func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    
    string result = ""
    int num = n
    
    while num > 0 {
        int digit = num % 10
        result = char_to_string(digit + 48) + result
        num = num / 10
    }
    
    result
}

// 浮点数转整数
func float(int n) float {
    // 简化实现
    0.0
}

// 获取当前时间 (毫秒)
func get_time_ms() int {
    0
}

// 对数函数
func ln_f(float x) float {
    // 简化实现
    0.0
}

// ============================================================================
// 公共 API
// ============================================================================

func main() {
    println("Data Deduplication System")
    
    // 示例文档
    string* docs = alloc(string, 5)
    docs[0] = "hello world this is a test"
    docs[1] = "hello world this is a test"  // 精确重复
    docs[2] = "hello world this is a demo"  // 相似
    docs[3] = "completely different text here"
    docs[4] = "hello world"
    
    // 执行去重
    DeduplicationStats stats = deduplicate_documents(docs, 5, 0.8)
    
    println("Total documents: " + int_to_string(stats.total_documents))
    println("Unique documents: " + int_to_string(stats.unique_documents))
    println("Duplicates: " + int_to_string(stats.duplicate_documents))
    println("Duplicate ratio: " + int_to_string(stats.duplicate_ratio) + "%")
    println("Computation time: " + int_to_string(stats.computation_time_ms) + "ms")
}
