package neurx.inference.speculative_decoding
import "neurx.util.math"
enum speculative_mode {
    DRAFT_VERIFIER = 0
    TREE_SEARCH = 1
    ADAPTIVE = 2
    BATCH_VERIFICATION = 3
}

struct speculative_config {
    speculative_mode mode
    int draft_model_size
    int max_speculation_steps
    int min_speculation_steps
    int tree_search_width
    int tree_search_depth
    float temperature
    float top_p
    int top_k
    float draft_confidence_threshold
    float verification_threshold
    bool use_adaptive_speculation
    bool use_batch_verification
    bool use_tree_search
    int batch_size
    float gamma
    float alpha
}

struct draft_model {
    []float embeddings
    [][]float weights
    [][]float biases
    int vocab_size
    int hidden_dim
    int num_layers
}

struct verifier_model {
    []float embeddings
    [][]float weights
    [][]float biases
    int vocab_size
    int hidden_dim
    int num_layers
}

struct speculative_state {
    speculative_config config
    draft_model draft
    verifier_model verifier
    []int draft_tokens
    []int verified_tokens
    []float draft_probs
    []float verification_scores
    int current_speculation_steps
    int total_speculation_steps
    int accepted_count
    int rejected_count
    float avg_accept_rate
}

struct tree_node {
    int token
    float probability
    float score
    []tree_node children
    int depth
}

struct speculative_result {
    []int tokens
    []float probabilities
    int accepted_count
    int rejected_count
    float accept_rate
    int total_steps
}

func new_speculative_config() speculative_config {
    speculative_config {
        mode: ADAPTIVE,
        draft_model_size: 6,
        max_speculation_steps: 5,
        min_speculation_steps: 1,
        tree_search_width: 4,
        tree_search_depth: 3,
        temperature: 0.7,
        top_p: 0.9,
        top_k: 50,
        draft_confidence_threshold: 0.5,
        verification_threshold: 0.95,
        use_adaptive_speculation: true,
        use_batch_verification: true,
        use_tree_search: true,
        batch_size: 8,
        gamma: 0.9,
        alpha: 0.1,
    }
}

func new_draft_model(int vocab_size, int hidden_dim, int num_layers) draft_model {
    draft_model {
        embeddings: math.allocate_float(vocab_size * hidden_dim, 0.0),
        weights: [][]float{cap: num_layers},
        biases: [][]float{cap: num_layers},
        vocab_size: vocab_size,
        hidden_dim: hidden_dim,
        num_layers: num_layers,
    }
}

func new_verifier_model(int vocab_size, int hidden_dim, int num_layers) verifier_model {
    verifier_model {
        embeddings: math.allocate_float(vocab_size * hidden_dim, 0.0),
        weights: [][]float{cap: num_layers},
        biases: [][]float{cap: num_layers},
        vocab_size: vocab_size,
        hidden_dim: hidden_dim,
        num_layers: num_layers,
    }
}

func new_speculative_state(speculative_config config) speculative_state {
    speculative_state {
        config: config,
        draft: new_draft_model(32000, 1024, 6),
        verifier: new_verifier_model(32000, 8192, 70),
        draft_tokens: []int{cap: config.max_speculation_steps},
        verified_tokens: []int{cap: 1024},
        draft_probs: math.allocate_float(config.max_speculation_steps, 0.0),
        verification_scores: math.allocate_float(config.max_speculation_steps, 0.0),
        current_speculation_steps: 0,
        total_speculation_steps: 0,
        accepted_count: 0,
        rejected_count: 0,
        avg_accept_rate: 0.0,
    }
}

func draft_model_predict(draft_model model, []int input_tokens, int seq_len) ([]int, []float) {
    int vocab_size = model.vocab_size
    int hidden_dim = model.hidden_dim
    []float hidden = math.allocate_float(hidden_dim, 0.0)
    int i = 0
    while i < seq_len {
        int token = input_tokens[i]
        int j = 0
        while j < hidden_dim {
            hidden[j] = model.embeddings[token * hidden_dim + j]
            j = j + 1
        }
        int layer = 0
        while layer < model.num_layers {
            []float layer_hidden = math.allocate_float(hidden_dim, 0.0)
            j = 0
            while j < hidden_dim {
                layer_hidden[j] = model.biases[layer][j]
                int k = 0
                while k < hidden_dim {
                    layer_hidden[j] = layer_hidden[j] + hidden[k] * model.weights[layer][k * hidden_dim + j]
                    k = k + 1
                }
                layer_hidden[j] = math.gelu_approx(layer_hidden[j])
                j = j + 1
            }
            hidden = layer_hidden
            layer = layer + 1
        }
        i = i + 1
    }
    []float logits = math.allocate_float(vocab_size, 0.0)
    j = 0
    while j < vocab_size {
        logits[j] = model.biases[model.num_layers][j]
        int k = 0
        while k < hidden_dim {
            logits[j] = logits[j] + hidden[k] * model.weights[model.num_layers][k * vocab_size + j]
            k = k + 1
        }
        j = j + 1
    }
    []float probs = math.softmax_1d(logits)
    ([]int top_indices, []float top_probs) = math.top_k_select(probs, vocab_size, 1)
    (top_indices, top_probs)
}

