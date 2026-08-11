package neurx.inference.advanced.pooling
func pooling_copy_row([]float hidden_states, int sequence_length, int hidden_size, int row) []float {
    []float output = []float{cap: hidden_size}
    if sequence_length <= 0 || hidden_size <= 0 || row < 0 || row >= sequence_length || len(hidden_states) < sequence_length * hidden_size {
        return output
    }
    int i = 0
    while i < hidden_size {
        output[i] = hidden_states[row * hidden_size + i]
        i = i + 1
    }
    output
}
func pooling_cls([]float hidden_states, int sequence_length, int hidden_size) []float {
    pooling_copy_row(hidden_states, sequence_length, hidden_size, 0)
}
func pooling_last([]float hidden_states, []int attention_mask, int sequence_length, int hidden_size) []float {
    int row = sequence_length - 1
    if len(attention_mask) >= sequence_length {
        int i = sequence_length - 1
        while i >= 0 {
            if attention_mask[i] > 0 {
                row = i
                break
            }
            i = i - 1
        }
    }
    pooling_copy_row(hidden_states, sequence_length, hidden_size, row)
}
func pooling_mean([]float hidden_states, []int attention_mask, int sequence_length, int hidden_size) []float {
    []float output = []float{cap: hidden_size}
    if sequence_length <= 0 || hidden_size <= 0 || len(hidden_states) < sequence_length * hidden_size {
        return output
    }
    int token_count = 0
    int token = 0
    while token < sequence_length {
        bool include = true
        if len(attention_mask) >= sequence_length {
            include = attention_mask[token] > 0
        }
        if include {
            int i = 0
            while i < hidden_size {
                output[i] = output[i] + hidden_states[token * hidden_size + i]
                i = i + 1
            }
            token_count = token_count + 1
        }
        token = token + 1
    }
    if token_count > 0 {
        int i = 0
        while i < hidden_size {
            output[i] = output[i] / float(token_count)
            i = i + 1
        }
    }
    output
}
func pooling_l2_normalize([]float embedding) []float {
    []float output = []float{cap: len(embedding)}
    float squared_norm = 0.0
    int i = 0
    while i < len(embedding) {
        squared_norm = squared_norm + embedding[i] * embedding[i]
        i = i + 1
    }
    if squared_norm <= 0.0 {
        return output
    }
    float norm = sqrt(squared_norm)
    i = 0
    while i < len(embedding) {
        output[i] = embedding[i] / norm
        i = i + 1
    }
    output
}
func pooling_cosine_similarity([]float left, []float right) float {
    int length = len(left)
    if len(right) < length {
        length = len(right)
    }
    float dot = 0.0
    float left_norm = 0.0
    float right_norm = 0.0
    int i = 0
    while i < length {
        dot = dot + left[i] * right[i]
        left_norm = left_norm + left[i] * left[i]
        right_norm = right_norm + right[i] * right[i]
        i = i + 1
    }
    if left_norm <= 0.0 || right_norm <= 0.0 {
        return 0.0
    }
    dot / (sqrt(left_norm) * sqrt(right_norm))
}
func pooling_linear_head([]float embedding, []float weights, []float bias, int label_count) []float {
    []float logits = []float{cap: label_count}
    if label_count <= 0 || len(embedding) <= 0 || len(weights) < label_count * len(embedding) {
        return logits
    }
    int label = 0
    while label < label_count {
        float score = 0.0
        if label < len(bias) {
            score = bias[label]
        }
        int i = 0
        while i < len(embedding) {
            score = score + weights[label * len(embedding) + i] * embedding[i]
            i = i + 1
        }
        logits[label] = score
        label = label + 1
    }
    logits
}
func pooling_rerank([]float query_embedding, []float document_embeddings, int document_count, int embedding_size) []float {
    []float scores = []float{cap: document_count}
    if document_count <= 0 || embedding_size <= 0 || len(document_embeddings) < document_count * embedding_size {
        return scores
    }
    int document = 0
    while document < document_count {
        float dot = 0.0
        float query_norm = 0.0
        float document_norm = 0.0
        int i = 0
        while i < embedding_size && i < len(query_embedding) {
            float query_value = query_embedding[i]
            float document_value = document_embeddings[document * embedding_size + i]
            dot = dot + query_value * document_value
            query_norm = query_norm + query_value * query_value
            document_norm = document_norm + document_value * document_value
            i = i + 1
        }
        if query_norm > 0.0 && document_norm > 0.0 {
            scores[document] = dot / (sqrt(query_norm) * sqrt(document_norm))
        } else {
            scores[document] = 0.0
        }
        document = document + 1
    }
    scores
}
