struct verifier_config {
    string model_type
    int vocab_size
    float acceptance_threshold
    bool verify_all
    bool confidence_based_verification
    int max_verification_depth
}

struct verification_context {
    int draft_token_id
    draft_logits: []float
    int verified_token_id
    verified_logits: []float
    bool match_found
    int verification_depth
}

struct verifier_executor {
    verifier_config config
    model_embeddings: [][]float
    model_weights: [][]float
    int64 verification_count
    int64 acceptance_count
    int64 rejection_count
    float64 total_verify_time_ms
}

struct verification_batch {
    int batch_id
    draft_predictions: [][]draft_token
    verification_results: [][]verification_result
    float batch_accept_rate
    float batch_verify_time_ms
}

func new_verifier_config(int vocab, float threshold) verifier_config {
    cfg := verifier_config{
        model_type: "full_model",
        vocab_size: vocab,
        acceptance_threshold: threshold,
        verify_all: true,
        confidence_based_verification: true,
        max_verification_depth: 16,
    }
    cfg
}

func new_verifier_executor(verifier_config config) verifier_executor {
    executor := verifier_executor{
        config: config,
        model_embeddings: [][]float{},
        model_weights: [][]float{},
        verification_count: 0,
        acceptance_count: 0,
        rejection_count: 0,
        total_verify_time_ms: 0.0,
    }
    executor
}

func initialize_verifier_embeddings(verifier_executor executor, int vocab_size, int embed_dim) verifier_executor {
    updated := executor
    i := 0
    for i < vocab_size {
        embedding := []float{}
        j := 0
        for j < embed_dim {
            embedding = append(embedding, 0.02)
            j = j + 1
        }
        updated.model_embeddings = append(updated.model_embeddings, embedding)
        i = i + 1
    }
    updated
}

func verifier_embedding_lookup(verifier_executor executor, int token_id) []float {
    if token_id >= 0 && token_id < executor.model_embeddings.len {
        executor.model_embeddings[token_id]
    } else {
        []float{}
    }
}

func verifier_layer_forward([]float input, []float layer_weight, int hidden_dim) []float {
    output := []float{}
    i := 0
    for i < hidden_dim {
        val := 0.0
        j := 0
        for j < input.len {
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

func verifier_apply_residual([]float original, []float transformed) []float {
    result := []float{}
    i := 0
    for i < original.len && i < transformed.len {
        result = append(result, original[i] + transformed[i])
        i = i + 1
    }
    result
}

func verifier_forward_single(verifier_executor executor, int token_id, int hidden_dim) []float {
    hidden := verifier_embedding_lookup(executor, token_id)
    if hidden.len == 0 {
        return []float{}
    }
    i := 0
    for i < executor.model_weights.len && i < 24 {
        residual := hidden
        hidden = verifier_layer_forward(hidden, executor.model_weights[i], hidden_dim)
        hidden = draft_apply_activation(hidden)
        hidden = verifier_apply_residual(residual, hidden)
        i = i + 1
    }
    hidden
}

func verifier_output_logits([]float hidden_states, int vocab_size) []float {
    logits := []float{}
    i := 0
    for i < vocab_size {
        score := 0.0
        j := 0
        for j < hidden_states.len {
            idx := (i * hidden_states.len + j) % (hidden_states.len * 16)
            if idx < hidden_states.len {
                score = score + hidden_states[idx] * 0.1
            }
            j = j + 1
        }
        logits = append(logits, score)
        i = i + 1
    }
    logits
}

func verify_single_draft(verifier_executor executor, draft_token draft) verification_result {
    hidden := verifier_forward_single(executor, draft.token_id, 768)
    logits := verifier_output_logits(hidden, executor.config.vocab_size)
    is_match := verify_token_match(draft.logits, logits, 1.0)
    if is_match && draft.confidence >= executor.config.acceptance_threshold {
        vr := new_verification_result(true, 1, draft.token_id)
        vr.verification_logits = logits
        vr
    } else {
        fallback_token := 0
        if logits.len > 0 {
            max_logit := logits[0]
            j := 1
            for j < logits.len {
                if logits[j] > max_logit {
                    max_logit = logits[j]
                    fallback_token = j
                }
                j = j + 1
            }
        }
        vr := new_verification_result(false, 0, fallback_token)
        vr.verification_logits = logits
        vr
    }
}

func verify_draft_sequence(verifier_executor executor, []draft_token draft_sequence) []verification_result {
    results := []verification_result{}
    i := 0
    for i < draft_sequence.len {
        result := verify_single_draft(executor, draft_sequence[i])
        results = append(results, result)
        if result.accepted {
            executor.acceptance_count = executor.acceptance_count + 1
        } else {
            executor.rejection_count = executor.rejection_count + 1
        }
        executor.verification_count = executor.verification_count + 1
        i = i + 1
    }
    results
}

func verify_with_confidence_filtering(verifier_executor executor, []draft_token draft_sequence, float confidence_threshold) []verification_result {
    high_confidence := filter_predictions_by_confidence(draft_sequence, confidence_threshold)
    verify_draft_sequence(executor, high_confidence)
}

func compute_acceptance_rate([]verification_result results) float {
    accepted := 0
    i := 0
    for i < results.len {
        if results[i].accepted {
            accepted = accepted + 1
        }
        i = i + 1
    }
    if results.len > 0 {
        (accepted as float) / (results.len as float)
    } else {
        0.0
    }
}

func should_accept_draft(verification_result result, verifier_config config) bool {
    if !config.verify_all {
        return result.accepted
    }
    result.accepted
}

func get_verifier_stats(verifier_executor executor) string {
    result := "Verifier Stats:"
    result = result + " Verified=" + (executor.verification_count as string)
    result = result + " Accepted=" + (executor.acceptance_count as string)
    result = result + " Rejected=" + (executor.rejection_count as string)
    if executor.verification_count > 0 {
        acceptance_rate := (executor.acceptance_count as float) / (executor.verification_count as float)
        result = result + " AcceptRate=" + (acceptance_rate as string)
    }
    result
}

func reset_verifier_statistics(verifier_executor executor) verifier_executor {
    updated := executor
    updated.verification_count = 0
    updated.acceptance_count = 0
    updated.rejection_count = 0
    updated.total_verify_time_ms = 0.0
    updated
}

func adaptive_threshold_adjustment(verifier_executor executor, float current_acceptance_rate) verifier_executor {
    updated := executor
    if current_acceptance_rate > 0.9 {
        updated.config.acceptance_threshold = updated.config.acceptance_threshold - 0.05
    } else if current_acceptance_rate < 0.7 {
        updated.config.acceptance_threshold = updated.config.acceptance_threshold + 0.05
    }
    if updated.config.acceptance_threshold < 0.5 {
        updated.config.acceptance_threshold = 0.5
    }
    if updated.config.acceptance_threshold > 0.95 {
        updated.config.acceptance_threshold = 0.95
    }
    updated
}
