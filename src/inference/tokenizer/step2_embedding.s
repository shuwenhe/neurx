package step2_embedding
use neurx.inference.safetensors_loader.{load_tensor_embedding}

struct embedding_layer {
    int vocab_size
    int hidden_size
}
var GLOBAL_EMBEDDING [][]float

func create_embedding_layer() embedding_layer {
    return embedding_layer{
        vocab_size: 151936,
        hidden_size: 896
    }
}

func ensure_embeddings_loaded() {
    if len(GLOBAL_EMBEDDING) > 0 {
        return
    }
    string model_file = "/home/shuwen/shuwen/posttrain/model.safetensors"
    GLOBAL_EMBEDDING = load_tensor_embedding(model_file, 151936, 896)
}

func lookup_embedding(int token_id) []float {
    ensure_embeddings_loaded()
    if token_id < 0 || token_id >= len(GLOBAL_EMBEDDING) {
        []float zeros = []float{cap: 896}
        int i = 0
        while i < 896 { zeros[i] = 0.0; i = i + 1 }
        return zeros
    }
    GLOBAL_EMBEDDING[token_id]
}

func embed_tokens([]int token_ids) [][]float {
    [][]float result = [][]float{cap: len(token_ids)}
    int i = 0
    while i < len(token_ids) {
        result.push(lookup_embedding(token_ids[i]))
        i = i + 1
    }
    result
}
