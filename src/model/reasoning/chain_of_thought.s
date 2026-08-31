package neurx.model.reasoning.chain_of_thought
import "neurx.util.math"
    STEP_BY_STEP = 0
    SELF_CONSISTENCY = 1
    TREE_SEARCH = 2
    DECOMPOSITION = 3
    REFLECTION = 4
    MULTI_PART = 5
}

struct cot_config {
    reasoning_strategy strategy
    int max_steps
    int num_samples
    int tree_width
    int tree_depth
    float temperature
    float top_p
    int top_k
    float confidence_threshold
    float reflection_weight
    bool use_self_consistency
    bool use_reflection
    bool use_decomposition
    bool use_tree_search
    int num_reflection_rounds
    float consistency_threshold
}

struct thought_step {
    int[] tokens
    float confidence
    float reward
    int step_index
    bool is_final
}

struct reasoning_tree {
    int token
    float probability
    float score
    []reasoning_tree children
    int depth
    bool is_terminal
}

struct decomposition_result {
    string[] sub_problems
    float[] sub_problem_difficulty
    int[] sub_problem_order
}

struct reflection_result {
    int[] original_tokens
    int[] revised_tokens
    float improvement_score
    float confidence_change
    int reflection_round
}

struct cot_state {
    cot_config config
    []thought_step steps
    reasoning_tree tree
    decomposition_result decomposition
    []reflection_result reflections
    int current_step
    int current_round
    float total_confidence
    float best_score
}

struct reasoning_result {
    int[] final_tokens
    []thought_step steps
    float confidence
    float score
    int num_steps
    int num_samples
    bool is_consistent
}

func new_cot_config() cot_config {
    cot_config {
        strategy: STEP_BY_STEP,
        max_steps: 50,
        num_samples: 5,
        tree_width: 3,
        tree_depth: 5,
        temperature: 0.7,
        top_p: 0.9,
        top_k: 50,
        confidence_threshold: 0.8,
        reflection_weight: 0.3,
        use_self_consistency: true,
        use_reflection: true,
        use_decomposition: true,
        use_tree_search: true,
        num_reflection_rounds: 2,
        consistency_threshold: 0.7,
    }
}

func new_thought_step(int[] tokens, float confidence, float reward, int step_index, bool is_final) thought_step {
    thought_step {
        tokens: tokens,
        confidence: confidence,
        reward: reward,
        step_index: step_index,
        is_final: is_final,
    }
}

func new_reasoning_tree(int token, float probability, float score, int depth, bool is_terminal) reasoning_tree {
    reasoning_tree {
        token: token,
        probability: probability,
        score: score,
        children: make([]reasoning_tree, 5),
        depth: depth,
        is_terminal: is_terminal,
    }
}

func new_cot_state(cot_config config) cot_state {
    cot_state {
        config: config,
        steps: make([]thought_step, config.max_steps),
        tree: new_reasoning_tree(-1, 1.0, 0.0, 0, false),
        decomposition: decomposition_result{
            sub_problems: make([]string, 10),
            sub_problem_difficulty: math.allocate_float(10, 0.0),
            sub_problem_order: math.allocate_int(10, 0),
        },
        reflections: make([]reflection_result, config.num_reflection_rounds),
        current_step: 0,
        current_round: 0,
        total_confidence: 0.0,
        best_score: 0.0,
    }
}

func step_by_step_reasoning(cot_state state, int[] input_tokens, int seq_len) reasoning_result {
    cot_config config = state.config
    int[] current_input = math.copy_int(input_tokens)
    []thought_step steps = make([]thought_step, config.max_steps)
    int step = 0
    for step < config.max_steps {
        int[] next_tokens = generate_next_step(current_input, seq_len + step * 64, config)
        float confidence = compute_confidence(next_tokens, config)
        float reward = compute_reward(next_tokens, config)
        thought_step ts = new_thought_step(next_tokens, confidence, reward, step, confidence >= config.confidence_threshold)
        steps = append(steps, ts)
        int i = 0
        for i < len(next_tokens) {
            current_input = append(current_input, next_tokens[i])
            i = i + 1
        }
        if confidence >= config.confidence_threshold {
            break
        }
        step = step + 1
    }
    float total_confidence = 0.0
    int i = 0
    for i < len(steps) {
        total_confidence = total_confidence + steps[i].confidence
        i = i + 1
    }
    total_confidence = total_confidence / float(len(steps))
    reasoning_result {
        final_tokens: current_input,
        steps: steps,
        confidence: total_confidence,
        score: compute_final_score(steps, config),
        num_steps: len(steps),
        num_samples: 1,
        is_consistent: true,
    }
}

