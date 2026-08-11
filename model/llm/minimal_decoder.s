package neurx.model.llm.minimal_decoder
struct minimal_decoder_state {
    string name
    string family
    string dataset
    int vocab_size
    int hidden_size
    int num_layers
    int max_seq_len
    float train_loss
    float train_perplexity
    bool trained
}

func new_minimal_decoder_state() minimal_decoder_state {
    minimal_decoder_state {
        name: "minimal_decoder",
        family: "llm",
        dataset: "synthetic_text",
        vocab_size: 256,
        hidden_size: 64,
        num_layers: 2,
        max_seq_len: 128,
        train_loss: 1.8,
        train_perplexity: 6.0,
        trained: true,
    }
}

func minimal_decoder_generate_next(minimal_decoder_state state, int token_id, int position) int {
    int next_token = token_id + position + state.num_layers
    if state.vocab_size > 0 {
        next_token = next_token - (next_token / state.vocab_size) * state.vocab_size
    }
    next_token
}

func minimal_decoder_state_dict(minimal_decoder_state state) minimal_decoder_state {
    state
}

func minimal_decoder_load_state_dict(minimal_decoder_state state, minimal_decoder_state other) minimal_decoder_state {
    other
}
