struct draft_model_config {
    model_size: string
    num_layers: int
    hidden_dim: int
    vocab_size: int
    num_heads: int
    compression_ratio: float
    shared_embeddings: bool
}

struct draft_model_executor {
    config: draft_model_config
    embeddings: [][]float
    layer_weights: [][]float
    output_projection: [][]float
    layer_cache: [][]float
    inference_count: int64
    total_time_ms: float64
}

struct draft_prediction_batch {
    batch_id: int
    input_ids: [][]int
    attention_mask: [][]bool
    batch_predictions: [][]draft_token
    batch_embeddings: [][]float
    batch_time_ms: float
}

func new_draft_model_config(size: string, num_layers: int, hidden: int, vocab: int) draft_model_config {
    cfg := draft_model_config{
        model_size: size,
        num_layers: num_layers,
        hidden_dim: hidden,
        vocab_size: vocab,
        num_heads: 8,
        compression_ratio: 0.3,
        shared_embeddings: true,
    }
    cfg
}

func new_draft_model_executor(config: draft_model_config) draft_model_executor {
    executor := draft_model_executor{
        config: config,
        embeddings: [][]float{},
        layer_weights: [][]float{},
        output_projection: [][]float{},
        layer_cache: [][]float{},
        inference_count: 0,
        total_time_ms: 0.0,
    }
    executor
}

func initialize_draft_embeddings(executor: draft_model_executor, vocab_size: int, embed_dim: int) draft_model_executor {
    updated := executor

    i := 0
    while i < vocab_size {
        embedding := []float{}
        j := 0
        while j < embed_dim {
            embedding = append(embedding, 0.01)
            j = j + 1
        }
        updated.embeddings = append(updated.embeddings, embedding)
        i = i + 1
    }

    updated
}

func initialize_draft_layers(executor: draft_model_executor, num_layers: int, hidden_dim: int) draft_model_executor {
    updated := executor

    i := 0
    while i < num_layers {
        layer_weight := []float{}
        j := 0
        while j < hidden_dim * hidden_dim / 8 {
            layer_weight = append(layer_weight, 0.01)
            j = j + 1
        }
        updated.layer_weights = append(updated.layer_weights, layer_weight)
        i = i + 1
    }

    updated
}

func draft_embedding_lookup(executor: draft_model_executor, token_id: int) []float {
    if token_id >= 0 && token_id < executor.embeddings.len {
        executor.embeddings[token_id]
    } else {
        []float{}
    }
}

func draft_layer_forward(input: []float, layer_weight: []float, hidden_dim: int) []float {
    output := []float{}

    i := 0
    while i < hidden_dim {
        val := 0.0
        j := 0
        while j < input.len {
            idx := i * input.len + j
            if idx < layer_weight.len {
                val = val + input[j] * layer_weight[idx]
            }
            j = j + 1
        }
        output = append(output, val)
        i = i + 1
    }

    output
}

func draft_apply_activation(hidden_states: []float) []float {
    activated := []float{}
    i := 0
    while i < hidden_states.len {
        x := hidden_states[i]
        if x > 0.0 {
            activated = append(activated, x)
        } else {
            activated = append(activated, x * 0.01)
        }
        i = i + 1
    }
    activated
}

func draft_normalize(hidden_states: []float) []float {
    mean := 0.0
    i := 0
    while i < hidden_states.len {
        mean = mean + hidden_states[i]
        i = i + 1
    }
    if hidden_states.len > 0 {
        mean = mean / (hidden_states.len as float)
    }

    variance := 0.0
    i = 0
    while i < hidden_states.len {
        diff := hidden_states[i] - mean
        variance = variance + diff * diff
        i = i + 1
    }
    if hidden_states.len > 0 {
        variance = variance / (hidden_states.len as float)
    }

    normalized := []float{}
    i = 0
    while i < hidden_states.len {
        normalized = append(normalized, (hidden_states[i] - mean) / (1e-5 + (variance ^ 0.5)))
        i = i + 1
    }
    normalized
}

func draft_forward_single(executor: draft_model_executor, token_id: int) []float {
    hidden := draft_embedding_lookup(executor, token_id)

    if hidden.len == 0 {
        return []float{}
    }

    i := 0
    while i < executor.config.num_layers && i < executor.layer_weights.len {
        hidden = draft_layer_forward(hidden, executor.layer_weights[i], executor.config.hidden_dim)
        hidden = draft_apply_activation(hidden)
        hidden = draft_normalize(hidden)
        i = i + 1
    }

    hidden
}

func draft_output_logits(executor: draft_model_executor, hidden_states: []float) []float {
    logits := []float{}

    i := 0
    while i < executor.config.vocab_size {
        score := 0.0
        j := 0
        while j < hidden_states.len && j < executor.output_projection.len {
            score = score + hidden_states[j] * executor.output_projection[i][j]
            j = j + 1
        }
        logits = append(logits, score)
        i = i + 1
    }

    logits
}

func draft_predict_next_token(executor: draft_model_executor, token_id: int, config: speculative_decode_config) draft_token {
    hidden := draft_forward_single(executor, token_id)
    logits := draft_output_logits(executor, hidden)
    confidence := compute_confidence_score(logits)

    dt := new_draft_token(
        sample_top_k(logits, config.top_k, config.temperature),
        logits,
        confidence,
    )
    dt
}

func draft_predict_batch(executor: draft_model_executor, input_ids: []int, config: speculative_decode_config) []draft_token {
    predictions := []draft_token{}

    i := 0
    while i < input_ids.len {
        if i < config.num_draft_tokens {
            pred := draft_predict_next_token(executor, input_ids[i], config)
            predictions = append(predictions, pred)
        }
        i = i + 1
    }

    predictions
}

func draft_batch_forward(executor: draft_model_executor, batch: draft_prediction_batch, config: speculative_decode_config) draft_prediction_batch {
    updated := batch

    i := 0
    while i < batch.input_ids.len {
        predictions := draft_predict_batch(executor, batch.input_ids[i], config)
        updated.batch_predictions = append(updated.batch_predictions, predictions)
        i = i + 1
    }

    executor.inference_count = executor.inference_count + 1
    updated
}

func get_draft_model_stats(executor: draft_model_executor) string {
    result := "Draft Model Stats:"
    result = result + " Inferences=" + (executor.inference_count as string)
    result = result + " TotalTime=" + (executor.total_time_ms as string) + "ms"
    if executor.inference_count > 0 {
        avg_time := executor.total_time_ms / (executor.inference_count as float)
        result = result + " AvgTime=" + (avg_time as string) + "ms"
    }
    result
}

func clear_draft_cache(executor: draft_model_executor) draft_model_executor {
    updated := executor
    updated.layer_cache = [][]float{}
    updated
}
