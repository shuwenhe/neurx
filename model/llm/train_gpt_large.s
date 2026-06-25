package neurx.model.llm.train_gpt_large

use neurx.model.llm.gpt_large.{gpt_large_state, new_gpt_large_state, gpt_large_summary, gpt_large_is_transformer_valid}
use neurx.model.llm.gpt_large_train.{gpt_large_training_config, new_gpt_large_training_config, new_gpt_large_training_state, gpt_large_training_run}

func main() int {
    gpt_large_state init_state = new_gpt_large_state()
    gpt_large_training_config config = new_gpt_large_training_config(8, 16, 64, 0.00015)
    []string documents = []string{cap: 3}
    documents[0] = "neurx trains language models with s."
    documents[1] = "decoder only transformer training runs on token batches."
    documents[2] = "model level training keeps the pipeline explicit."

    gpt_large_training_state pipeline = new_gpt_large_training_state(documents, config)
    gpt_large_training_state trained = gpt_large_training_run(pipeline, config.max_steps)
    gpt_large_state snapshot = trained.model

    println("model: ", gpt_large_summary(snapshot))
    println("steps: ", snapshot.training_steps)
    println("train_loss: ", snapshot.train_loss)
    println("val_loss: ", snapshot.validation_loss)
    println("best_val_loss: ", snapshot.best_validation_loss)
    println("trained: ", snapshot.trained)

    if !gpt_large_is_transformer_valid(snapshot) {
        println("invalid transformer config")
        1
    }

    if snapshot.training_steps != config.max_steps {
        println("unexpected training step count")
        1
    }

    if snapshot.train_loss > init_state.train_loss {
        println("loss did not decrease")
        1
    }

    0
}