func generate_next_step(int[] input_tokens, int seq_len, cot_config config) []int {
    int output_len = 64
    int[] next_tokens = math.allocate_int(output_len, 0)
    int i = 0
    for i < output_len {
        float rand_val = float(i) / float(output_len)
        next_tokens[i] = int(rand_val * 1000.0)
        i = i + 1
    }
    next_tokens
}

func compute_confidence(int[] tokens, cot_config config) float {
    float confidence = 0.5 + float(len(tokens)) * 0.01
    confidence = math.clamp_float(confidence, 0.0, 1.0)
    confidence
}

func compute_reward(int[] tokens, cot_config config) float {
    float reward = float(len(tokens)) * 0.1
    reward
}

func compute_final_score([]thought_step steps, cot_config config) float {
    float score = 0.0
    int i = 0
    for i < len(steps) {
        score = score + steps[i].confidence * steps[i].reward
        i = i + 1
    }
    score / float(len(steps))
}

func self_consistency_reasoning(cot_state state, int[] input_tokens, int seq_len) reasoning_result {
    cot_config config = state.config
    []reasoning_result samples = make([]reasoning_result, config.num_samples)
    int sample = 0
    for sample < config.num_samples {
        reasoning_result result = step_by_step_reasoning(state, input_tokens, seq_len)
        samples = append(samples, result)
        sample = sample + 1
    }
    float[] confidences = math.allocate_float(config.num_samples, 0.0)
    int i = 0
    for i < len(samples) {
        confidences[i] = samples[i].confidence
        i = i + 1
    }
    float[] weights = math.softmax_1d(confidences)
    int best_idx = 0
    float best_score = -1e10
    i = 0
    for i < len(samples) {
        float weighted_score = weights[i] * samples[i].score
        if weighted_score > best_score {
            best_score = weighted_score
            best_idx = i
        }
        i = i + 1
    }
    float consistency = compute_consistency(samples, config)
    reasoning_result {
        final_tokens: samples[best_idx].final_tokens,
        steps: samples[best_idx].steps,
        confidence: samples[best_idx].confidence,
        score: best_score,
        num_steps: samples[best_idx].num_steps,
        num_samples: config.num_samples,
        is_consistent: consistency >= config.consistency_threshold,
    }
}

func compute_consistency([]reasoning_result samples, cot_config config) float {
    if len(samples) < 2 {
        return 1.0
    }
    float total_similarity = 0.0
    int count = 0
    int i = 0
    for i < len(samples) {
        int j = i + 1
        for j < len(samples) {
            float similarity = compute_sequence_similarity(samples[i].final_tokens, samples[j].final_tokens)
            total_similarity = total_similarity + similarity
            count = count + 1
            j = j + 1
        }
        i = i + 1
    }
    total_similarity / float(count)
}

func compute_sequence_similarity(int[] a, int[] b) float {
    if len(a) == 0 || len(b) == 0 {
        return 0.0
    }
    int common = 0
    int max_len = math.max_int(len(a), len(b))
    int i = 0
    for i < len(a) && i < len(b) {
        if a[i] == b[i] {
            common = common + 1
        }
        i = i + 1
    }
    float(common) / float(max_len)
}

func tree_search_reasoning(cot_state state, int[] input_tokens, int seq_len) reasoning_result {
    cot_config config = state.config
    reasoning_tree root = build_reasoning_tree(input_tokens, seq_len, config)
    int[] best_path = select_best_path(root)
    int[] final_tokens = math.copy_int(input_tokens)
    int i = 0
    for i < len(best_path) {
        final_tokens = append(final_tokens, best_path[i])
        i = i + 1
    }
    float confidence = root.score / float(config.tree_depth)
    reasoning_result {
        final_tokens: final_tokens,
        steps: make([]thought_step, 0),
        confidence: confidence,
        score: root.score,
        num_steps: config.tree_depth,
        num_samples: 1,
        is_consistent: true,
    }
}

func build_reasoning_tree(int[] input_tokens, int seq_len, cot_config config) reasoning_tree {
    reasoning_tree root = new_reasoning_tree(-1, 1.0, 0.0, 0, false)
    expand_tree(root, input_tokens, seq_len, config)
    root
}

