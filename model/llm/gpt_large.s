package neurx.model.llm.gpt_large

struct gpt_large_state {
    string name
    string family
    string architecture
    string dataset
    int vocab_size
    int max_seq_len
    int hidden_size
    int num_heads
    int num_layers
    int intermediate_size
    int context_window
    int parameter_count_m
    int training_steps
    int training_tokens_b
    float train_loss
    float train_perplexity
    float validation_loss
    float validation_perplexity
    float learning_rate
    float dropout
    float rope_base
    bool tied_embeddings
    int gradient_accum_steps
    int global_batch_tokens
    int current_step
    int seen_tokens
    float best_validation_loss
    bool trained
}

struct gpt_large_train_config {
    int steps
    int batch_size
    int seq_len
    int warmup_steps
    int eval_interval
    int tokens_per_step
    float target_loss
    float min_lr
}

func new_gpt_large_state() gpt_large_state {
    gpt_large_state {
        name: "gpt_large",
        family: "llm",
        architecture: "decoder-only-transformer",
        dataset: "synthetic_webtext_mix",
        vocab_size: 50257,
        max_seq_len: 2048,
        hidden_size: 4096,
        num_heads: 32,
        num_layers: 32,
        intermediate_size: 11008,
        context_window: 2048,
        parameter_count_m: 3400,
        training_steps: 0,
        training_tokens_b: 0,
        train_loss: 3.8,
        train_perplexity: 44.0,
        validation_loss: 3.9,
        validation_perplexity: 49.0,
        learning_rate: 0.00015,
        dropout: 0.0,
        rope_base: 10000.0,
        tied_embeddings: true,
        gradient_accum_steps: 8,
        global_batch_tokens: 1048576,
        current_step: 0,
        seen_tokens: 0,
        best_validation_loss: 3.9,
        trained: false,
    }
}

func new_gpt_large_train_config() gpt_large_train_config {
    gpt_large_train_config {
        steps: 2000,
        batch_size: 32,
        seq_len: 2048,
        warmup_steps: 200,
        eval_interval: 100,
        tokens_per_step: 65536,
        target_loss: 1.2,
        min_lr: 0.00001,
    }
}

func gpt_large_is_transformer_valid(gpt_large_state state) bool {
    if state.hidden_size <= 0 {
        return false
    }
    if state.num_heads <= 0 {
        return false
    }
    if state.num_layers <= 0 {
        return false
    }
    if state.max_seq_len <= 0 {
        return false
    }
    if state.hidden_size / state.num_heads * state.num_heads != state.hidden_size {
        return false
    }
    true
}

func gpt_large_head_dim(gpt_large_state state) int {
    if state.num_heads <= 0 {
        return 0
    }
    state.hidden_size / state.num_heads
}

func gpt_large_effective_lr(gpt_large_state state, gpt_large_train_config config, int step) float {
    float lr = state.learning_rate
    if config.warmup_steps > 0 && step < config.warmup_steps {
        lr = state.learning_rate * (step + 1) * 1.0 / (config.warmup_steps * 1.0)
    }
    if lr < config.min_lr {
        lr = config.min_lr
    }
    lr
}

func gpt_large_loss_after_step(gpt_large_state state, gpt_large_train_config config, int step) float {
    float capacity = (state.hidden_size * state.num_layers) * 1.0 / 131072.0
    if capacity < 1.0 {
        capacity = 1.0
    }
    float lr = gpt_large_effective_lr(state, config, step)
    float progress = (step + 1) * 1.0 * lr * capacity * 2.0
    float base_loss = 3.8
    float decay = base_loss / (1.0 + progress)
    float regularizer = 0.02 + state.dropout * 0.1
    float loss = decay + regularizer
    if loss < config.target_loss {
        return config.target_loss
    }
    loss
}

func gpt_large_perplexity_from_loss(float loss) float {
    1.0 + loss * loss * 3.0
}

func gpt_large_validation_loss_from_train(float train_loss) float {
    train_loss + 0.08
}

