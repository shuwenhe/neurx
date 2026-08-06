package main
func test_close(float actual, float expected, float tolerance) bool {
    float delta = actual - expected
    if delta < 0.0 {
        delta = -delta
    }
    delta <= tolerance
}

func main() {
    if !test_close(pretrain_eval_perplexity_from_loss(0.0), 1.0, 0.000001) {
        println("[pretrain-eval] FAIL: exp(0)")
        return 1
    }
    if !test_close(pretrain_eval_perplexity_from_loss(0.6931471805599453), 2.0, 0.00001) {
        println("[pretrain-eval] FAIL: exp(ln(2))")
        return 2
    }
    if !test_close(pretrain_eval_perplexity_from_loss(1.0), 2.718281828459045, 0.00002) {
        println("[pretrain-eval] FAIL: exp(1)")
        return 3
    }
    pretrain_eval_state state = new_pretrain_eval_state()
    state = pretrain_eval_update_from_loss(state, 10, 1.0)
    if !pretrain_eval_has_result(state) || !pretrain_eval_is_best(state) {
        println("[pretrain-eval] FAIL: first result")
        return 4
    }
    if !test_close(state.ppl, 2.718281828459045, 0.00002) {
        println("[pretrain-eval] FAIL: state perplexity")
        return 5
    }
    println("[pretrain-eval] perplexity exp(mean_nll): PASS")
    0
}
