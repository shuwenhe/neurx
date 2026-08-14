package neurx.model.model_zoo

use std.map

struct model_spec {
    name: string
    model_type: string
    hidden_size: int
    num_hidden_layers: int
    vocab_size: int
    num_attention_heads: int
    num_key_value_heads: int
    intermediate_size: int
    max_position_embeddings: int
    rms_norm_eps: f32
    rope_theta: f32
    attention_bias: bool
    use_cache: bool
    tie_word_embeddings: bool
    initializer_range: f32
    architectures: []string
}

func create_llama_7b() model_spec {
    model_spec {
        name: "llama-7b",
        model_type: "llama",
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
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["LlamaForCausalLM"],
    }
}

func create_llama_13b() model_spec {
    let mut spec = create_llama_7b()
    spec.name = "llama-13b"
    spec.hidden_size = 5120
    spec.num_hidden_layers = 40
    spec.num_attention_heads = 40
    spec.num_key_value_heads = 10
    spec.intermediate_size = 13824
    spec
}

func create_llama2_7b() model_spec {
    let mut spec = create_llama_7b()
    spec.name = "llama2-7b"
    spec.model_type = "llama2"
    spec.max_position_embeddings = 4096
    spec
}

func create_llama2_13b() model_spec {
    let mut spec = create_llama2_7b()
    spec.name = "llama2-13b"
    spec.hidden_size = 5120
    spec.num_hidden_layers = 40
    spec.num_attention_heads = 40
    spec.num_key_value_heads = 10
    spec.intermediate_size = 13824
    spec
}

func create_llama3_8b() model_spec {
    model_spec {
        name: "llama3-8b",
        model_type: "llama3",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 128000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 14336,
        max_position_embeddings: 8192,
        rms_norm_eps: 1e-5,
        rope_theta: 500000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["LlamaForCausalLM"],
    }
}

func create_qwen_7b() model_spec {
    model_spec {
        name: "qwen-7b",
        model_type: "qwen",
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
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["QwenForCausalLM"],
    }
}

func create_qwen_14b() model_spec {
    let mut spec = create_qwen_7b()
    spec.name = "qwen-14b"
    spec.hidden_size = 5120
    spec.num_hidden_layers = 40
    spec.num_attention_heads = 40
    spec.intermediate_size = 13824
    spec
}

func create_qwen2_0_5b() model_spec {
    model_spec {
        name: "qwen2-0.5b",
        model_type: "qwen2",
        hidden_size: 1024,
        num_hidden_layers: 24,
        vocab_size: 151936,
        num_attention_heads: 16,
        num_key_value_heads: 16,
        intermediate_size: 2816,
        max_position_embeddings: 32768,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["Qwen2ForCausalLM"],
    }
}

func create_qwen2_7b() model_spec {
    model_spec {
        name: "qwen2-7b",
        model_type: "qwen2",
        hidden_size: 3584,
        num_hidden_layers: 28,
        vocab_size: 151936,
        num_attention_heads: 28,
        num_key_value_heads: 4,
        intermediate_size: 18944,
        max_position_embeddings: 131072,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["Qwen2ForCausalLM"],
    }
}

func create_qwen2_5() model_spec {
    model_spec {
        name: "qwen2.5",
        model_type: "qwen2.5",
        hidden_size: 2048,
        num_hidden_layers: 24,
        vocab_size: 151936,
        num_attention_heads: 16,
        num_key_value_heads: 16,
        intermediate_size: 5632,
        max_position_embeddings: 131072,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["Qwen2ForCausalLM"],
    }
}

func create_deepseek_7b() model_spec {
    model_spec {
        name: "deepseek-7b",
        model_type: "deepseek",
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
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["DeepseekForCausalLM"],
    }
}

func create_deepseek_moe() model_spec {
    model_spec {
        name: "deepseek-moe-16b",
        model_type: "deepseek_moe",
        hidden_size: 2048,
        num_hidden_layers: 27,
        vocab_size: 102400,
        num_attention_heads: 16,
        num_key_value_heads: 2,
        intermediate_size: 8960,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["DeepseekMoEForCausalLM"],
    }
}

