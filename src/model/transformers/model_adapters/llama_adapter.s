package neurx.transformers_utils.model_adapters.llama_adapter
struct llama_model_config {
    int hidden_size
    int num_hidden_layers
    int num_attention_heads
    int num_key_value_heads
    int intermediate_size
    string hidden_act
    float rms_norm_eps
    float rope_theta
    int max_position_embeddings
}

func get_llama_7b_config() llama_model_config {
    llama_model_config {
        hidden_size: 4096,
        num_hidden_layers: 32,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 11008,
        hidden_act: "silu",
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        max_position_embeddings: 4096,
    }
}

func get_llama_13b_config() llama_model_config {
    llama_model_config {
        hidden_size: 5120,
        num_hidden_layers: 40,
        num_attention_heads: 40,
        num_key_value_heads: 40,
        intermediate_size: 13824,
        hidden_act: "silu",
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        max_position_embeddings: 4096,
    }
}

func get_llama_2_7b_config() llama_model_config {
    llama_model_config {
        hidden_size: 4096,
        num_hidden_layers: 32,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 11008,
        hidden_act: "silu",
        rms_norm_eps: 1e-5,
        rope_theta: 10000.0,
        max_position_embeddings: 4096,
    }
}

func get_llama_3_8b_config() llama_model_config {
    llama_model_config {
        hidden_size: 4096,
        num_hidden_layers: 32,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 14336,
        hidden_act: "silu",
        rms_norm_eps: 1e-5,
        rope_theta: 500000.0,
        max_position_embeddings: 8192,
    }
}

func get_llama_config_by_version(string version) llama_model_config {
    if version == "llama-7b" || version == "meta-llama/Llama-2-7b" {
        return get_llama_7b_config()
    }
    if version == "llama-13b" {
        return get_llama_13b_config()
    }
    if version == "llama-2-7b" {
        return get_llama_2_7b_config()
    }
    if version == "llama-3-8b" || version == "meta-llama/Llama-3-8b" {
        return get_llama_3_8b_config()
    }
    get_llama_7b_config()
}

func get_llama_attention_type(int num_kv_heads) string {
    if num_kv_heads == 1 {
        return "mqa"
    }
    if num_kv_heads < 32 {
        return "gqa"
    }
    "mha"
}

struct llama_optimizer_config {
    string optimizer_type
    float learning_rate
    float weight_decay
    int warmup_steps
    string lr_scheduler_type
}

func get_llama_optimizer_config() llama_optimizer_config {
    llama_optimizer_config {
        optimizer_type: "adamw_torch",
        learning_rate: 2e-5,
        weight_decay: 0.01,
        warmup_steps: 500,
        lr_scheduler_type: "cosine",
    }
}

struct llama_lora_config {
    int lora_rank
    int lora_alpha
    float lora_dropout
    []string target_modules
}

func get_llama_lora_config() llama_lora_config {
    llama_lora_config {
        lora_rank: 64,
        lora_alpha: 128,
        lora_dropout: 0.05,
        target_modules: ["q_proj", "v_proj", "k_proj", "o_proj"],
    }
}

struct llama_quantization_config {
    string quant_method
    bool use_double_quant
    int quant_type
}

func get_llama_quantization_config(string method) llama_quantization_config {
    if method == "4bit" {
        return llama_quantization_config {
            quant_method: "int4",
            use_double_quant: true,
            quant_type: 0,
        }
    }
    if method == "8bit" {
        return llama_quantization_config {
            quant_method: "int8",
            use_double_quant: false,
            quant_type: 0,
        }
    }
    llama_quantization_config {
        quant_method: "bfloat16",
        use_double_quant: false,
        quant_type: 0,
    }
}

struct llama_training_config {
    int batch_size
    int gradient_accumulation_steps
    float learning_rate
    int num_epochs
    int max_steps
    float grad_clip
    bool use_flash_attention
    bool use_paged_attention
}

func get_llama_training_config_7b() llama_training_config {
    llama_training_config {
        batch_size: 4,
        gradient_accumulation_steps: 8,
        learning_rate: 2e-5,
        num_epochs: 3,
        max_steps: -1,
        grad_clip: 1.0,
        use_flash_attention: true,
        use_paged_attention: true,
    }
}

func get_llama_training_config_13b() llama_training_config {
    llama_training_config {
        batch_size: 2,
        gradient_accumulation_steps: 16,
        learning_rate: 1e-5,
        num_epochs: 3,
        max_steps: -1,
        grad_clip: 1.0,
        use_flash_attention: true,
        use_paged_attention: true,
    }
}

struct llama_inference_optimization {
    bool use_cache
    bool use_flash_attention
    bool use_paged_attention
    bool use_prefix_cache
    string dtype
    int max_batch_size
}

func get_llama_inference_optimization() llama_inference_optimization {
    llama_inference_optimization {
        use_cache: true,
        use_flash_attention: true,
        use_paged_attention: true,
        use_prefix_cache: true,
        dtype: "bfloat16",
        max_batch_size: 64,
    }
}

func print_llama_config(llama_model_config config) {
    print("\n╔════════════════════════════════════════════════╗\n")
    print("║  🦙 LLaMA Model Configuration                ║\n")
    print("╚════════════════════════════════════════════════╝\n\n")
    print("Architecture\n")
    print("─────────────────────────────────────────────\n")
    print("Hidden size: " + int_to_string(config.hidden_size) + "\n")
    print("Num layers: " + int_to_string(config.num_hidden_layers) + "\n")
    print("Num heads: " + int_to_string(config.num_attention_heads) + "\n")
    print("KV heads: " + int_to_string(config.num_key_value_heads) + "\n")
    print("Attention type: " + get_llama_attention_type(config.num_key_value_heads) + "\n")
    print("Intermediate size: " + int_to_string(config.intermediate_size) + "\n")
    print("Activation: " + config.hidden_act + "\n\n")
    print("Positional Encoding\n")
    print("─────────────────────────────────────────────\n")
    print("RoPE theta: " + float_to_string(config.rope_theta) + "\n")
    print("Max position embeddings: " + int_to_string(config.max_position_embeddings) + "\n\n")
    print("Normalization\n")
    print("─────────────────────────────────────────────\n")
    print("RMSNorm eps: " + float_to_string(config.rms_norm_eps) + "\n\n")
}
