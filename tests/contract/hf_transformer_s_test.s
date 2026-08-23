package main
use neurx.backends.cpu.transformer_decode.{hf_cpu_config, hf_kv_cache, hf_layer_result, new_hf_kv_cache, hf_cpu_layer}
use neurx.models.loaders.hf_transformer.{hf_layer_weights}

func matrix(int rows, int columns, float diagonal, float other) []float {
    []float values = []float{cap: rows * columns}
    int row = 0
    while row < rows {
        int column = 0
        while column < columns {
            values[row * columns + column] = other
            if row == column { values[row * columns + column] = diagonal }
            column = column + 1
        }
        row = row + 1
    }
    values
}

func ones(int count) []float {
    []float values = []float{cap: count}
    int i = 0
    while i < count { values[i] = 1.0; i = i + 1 }
    values
}

func main() {
    hf_cpu_config config = hf_cpu_config { hidden_size: 4, intermediate_size: 4, attention_heads: 2, kv_heads: 1, head_dim: 2, rms_epsilon: 0.00001, rope_theta: 10000.0 }
    hf_layer_weights weights = hf_layer_weights {
        valid: true,
        input_norm: ones(4),
        q_proj: matrix(4, 4, 1.0, 0.0),
        k_proj: matrix(2, 4, 1.0, 0.0),
        v_proj: matrix(2, 4, 1.0, 0.0),
        o_proj: matrix(4, 4, 1.0, 0.0),
        post_norm: ones(4),
        gate_proj: matrix(4, 4, 1.0, 0.0),
        up_proj: matrix(4, 4, 1.0, 0.0),
        down_proj: matrix(4, 4, 1.0, 0.0),
        error_code: "",
    }
    []float first = ones(4)
    hf_kv_cache cache = new_hf_kv_cache(4, 2)
    hf_layer_result result = hf_cpu_layer(config, weights, first, cache, 0)
    if !result.ok || result.cache.length != 1 || len(result.hidden) != 4 { return 1 }
    []float second = []float{cap: 4}
    second[0] = 2.0
    second[1] = 1.0
    second[2] = 0.5
    second[3] = 0.25
    result = hf_cpu_layer(config, weights, second, result.cache, 1)
    if !result.ok || result.cache.length != 2 || len(result.hidden) != 4 { return 1 }
    if result.hidden[0] == second[0] { return 1 }
    println("PASS pure S HF Transformer GQA RoPE KV contract")
    0
}