func verifier_model_verify(verifier_model model, []int input_tokens, []int draft_tokens,
                           int seq_len, int draft_len) []float {
    int vocab_size = model.vocab_size
    int hidden_dim = model.hidden_dim
    []float verification_scores = math.allocate_float(draft_len, 0.0)
    []int combined_tokens = math.allocate_int(seq_len + draft_len, 0)
    int i = 0
    while i < seq_len {
        combined_tokens[i] = input_tokens[i]
        i = i + 1
    }
    i = 0
    while i < draft_len {
        combined_tokens[seq_len + i] = draft_tokens[i]
        i = i + 1
    }
    []float hidden = math.allocate_float(hidden_dim, 0.0)
    i = 0
    while i < seq_len + draft_len {
        int token = combined_tokens[i]
        int j = 0
        while j < hidden_dim {
            hidden[j] = model.embeddings[token * hidden_dim + j]
            j = j + 1
        }
        int layer = 0
        while layer < model.num_layers {
            []float layer_hidden = math.allocate_float(hidden_dim, 0.0)
            j = 0
            while j < hidden_dim {
                layer_hidden[j] = model.biases[layer][j]
                int k = 0
                while k < hidden_dim {
                    layer_hidden[j] = layer_hidden[j] + hidden[k] * model.weights[layer][k * hidden_dim + j]
                    k = k + 1
                }
                layer_hidden[j] = math.gelu_approx(layer_hidden[j])
                j = j + 1
            }
            hidden = layer_hidden
            layer = layer + 1
        }
        if i >= seq_len {
            []float logits = math.allocate_float(vocab_size, 0.0)
            j = 0
            while j < vocab_size {
                logits[j] = model.biases[model.num_layers][j]
                int k = 0
                while k < hidden_dim {
                    logits[j] = logits[j] + hidden[k] * model.weights[model.num_layers][k * vocab_size + j]
                    k = k + 1
                }
                j = j + 1
            }
            []float probs = math.softmax_1d(logits)
            verification_scores[i - seq_len] = probs[draft_tokens[i - seq_len]]
        }
        i = i + 1
    }
    verification_scores
}

func adaptive_speculation_steps(speculative_state state) int {
    if !state.config.use_adaptive_speculation {
        return state.config.max_speculation_steps
    }
    float avg_accept_rate = state.avg_accept_rate
    float target_steps = float(state.config.min_speculation_steps) +
                         float(state.config.max_speculation_steps - state.config.min_speculation_steps) *
                         avg_accept_rate
    int steps = int(target_steps)
    steps = math.max_int(state.config.min_speculation_steps, steps)
    steps = math.min_int(state.config.max_speculation_steps, steps)
    steps
}

func tree_search_generate(draft_model model, []int input_tokens, int seq_len,
                          int width, int depth, float temperature) tree_node {
    tree_node root {
        token: -1,
        probability: 1.0,
        score: 0.0,
        children: []tree_node{cap: width},
        depth: 0,
    }
    build_tree(root, model, input_tokens, seq_len, width, depth, temperature)
    root
}

func build_tree(tree_node node, draft_model model, []int input_tokens, int seq_len,
                int width, int depth, float temperature) {
    if node.depth >= depth {
        return
    }
    []int extended_tokens = math.allocate_int(seq_len + node.depth + 1, 0)
    int i = 0
    while i < seq_len + node.depth {
        extended_tokens[i] = input_tokens[i]
        i = i + 1
    }
    tree_node curr = node
    i = node.depth - 1
    while i >= 0 {
        if len(curr.children) > 0 {
            extended_tokens[seq_len + i + 1] = curr.children[0].token
        }
        i = i - 1
    }
    ([]int next_tokens, []float next_probs) = draft_model_predict(model, extended_tokens, seq_len + node.depth)
    int num_tokens = math.min_int(width, len(next_tokens))
    i = 0
    while i < num_tokens {
        float adjusted_prob = next_probs[i]
        if temperature > 0 {
            adjusted_prob = math.exp_approx(math.log_approx(next_probs[i]) / temperature)
        }
        tree_node child {
            token: next_tokens[i],
            probability: adjusted_prob,
            score: node.score + math.log_approx(adjusted_prob),
            children: []tree_node{cap: width},
            depth: node.depth + 1,
        }
        node.children.push(child)
        build_tree(child, model, extended_tokens, seq_len, width, depth, temperature)
        i = i + 1
    }
}

