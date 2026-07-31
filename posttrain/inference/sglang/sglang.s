package neurx.posttrain.inference.sglang

use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}

// SGLang (Structured Generation Language) integration
// Fast inference with structured generation and RadixAttention

struct sglang_config {
    int max_total_tokens
    int max_prefill_tokens
    int max_running_requests
    int context_length
    float mem_fraction_static
    int tp_size
    bool enable_flashinfer
    bool disable_radix_cache
    int schedule_conservativeness
    string attention_backend
}

struct radix_node {
    int node_id
    []int token_ids
    int parent_id
    []int children_ids
    int ref_count
    bool is_cached
    tensor key_cache
    tensor value_cache
}

struct radix_tree {
    []radix_node nodes
    int root_id
    int next_node_id
}

struct sglang_request {
    int request_id
    []int input_ids
    int max_new_tokens
    float temperature
    float top_p
    int top_k
    []int output_ids
    bool finished
    int radix_node_id  // Current position in radix tree
}

struct sglang_engine {
    module model
    sglang_config config
    radix_tree cache_tree
    []sglang_request requests
    int next_request_id
}

func new_sglang_config() sglang_config {
    sglang_config {
        max_total_tokens: 4096,
        max_prefill_tokens: 2048,
        max_running_requests: 256,
        context_length: 4096,
        mem_fraction_static: 0.9,
        tp_size: 1,
        enable_flashinfer: true,
        disable_radix_cache: false,
        schedule_conservativeness: 1,
        attention_backend: "flashinfer",
    }
}

func radix_tree_find_prefix(
    radix_tree tree,
    []int tokens
) int {
    // Find the longest prefix match in the radix tree
    // Returns node_id of the longest matching prefix
    
    if tree.nodes.len == 0 {
        return -1
    }
    
    int current_node = tree.root_id
    int matched_len = 0
    int best_node = current_node
    
    while matched_len < tokens.len {
        // Try to find child node that matches next token
        radix_node node = tree.nodes[current_node]
        
        bool found = false
        int i = 0
        while i < node.children_ids.len {
            int child_id = node.children_ids[i]
            radix_node child = tree.nodes[child_id]
            
            // Check if child's tokens match
            bool matches = true
            int j = 0
            while j < child.token_ids.len {
                if matched_len + j >= tokens.len {
                    matches = false
                    break
                }
                if child.token_ids[j] != tokens[matched_len + j] {
                    matches = false
                    break
                }
                j = j + 1
            }
            
            if matches {
                current_node = child_id
                matched_len = matched_len + child.token_ids.len
                best_node = child_id
                found = true
                break
            }
            
            i = i + 1
        }
        
        if !found {
            break
        }
    }
    
    best_node
}

func radix_tree_insert(
    radix_tree tree,
    []int tokens,
    tensor key_cache,
    tensor value_cache
) int {
    // Insert tokens into radix tree with KV cache
    // Returns node_id of inserted node
    
    // Find existing prefix
    int prefix_node = radix_tree_find_prefix(tree, tokens)
    
    if prefix_node < 0 {
        // Create new root-level node
        radix_node new_node = radix_node {
            node_id: tree.next_node_id,
            token_ids: tokens,
            parent_id: tree.root_id,
            children_ids: []int{},
            ref_count: 1,
            is_cached: true,
            key_cache: key_cache,
            value_cache: value_cache,
        }
        
        tree.nodes[tree.next_node_id] = new_node
        tree.nodes[tree.root_id].children_ids[
            tree.nodes[tree.root_id].children_ids.len
        ] = tree.next_node_id
        
        tree.next_node_id = tree.next_node_id + 1
        return new_node.node_id
    }
    
    // Check if we need to split or extend
    radix_node prefix = tree.nodes[prefix_node]
    int prefix_len = prefix.token_ids.len
    
    if prefix_len == tokens.len {
        // Exact match, update cache
        tree.nodes[prefix_node].key_cache = key_cache
        tree.nodes[prefix_node].value_cache = value_cache
        tree.nodes[prefix_node].ref_count = tree.nodes[prefix_node].ref_count + 1
        return prefix_node
    }
    
    // Create new child node for remaining tokens
    []int remaining = []int{cap: tokens.len - prefix_len}
    int i = prefix_len
    while i < tokens.len {
        remaining[i - prefix_len] = tokens[i]
        i = i + 1
    }
    
    radix_node new_node = radix_node {
        node_id: tree.next_node_id,
        token_ids: remaining,
        parent_id: prefix_node,
        children_ids: []int{},
        ref_count: 1,
        is_cached: true,
        key_cache: key_cache,
        value_cache: value_cache,
    }
    
    tree.nodes[tree.next_node_id] = new_node
    tree.nodes[prefix_node].children_ids[
        tree.nodes[prefix_node].children_ids.len
    ] = tree.next_node_id
    
    tree.next_node_id = tree.next_node_id + 1
    return new_node.node_id
}

