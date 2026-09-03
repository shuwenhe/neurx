package main
use neurx.backends.cpu.transformer_decode.{cpu_transformer_result, cpu_abs, cpu_rms_norm, cpu_transformer_prefill_decode}
use neurx.models.formats.safetensors_embedding.{safetensors_embedding, load_f32_embedding}

func main() {
    []float input = make([]float, 2)
    input[0] = 3.0
    input[1] = 4.0
    []float normalized = cpu_rms_norm(input)
    if len(normalized) != 2 { return 1 }
    if cpu_abs(normalized[0] - 0.848528) > 0.001 { return 1 }
    if cpu_abs(normalized[1] - 1.131371) > 0.001 { return 1 }

    safetensors_embedding embedding = load_f32_embedding("artifact/build/commands/native-test/embedding.safetensors", "embedding.weight")
    []int tokens = make([]int, 2)
    tokens[0] = 1
    tokens[1] = 0
    cpu_transformer_result result = cpu_transformer_prefill_decode(embedding, tokens, 2)
    if !result.ok || result.next_token != 1 || result.generated_tokens != 2 { return 1 }
    if result.last_logit <= 0.0 { return 1 }
    println("PASS CPU Transformer kernel contract")
    0
}
