package step2_embedding

struct embedding_layer {
    int vocab_size
    int hidden_size
}

func create_embedding_layer() embedding_layer {
    return embedding_layer{
        vocab_size: 151936,
        hidden_size: 896
    }
}

func lookup_embedding(int token_id) []float {
    []float embedding = make([]float, 896)
    int i = 0
    while i < 896 {
        embedding[i] = 0.0
        i = i + 1
    }
    return embedding
}

func embed_tokens([]int token_ids) [][]float {
    [][]float result = make([][]float, len(token_ids))
    int i = 0
    while i < len(token_ids) {
        result[i] = lookup_embedding(token_ids[i])
        i = i + 1
    }
    return result
}
