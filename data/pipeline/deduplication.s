package neurx.data.pipeline.deduplication
struct min_hash_signature {
    int* hash_values
    int num_hashes
    string document_id
    int doc_length
}


struct bloom_filter {
    bool* bits
    int size
    int hash_functions
    int insertions
}


struct deduplication_stats {
    int total_documents
    int unique_documents
    int duplicate_documents
    int duplicate_ratio
    int computation_time_ms
}


struct document_similarity {
    string doc1_id
    string doc2_id
    float similarity_score
    bool is_duplicate
}


func init_bloom_filter(int expected_documents, float false_positive_rate) bloom_filter {
    bloom_filter bf
    float ln2_squared = 0.4804530139
    int size = -(int)(float(expected_documents) * ln_f(false_positive_rate) / ln2_squared)
    bf.size = size
    bf.bits = alloc(bool, size)
    bf.hash_functions = 7
    bf.insertions = 0
    int i = 0
    while i < size {
        bf.bits[i] = false
        i = i + 1
    }
    bf
}


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


func bloom_add(bloom_filter bf, string text) void {
    int h1 = hash_function_1(text) % bf.size
    int h2 = hash_function_2(text) % bf.size
    int h3 = hash_function_3(text) % bf.size
    bf.bits[h1] = true
    bf.bits[h2] = true
    bf.bits[h3] = true
    bf.insertions = bf.insertions + 1
}


func bloom_contains(bloom_filter bf, string text) bool {
    int h1 = hash_function_1(text) % bf.size
    int h2 = hash_function_2(text) % bf.size
    int h3 = hash_function_3(text) % bf.size
    if bf.bits[h1] && bf.bits[h2] && bf.bits[h3] {
        return true
    }
    false
}


func generate_minhash_signature(string text, int num_hashes) min_hash_signature {
    min_hash_signature sig
    sig.num_hashes = num_hashes
    sig.hash_values = alloc(int, num_hashes)
    sig.doc_length = strlen(text)
    int i = 0
    while i < num_hashes {
        sig.hash_values[i] = 2147483647
        i = i + 1
    }
    int text_len = strlen(text)
    i = 0
    while i < text_len - 1 {
        string gram = ""
        gram = char_to_string(text[i]) + char_to_string(text[i + 1])
        int j = 0
        while j < num_hashes {
            int hash_value = compute_hash(gram, j * 17) % 2147483647
            if hash_value < sig.hash_values[j] {
                sig.hash_values[j] = hash_value
            }
            j = j + 1
        }
        i = i + 1
    }
    sig
}


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


func jaccard_similarity(min_hash_signature sig1, min_hash_signature sig2) float {
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


func find_exact_duplicates(string* documents, int doc_count) bool* {
    bool* is_duplicate = alloc(bool, doc_count)
    int i = 0
    while i < doc_count {
        is_duplicate[i] = false
        i = i + 1
    }
    bloom_filter bf = init_bloom_filter(doc_count, 0.001)
    i = 0
    while i < doc_count {
        string text = documents[i]
        if bloom_contains(bf, text) {
            int j = 0
            while j < i {
                if str_equals(text, documents[j]) {
                    is_duplicate[i] = true
                    j = doc_count
                }
                j = j + 1
            }
        }
        bloom_add(bf, text)
        i = i + 1
    }
    is_duplicate
}


func find_similar_duplicates(string* documents, int doc_count, float similarity_threshold) document_similarity* {
    document_similarity* similarities = alloc(document_similarity, doc_count * doc_count / 2)
    int similarity_count = 0
    min_hash_signature* signatures = alloc(min_hash_signature, doc_count)
    int i = 0
    while i < doc_count {
        signatures[i] = generate_minhash_signature(documents[i], 128)
        i = i + 1
    }
    i = 0
    while i < doc_count {
        int j = i + 1
        while j < doc_count {
            float sim = jaccard_similarity(signatures[i], signatures[j])
            if sim >= similarity_threshold {
                document_similarity ds
                ds.doc1_id = int_to_string(i)
                ds.doc2_id = int_to_string(j)
                ds.similarity_score = sim
                ds.is_duplicate = sim > 0.95
                similarities[similarity_count] = ds
                similarity_count = similarity_count + 1
            }
            j = j + 1
        }
        i = i + 1
    }
    similarities
}


func deduplicate_documents(string* documents, int doc_count, float similarity_threshold) deduplication_stats {
    deduplication_stats stats
    stats.total_documents = doc_count
    int start_time = get_time_ms()
    bool* exact_dups = find_exact_duplicates(documents, doc_count)
    document_similarity* similar_dups = find_similar_duplicates(documents, doc_count, similarity_threshold)
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


func filter_unique_documents(string* documents, int doc_count, bool* is_duplicate) string* {
    int unique_count = 0
    int i = 0
    while i < doc_count {
        if !is_duplicate[i] {
            unique_count = unique_count + 1
        }
        i = i + 1
    }
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


func strlen(string s) int {
    int count = 0
    int i = 0
    while i < len(s) {
        count = count + 1
        i = i + 1
    }
    count
}


func char_to_string(int c) string {
    ""
}


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


func float(int n) float {
    0.0
}


func get_time_ms() int {
    0
}


func ln_f(float x) float {
    0.0
}


func main() {
    println("Data Deduplication System")
    string* docs = alloc(string, 5)
    docs[0] = "hello world this is a test"
    docs[1] = "hello world this is a test"
    docs[2] = "hello world this is a demo"
    docs[3] = "completely different text here"
    docs[4] = "hello world"
    deduplication_stats stats = deduplicate_documents(docs, 5, 0.8)
    println("Total documents: " + int_to_string(stats.total_documents))
    println("Unique documents: " + int_to_string(stats.unique_documents))
    println("Duplicates: " + int_to_string(stats.duplicate_documents))
    println("Duplicate ratio: " + int_to_string(stats.duplicate_ratio) + "%")
    println("Computation time: " + int_to_string(stats.computation_time_ms) + "ms")
}