func expand_tree(reasoning_tree node, int[] input_tokens, int seq_len, cot_config config) {
    if node.depth >= config.tree_depth {
        node.is_terminal = true
        return
    }
    int[] next_tokens = generate_next_step(input_tokens, seq_len, config)
    (int[] top_tokens, float[] top_probs) = math.top_k_select(next_tokens, len(next_tokens), config.tree_width)
    int i = 0
    for i < len(top_tokens) {
        float adjusted_prob = top_probs[i]
        if config.temperature > 0 {
            adjusted_prob = math.exp_approx(math.log_approx(top_probs[i]) / config.temperature)
        }
        reasoning_tree child = new_reasoning_tree(top_tokens[i], adjusted_prob, node.score + math.log_approx(adjusted_prob), node.depth + 1, false)
        node.children = append(node.children, child)
        int[] extended_input = math.copy_int(input_tokens)
        extended_input = append(extended_input, top_tokens[i])
        expand_tree(child, extended_input, seq_len + 1, config)
        i = i + 1
    }
}

func select_best_path(reasoning_tree root) []int {
    int[] path = make([]int, 10)
    reasoning_tree curr = root
    for len(curr.children) > 0 {
        float best_score = -1e10
        int best_idx = -1
        int i = 0
        for i < len(curr.children) {
            if curr.children[i].score > best_score {
                best_score = curr.children[i].score
                best_idx = i
            }
            i = i + 1
        }
        if best_idx >= 0 {
            path = append(path, curr.children[best_idx].token)
            curr = curr.children[best_idx]
        } else {
            break
        }
    }
    path
}

func decomposition_reasoning(cot_state state, int[] input_tokens, int seq_len) reasoning_result {
    cot_config config = state.config
    decomposition_result decomp = decompose_problem(input_tokens, config)
    int[] final_tokens = math.copy_int(input_tokens)
    []thought_step steps = make([]thought_step, 10)
    int i = 0
    for i < len(decomp.sub_problems) {
        int sub_idx = decomp.sub_problem_order[i]
        int[] sub_input = math.copy_int(input_tokens)
        reasoning_result sub_result = step_by_step_reasoning(state, sub_input, seq_len)
        int j = 0
        for j < len(sub_result.final_tokens) {
            final_tokens = append(final_tokens, sub_result.final_tokens[j])
            j = j + 1
        }
        thought_step ts = new_thought_step(sub_result.final_tokens, sub_result.confidence,
                                           sub_result.score, i, i == len(decomp.sub_problems) - 1)
        steps = append(steps, ts)
        i = i + 1
    }
    float total_confidence = 0.0
    i = 0
    for i < len(steps) {
        total_confidence = total_confidence + steps[i].confidence
        i = i + 1
    }
    total_confidence = total_confidence / float(len(steps))
    reasoning_result {
        final_tokens: final_tokens,
        steps: steps,
        confidence: total_confidence,
        score: compute_final_score(steps, config),
        num_steps: len(steps),
        num_samples: 1,
        is_consistent: true,
    }
}

func decompose_problem(int[] input_tokens, cot_config config) decomposition_result {
    int num_sub_problems = 3
    decomposition_result decomp {
        sub_problems: make([]string, num_sub_problems),
        sub_problem_difficulty: math.allocate_float(num_sub_problems, 0.0),
        sub_problem_order: math.allocate_int(num_sub_problems, 0),
    }
    int i = 0
    for i < num_sub_problems {
        decomp.sub_problems = append(decomp.sub_problems, "sub_problem_" + string(i))
        decomp.sub_problem_difficulty[i] = float(i) / float(num_sub_problems)
        decomp.sub_problem_order[i] = i
        i = i + 1
    }
    decomp
}

func reflection_reasoning(cot_state state, int[] input_tokens, int seq_len) reasoning_result {
    cot_config config = state.config
    int[] current_tokens = math.copy_int(input_tokens)
    []reflection_result reflections = make([]reflection_result, config.num_reflection_rounds)
    int round_idx = 0
    for round_idx < config.num_reflection_rounds {
        int[] original_tokens = math.copy_int(current_tokens)
        reasoning_result initial_result = step_by_step_reasoning(state, current_tokens, seq_len)
        int[] revised_tokens = revise_reasoning(initial_result, config)
        float improvement = compute_improvement(original_tokens, revised_tokens)
        float confidence_change = compute_confidence(revised_tokens, config) - compute_confidence(original_tokens, config)
        reflection_result ref = reflection_result {
            original_tokens: original_tokens,
            revised_tokens: revised_tokens,
            improvement_score: improvement,
            confidence_change: confidence_change,
            reflection_round: round_idx,
        }
        reflections = append(reflections, ref)
        if improvement > 0.1 {
            current_tokens = revised_tokens
        } else {
            break
        }
        round_idx = round_idx + 1
    }
    float final_confidence = compute_confidence(current_tokens, config)
    reasoning_result {
        final_tokens: current_tokens,
        steps: make([]thought_step, 0),
        confidence: final_confidence,
        score: final_confidence * (1.0 + float(len(reflections)) * config.reflection_weight),
        num_steps: len(reflections),
        num_samples: 1,
        is_consistent: true,
    }
}

