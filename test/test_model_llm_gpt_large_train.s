package neurx.test_model_llm_gpt_large_train

use neurx.model.llm.gpt_large.{gpt_large_state, new_gpt_large_state, gpt_large_is_transformer_valid}
use neurx.model.llm.gpt_large_train.{gpt_large_training_config, gpt_large_training_state, new_gpt_large_training_config, new_gpt_large_training_state, gpt_large_training_step, gpt_large_training_run}

func main() int {
    []string documents = []string{cap: 2}
    documents[0] = "neurx trains gpt models in s."
    documents[1] = "the pipeline consumes tokens, computes loss, and updates parameters."

    gpt_large_training_config config = new_gpt_large_training_config(4, 8, 4, 0.00015)
    gpt_large_training_state state = new_gpt_large_training_state(documents, config)
    if !gpt_large_is_transformer_valid(state.model) {
        println("invalid transformer config")
        return 1
    }

    gpt_large_training_state next_state = gpt_large_training_step(state)
    if next_state.step <= state.step {
        println("step did not advance")
        return 1
    }

    gpt_large_training_state trained = gpt_large_training_run(next_state, 3)
    if trained.model.training_steps < 1 {
        println("training steps did not update")
        return 1
    }

    println("gpt large train step: ", trained.step)
    println("train loss: ", trained.model.train_loss)
    println("val loss: ", trained.model.validation_loss)
    println("best val loss: ", trained.model.best_validation_loss)
    0
}
