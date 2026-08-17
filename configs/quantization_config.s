package config

type quantization_method string

const (
    quant_none          quantization_method = "none"
    quant_int8          quantization_method = "int8"
    quant_int4          quantization_method = "int4"
    quant_nf4           quantization_method = "nf4"
    quant_bnb           quantization_method = "bnb"
    quant_gptq          quantization_method = "gptq"
    quant_awq           quantization_method = "awq"
    quant_fp8           quantization_method = "fp8"
)

struct quantization_config {
    quantization_method method
    bool enable_quantization

    int32 num_bits
    bool use_sym_quant
    bool per_channel_quantization

    string calibration_method
    int32 calibration_steps
    float32 calibration_q_alpha

    bool enable_dynamic_quantization
    bool enable_static_quantization

    bool enable_int8_activation
    bool enable_int8_weight

    float32 scale_factor
    int32 zero_point

    bool use_smooth_quant
    float32 smooth_quant_alpha

    bool enable_mixed_precision
    []string mixed_precision_layers

    map[string]interface{} extra_config
}

func create_default_quantization_config() quantization_config {
    return quantization_config{
        method: quant_none,
        enable_quantization: false,
        num_bits: 8,
        use_sym_quant: true,
        per_channel_quantization: true,
        calibration_method: "kl",
        calibration_steps: 32,
        calibration_q_alpha: 0.5,
        enable_dynamic_quantization: false,
        enable_static_quantization: true,
        enable_int8_activation: false,
        enable_int8_weight: false,
        scale_factor: 1.0,
        zero_point: 0,
        use_smooth_quant: false,
        smooth_quant_alpha: 0.5,
        enable_mixed_precision: false,
        mixed_precision_layers: make([]string, 0),
        extra_config: make(map[string]interface{}),
    }
}

func (quantization_config* cfg) validate() bool {
    if cfg.num_bits < 4 || cfg.num_bits > 32 {
        return false
    }
    if cfg.calibration_steps <= 0 {
        return false
    }
    return true
}

func (quantization_config* cfg) is_quantized() bool {
    return cfg.enable_quantization && cfg.method != quant_none
}

func (quantization_config* cfg) get_memory_reduction_factor() float32 {
    bits_per_param := float32(cfg.num_bits)
    original_bits := float32(32)
    return original_bits / bits_per_param
}

func (quantization_config* cfg) enable_awq() {
    cfg.method = quant_awq
    cfg.enable_quantization = true
    cfg.num_bits = 4
    cfg.per_channel_quantization = true
}

func (quantization_config* cfg) enable_gptq() {
    cfg.method = quant_gptq
    cfg.enable_quantization = true
    cfg.num_bits = 4
    cfg.calibration_method = "kl"
}

func (quantization_config* cfg) enable_int8() {
    cfg.method = quant_int8
    cfg.enable_quantization = true
    cfg.num_bits = 8
    cfg.enable_int8_activation = true
    cfg.enable_int8_weight = true
}
