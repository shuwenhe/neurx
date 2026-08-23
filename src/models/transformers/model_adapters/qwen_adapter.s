package neurx.transformers_utils.model_adapters.qwen_adapter

struct qwen_model_config {
    int hidden_size
    int num_hidden_layers
    int num_attention_heads
    int num_key_value_heads
    int intermediate_size
    string hidden_act
    float rms_norm_eps
    int max_position_embeddings
    float rope_theta
    string rope_scaling_type
    int sliding_window
    bool use_long_context_attn
}

func get_qwen_7b_config() qwen_model_config {
    qwen_model_config {
        hidden_size: 4096,
        num_hidden_layers: 32,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 22016,
        hidden_act: "silu",
        rms_norm_eps: 1e-6,
        max_position_embeddings: 32768,
        rope_theta: 1000000.0,
        rope_scaling_type: "linear",
        sliding_window: -1,
        use_long_context_attn: false,
    }
}

func get_qwen_14b_config() qwen_model_config {
    qwen_model_config {
        hidden_size: 5120,
        num_hidden_layers: 40,
        num_attention_heads: 40,
        num_key_value_heads: 40,
        intermediate_size: 27648,
        hidden_act: "silu",
        rms_norm_eps: 1e-6,
        max_position_embeddings: 32768,
        rope_theta: 1000000.0,
        rope_scaling_type: "linear",
        sliding_window: -1,
        use_long_context_attn: false,
    }
}

func get_qwen2_7b_config() qwen_model_config {
    qwen_model_config {
        hidden_size: 3584,
        num_hidden_layers: 28,
        num_attention_heads: 28,
        num_key_value_heads: 4,
        intermediate_size: 18944,
        hidden_act: "silu",
        rms_norm_eps: 1e-6,
        max_position_embeddings: 32768,
        rope_theta: 1000000.0,
        rope_scaling_type: "dynamic",
        sliding_window: -1,
        use_long_context_attn: false,
    }
}

func get_qwen2_5_7b_config() qwen_model_config {
    qwen_model_config {
        hidden_size: 3584,
        num_hidden_layers: 28,
        num_attention_heads: 28,
        num_key_value_heads: 4,
        intermediate_size: 18944,
        hidden_act: "silu",
        rms_norm_eps: 1e-6,
        max_position_embeddings: 131072,
        rope_theta: 1000000.0,
        rope_scaling_type: "dynamic",
        sliding_window: -1,
        use_long_context_attn: true,
    }
}

func get_qwen_config_by_version(version: string) qwen_model_config {
    if version == "qwen-7b" {
        return get_qwen_7b_config()
    }
    if version == "qwen-14b" {
        return get_qwen_14b_config()
    }
    if version == "qwen2-7b" || version == "Qwen/Qwen2-7B" {
        return get_qwen2_7b_config()
    }
    if version == "qwen2.5-7b" || version == "Qwen/Qwen2.5-7B" {
        return get_qwen2_5_7b_config()
    }
    get_qwen2_7b_config()
}

func get_qwen_chat_template() string {
    string template = ""
    template = template + "<|im_start|>system\n"
    template = template + "{system}<|im_end|>\n"
    template = template + "<|im_start|>user\n"
    template = template + "{user}<|im_end|>\n"
    template = template + "<|im_start|>assistant\n"
    template = template + "{assistant}<|im_end|>"
    template
}

func get_qwen_attention_type(num_kv_heads: int) string {
    if num_kv_heads == 1 {
        return "mqa"
    }
    if num_kv_heads < 8 {
        return "gqa"
    }
    "mha"
}

struct qwen_optimizer_config {
    string optimizer_type
    float learning_rate
    float weight_decay
    int warmup_steps
    string lr_scheduler_type
    float gradient_clip_value
}

func get_qwen_optimizer_config() qwen_optimizer_config {
    qwen_optimizer_config {
        optimizer_type: "adamw_torch",
        learning_rate: 5e-6,
        weight_decay: 0.01,
        warmup_steps: 500,
        lr_scheduler_type: "cosine",
        gradient_clip_value: 1.0,
    }
}

struct qwen_lora_config {
    int lora_rank
    int lora_alpha
    float lora_dropout
    []string target_modules
}