func gpt_large_train_step(gpt_large_state state, gpt_large_train_config config, int step) gpt_large_state {
    float train_loss = gpt_large_loss_after_step(state, config, step)
    float val_loss = gpt_large_validation_loss_from_train(train_loss)
    float train_ppl = gpt_large_perplexity_from_loss(train_loss)
    float val_ppl = gpt_large_perplexity_from_loss(val_loss)

    int seen_tokens = state.seen_tokens + config.tokens_per_step
    int tokens_b = seen_tokens / 1000000000
    float best_val = state.best_validation_loss
    if val_loss < best_val {
        best_val = val_loss
    }

    gpt_large_state {
        name: state.name,
        family: state.family,
        architecture: state.architecture,
        dataset: state.dataset,
        vocab_size: state.vocab_size,
        max_seq_len: state.max_seq_len,
        hidden_size: state.hidden_size,
        num_heads: state.num_heads,
        num_layers: state.num_layers,
        intermediate_size: state.intermediate_size,
        context_window: state.context_window,
        parameter_count_m: state.parameter_count_m,
        training_steps: state.training_steps + 1,
        training_tokens_b: tokens_b,
        train_loss: train_loss,
        train_perplexity: train_ppl,
        validation_loss: val_loss,
        validation_perplexity: val_ppl,
        learning_rate: gpt_large_effective_lr(state, config, step),
        dropout: state.dropout,
        rope_base: state.rope_base,
        tied_embeddings: state.tied_embeddings,
        gradient_accum_steps: state.gradient_accum_steps,
        global_batch_tokens: state.global_batch_tokens,
        current_step: step + 1,
        seen_tokens: seen_tokens,
        best_validation_loss: best_val,
        trained: false,
    }
}

func train_gpt_large(gpt_large_state state, gpt_large_train_config config) gpt_large_state {
    if !gpt_large_is_transformer_valid(state) {
        return state
    }
    int i = 0
    gpt_large_state current = state
    while i < config.steps {
        current = gpt_large_train_step(current, config, i)
        i = i + 1
    }
    bool trained = current.train_loss <= config.target_loss
    gpt_large_state {
        name: current.name,
        family: current.family,
        architecture: current.architecture,
        dataset: current.dataset,
        vocab_size: current.vocab_size,
        max_seq_len: current.max_seq_len,
        hidden_size: current.hidden_size,
        num_heads: current.num_heads,
        num_layers: current.num_layers,
        intermediate_size: current.intermediate_size,
        context_window: current.context_window,
        parameter_count_m: current.parameter_count_m,
        training_steps: current.training_steps,
        training_tokens_b: current.training_tokens_b,
        train_loss: current.train_loss,
        train_perplexity: current.train_perplexity,
        validation_loss: current.validation_loss,
        validation_perplexity: current.validation_perplexity,
        learning_rate: current.learning_rate,
        dropout: current.dropout,
        rope_base: current.rope_base,
        tied_embeddings: current.tied_embeddings,
        gradient_accum_steps: current.gradient_accum_steps,
        global_batch_tokens: current.global_batch_tokens,
        current_step: current.current_step,
        seen_tokens: current.seen_tokens,
        best_validation_loss: current.best_validation_loss,
        trained: trained,
    }
}

func train_default_gpt_large() gpt_large_state {
    gpt_large_state init_state = new_gpt_large_state()
    gpt_large_train_config config = new_gpt_large_train_config()
    train_gpt_large(init_state, config)
}

func gpt_large_next_token(gpt_large_state state, int token_id, int position) int {
    int next_token = token_id + position + state.num_layers + state.num_heads
    if state.vocab_size > 0 {
        next_token = next_token - (next_token / state.vocab_size) * state.vocab_size
    }
    next_token
}

func gpt_large_summary(gpt_large_state state) string {
    state.name + "[" + state.architecture + "," + string(state.parameter_count_m) + "M" + ",layers=" + string(state.num_layers) + ",heads=" + string(state.num_heads) + ",ctx=" + string(state.context_window) + "]"
}

func gpt_large_state_dict(gpt_large_state state) gpt_large_state {
    state
}

func gpt_large_load_state_dict(gpt_large_state state, gpt_large_state other) gpt_large_state {
    other
}
