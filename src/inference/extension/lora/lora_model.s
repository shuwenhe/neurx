package lora
type lora_dtype string
const (
    lora_dtype_fp32   lora_dtype = "fp32"
    lora_dtype_fp16   lora_dtype = "fp16"
    lora_dtype_bf16   lora_dtype = "bf16"
)
type adapter_status string
const (
    status_unloaded    adapter_status = "unloaded"
    status_loading     adapter_status = "loading"
    status_loaded      adapter_status = "loaded"
    status_inactive    adapter_status = "inactive"
)
struct lora_config {
    int32 rank
    int32 lora_alpha
    float32 dropout
    bool target_conv2d
    string target_modules
    bool modules_to_save
}

struct lora_matrix {
    float32[][]] weights
    int32 rows
    int32 cols
    lora_dtype dtype
}

struct lora_layer {
    lora_matrix* lora_a
    lora_matrix* lora_b
    string layer_name
    bool is_active
}

struct lora_model {
    string adapter_name
    lora_config config
    map[string]lora_layer* layers
    adapter_status status
    int32 num_layers
    int32 total_params
    int32 trainable_params
}

func create_lora_model(string adapter_name, lora_config config) lora_model* {
    model := lora_model{
        adapter_name: adapter_name,
        config: config,
        layers: make(map[string]lora_layer*),
        status: status_unloaded,
        num_layers: 0,
        total_params: 0,
        trainable_params: 0,
    }
    return *model
}

func (lora_model* model) add_lora_layer(string layer_name, int32 in_features, int32 out_features) {
    layer := *lora_layer{
        lora_a: *lora_matrix{
            weights: make(float32[][]]),
            rows: model.config.rank,
            cols: in_features,
            dtype: lora_dtype_fp32,
        },
        lora_b: *lora_matrix{
            weights: make(float32[][]]),
            rows: out_features,
            cols: model.config.rank,
            dtype: lora_dtype_fp32,
        },
        layer_name: layer_name,
        is_active: true,
    }
    model.layers[layer_name] = layer
    model.num_layers = model.num_layers + 1
    model.trainable_params = model.trainable_params + (model.config.rank * in_features) + (out_features * model.config.rank)
}

func (lora_model* model) activate_layer(string layer_name) bool {
    if layer, exists := model.layers[layer_name]; exists {
        layer.is_active = true
        return true
    }
    return false
}

func (lora_model* model) deactivate_layer(string layer_name) bool {
    if layer, exists := model.layers[layer_name]; exists {
        layer.is_active = false
        return true
    }
    return false
}

func (lora_model* model) get_lora_layer(string layer_name) lora_layer* {
    if layer, exists := model.layers[layer_name]; exists {
        return layer
    }
    return nil
}

func (lora_model* model) set_status(adapter_status new_status) {
    model.status = new_status
}

func (lora_model* model) is_loaded() bool {
    return model.status == status_loaded
}

func (lora_model* model) initialize_weights() {
    for name := range model.layers {
        layer := model.layers[name]
        layer.lora_a.weights = make(float32[][]])
        for i := 0; i < layer.lora_a.rows; i = i + 1 {
            row := make(float32[])
            for j := 0; j < layer.lora_a.cols; j = j + 1 {
                row = append(row, 0.1)
            }
            layer.lora_a.weights = append(layer.lora_a.weights, row)
        }
        layer.lora_b.weights = make(float32[][]])
        for i := 0; i < layer.lora_b.rows; i = i + 1 {
            row := make(float32[])
            for j := 0; j < layer.lora_b.cols; j = j + 1 {
                row = append(row, 0.0)
            }
            layer.lora_b.weights = append(layer.lora_b.weights, row)
        }
    }
}

func (lora_model* model) validate_config() bool {
    if model.config.rank <= 0 {
        return false
    }
    if model.config.lora_alpha <= 0 {
        return false
    }
    if model.config.dropout < 0.0 || model.config.dropout > 1.0 {
        return false
    }
    return true
}

func (lora_model* model) get_model_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["adapter_name"] = model.adapter_name
    stats["status"] = model.status
    stats["num_layers"] = model.num_layers
    stats["total_params"] = model.total_params
    stats["trainable_params"] = model.trainable_params
    stats["rank"] = model.config.rank
    stats["lora_alpha"] = model.config.lora_alpha
    stats["dropout"] = model.config.dropout
    active_layers := 0
    for name := range model.layers {
        if model.layers[name].is_active {
            active_layers = active_layers + 1
        }
    }
    stats["active_layers"] = active_layers
    return stats
}

func (lora_model* model) compute_scaling_factor() float32 {
    if model.config.lora_alpha == 0 {
        return 1.0
    }
    scaling := float32(model.config.lora_alpha) / float32(model.config.rank)
    return scaling
}
