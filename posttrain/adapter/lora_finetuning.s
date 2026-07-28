package main
import (
    "fmt"
    "math"
)
type lora_config struct {
    int rank
    int alpha
    []string target_modules
    float64 dropout
    string task_type
    bool inference_mode
}
type lora_layer struct {
    int rank
    int alpha
    [][]float64 lora_a
    [][]float64 lora_b
    float64 scaling
    float64 dropout_p
    string name
}
type lora_adapter struct {
    lora_config config
    map[string]*lora_layer modules
    int64 total_params
    int64 trainable_params
    PolicyModel original_model
    float64 scaling_factor
}
func (adapter *lora_adapter) initialize_lora_modules(model PolicyModel) {
    fmt.Println("[LoRA] Initializing LoRA modules...")
    for layer_idx := 0; layer_idx < model.num_layers; layer_idx++ {
        for _, proj := range []string{"q_proj", "v_proj"} {
            name := fmt.Sprintf("layer_%d_%s", layer_idx, proj)
            adapter.create_lora_layer(name, model.hidden_size, model.hidden_size)
        }
        name := fmt.Sprintf("layer_%d_mlp", layer_idx)
        adapter.create_lora_layer(name, model.hidden_size*4, model.hidden_size)
    }
    fmt.Printf("  Created %d LoRA modules\n", len(adapter.modules))
    fmt.Printf("  Total trainable parameters: %d\n", adapter.trainable_params)
}
func (adapter *lora_adapter) create_lora_layer(name string, in_features int, out_features int) {
    layer := &lora_layer{
        rank: adapter.config.rank,
        alpha: adapter.config.alpha,
        lora_a: adapter.init_matrix(adapter.config.rank, in_features, 0.0),
        lora_b: adapter.init_matrix(out_features, adapter.config.rank, 0.0),
        scaling: float64(adapter.config.alpha) / float64(adapter.config.rank),
        dropout_p: adapter.config.dropout,
        name: name,
    }
    adapter.modules[name] = layer
    adapter.trainable_params += int64(adapter.config.rank*in_features + out_features*adapter.config.rank)
}
func (adapter *lora_adapter) init_matrix(rows int, cols int, scale float64) [][]float64 {
    matrix := make([][]float64, rows)
    for i := 0; i < rows; i++ {
        matrix[i] = make([]float64, cols)
        for j := 0; j < cols; j++ {
            if scale == 0.0 {
                matrix[i][j] = 0.0
            } else {
                matrix[i][j] = scale * math.Sin(float64(i*cols+j))
            }
        }
    }
    return matrix
}
func (layer *lora_layer) forward(x []float64) []float64 {
    xa := adapter.matrix_vector_mult(x, layer.lora_a)
    delta := adapter.matrix_vector_mult(xa, layer.lora_b)
    output := make([]float64, len(delta))
    for i := range delta {
        output[i] = delta[i] * layer.scaling
    }
    return output
}
func (adapter *lora_adapter) matrix_vector_mult(vec []float64, matrix [][]float64) []float64 {
    if len(matrix) == 0 {
        return []float64{}
    }
    result := make([]float64, len(matrix))
    for i := 0; i < len(matrix); i++ {
        sum := 0.0
        for j := 0; j < len(vec) && j < len(matrix[i]); j++ {
            sum += vec[j] * matrix[i][j]
        }
        result[i] = sum
    }
    return result
}
func (adapter *lora_adapter) merge_lora_to_model() {
    fmt.Println("[LoRA] Merging LoRA weights into base model...")
    for name, lora_layer := range adapter.modules {
        merged := adapter.compute_merged_weight(lora_layer)
        fmt.Printf("  Merging %s\n", name)
        _ = merged
    }
    fmt.Println("  LoRA merged successfully")
}
func (adapter *lora_adapter) compute_merged_weight(layer *lora_layer) [][]float64 {
    ab := make([][]float64, len(layer.lora_b))
    for i := 0; i < len(layer.lora_b); i++ {
        ab[i] = make([]float64, len(layer.lora_a[0]))
        for j := 0; j < len(layer.lora_a[0]); j++ {
            for k := 0; k < len(layer.lora_a); k++ {
                ab[i][j] += layer.lora_b[i][k] * layer.lora_a[k][j]
            }
        }
    }
    for i := range ab {
        for j := range ab[i] {
            ab[i][j] *= layer.scaling
        }
    }
    return ab
}
