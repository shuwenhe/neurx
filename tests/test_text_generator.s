package main
use neurx.inference
func assert_true(bool value, string name) {
    if value {
        println("PASS " + name)
    } else {
        println("FAIL " + name)
    }
}

func dummy_forward([]int token_ids) []float {
    int n = 8
    []float logits = []float{cap: n}
    int i = 0
    while i < n {
        logits[i] = -5.0
        i = i + 1
    }
    int preferred = (len(token_ids) + 1) % n
    logits[preferred] = 7.0
    logits[2] = 1.0
    if len(token_ids) >= 3 {
        logits[2] = 10.0
    }
    logits
}

func contrastive_forward([]int token_ids) []float {
    int n = 6
    []float logits = []float{cap: n}
    int i = 0
    while i < n {
        logits[i] = -6.0
        i = i + 1
    }
    if len(token_ids) <= 1 {
        logits[0] = 8.0
        logits[1] = 7.5
    } else {
        logits[0] = 8.0
        logits[1] = 7.9
    }
    logits
}

func ngram_forward([]int token_ids) []float {
    int n = 6
    []float logits = []float{cap: n}
    int i = 0
    while i < n {
        logits[i] = -6.0
        i = i + 1
    }
    if len(token_ids) == 0 {
        logits[0] = 9.0
    } else if len(token_ids) == 1 {
        logits[1] = 9.0
    } else if len(token_ids) == 2 {
        logits[0] = 9.0
    } else {
        logits[1] = 9.0
        logits[2] = 8.5
    }
    logits
}

func test_generate_greedy_full_text() {
    neurx.inference.generator_config cfg = neurx.inference.default_generator_config()
    cfg.sampling = neurx.inference.sampling_strategies.greedy_config()
    cfg.max_new_tokens = 3
    cfg.return_full_text = true
    cfg.return_scores = true
    neurx.inference.generation_result result = neurx.inference.generate([5, 6], cfg)
    assert_true(len(result.sequences) == 1, "greedy sequence count")
    assert_true(len(result.sequences[0]) >= 3, "greedy full text length")
    assert_true(result.sequences[0][0] == 5, "greedy keeps prompt")
    assert_true(len(result.scores) == 1, "greedy score count")
    assert_true(len(result.token_logprobs) == 1, "greedy logprob sequence count")
    assert_true(len(result.token_logprobs[0]) >= 1, "greedy logprob steps")
    assert_true(len(result.top_logprobs) == 1, "greedy top logprob sequence count")
    assert_true(len(result.top_logprobs[0]) >= 1, "greedy top logprob steps")
    assert_true(len(result.top_logprobs[0][0]) >= 1, "greedy top logprob candidates")
}

func test_generate_new_tokens_only() {
    neurx.inference.generator_config cfg = neurx.inference.default_generator_config()
    cfg.sampling = neurx.inference.sampling_strategies.new_sampling_config()
    cfg.max_new_tokens = 2
    cfg.return_full_text = false
    neurx.inference.generation_result result = neurx.inference.generate([3, 4], cfg)
    assert_true(len(result.sequences) == 1, "new token sequence count")
    assert_true(len(result.sequences[0]) <= 3, "new token only length")
    if len(result.sequences[0]) > 0 {
        assert_true(result.sequences[0][0] != 3, "new token omits prompt")
    }
}

func test_generate_beam_search() {
    neurx.inference.generator_config cfg = neurx.inference.default_generator_config()
    cfg.sampling = neurx.inference.sampling_strategies.new_sampling_config()
    cfg.sampling.strategy = "beam_search"
    cfg.sampling.num_beams = 2
    cfg.sampling.do_sample = false
    cfg.max_new_tokens = 3
    cfg.return_full_text = true
    neurx.inference.generation_result result = neurx.inference.generate([1], cfg)
    assert_true(len(result.sequences) == 1, "beam sequence count")
    assert_true(len(result.sequences[0]) >= 2, "beam produced tokens")
}