func create_deepseek_v3() model_spec {
    model_spec {
        name: "deepseek-v3",
        model_type: "deepseek_v3",
        hidden_size: 4096,
        num_hidden_layers: 40,
        vocab_size: 102400,
        num_attention_heads: 160,
        num_key_value_heads: 20,
        intermediate_size: 28672,
        max_position_embeddings: 8192,
        rms_norm_eps: 1e-6,
        rope_theta: 500000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["DeepseekV3ForCausalLM"],
    }
}

func create_mistral_7b() model_spec {
    model_spec {
        name: "mistral-7b",
        model_type: "mistral",
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
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["MistralForCausalLM"],
    }
}

func create_mixtral_8x7b() model_spec {
    model_spec {
        name: "mixtral-8x7b",
        model_type: "mixtral",
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
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["MixtralForCausalLM"],
    }
}

func create_mixtral_8x22b() model_spec {
    model_spec {
        name: "mixtral-8x22b",
        model_type: "mixtral",
        hidden_size: 6144,
        num_hidden_layers: 56,
        vocab_size: 32768,
        num_attention_heads: 48,
        num_key_value_heads: 12,
        intermediate_size: 16384,
        max_position_embeddings: 65536,
        rms_norm_eps: 1e-5,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["MixtralForCausalLM"],
    }
}

func create_phi_2b() model_spec {
    model_spec {
        name: "phi-2b",
        model_type: "phi",
        hidden_size: 2560,
        num_hidden_layers: 32,
        vocab_size: 50257,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 10240,
        max_position_embeddings: 2048,
        rms_norm_eps: 1e-5,
        rope_theta: 10000.0,
        attention_bias: true,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["PhiForCausalLM"],
    }
}

func create_phi3_mini() model_spec {
    model_spec {
        name: "phi3-mini",
        model_type: "phi3",
        hidden_size: 3072,
        num_hidden_layers: 32,
        vocab_size: 32064,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 8192,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-5,
        rope_theta: 500000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["Phi3ForCausalLM"],
    }
}

func create_phi3_small() model_spec {
    let mut spec = create_phi3_mini()
    spec.name = "phi3-small"
    spec.hidden_size = 3840
    spec.num_hidden_layers = 36
    spec.num_attention_heads = 32
    spec.intermediate_size = 10240
    spec
}

func create_baichuan_7b() model_spec {
    model_spec {
        name: "baichuan-7b",
        model_type: "baichuan",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 125696,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 11008,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["BaichuanForCausalLM"],
    }
}

func create_baichuan2_13b() model_spec {
    model_spec {
        name: "baichuan2-13b",
        model_type: "baichuan2",
        hidden_size: 5120,
        num_hidden_layers: 40,
        vocab_size: 125696,
        num_attention_heads: 40,
        num_key_value_heads: 40,
        intermediate_size: 13824,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["Baichuan2ForCausalLM"],
    }
}

func create_internlm_7b() model_spec {
    model_spec {
        name: "internlm-7b",
        model_type: "internlm",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 103168,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 11008,
        max_position_embeddings: 2048,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["InternLMForCausalLM"],
    }
}

func create_internlm2_7b() model_spec {
    model_spec {
        name: "internlm2-7b",
        model_type: "internlm2",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 92544,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 14336,
        max_position_embeddings: 2048,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["InternLM2ForCausalLM"],
    }
}

func create_chatglm3_6b() model_spec {
    model_spec {
        name: "chatglm3-6b",
        model_type: "chatglm3",
        hidden_size: 4096,
        num_hidden_layers: 28,
        vocab_size: 65024,
        num_attention_heads: 32,
        num_key_value_heads: 2,
        intermediate_size: 13696,
        max_position_embeddings: 8192,
        rms_norm_eps: 1e-5,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: true,
        initializer_range: 0.02,
        architectures: ["ChatGLMForConditionalGeneration"],
    }
}

func create_chatglm4() model_spec {
    model_spec {
        name: "chatglm4",
        model_type: "chatglm4",
        hidden_size: 8192,
        num_hidden_layers: 40,
        vocab_size: 150000,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 27392,
        max_position_embeddings: 8192,
        rms_norm_eps: 1e-6,
        rope_theta: 1000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["ChatGLM4ForConditionalGeneration"],
    }
}

func create_yi_6b() model_spec {
    model_spec {
        name: "yi-6b",
        model_type: "yi",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 64000,
        num_attention_heads: 32,
        num_key_value_heads: 4,
        intermediate_size: 11008,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-5,
        rope_theta: 5000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["YiForCausalLM"],
    }
}

