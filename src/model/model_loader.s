package neurx.model.loader

use std.vec.vec
use std.option.option
use std.result.result
use std.map.map

struct model_config {
    name: string
    hidden_size: int
    num_hidden_layers: int
    vocab_size: int
    num_attention_heads: int
    num_key_value_heads: int
    intermediate_size: int
    max_position_embeddings: int
    rms_norm_eps: float
    rope_theta: float
    attention_bias: bool
    use_cache: bool
}

struct model_architecture {
    model_type: string
    config: model_config
    weight_map: map[string, string]
}

struct model_loader_error {
    code: string
    message: string
}

func create_llama_config() model_config {
    model_config {
        name: "llama",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 32000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 11008,
        max_position_embeddings: 2048,
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_llama2_config() model_config {
    let mut config = create_llama_config()
    config.max_position_embeddings = 4096
    config
}

func create_qwen_config() model_config {
    model_config {
        name: "qwen",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 151936,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 11008,
        max_position_embeddings: 2048,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_qwen2_config() model_config {
    let mut config = create_qwen_config()
    config.num_hidden_layers = 24
    config.hidden_size = 1024
    config.intermediate_size = 2816
    config.num_attention_heads = 16
    config.num_key_value_heads = 16
    config
}

func create_deepseek_config() model_config {
    model_config {
        name: "deepseek",
        hidden_size: 4096,
        num_hidden_layers: 30,
        vocab_size: 102400,
        num_attention_heads: 128,
        num_key_value_heads: 16,
        intermediate_size: 10240,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_mistral_config() model_config {
    model_config {
        name: "mistral",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 32000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 14336,
        max_position_embeddings: 32768,
        rms_norm_eps: 1e-5,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_phi_config() model_config {
    model_config {
        name: "phi",
        hidden_size: 2560,
        num_hidden_layers: 32,
        vocab_size: 50256,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 10240,
        max_position_embeddings: 2048,
        rms_norm_eps: 1e-5,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_baichuan_config() model_config {
    model_config {
        name: "baichuan",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 125696,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 11008,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_internlm_config() model_config {
    model_config {
        name: "internlm",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 103168,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 11008,
        max_position_embeddings: 2048,
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_glm_config() model_config {
    model_config {
        name: "glm",
        hidden_size: 4096,
        num_hidden_layers: 28,
        vocab_size: 150528,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 16384,
        max_position_embeddings: 32768,
        rms_norm_eps: 1e-5,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_mixtral_config() model_config {
    model_config {
        name: "mixtral",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 32000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 14336,
        max_position_embeddings: 32768,
        rms_norm_eps: 1e-5,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_yi_config() model_config {
    model_config {
        name: "yi",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 64000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 11008,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-5,
        rope_theta: 5000000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_openchat_config() model_config {
    model_config {
        name: "openchat",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 32000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 11008,
        max_position_embeddings: 8192,
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_neural_chat_config() model_config {
    model_config {
        name: "neural_chat",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 32000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 11008,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_solar_config() model_config {
    model_config {
        name: "solar",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 32000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 18944,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
    }
}

func create_model_config(model_name: string) result[model_config, model_loader_error] {
    switch model_name {
        "llama" : (create_llama_config(, "")),
        "llama2" : (create_llama2_config(, "")),
        "qwen" : (create_qwen_config(, "")),
        "qwen2" : (create_qwen2_config(, "")),
        "deepseek" : (create_deepseek_config(, "")),
        "mistral" : (create_mistral_config(, "")),
        "phi" : (create_phi_config(, "")),
        "baichuan" : (create_baichuan_config(, "")),
        "internlm" : (create_internlm_config(, "")),
        "glm" : (create_glm_config(, "")),
        "mixtral" : (create_mixtral_config(, "")),
        "yi" : (create_yi_config(, "")),
        "openchat" : (create_openchat_config(, "")),
        "neural_chat" : (create_neural_chat_config(, "")),
        "solar" : (create_solar_config(, "")),
        _ : (model_loader_error {
            code: "UNKNOWN_MODEL",
            message: "Unknown model type: " + model_name,
        }),
    }
}

func (model_config* config) get_num_layers() int {
    config.num_hidden_layers
}

func (model_config* config) get_hidden_size() int {
    config.hidden_size
}

func (model_config* config) get_vocab_size() int {
    config.vocab_size
}

func (model_config* config) get_num_heads() int {
    config.num_attention_heads
}

func (model_config* config) get_intermediate_size() int {
    config.intermediate_size
}

func (model_config* config) is_valid() result[(), model_loader_error] {
    if config.hidden_size <= 0 {
        return (model_loader_error {
            code: "INVALID_CONFIG",
            message: "Hidden size must be positive",
        })
    }

    if config.num_hidden_layers <= 0 {
        return (model_loader_error {
            code: "INVALID_CONFIG",
            message: "Number of layers must be positive",
        })
    }

    if config.vocab_size <= 0 {
        return (model_loader_error {
            code: "INVALID_CONFIG",
            message: "Vocab size must be positive",
        })
    }

    if config.num_attention_heads <= 0 {
        return (model_loader_error {
            code: "INVALID_CONFIG",
            message: "Number of attention heads must be positive",
        })
    }

    if config.hidden_size % config.num_attention_heads != 0 {
        return (model_loader_error {
            code: "INVALID_CONFIG",
            message: "Hidden size must be divisible by number of attention heads",
        })
    }

    ((, ""))
}

func load_model_architecture(model_name: string) result[model_architecture, model_loader_error] {
    let config = create_model_config(model_name)?
    config.is_valid()?

    (model_architecture {
        model_type: model_name,
        config: config,
        weight_map: map[string, string](),
    })
}

func main() {
    let model_names = vec[string]()
    model_names.push("llama")
    model_names.push("qwen")
    model_names.push("deepseek")
    model_names.push("mistral")
    model_names.push("phi")

    let i = 0
    while i < model_names.len() {
        let name = model_names[i]
        switch load_model_architecture(name) {
            (arch, "") : {
                ""
            },
            (0, err) : {
                ""
            },
        }
        i = i + 1
    }
}