func select_best_path(tree_node root) []int {
    []int path = []int{cap: 10}
    tree_node curr = root
    while len(curr.children) > 0 {
        float best_score = -1e10
        int best_idx = -1
        int i = 0
        while i < len(curr.children) {
            if curr.children[i].score > best_score {
                best_score = curr.children[i].score
                best_idx = i
            }
            i = i + 1
        }
        if best_idx >= 0 {
            path.push(curr.children[best_idx].token)
            curr = curr.children[best_idx]
        } else {
            break
        }
    }
    path
}

func batch_verify(verifier_model model, [][]int input_batches, [][]int draft_batches,
                  int seq_len, int draft_len, int batch_size) [][]float {
    [][]float all_scores = [][]float{cap: batch_size}
    int batch_idx = 0
    while batch_idx < batch_size {
        []float scores = verifier_model_verify(model, input_batches[batch_idx], draft_batches[batch_idx], seq_len, draft_len)
        all_scores.push(scores)
        batch_idx = batch_idx + 1
    }
    all_scores
}

func speculative_decode_step(speculative_state state, []int input_tokens, int seq_len) speculative_result {
    speculative_config config = state.config
    int speculation_steps = adaptive_speculation_steps(state)
    []int draft_tokens = []int{cap: speculation_steps}
    []float draft_probs = math.allocate_float(speculation_steps, 0.0)
    []int current_input = math.copy_int(input_tokens)
    int step = 0
    while step < speculation_steps {
        ([]int next_token, []float next_prob) = draft_model_predict(state.draft, current_input, len(current_input))
        if len(next_token) > 0 && len(next_prob) > 0 {
            draft_tokens.push(next_token[0])
            draft_probs[step] = next_prob[0]
            current_input.push(next_token[0])
        }
        step = step + 1
    }
    state.current_speculation_steps = speculation_steps
    state.total_speculation_steps = state.total_speculation_steps + speculation_steps
    []float verification_scores = verifier_model_verify(state.verifier, input_tokens, draft_tokens, seq_len, speculation_steps)
    state.verification_scores = verification_scores
    []int accepted_tokens = []int{cap: speculation_steps}
    []int rejected_tokens = []int{cap: speculation_steps}
    int accepted_count = 0
    int rejected_count = 0
    step = 0
    while step < speculation_steps {
        if verification_scores[step] >= config.verification_threshold {
            accepted_tokens.push(draft_tokens[step])
            accepted_count = accepted_count + 1
        } else {
            rejected_tokens.push(draft_tokens[step])
            rejected_count = rejected_count + 1
        }
        step = step + 1
    }
    state.accepted_count = state.accepted_count + accepted_count
    state.rejected_count = state.rejected_count + rejected_count
    float total = float(state.accepted_count + state.rejected_count)
    if total > 0 {
        state.avg_accept_rate = float(state.accepted_count) / total
    }
    []int final_tokens = accepted_tokens
    if len(rejected_tokens) > 0 {
        []int fallback_input = math.copy_int(input_tokens)
        int i = 0
        while i < len(accepted_tokens) {
            fallback_input.push(accepted_tokens[i])
            i = i + 1
        }
        ([]int correct_token, []float correct_prob) = draft_model_predict(state.verifier, fallback_input, len(fallback_input))
        if len(correct_token) > 0 {
            final_tokens.push(correct_token[0])
        }
    }
    state.draft_tokens = draft_tokens
    state.verified_tokens = final_tokens
    speculative_result {
        tokens: final_tokens,
        probabilities: draft_probs,
        accepted_count: accepted_count,
        rejected_count: rejected_count,
        accept_rate: float(accepted_count) / float(speculation_steps),
        total_steps: speculation_steps,
    }
}

func speculative_decode_full(speculative_state state, []int input_tokens, int seq_len, int max_len) []int {
    []int output = math.copy_int(input_tokens)
    int pos = seq_len
    while pos < max_len {
        speculative_result result = speculative_decode_step(state, output, len(output))
        int i = 0
        while i < len(result.tokens) && pos < max_len {
            output.push(result.tokens[i])
            pos = pos + 1
            i = i + 1
        }
    }
    output
}

func speculative_get_metrics(speculative_state state) speculative_result {
    float total = float(state.accepted_count + state.rejected_count)
    float accept_rate = 0.0
    if total > 0 {
        accept_rate = float(state.accepted_count) / total
    }
    speculative_result {
        tokens: state.verified_tokens,
        probabilities: state.draft_probs,
        accepted_count: state.accepted_count,
        rejected_count: state.rejected_count,
        accept_rate: accept_rate,
        total_steps: state.total_speculation_steps,
    }
}

func speculative_reset(speculative_state state) speculative_state {
    state.draft_tokens = []int{cap: state.config.max_speculation_steps}
    state.verified_tokens = []int{cap: 1024}
    state.current_speculation_steps = 0
    state.total_speculation_steps = 0
    state.accepted_count = 0
    state.rejected_count = 0
    state.avg_accept_rate = 0.5
    state
}
