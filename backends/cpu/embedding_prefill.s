package neurx.backends.cpu.embedding_prefill
use neurx.backends.api.inference_backend.{backend_generation_result, backend_generation_success, backend_generation_failure}
use neurx.models.formats.safetensors_embedding.{safetensors_embedding, embedding_lookup_result, lookup_f32_embedding}

func prefill_index_text(int index) string {
    if index == 0 { return "0" }
    if index == 1 { return "1" }
    if index == 2 { return "2" }
    if index == 3 { return "3" }
    if index == 4 { return "4" }
    if index == 5 { return "5" }
    if index == 6 { return "6" }
    if index == 7 { return "7" }
    if index == 8 { return "8" }
    if index == 9 { return "9" }
    "many"
}

func cpu_embedding_prefill(safetensors_embedding embedding, []int token_ids) backend_generation_result {
    if !embedding.valid { return backend_generation_failure("cpu-prefill", embedding.error_code, "embedding model is invalid") }
    if len(token_ids) == 0 { return backend_generation_failure("cpu-prefill", "empty_tokens", "tokenizer produced no tokens") }
    []float hidden = []float{cap: embedding.columns}
    int column = 0
    while column < embedding.columns { hidden[column] = 0.0; column = column + 1 }
    int token = 0
    while token < len(token_ids) {
        embedding_lookup_result row = lookup_f32_embedding(embedding, token_ids[token])
        if !row.ok { return backend_generation_failure("cpu-prefill", row.error_code, "embedding lookup failed") }
        column = 0
        while column < embedding.columns {
            hidden[column] = hidden[column] + row.values[column]
            column = column + 1
        }
        token = token + 1
    }
    column = 0
    int best = 0
    while column < embedding.columns {
        hidden[column] = hidden[column] / (len(token_ids) * 1.0)
        if hidden[column] > hidden[best] { best = column }
        column = column + 1
    }
    backend_generation_success("prefill:" + prefill_index_text(best), "cpu-prefill")
}