func get_qwen_lora_config() qwen_lora_config {
    qwen_lora_config {
        lora_rank: 64,
        lora_alpha: 128,
        lora_dropout: 0.05,
        target_modules: ["q_proj", "v_proj", "k_proj", "o_proj"],
    }
}

struct qwen_quantization_config {
    string quant_method
    bool use_double_quant
    int quant_type
}

func get_qwen_quantization_config(method: string) qwen_quantization_config {
    if method == "4bit" {
        return qwen_quantization_config {
            quant_method: "int4",
            use_double_quant: true,
            quant_type: 0,
        }
    }

    if method == "8bit" {
        return qwen_quantization_config {
            quant_method: "int8",
            use_double_quant: false,
            quant_type: 0,
        }
    }

    qwen_quantization_config {
        quant_method: "bfloat16",
        use_double_quant: false,
        quant_type: 0,
    }
}

struct qwen_training_config {
    int batch_size
    int gradient_accumulation_steps
    float learning_rate
    int num_epochs
    int max_steps
    float grad_clip
    bool use_flash_attention
    bool use_paged_attention
    bool use_long_context_attn
}

func get_qwen_training_config_7b() qwen_training_config {
    qwen_training_config {
        batch_size: 4,
        gradient_accumulation_steps: 8,
        learning_rate: 5e-6,
        num_epochs: 3,
        max_steps: -1,
        grad_clip: 1.0,
        use_flash_attention: true,
        use_paged_attention: true,
        use_long_context_attn: false,
    }
}

func get_qwen_training_config_14b() qwen_training_config {
    qwen_training_config {
        batch_size: 2,
        gradient_accumulation_steps: 16,
        learning_rate: 2e-6,
        num_epochs: 3,
        max_steps: -1,
        grad_clip: 1.0,
        use_flash_attention: true,
        use_paged_attention: true,
        use_long_context_attn: false,
    }
}

struct qwen_inference_optimization {
    bool use_cache
    bool use_flash_attention
    bool use_paged_attention
    bool use_prefix_cache
    bool use_sliding_window_attn
    string dtype
    int max_batch_size
}

func get_qwen_inference_optimization() qwen_inference_optimization {
    qwen_inference_optimization {
        use_cache: true,
        use_flash_attention: true,
        use_paged_attention: true,
        use_prefix_cache: true,
        use_sliding_window_attn: false,
        dtype: "bfloat16",
        max_batch_size: 64,
    }
}

struct qwen_special_tokens {
    int bos_token_id
    int eos_token_id
    int pad_token_id
    int im_start_id
    int im_end_id
}

func get_qwen_special_tokens() qwen_special_tokens {
    qwen_special_tokens {
        bos_token_id: 151657,
        eos_token_id: 151643,
        pad_token_id: 151643,
        im_start_id: 151644,
        im_end_id: 151645,
    }
}

func print_qwen_config(config: qwen_model_config) {
    print("\n╔════════════════════════════════════════════════╗\n")
    print("║  🏮 Qwen Model Configuration                 ║\n")
    print("╚════════════════════════════════════════════════╝\n\n")

    print("Architecture\n")
    print("─────────────────────────────────────────────\n")
    print("Hidden size: " + int_to_string(config.hidden_size) + "\n")
    print("Num layers: " + int_to_string(config.num_hidden_layers) + "\n")
    print("Num heads: " + int_to_string(config.num_attention_heads) + "\n")
    print("KV heads (GQA): " + int_to_string(config.num_key_value_heads) + "\n")
    print("Attention type: " + get_qwen_attention_type(config.num_key_value_heads) + "\n")
    print("Intermediate size: " + int_to_string(config.intermediate_size) + "\n")
    print("Activation: " + config.hidden_act + "\n\n")

    print("Context & Positional Encoding\n")
    print("─────────────────────────────────────────────\n")
    print("Max position embeddings: " + int_to_string(config.max_position_embeddings) + "\n")
    print("RoPE theta: " + float_to_string(config.rope_theta) + "\n")
    print("RoPE scaling: " + config.rope_scaling_type + "\n")
    print("Sliding window: " + int_to_string(config.sliding_window) + "\n")
    print("Long context attn: " + (config.use_long_context_attn ? "Yes" : "No") + "\n\n")

    print("Normalization\n")
    print("─────────────────────────────────────────────\n")
    print("RMSNorm eps: " + float_to_string(config.rms_norm_eps) + "\n\n")
}
