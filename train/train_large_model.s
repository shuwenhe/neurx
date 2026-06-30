package neurx.training.large_model

use neurx.model.llm.gpt_large_train.{
    gpt_large_training_config,
    gpt_large_training_state,
    new_gpt_large_training_config,
    new_gpt_large_training_state,
    gpt_large_training_run
}

func build_demo_documents() []string {
    []string{cap: 0}
}

func build_demo_config() gpt_large_training_config {
    new_gpt_large_training_config(2, 8, 3, 0.0005)
}

func train_large_model() gpt_large_training_state {
    []string documents = build_demo_documents()
    gpt_large_training_config config = build_demo_config()
    gpt_large_training_state state = new_gpt_large_training_state(documents, config)
    gpt_large_training_run(state, config.max_steps)
}

func main() int {
    println("NeurX large model training smoke test")
    gpt_large_training_state final_state = train_large_model()
    println("training steps: " + string(final_state.step))
    println("last loss: " + string(final_state.last_loss))
    println("last perplexity: " + string(final_state.last_perplexity))
    if final_state.finished {
        println("status: finished")
    } else {
        println("status: not finished")
    }
    return 0
}
