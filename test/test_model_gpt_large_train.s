package neurx.test_model_gpt_large_train

use neurx.model.llm.gpt_large

func main() int {
    gpt_large_state init_state = new_gpt_large_state()
    if !gpt_large_is_transformer_valid(init_state) {
        println("initial transformer config should be valid")
        1
    }

    if gpt_large_head_dim(init_state) != 128 {
        println("head dim should be hidden_size / num_heads")
        1
    }

    gpt_large_train_config config = new_gpt_large_train_config()
    config.steps = 120
    config.warmup_steps = 20
    config.tokens_per_step = 65536
    config.target_loss = 1.8

    gpt_large_state trained = train_gpt_large(init_state, config)

    if trained.training_steps != config.steps {
        println("training step mismatch")
        1
    }

    if trained.current_step != config.steps {
        println("current_step mismatch")
        1
    }

    if trained.seen_tokens != config.steps * config.tokens_per_step {
        println("seen token accounting mismatch")
        1
    }

    if trained.train_loss > init_state.train_loss {
        println("expected training loss to decrease")
        1
    }

    if trained.best_validation_loss > trained.validation_loss {
        println("best validation loss should be <= current validation loss")
        1
    }

    println("gpt_large train test passed")
    0
}