func revise_reasoning(reasoning_result result, cot_config config) []int {
    int[] revised = math.copy_int(result.final_tokens)
    float noise = 0.01
    int i = 0
    for i < len(revised) {
        if float(i) / float(len(revised)) > 0.5 {
            revised[i] = revised[i] + int(noise * 100.0)
        }
        i = i + 1
    }
    revised
}

func compute_improvement(int[] original, int[] revised) float {
    float original_confidence = float(len(original)) / 1000.0
    float revised_confidence = float(len(revised)) / 1000.0
    revised_confidence - original_confidence
}

func cot_reason(cot_state state, int[] input_tokens, int seq_len) reasoning_result {
    cot_config config = state.config
    switch config.strategy {
        case STEP_BY_STEP:
            return step_by_step_reasoning(state, input_tokens, seq_len)
        case SELF_CONSISTENCY:
            return self_consistency_reasoning(state, input_tokens, seq_len)
        case TREE_SEARCH:
            return tree_search_reasoning(state, input_tokens, seq_len)
        case DECOMPOSITION:
            return decomposition_reasoning(state, input_tokens, seq_len)
        case REFLECTION:
            return reflection_reasoning(state, input_tokens, seq_len)
        case MULTI_PART:
            return multi_part_reasoning(state, input_tokens, seq_len)
    }
    step_by_step_reasoning(state, input_tokens, seq_len)
}

func multi_part_reasoning(cot_state state, int[] input_tokens, int seq_len) reasoning_result {
    decomposition_result decomp = decompose_problem(input_tokens, state.config)
    []reasoning_result results = make([]reasoning_result, len(decomp.sub_problems))
    int i = 0
    for i < len(decomp.sub_problems) {
        reasoning_result result = self_consistency_reasoning(state, input_tokens, seq_len)
        results = append(results, result)
        i = i + 1
    }
    int[] final_tokens = math.copy_int(input_tokens)
    float total_confidence = 0.0
    int total_steps = 0
    i = 0
    for i < len(results) {
        int j = 0
        for j < len(results[i].final_tokens) {
            final_tokens = append(final_tokens, results[i].final_tokens[j])
            j = j + 1
        }
        total_confidence = total_confidence + results[i].confidence
        total_steps = total_steps + results[i].num_steps
        i = i + 1
    }
    total_confidence = total_confidence / float(len(results))
    reasoning_result {
        final_tokens: final_tokens,
        steps: make([]thought_step, 0),
        confidence: total_confidence,
        score: total_confidence * float(total_steps),
        num_steps: total_steps,
        num_samples: len(results) * state.config.num_samples,
        is_consistent: true,
    }
}

func cot_get_best_result(cot_state state) reasoning_result {
    float best_score = -1e10
    reasoning_result best_result = reasoning_result {
        final_tokens: []int{},
        steps: make([]thought_step, 0),
        confidence: 0.0,
        score: 0.0,
        num_steps: 0,
        num_samples: 0,
        is_consistent: false,
    }
    int i = 0
    for i < len(state.steps) {
        float step_score = state.steps[i].confidence * state.steps[i].reward
        if step_score > best_score {
            best_score = step_score
            best_result = reasoning_result {
                final_tokens: state.steps[i].tokens,
                steps: make([]thought_step, 0),
                confidence: state.steps[i].confidence,
                score: step_score,
                num_steps: 1,
                num_samples: 1,
                is_consistent: true,
            }
        }
        i = i + 1
    }
    best_result
}

func cot_reset(cot_state state) cot_state {
    state.steps = make([]thought_step, state.config.max_steps)
    state.reflections = make([]reflection_result, state.config.num_reflection_rounds)
    state.current_step = 0
    state.current_round = 0
    state.total_confidence = 0.0
    state.best_score = 0.0
    state
}