func create_yi_34b() model_spec {
    model_spec {
        name: "yi-34b",
        model_type: "yi",
        hidden_size: 7168,
        num_hidden_layers: 60,
        vocab_size: 64000,
        num_attention_heads: 56,
        num_key_value_heads: 8,
        intermediate_size: 20480,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-5,
        rope_theta: 5000000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["YiForCausalLM"],
    }
}

func create_openchat_3_5() model_spec {
    model_spec {
        name: "openchat-3.5",
        model_type: "mistral",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 32000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 14336,
        max_position_embeddings: 8192,
        rms_norm_eps: 1e-5,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["MistralForCausalLM"],
    }
}

func create_solar_10_7b() model_spec {
    model_spec {
        name: "solar-10.7b",
        model_type: "llama",
        hidden_size: 4096,
        num_hidden_layers: 42,
        vocab_size: 32000,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 13824,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-6,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["LlamaForCausalLM"],
    }
}

func create_neural_chat_7b() model_spec {
    model_spec {
        name: "neural-chat-7b",
        model_type: "mistral",
        hidden_size: 4096,
        num_hidden_layers: 32,
        vocab_size: 32000,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 14336,
        max_position_embeddings: 4096,
        rms_norm_eps: 1e-5,
        rope_theta: 10000.0,
        attention_bias: false,
        use_cache: true,
        tie_word_embeddings: false,
        initializer_range: 0.02,
        architectures: ["MistralForCausalLM"],
    }
}

func get_all_models() []model_spec {
    [

        create_llama_7b(),
        create_llama_13b(),
        create_llama2_7b(),
        create_llama2_13b(),
        create_llama3_8b(),

        create_qwen_7b(),
        create_qwen_14b(),
        create_qwen2_0_5b(),
        create_qwen2_7b(),
        create_qwen2_5(),

        create_deepseek_7b(),
        create_deepseek_moe(),
        create_deepseek_v3(),

        create_mistral_7b(),
        create_mixtral_8x7b(),
        create_mixtral_8x22b(),

        create_phi_2b(),
        create_phi3_mini(),
        create_phi3_small(),

        create_baichuan_7b(),
        create_baichuan2_13b(),

        create_internlm_7b(),
        create_internlm2_7b(),

        create_chatglm3_6b(),
        create_chatglm4(),

        create_yi_6b(),
        create_yi_34b(),

        create_openchat_3_5(),
        create_solar_10_7b(),
        create_neural_chat_7b(),
    ]
}

func get_model_by_name(name: string) option[model_spec] {
    let models = get_all_models()
    for model in models.iter() {
        if model.name == name {
            return some(model)
        }
    }
    none
}

func get_model_by_type(model_type: string) []model_spec {
    let models = get_all_models()
    let mut result = vec[]()
    for model in models.iter() {
        if model.model_type == model_type {
            result.push(model)
        }
    }
    result
}

func list_all_model_names() []string {
    let models = get_all_models()
    let mut names = vec[]()
    for model in models.iter() {
        names.push(model.name)
    }
    names
}

func main() {
    println("🚀 Model Zoo - 30+ 种模型配置库")
    println("==================================")

    let models = get_all_models()
    println(f"✅ 总模型数: {models.len()}")
    println("")

    println("📊 模型类型统计:")
    let llama_models = get_model_by_type("llama")
    println(f"  LLaMA 系列: {llama_models.len()}")

    let qwen_models = get_model_by_type("qwen")
    let qwen2_models = get_model_by_type("qwen2")
    let qwen25_models = get_model_by_type("qwen2.5")
    println(f"  Qwen 系列: {qwen_models.len() + qwen2_models.len() + qwen25_models.len()}")

    let mistral_models = get_model_by_type("mistral")
    let mixtral_models = get_model_by_type("mixtral")
    println(f"  Mistral 系列: {mistral_models.len() + mixtral_models.len()}")

    println("")
    println("📋 完整模型列表:")
    for i in 0..models.len() {
        let model = models[i]
        println(f"  {i + 1:2}. {model.name:20} ({model.model_type})")
    }

    println("")
    println("✅ 核心特性:")
    println("  ✓ 30+ 种主流模型支持")
    println("  ✓ 完整架构参数")
    println("  ✓ 工厂模式快速创建")
    println("  ✓ 易于扩展新模型")
}
