package main
use neurx.inference.sampling_strategies
func assert_true(bool value, string name) {
    if value {
        println("PASS " + name)
    } else {
        println("FAIL " + name)
    }
}

func assert_close(float actual, float expected, string name) {
    float diff = actual - expected
    if diff < 0.0 {
        diff = -diff
    }
    assert_true(diff < 0.0001, name)
}

func test_temperature_and_penalty() {
    []float logits = [2.0, 4.0, 0.0]
    logits[2] = -2.0
    []float scaled = neurx.inference.sampling_strategies.apply_temperature(logits, 2.0)
    []float penalized = neurx.inference.sampling_strategies.apply_repetition_penalty(logits, [0, 2], 2.0)
    assert_close(scaled[0], 1.0, "temperature 0")
    assert_close(scaled[1], 2.0, "temperature 1")
    assert_close(penalized[0], 1.0, "penalty 0")
    assert_close(penalized[1], 4.0, "penalty 1")
    assert_close(penalized[2], -4.0, "penalty 2")
}

func test_presence_and_frequency() {
    []float logits = [5.0, 1.0, 0.0]
    []int past = [0, 0, 2]
    []float adjusted = neurx.inference.sampling_strategies.apply_presence_frequency_penalties(
        logits,
        past,
        1.0,
        0.5
    )
    assert_close(adjusted[0], 3.0, "presence frequency 0")
    assert_close(adjusted[1], 1.0, "presence frequency 1")
    assert_close(adjusted[2], -1.5, "presence frequency 2")
}

func test_ngram_blocking() {
    []float logits = [5.0, 4.0, 3.0, 2.0]
    []int past = [0, 1, 0]
    []int blocked = neurx.inference.sampling_strategies.get_blocked_tokens(past, 2, 4)
    []float adjusted = neurx.inference.sampling_strategies.apply_ngram_blocking(logits, past, 2)
    assert_true(len(blocked) == 1, "ngram blocked count")
    assert_true(blocked[0] == 1, "ngram blocked token")
    assert_close(adjusted[0], 5.0, "ngram keep 0")
    assert_true(adjusted[1] < -1000000000.0, "ngram mask 1")
}

func test_greedy_and_distribution() {
    []float logits = [1.0, 3.0, 2.0]
    int greedy = neurx.inference.sampling_strategies.greedy_sample(logits)
    int sampled = neurx.inference.sampling_strategies.sample_next_token_index(
        logits,
        [],
        neurx.inference.sampling_strategies.greedy_config(),
        123
    )
    int dist_idx = neurx.inference.sampling_strategies.sample_from_distribution_index([0.0, 1.0], 7)
    assert_true(greedy == 1, "greedy sample")
    assert_true(sampled == 1, "greedy config sample")
    assert_true(dist_idx == 1, "distribution sample")
}

func test_topk_and_topp() {
    []float logits = [10.0, 1.0, 0.5, 0.0]
    logits[3] = -2.0
    neurx.inference.sampling_strategies.sampling_config cfg = neurx.inference.sampling_strategies.new_sampling_config()
    cfg.temperature = 1.0
    cfg.top_k = 1
    cfg.top_p = 0.9
    cfg.do_sample = true
    []float topk_logits = neurx.inference.sampling_strategies.apply_top_k(logits, 1)
    []float topp_logits = neurx.inference.sampling_strategies.apply_top_p(logits, 0.5)
    int next_token = neurx.inference.sampling_strategies.sample_next_token_index(logits, [], cfg, 99)
    int alias_token = neurx.inference.sampling_strategies.sample_token(logits, [], cfg, 99)
    assert_close(topk_logits[0], 10.0, "topk keep")
    assert_true(topk_logits[1] < -1000000000.0, "topk mask 1")
    assert_true(topk_logits[2] < -1000000000.0, "topk mask 2")
    assert_true(topk_logits[3] < -1000000000.0, "topk mask 3")
    assert_close(topp_logits[0], 10.0, "topp keep")
    assert_true(topp_logits[1] < -1000000000.0, "topp mask 1")
    assert_true(next_token == 0, "sample next token with top-k")
    assert_true(alias_token == 0, "sample token alias")
}

func test_typical_sampling() {
    []float logits = [3.0, 2.0, 0.0, 0.0]
    logits[3] = -2.0
    neurx.inference.sampling_strategies.sampling_config cfg = neurx.inference.sampling_strategies.new_sampling_config()
    cfg.temperature = 1.0
    cfg.top_k = 0
    cfg.top_p = 0.0
    cfg.typical_p = 0.5
    cfg.do_sample = true
    []float typical_logits = neurx.inference.sampling_strategies.apply_typical_p(logits, 0.5)
    int next_token = neurx.inference.sampling_strategies.sample_next_token_index(logits, [], cfg, 99)
    assert_close(typical_logits[0], 3.0, "typical keep 0")
    assert_true(typical_logits[1] < -1000000000.0, "typical mask 1")
    assert_true(typical_logits[2] < -1000000000.0, "typical mask 2")
    assert_true(typical_logits[3] < -1000000000.0, "typical mask 3")
    assert_true(next_token == 0, "sample next token typical")
}

func test_contrastive_search() {
    []float logits = [4.0, 3.9, 1.0, 0.5]
    []int past = [0, 0, 2]
    neurx.inference.sampling_strategies.sampling_config cfg = neurx.inference.sampling_strategies.new_sampling_config()
    cfg.strategy = "contrastive"
    cfg.do_sample = true
    cfg.top_k = 0
    cfg.top_p = 0.0
    cfg.typical_p = 1.0
    cfg.contrastive_top_k = 2
    cfg.penalty_alpha = 0.8
    int next_token = neurx.inference.sampling_strategies.sample_next_token_index(logits, past, cfg, 99)
    assert_true(next_token == 1, "contrastive picks less repetitive token")
}

func test_beam_search() {
    []float step0 = [1.0, 3.0, 2.0]
    []float step1 = [0.5, 4.0, 1.0]
    neurx.inference.sampling_strategies.sampling_config cfg = neurx.inference.sampling_strategies.new_sampling_config()
    cfg.strategy = "beam_search"
    cfg.do_sample = false
    cfg.num_beams = 2
    cfg.max_length = 2
    cfg.min_length = 0
    cfg.early_stopping = true
    []int beam = neurx.inference.sampling_strategies.beam_search_decode_two_steps(step0, step1, cfg, 2)
    assert_true(len(beam) == 2, "beam length")
    assert_true(beam[0] == 1, "beam token 0")
    assert_true(beam[1] == 1, "beam token 1")
}

func main() {
    println("NeurX sampling strategies tests")
    test_temperature_and_penalty()
    test_presence_and_frequency()
    test_ngram_blocking()
    test_greedy_and_distribution()
    test_topk_and_topp()
    test_typical_sampling()
    test_contrastive_search()
    test_beam_search()
}
