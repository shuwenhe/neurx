package model


    float32
    float16
    bfloat16
    int8
    int4
    nf4
}


    none
    symmetric
    asymmetric
    per_channel
    per_token
}

struct parameter_metadata {
    string param_name
    vec[int64] shape
    parameter_dtype dtype
    int64 total_elements
    int64 size_bytes
    quantization_method quant_method
    bool is_quantized
    string device_type
}

struct quantization_config {
    quantization_method method
    parameter_dtype target_dtype
    bool per_channel
    float scale_factor
    bool symmetric
}

struct model_weight {
    string weight_id
    parameter_metadata metadata
    int64 ptr
    bool is_packed
    int64 pack_ratio
    map[string, string] attributes
}

struct packed_weight {
    string weight_id
    string original_weight_id
    int64 ptr
    int64 compressed_size
    int64 original_size
    string compression_algorithm
    bool is_compressed
}

struct quantized_weight {
    string weight_id
    parameter_dtype original_dtype
    parameter_dtype quantized_dtype
    int64 scale_ptr
    int64 zero_ptr
    int64 weight_ptr
    quantization_config config
    float scale
    float zero_point
}

struct weight_parameter {
    model_weight weight
    quantized_weight quant_data
    bool uses_quantization
    bool uses_packing
}

func new_parameter_metadata(string name, vec[int64] shape, parameter_dtype dtype) parameter_metadata {
    total_elements := 1
    i := 0
    for i < shape.len() {
        total_elements = total_elements * shape[i]
        i = i + 1
    }

    size_bytes := total_elements * 4
    switch dtype {
        parameter_dtype::float32 : size_bytes = total_elements * 4,
        parameter_dtype::float16 : size_bytes = total_elements * 2,
        parameter_dtype::bfloat16 : size_bytes = total_elements * 2,
        parameter_dtype::int8 : size_bytes = total_elements,
        parameter_dtype::int4 : size_bytes = total_elements / 2,
        parameter_dtype::nf4 : size_bytes = total_elements / 2,
    }

    parameter_metadata {
        param_name: name,
        shape: shape,
        dtype: dtype,
        total_elements: total_elements,
        size_bytes: size_bytes,
        quant_method: quantization_method::none,
        is_quantized: false,
        device_type: "cuda",
    }
}

func new_model_weight(string weight_id, parameter_metadata metadata) model_weight {
    model_weight {
        weight_id: weight_id,
        metadata: metadata,
        ptr: 0,
        is_packed: false,
        pack_ratio: 1,
        attributes: map[string, string]{},
    }
}

func new_quantized_weight(string weight_id, parameter_dtype original_dtype, parameter_dtype target_dtype) quantized_weight {
    quantized_weight {
        weight_id: weight_id,
        original_dtype: original_dtype,
        quantized_dtype: target_dtype,
        scale_ptr: 0,
        zero_ptr: 0,
        weight_ptr: 0,
        config: quantization_config {
            method: quantization_method::symmetric,
            target_dtype: target_dtype,
            per_channel: true,
            scale_factor: 1.0,
            symmetric: true,
        },
        scale: 1.0,
        zero_point: 0.0,
    }
}

func new_packed_weight(string weight_id, string original_weight_id, string algorithm) packed_weight {
    packed_weight {
        weight_id: weight_id,
        original_weight_id: original_weight_id,
        ptr: 0,
        compressed_size: 0,
        original_size: 0,
        compression_algorithm: algorithm,
        is_compressed: false,
    }
}

func (model_weight* weight) get_dtype_string() string {
    switch weight.metadata.dtype {
        parameter_dtype::float32 : "float32",
        parameter_dtype::float16 : "float16",
        parameter_dtype::bfloat16 : "bfloat16",
        parameter_dtype::int8 : "int8",
        parameter_dtype::int4 : "int4",
        parameter_dtype::nf4 : "nf4",
    }
}

func (model_weight* weight) get_size_bytes() int64 {
    weight.metadata.size_bytes
}

func (model_weight* weight) get_total_elements() int64 {
    weight.metadata.total_elements
}

func (model_weight* weight) set_device(string device_type) () {
    weight.metadata.device_type = device_type
}

func (model_weight* weight) get_device() string {
    weight.metadata.device_type
}

func (quantized_weight* qweight) set_scales(float scale, float zero_pt) () {
    qweight.scale = scale
    qweight.zero_point = zero_pt
}

func (quantized_weight* qweight) get_compression_ratio() float {
    switch qweight.quantized_dtype {
        parameter_dtype::int8 : 4.0,
        parameter_dtype::int4 : 8.0,
        parameter_dtype::nf4 : 8.0,
        parameter_dtype::float16 : 2.0,
        parameter_dtype::float32 : 1.0,
        parameter_dtype::bfloat16 : 2.0,
    }
}

func (weight_parameter* pweight) enable_quantization() bool {
    pweight.uses_quantization = true
    true
}

func (weight_parameter* pweight) enable_packing() bool {
    pweight.uses_packing = true
    true
}

func (weight_parameter* pweight) is_compressed() bool {
    pweight.uses_quantization || pweight.uses_packing
}

struct layer_weights {
    string layer_id
    map[string, weight_parameter] weights
    int64 total_memory_bytes
    bool all_quantized
    int weight_count
}

func new_layer_weights(string layer_id) layer_weights {
    layer_weights {
        layer_id: layer_id,
        weights: map[string, weight_parameter]{},
        total_memory_bytes: 0,
        all_quantized: false,
        weight_count: 0,
    }
}

func (layer_weights* layer) add_weight(string weight_id, weight_parameter param) bool {
    layer.weights[weight_id] = param
    layer.total_memory_bytes = layer.total_memory_bytes + param.weight.get_size_bytes()
    layer.weight_count = layer.weight_count + 1
    true
}

func (layer_weights* layer) get_weight(string weight_id) weight_parameter {
    if weight_id in layer.weights {
        layer.weights[weight_id]
    }

    metadata := new_parameter_metadata("", vec[int64]{}, parameter_dtype::float32)
    weight := new_model_weight("", metadata)
    weight_parameter {
        weight: weight,
        quant_data: new_quantized_weight("", parameter_dtype::float32, parameter_dtype::float32),
        uses_quantization: false,
        uses_packing: false,
    }
}

func (layer_weights* layer) has_weight(string weight_id) bool {
    weight_id in layer.weights
}

func (layer_weights* layer) get_total_memory() int64 {
    layer.total_memory_bytes
}

func (layer_weights* layer) get_weight_count() int {
    layer.weight_count
}
