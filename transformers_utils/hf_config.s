package neurx.transformers_utils.hf_config

struct hf_model_config {
    string model_id
    string model_type
    string architecture_type
    int hidden_size
    int num_hidden_layers
    int num_attention_heads
    int num_key_value_heads
    int intermediate_size
    string hidden_act
    float hidden_dropout_prob
    float attention_probs_dropout_prob
    int vocab_size
    int max_position_embeddings
    int max_seq_length
    string rope_scaling_type
    float rope_theta
    string initializer_range
    bool tie_word_embeddings
    bool use_cache
    string torch_dtype
    string quantization_config
    []string supported_prompt_formats
}

func create_llama_config() hf_model_config {
    hf_model_config {
        model_id: "meta-llama/Llama-2-7b",
        model_type: "llama",
        architecture_type: "decoder_only",
        hidden_size: 4096,
        num_hidden_layers: 32,
        num_attention_heads: 32,
        num_key_value_heads: 32,
        intermediate_size: 11008,
        hidden_act: "silu",
        hidden_dropout_prob: 0.0,
        attention_probs_dropout_prob: 0.0,
        vocab_size: 32000,
        max_position_embeddings: 4096,
        max_seq_length: 4096,
        rope_scaling_type: "linear",
        rope_theta: 10000.0,
        initializer_range: "0.02",
        tie_word_embeddings: false,
        use_cache: true,
        torch_dtype: "float16",
        quantization_config: "",
        supported_prompt_formats: ["default"],
    }
}

func create_qwen_config() hf_model_config {
    hf_model_config {
        model_id: "Qwen/Qwen2-7B",
        model_type: "qwen",
        architecture_type: "decoder_only",
        hidden_size: 3584,
        num_hidden_layers: 28,
        num_attention_heads: 28,
        num_key_value_heads: 4,
        intermediate_size: 18944,
        hidden_act: "silu",
        hidden_dropout_prob: 0.0,
        attention_probs_dropout_prob: 0.0,
        vocab_size: 152064,
        max_position_embeddings: 32768,
        max_seq_length: 32768,
        rope_scaling_type: "dynamic",
        rope_theta: 1000000.0,
        initializer_range: "0.02",
        tie_word_embeddings: false,
        use_cache: true,
        torch_dtype: "bfloat16",
        quantization_config: "",
        supported_prompt_formats: ["qwen", "chatml"],
    }
}

func create_mistral_config() hf_model_config {
    hf_model_config {
        model_id: "mistralai/Mistral-7B-v0.1",
        model_type: "mistral",
        architecture_type: "decoder_only",
        hidden_size: 4096,
        num_hidden_layers: 32,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 14336,
        hidden_act: "silu",
        hidden_dropout_prob: 0.0,
        attention_probs_dropout_prob: 0.0,
        vocab_size: 32000,
        max_position_embeddings: 32768,
        max_seq_length: 32768,
        rope_scaling_type: "linear",
        rope_theta: 10000.0,
        initializer_range: "0.02",
        tie_word_embeddings: false,
        use_cache: true,
        torch_dtype: "bfloat16",
        quantization_config: "",
        supported_prompt_formats: ["default"],
    }
}

func create_deepseek_config() hf_model_config {
    hf_model_config {
        model_id: "deepseek-ai/deepseek-7b",
        model_type: "deepseek",
        architecture_type: "decoder_only",
        hidden_size: 4096,
        num_hidden_layers: 32,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        intermediate_size: 11008,
        hidden_act: "silu",
        hidden_dropout_prob: 0.0,
        attention_probs_dropout_prob: 0.0,
        vocab_size: 102400,
        max_position_embeddings: 4096,
        max_seq_length: 4096,
        rope_scaling_type: "linear",
        rope_theta: 10000.0,
        initializer_range: "0.02",
        tie_word_embeddings: false,
        use_cache: true,
        torch_dtype: "bfloat16",
        quantization_config: "",
        supported_prompt_formats: ["default"],
    }
}

func get_hf_config_by_model_id(model_id: string) hf_model_config {
    if model_id == "meta-llama/Llama-2-7b" || model_id == "meta-llama/Llama-3-8b" {
        return create_llama_config()
    }
    if model_id == "Qwen/Qwen2-7B" || model_id == "Qwen/Qwen2.5-7B" {
        return create_qwen_config()
    }
    if model_id == "mistralai/Mistral-7B-v0.1" || model_id == "mistralai/Mixtral-8x7B" {
        return create_mistral_config()
    }
    if model_id == "deepseek-ai/deepseek-7b" {
        return create_deepseek_config()
    }
    create_llama_config()
}

func get_hf_config_by_type(model_type: string) hf_model_config {
    if model_type == "llama" {
        return create_llama_config()
    }
    if model_type == "qwen" {
        return create_qwen_config()
    }
    if model_type == "mistral" {
        return create_mistral_config()
    }
    if model_type == "deepseek" {
        return create_deepseek_config()
    }
    create_llama_config()
}
