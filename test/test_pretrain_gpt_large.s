package neurx.test_pretrain_gpt_large

use neurx.pretrain.llm.gpt_large_pretrain.{gpt_large_pretrain_state, new_gpt_large_pretrain_state, gpt_large_pretrain_step, gpt_large_pretrain_run, gpt_large_pretrain_complete}

func main() int {
    gpt_large_pretrain_state state = new_gpt_large_pretrain_state()
    if gpt_large_pretrain_complete(state) {
        println("pretrain should not be complete at init")
        return 1
    }

    gpt_large_pretrain_state next_state = gpt_large_pretrain_step(state)
    if next_state.loop.global_step <= state.loop.global_step {
        println("pretrain step did not advance")
        return 1
    }

    gpt_large_pretrain_state trained = gpt_large_pretrain_run(next_state, 4)
    println("pretrain step: ", trained.loop.global_step)
    println("pretrain loss: ", trained.training.model.train_loss)
    println("pretrain val loss: ", trained.training.model.validation_loss)
    println("pretrain best val loss: ", trained.checkpoint.best_metric)
    0
}