func test_generate_with_forward() {
    neurx.inference.generator_config cfg = neurx.inference.default_generator_config()
    cfg.sampling = neurx.inference.sampling_strategies.greedy_config()
    cfg.max_new_tokens = 3
    cfg.return_full_text = true
    neurx.inference.generation_result result = neurx.inference.generate_with_forward([1], dummy_forward, cfg)
    assert_true(len(result.sequences) == 1, "forward sequence count")
    assert_true(len(result.sequences[0]) >= 2, "forward generated tokens")
    assert_true(result.sequences[0][0] == 1, "forward keeps prompt")
    assert_true(len(result.token_logprobs) == 1, "forward logprob sequence count")
    assert_true(len(result.token_logprobs[0]) >= 1, "forward logprob steps")
    assert_true(len(result.top_logprobs[0]) >= 1, "forward top logprob steps")
    assert_true(result.top_logprobs[0][0][0].token_id >= 0, "forward top logprob token id")
}

func test_generate_overload_with_forward() {
    neurx.inference.generator_config cfg = neurx.inference.default_generator_config()
    cfg.sampling = neurx.inference.sampling_strategies.greedy_config()
    cfg.max_new_tokens = 2
    neurx.inference.generation_result result = neurx.inference.generate([2], dummy_forward, cfg)
    assert_true(len(result.sequences) == 1, "forward overload sequence count")
    assert_true(result.sequences[0][0] == 2, "forward overload keeps prompt")
    assert_true(len(result.token_logprobs) == 1, "forward overload logprob sequence count")
    assert_true(len(result.top_logprobs[0]) >= 1, "forward overload top logprob steps")
}

func test_generate_contrastive_with_forward() {
    neurx.inference.generator_config cfg = neurx.inference.default_generator_config()
    cfg.sampling = neurx.inference.sampling_strategies.new_sampling_config()
    cfg.sampling.strategy = "contrastive"
    cfg.sampling.contrastive_top_k = 2
    cfg.sampling.penalty_alpha = 0.8
    cfg.sampling.top_k = 0
    cfg.sampling.top_p = 0.0
    cfg.sampling.typical_p = 1.0
    cfg.max_new_tokens = 2
    cfg.return_full_text = false
    neurx.inference.generation_result result = neurx.inference.generate_with_forward([5], contrastive_forward, cfg)
    assert_true(len(result.sequences) == 1, "contrastive forward sequence count")
    assert_true(len(result.sequences[0]) == 2, "contrastive forward token count")
    assert_true(result.sequences[0][0] == 0, "contrastive first token")
    assert_true(result.sequences[0][1] == 1, "contrastive avoids repetition")
    assert_true(len(result.token_logprobs[0]) == 2, "contrastive logprob steps")
    assert_true(len(result.top_logprobs[0][0]) >= 1, "contrastive top logprob candidates")
}

func test_generate_no_repeat_ngram_with_forward() {
    neurx.inference.generator_config cfg = neurx.inference.default_generator_config()
    cfg.sampling = neurx.inference.sampling_strategies.new_sampling_config()
    cfg.sampling.no_repeat_ngram_size = 2
    cfg.sampling.top_k = 0
    cfg.sampling.top_p = 0.0
    cfg.sampling.typical_p = 1.0
    cfg.max_new_tokens = 4
    cfg.return_full_text = false
    cfg.force_eos = false
    neurx.inference.generation_result result = neurx.inference.generate_with_forward([], ngram_forward, cfg)
    assert_true(len(result.sequences) == 1, "ngram forward sequence count")
    assert_true(len(result.sequences[0]) == 4, "ngram forward token count")
    assert_true(result.sequences[0][0] == 0, "ngram token 0")
    assert_true(result.sequences[0][1] == 1, "ngram token 1")
    assert_true(result.sequences[0][2] == 0, "ngram token 2")
    assert_true(result.sequences[0][3] == 2, "ngram blocked fallback token")
    assert_true(len(result.token_logprobs[0]) == 4, "ngram logprob steps")
    assert_true(len(result.top_logprobs[0][0]) >= 1, "ngram top logprob candidates")
}

func main() {
    println("NeurX text generator tests")
    test_generate_greedy_full_text()
    test_generate_new_tokens_only()
    test_generate_beam_search()
    test_generate_with_forward()
    test_generate_overload_with_forward()
    test_generate_contrastive_with_forward()
    test_generate_no_repeat_ngram_with_forward()
}