func sglang_radix_attention(
    tensor query,
    radix_tree tree,
    int node_id
) tensor {
    // Efficient attention using cached KV from radix tree
    
    if node_id < 0 || node_id >= tree.nodes.len {
        // No cache, compute from scratch
        return tensor_ops.zeros_like(query)
    }
    
    // Collect KV cache from root to current node
    []tensor key_caches = []tensor{}
    []tensor value_caches = []tensor{}
    
    int current = node_id
    while current >= 0 {
        radix_node node = tree.nodes[current]
        
        if node.is_cached {
            key_caches[key_caches.len] = node.key_cache
            value_caches[value_caches.len] = node.value_cache
        }
        
        current = node.parent_id
    }
    
    // Reverse to get root-to-leaf order
    // (Simplified - actual implementation would reverse)
    
    // Concatenate all cached K, V
    tensor key = tensor_ops.concat(key_caches, 1)
    tensor value = tensor_ops.concat(value_caches, 1)
    
    // Compute attention
    int head_dim = query.shape[-1]
    float scale = 1.0 / (head_dim * 1.0)
    
    tensor scores = tensor_ops.matmul(
        query,
        tensor_ops.transpose(key, -2, -1)
    )
    scores = tensor_ops.mul_scalar(scores, scale)
    
    tensor attn_weights = tensor_ops.softmax(scores, -1)
    tensor output = tensor_ops.matmul(attn_weights, value)
    
    output
}

func sglang_generate(
    sglang_engine engine,
    [][]int prompts,
    int max_tokens,
    float temperature,
    float top_p
) [][]int {
    // Generate with SGLang using RadixAttention
    
    // Create requests
    int i = 0
    while i < prompts.len {
        // Find prefix in radix tree
        int node_id = -1
        if !engine.config.disable_radix_cache {
            node_id = radix_tree_find_prefix(
                engine.cache_tree,
                prompts[i]
            )
        }
        
        sglang_request req = sglang_request {
            request_id: engine.next_request_id,
            input_ids: prompts[i],
            max_new_tokens: max_tokens,
            temperature: temperature,
            top_p: top_p,
            top_k: 0,
            output_ids: []int{},
            finished: false,
            radix_node_id: node_id,
        }
        
        engine.requests[engine.requests.len] = req
        engine.next_request_id = engine.next_request_id + 1
        
        i = i + 1
    }
    
    // Generation loop with continuous batching
    bool all_finished = false
    while !all_finished {
        // Schedule requests
        []int scheduled = []int{}
        
        int j = 0
        while j < engine.requests.len {
            if !engine.requests[j].finished {
                scheduled[scheduled.len] = j
            }
            j = j + 1
        }
        
        if scheduled.len == 0 {
            break
        }
        
        // Process batch with RadixAttention
        // (Actual implementation would build batch, run inference, sample)
        
        // Check completion
        all_finished = true
        j = 0
        while j < engine.requests.len {
            if !engine.requests[j].finished {
                all_finished = false
                break
            }
            j = j + 1
        }
    }
    
    // Collect outputs
    [][]int outputs = [][]int{cap: prompts.len}
    i = 0
    while i < engine.requests.len {
        outputs[i] = engine.requests[i].output_ids
        i = i + 1
    }
    
    outputs
}

func new_sglang_engine(module model, sglang_config config) sglang_engine {
    // Initialize radix tree with root node
    radix_node root = radix_node {
        node_id: 0,
        token_ids: []int{},
        parent_id: -1,
        children_ids: []int{},
        ref_count: 0,
        is_cached: false,
        key_cache: tensor{},
        value_cache: tensor{},
    }
    
    radix_tree tree = radix_tree {
        nodes: []radix_node{root},
        root_id: 0,
        next_node_id: 1,
    }
    
    sglang_engine {
        model: model,
        config: config,
        cache_tree: tree,
        requests: []sglang_request{cap: config.max_running_requests},
        next_request_id: 0,
    }
}
