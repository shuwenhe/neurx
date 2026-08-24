package main
use neurx.models.formats.safetensors_embedding.{safetensors_embedding, embedding_lookup_result, load_f32_embedding, lookup_f32_embedding}

func main() {
    safetensors_embedding embedding = load_f32_embedding("artifact/build/commands/model-format-test/embedding.safetensors", "embedding.weight")
    if !embedding.valid || embedding.rows != 2 || embedding.columns != 4 { return 1 }
    embedding_lookup_result row = lookup_f32_embedding(embedding, 1)
    if !row.ok || len(row.values) != 4 { return 1 }
    if row.values[0] != 5.0 || row.values[1] != 6.0 || row.values[2] != 7.0 || row.values[3] != 8.0 { return 1 }
    row = lookup_f32_embedding(embedding, 2)
    if row.ok || row.error_code != "token_out_of_range" { return 1 }
    println("PASS SafeTensors CPU embedding contract")
    0
}
