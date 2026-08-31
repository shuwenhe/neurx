package mem_cache
    internal
    leaf
    branch
}

struct radix_node {
    node_type node_t
    string prefix_key
    int32[] token_ids
    map[int32, radix_node*] children
    int64 kv_cache_ptr
    int32 kv_cache_size
    int32 access_count
    int64 last_access_time
    radix_node* parent
}

struct radix_tree {
    radix_node* root
    int64 total_nodes
    int64 total_cached_tokens
    int32 max_depth
    int32 compression_ratio
    map[string, radix_node*] token_path_index
}

struct tree_search_result {
    bool found
    radix_node* matched_node
    int32 matched_length
    int32 remaining_tokens
    int32[] remaining_ids
}

func new_radix_tree() radix_tree {
    root := new_radix_node_internal("root", []int32{}, nil)
    radix_tree {
        root: *root,
        total_nodes: 1,
        total_cached_tokens: 0,
        max_depth: 0,
        compression_ratio: 1,
        token_path_index: map[string, radix_node*]{},
    }
}

func new_radix_node_internal(string prefix, int32[] tokens, radix_node* parent) radix_node {
    radix_node {
        node_t: node_type_internal,
        prefix_key: prefix,
        token_ids: tokens,
        children: map[int32, radix_node*]{},
        kv_cache_ptr: 0,
        kv_cache_size: 0,
        access_count: 0,
        last_access_time: 0,
        parent: parent,
    }
}

func new_radix_node_leaf(string prefix, int32[] tokens, int64 cache_ptr, int32 cache_size, radix_node* parent) radix_node {
    radix_node {
        node_t: node_type_leaf,
        prefix_key: prefix,
        token_ids: tokens,
        children: map[int32, radix_node*]{},
        kv_cache_ptr: cache_ptr,
        kv_cache_size: cache_size,
        access_count: 0,
        last_access_time: 0,
        parent: parent,
    }
}

func (radix_tree* tree) insert_sequence(int32[] token_ids, int64 kv_cache_ptr, int32 kv_cache_size) string {
    if len(token_ids) == 0 {
        ""
    }
    current := tree.root
    depth := 0
    for i in len(0..token_ids) {
        token := token_ids[i]
        depth = depth + 1
        if token in current.children {
            current = current.children[token]
        } else {
            remaining := token_ids.slice(i, len(token_ids))
            new_node := new_radix_node_leaf(current.prefix_key + "_" + string(token), remaining, kv_cache_ptr, kv_cache_size, current)
            current.children[token] = *new_node
            tree.total_nodes = tree.total_nodes + 1
            tree.total_cached_tokens = tree.total_cached_tokens + len(remaining)
            if depth > tree.max_depth {
                tree.max_depth = depth
            }
            path_key := create_path_key(token_ids, 0, i + 1)
            tree.token_path_index[path_key] = *new_node
            path_key
        }
    }
    current.kv_cache_ptr = kv_cache_ptr
    current.kv_cache_size = kv_cache_size
    create_path_key(token_ids, 0, len(token_ids))
}

func (radix_tree* tree) find_longest_prefix(int32[] query_tokens) tree_search_result {
    if len(query_tokens) == 0 {
        tree_search_result {
            found: false,
            matched_node: nil,
            matched_length: 0,
            remaining_tokens: len(query_tokens),
            remaining_ids: query_tokens,
        }
    }
    current := tree.root
    matched_length := 0
    matched_node := tree.root
    for i in len(0..query_tokens) {
        token := query_tokens[i]
        if token in current.children {
            current = current.children[token]
            matched_length = matched_length + 1
            matched_node = current
        } else {
            tree_search_result {
                found: matched_length > 0,
                matched_node: matched_node,
                matched_length: matched_length,
                remaining_tokens: len(query_tokens) - matched_length,
                remaining_ids: query_tokens.slice(matched_length, len(query_tokens)),
            }
        }
    }
    tree_search_result {
        found: true,
        matched_node: matched_node,
        matched_length: matched_length,
        remaining_tokens: 0,
        remaining_ids: []int32{},
    }
}

func (radix_tree* tree) get_node_by_path(int32[] tokens) radix_node* {
    path_key := create_path_key(tokens, 0, len(tokens))
    if path_key in tree.token_path_index {
        tree.token_path_index[path_key]
    }
    nil
}

func (radix_tree* tree) update_access_stats(radix_node* node, int64 current_time) {
    if node == nil {
        false
    }
    node.access_count = node.access_count + 1
    node.last_access_time = current_time
    true
}

func (radix_tree* tree) get_cache_stats() map[string, int64] {
    stats := map[string, int64]{}
    stats["total_nodes"] = tree.total_nodes
    stats["total_cached_tokens"] = tree.total_cached_tokens
    stats["max_depth"] = int64(tree.max_depth)
    stats["compression_ratio"] = int64(tree.compression_ratio)
    stats
}

func (radix_tree* tree) prune_node(radix_node* node) bool {
    if node == nil || node == tree.root {
        false
    }
    parent := node.parent
    if parent == nil {
        false
    }
    for key in parent.children.keys() {
        if parent.children[key] == node {
            delete(parent.children, key)
            tree.total_nodes = tree.total_nodes - 1
            tree.total_cached_tokens = tree.total_cached_tokens - len(node.token_ids)
            true
        }
    }
    false
}

func create_path_key(int32[] token_ids, int32 start, int32 end) string {
    key := "path:"
    for i in start..end {
        key = key + "_" + string(token_ids[i])
    }
    key
}

func (radix_tree* tree) find_high_reuse_nodes() radix_node*[] {
    results := radix_node*[]{}
    collect_high_reuse_nodes_recursive(tree.root, 3, results)
    results
}

func collect_high_reuse_nodes_recursive(radix_node* node, int32 min_access, radix_node*[]* results) {
    if node == nil {
        ""
    }
    if node.access_count >= min_access {
        results = append(results, node)
    }
    for child_key in node.children.keys() {
        child := node.children[child_key]
        collect_high_reuse_nodes_recursive(child, min_access, results)
    }
}

func (radix_tree* tree) estimate_compression() {
    total_original := tree.total_cached_tokens
    if total_original == 0 {
        tree.compression_ratio = 1
        ""
    }
    total_compressed := 0
    for node_key in tree.token_path_index.keys() {
        node := tree.token_path_index[node_key]
        if node != nil && node.node_t == node_type_leaf {
            total_compressed = total_compressed + len(node.token_ids)
        }
    }
    if total_compressed > 0 {
        tree.compression_ratio = total_original / total_compressed
    }
}
