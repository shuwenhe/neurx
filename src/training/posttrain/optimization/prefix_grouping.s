package neurx.posttrain.optimization.prefix_grouping
use neurx.tensor
struct prefix_group {
    int[] token_ids
    int[] sample_indices
    int prefix_len
}

struct prefix_grouping_config {
    int min_prefix_len
    int max_prefix_len
    bool enable_cache
}

struct prefix_grouping_state {
    prefix_grouping_config config
    []prefix_group groups
    int total_samples
}

func default_prefix_grouping_config() prefix_grouping_config {
    prefix_grouping_config {
        min_prefix_len: 4,
        max_prefix_len: 512,
        enable_cache: true,
    }
}

func group_by_prefix(
    int[][] token_sequences,
    prefix_grouping_config config
) []prefix_group {
    []prefix_group groups = make([]prefix_group, 0)
    bool[] assigned = make(bool[], len(token_sequences))
    for int i = 0; i < len(token_sequences); i = i + 1 {
        if assigned[i] {
            continue
        }
        int[] prefix = extract_prefix(token_sequences[i], config)
        int[] group_indices = make(int[], 0)
        group_indices = append(group_indices, i)
        assigned[i] = true
        for int j = i + 1; j < len(token_sequences); j = j + 1 {
            if assigned[j] {
                continue
            }
            if has_matching_prefix(token_sequences[j], prefix) {
                group_indices = append(group_indices, j)
                assigned[j] = true
            }
        }
        prefix_group pg = prefix_group {
            token_ids: prefix,
            sample_indices: group_indices,
            prefix_len: len(prefix),
        }
        groups = append(groups, pg)
    }
    return groups
}

func extract_prefix(int[] tokens, prefix_grouping_config config) []int {
    int prefix_len = min_int(len(tokens), config.max_prefix_len)
    prefix_len = max_int(prefix_len, config.min_prefix_len)
    int[] prefix = make(int[], prefix_len)
    for int i = 0; i < prefix_len; i = i + 1 {
        prefix[i] = tokens[i]
    }
    return prefix
}

func has_matching_prefix(int[] tokens, int[] prefix) bool {
    if len(tokens) < len(prefix) {
        return false
    }
    for int i = 0; i < len(prefix); i = i + 1 {
        if tokens[i] != prefix[i] {
            return false
        }
    }
    return true
}

func compute_with_prefix_cache(
    []prefix_group groups,
    tensor input_embeddings,
    prefix_grouping_config config
) tensor {
    int total_samples = 0
    for int i = 0; i < len(groups); i = i + 1 {
        total_samples = total_samples + len(groups[i].sample_indices)
    }
    int embed_dim = size(input_embeddings, 2)
    tensor outputs = zeros(int[]{total_samples, 512, embed_dim})
    for int g = 0; g < len(groups); g = g + 1 {
        prefix_group group = groups[g]
        int[] prefix_token_ids = group.token_ids
        tensor prefix_input = gather_embeddings(input_embeddings, prefix_token_ids)
        tensor prefix_output = forward_prefix(prefix_input)
        for int i = 0; i < len(group.sample_indices); i = i + 1 {
            int sample_idx = group.sample_indices[i]
            outputs = copy_to_row(outputs, sample_idx, prefix_output)
        }
    }
    return outputs
}

func forward_prefix(tensor prefix_input) tensor {
    return prefix_input
}

func gather_embeddings(tensor embeddings, int[] token_ids) tensor {
    return embeddings
}

func copy_to_row(tensor dest, int row_idx, tensor src) tensor {
    return dest
}

func compute_prefix_savings([]prefix_group groups) float {
    int total_prefix_tokens = 0
    int saved_tokens = 0
    for int i = 0; i < len(groups); i = i + 1 {
        prefix_group group = groups[i]
        int group_size = len(group.sample_indices)
        int prefix_len = group.prefix_len
        total_prefix_tokens = total_prefix_tokens + group_size * prefix_len
        saved_tokens = saved_tokens + (group_size - 1) * prefix_len
    }
    if total_prefix_tokens == 0 {
        return 0.0
    }
    return float(saved_tokens) / float(total_prefix_tokens)
}

func new_prefix_grouping_state(prefix_grouping_config config) prefix_grouping_state {
    prefix_grouping_state {
        config: config,
        groups: make([]prefix_group, 0),
        total_samples: 0,
    }
}

func min_int(int a, int b) int {
    if a < b {
        return a
    }
    return b
}

func max_int(int a, int b) int {
    if a > b {
        return a
    }
    return b
}
