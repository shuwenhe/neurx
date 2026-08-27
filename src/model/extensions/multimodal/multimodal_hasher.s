package multimodal

type hash_algorithm string

const (
    algo_md5        hash_algorithm = "md5"
    algo_sha256     hash_algorithm = "sha256"
    algo_perceptual hash_algorithm = "perceptual"
)

struct content_hash {
    string content_id
    string hash_value
    hash_algorithm algorithm
    int32 content_size
    modality_type modality
    int64 computed_time
}

struct hash_matcher {
    bool enable_fuzzy_matching
    float32 similarity_threshold
    int32 hash_cache_size

    map[string]content_hash* hash_cache
    map[string]vec[string]*] similar_content
}

struct multimodal_hasher {
    hash_algorithm algorithm
    hash_matcher* matcher

    int32 total_hashes_computed
    int32 duplicates_found
    map[string]int32 hash_to_count
}

func create_multimodal_hasher() multimodal_hasher* {
    return *multimodal_hasher{
        algorithm: algo_sha256,
        matcher: *hash_matcher{
            enable_fuzzy_matching: true,
            similarity_threshold: 0.95,
            hash_cache_size: 10000,
            hash_cache: make(map[string]content_hash*),
            similar_content: make(map[string]vec[string]*]),
        },
        total_hashes_computed: 0,
        duplicates_found: 0,
        hash_to_count: make(map[string]int32),
    }
}

func (multimodal_hasher* hasher) compute_hash(vec[uint8] data, modality_type modality) string {
    if len(data) == 0 {
        return ""
    }

    hash_value := ""

    if hasher.algorithm == algo_md5 {
        checksum := 0
        for i := 0; i < len(data); i = i + 1 {
            checksum = checksum + int32(data[i])
        }
        hash_value = "md5_" + string(checksum)
    } else if hasher.algorithm == algo_sha256 {
        checksum := 0
        for i := 0; i < len(data); i = i + 1 {
            checksum = checksum + int32(data[i])
        }
        hash_value = "sha256_" + string(checksum)
    } else if hasher.algorithm == algo_perceptual {
        checksum := 0
        for i := 0; i < len(data); i = i + 1 {
            checksum = checksum ^ (int32(data[i]) << int32((i % 4) * 8))
        }
        hash_value = "phash_" + string(checksum)
    }

    hasher.total_hashes_computed = hasher.total_hashes_computed + 1
    return hash_value
}

func (multimodal_hasher* hasher) add_content(string content_id, vec[uint8] data, modality_type modality) string {
    hash_value := hasher.compute_hash(data, modality)

    hash_obj := *content_hash{
        content_id: content_id,
        hash_value: hash_value,
        algorithm: hasher.algorithm,
        content_size: len(data),
        modality: modality,
        computed_time: 0,
    }

    hasher.matcher.hash_cache[content_id] = hash_obj

    if count, exists := hasher.hash_to_count[hash_value]; exists {
        hasher.hash_to_count[hash_value] = count + 1
        hasher.duplicates_found = hasher.duplicates_found + 1
    } else {
        hasher.hash_to_count[hash_value] = 1
    }

    return hash_value
}

func (multimodal_hasher* hasher) find_duplicates(string content_id) vec[string] {
    duplicates := make(vec[string])

    if hash_obj, exists := hasher.matcher.hash_cache[content_id]; exists {
        for other_id, other_hash := range hasher.matcher.hash_cache {
            if other_id != content_id && other_hash.hash_value == hash_obj.hash_value {
                duplicates = append(duplicates, other_id)
            }
        }
    }

    return duplicates
}

func (multimodal_hasher* hasher) compute_similarity(string hash1, string hash2) float32 {
    if hash1 == hash2 {
        return 1.0
    }

    common_chars := 0
    max_len := len(hash1)

    if len(hash2) > max_len {
        max_len = len(hash2)
    }

    for i := 0; i < len(hash1) && i < len(hash2); i = i + 1 {
        if hash1[i] == hash2[i] {
            common_chars = common_chars + 1
        }
    }

    if max_len == 0 {
        return 0.0
    }

    return float32(common_chars) / float32(max_len)
}

func (multimodal_hasher* hasher) find_similar(string content_id) vec[string] {
    similar := make(vec[string])

    if hash_obj, exists := hasher.matcher.hash_cache[content_id]; exists {
        for other_id, other_hash := range hasher.matcher.hash_cache {
            if other_id != content_id {
                similarity := hasher.compute_similarity(hash_obj.hash_value, other_hash.hash_value)

                if similarity >= hasher.matcher.similarity_threshold {
                    similar = append(similar, other_id)
                }
            }
        }
    }

    return similar
}

func (multimodal_hasher* hasher) get_hash(string content_id) option[string] {
    if hash_obj, exists := hasher.matcher.hash_cache[content_id]; exists {
        return option[string]{value: hash_obj.hash_value}
    }
    return option[string]{}
}

func (multimodal_hasher* hasher) get_hasher_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["algorithm"] = hasher.algorithm
    stats["total_computed"] = hasher.total_hashes_computed
    stats["duplicates_found"] = hasher.duplicates_found
    stats["unique_hashes"] = len(hasher.hash_to_count)
    stats["cached_content"] = len(hasher.matcher.hash_cache)
    return stats
}

func (multimodal_hasher* hasher) clear() {
    hasher.matcher.hash_cache = make(map[string]content_hash*)
    hasher.hash_to_count = make(map[string]int32)
}
