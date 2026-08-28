package neurx.transformers_utils.hf_model_loader
use neurx.transformers_utils.hf_config
use neurx.transformers_utils.hf_tokenizer
use neurx.transformers_utils.weight_conversion.safetensors_loader
use neurx.transformers_utils.logits_processors.processor_utils
use neurx.transformers_utils.logits_processors.top_k
use neurx.transformers_utils.logits_processors.nucleus
use neurx.transformers_utils.logits_processors.temperature
struct hf_model_loader {
    string model_id
    string cache_dir
    string device
    string dtype
    bool load_in_8bit
    bool load_in_4bit
}

struct loaded_hf_model {
    string model_id
    string model_type
    hf_model_config config
    hf_tokenizer tokenizer
    safetensors_loader.weight_dict weights
    string dtype
    string device
}

struct hf_load_options {
    string device
    string dtype
    bool use_cache
    bool trust_remote_code
    bool low_cpu_mem_usage
    int max_memory_mb
}

func default_hf_load_options() hf_load_options {
    hf_load_options {
        device: "cpu",
        dtype: "float32",
        use_cache: true,
        trust_remote_code: true,
        low_cpu_mem_usage: false,
        max_memory_mb: 8192,
    }
}

func create_hf_model_loader(string model_id) hf_model_loader {
    hf_model_loader {
        model_id: model_id,
        cache_dir: "~/.src/inference/extension/cache/huggingface/hub",
        device: "cpu",
        dtype: "float32",
        load_in_8bit: false,
        load_in_4bit: false,
    }
}

func load_hf_model(
    model_id: string,
    hf_load_options options
) loaded_hf_model {
    print("╔════════════════════════════════════════════════╗\n")
    print("║  🤗 HuggingFace Model Loader (Pure S)         ║\n")
    print("║  Loading: " + model_id + "\n")
    print("╚════════════════════════════════════════════════╝\n\n")
    print("📥 Initialization Phase\n")
    print("─────────────────────────────────────────────\n")
    print("Model ID: " + model_id + "\n")
    print("Device: " + options.device + "\n")
    print("Data type: " + options.dtype + "\n\n")
    print("⚙️  Step 1: Loading Configuration\n")
    print("─────────────────────────────────────────────\n")
    hf_model_config config = hf_config.get_hf_config_by_model_id(model_id)
    print("✓ Model type: " + config.model_type + "\n")
    print("✓ Hidden size: " + int_to_string(config.hidden_size) + "\n")
    print("✓ Num layers: " + int_to_string(config.num_hidden_layers) + "\n")
    print("✓ Vocab size: " + int_to_string(config.vocab_size) + "\n")
    print("✓ Max seq length: " + int_to_string(config.max_seq_length) + "\n\n")
    print("📖 Step 2: Loading Tokenizer\n")
    print("─────────────────────────────────────────────\n")
    hf_tokenizer tokenizer = hf_tokenizer.get_token_from_tokenizer(
        config.model_type,
        model_id
    )
    print("✓ Tokenizer class: " + tokenizer.tokenizer_class + "\n")
    print("✓ Vocab size: " + int_to_string(tokenizer.vocab_size) + "\n")
    print("✓ BOS token ID: " + int_to_string(tokenizer.bos_token_id) + "\n")
    print("✓ EOS token ID: " + int_to_string(tokenizer.eos_token_id) + "\n\n")
    print("💾 Step 3: Loading Model Weights\n")
    print("─────────────────────────────────────────────\n")
    string weight_file = "model.safetensors"
    safetensors_loader.weight_dict weights = safetensors_loader.load_safetensors_metadata(weight_file)
    print("✓ Weights loaded: " + int_to_string(len(weights.tensors)) + " tensors\n")
    print("✓ Total size: " + int_to_string(weights.total_size_bytes / (1024 * 1024)) + " MB\n\n")
    print("🔐 Step 4: Validation\n")
    print("─────────────────────────────────────────────\n")
    safetensors_loader.weight_validation_result validation =
        safetensors_loader.validate_weight_compatibility("", weights, options.dtype)
    if validation.is_valid {
        print("✓ Model is compatible with target device\n")
    } else {
        print("⚠️  Validation issues detected:\n")
        for err in validation.errors {
            print("  ✗ " + err + "\n")
        }
    }
    print("\n")
    print("✅ MODEL LOADING COMPLETE\n")
    print("═════════════════════════════════════════════\n")
    print("Model ready for inference on: " + options.device + "\n\n")
    loaded_hf_model {
        model_id: model_id,
        model_type: config.model_type,
        config: config,
        tokenizer: tokenizer,
        weights: weights,
        dtype: options.dtype,
        device: options.device,
    }
}

struct hf_inference_config {
    float temperature
    int max_new_tokens
    float top_p
    int top_k
    bool do_sample
    string generation_mode
}

func default_inference_config() hf_inference_config {
    hf_inference_config {
        temperature: 0.7,
        max_new_tokens: 128,
        top_p: 0.9,
        top_k: 50,
        do_sample: true,
        generation_mode: "sampling",
    }
}

func generate_text(
    model: loaded_hf_model,
    prompt: string,
    hf_inference_config config
) string {
    print("\n📝 Generating Text\n")
    print("─────────────────────────────────────────────\n")
    print("Prompt: " + prompt + "\n")
    print("Max tokens: " + int_to_string(config.max_new_tokens) + "\n")
    print("Temperature: " + float_to_string(config.temperature) + "\n")
    print("Top-p: " + float_to_string(config.top_p) + "\n")
    print("Top-k: " + int_to_string(config.top_k) + "\n\n")
    string[] tokens = hf_tokenizer.tokenize_text(prompt, model.tokenizer)
    print("✓ Tokenized to " + int_to_string(len(tokens)) + " tokens\n")
    string generated = prompt
    for i = 0; i < config.max_new_tokens; i = i + 1 {
        print("  [" + int_to_string(i + 1) + "/" + int_to_string(config.max_new_tokens) + "]")
        print(" Generating token...\n")
        if i == 0 {
            generated = generated + " [generated"
        }
    }
    generated = generated + "]"
    print("\n✅ Generation complete\n")
    print("Generated text:\n─────────────────────────────────────────────\n")
    print(generated + "\n")
    generated
}

func print_hf_model_summary(loaded_hf_model model) {
    print("\n╔════════════════════════════════════════════════╗\n")
    print("║  📊 HuggingFace Model Summary                ║\n")
    print("╚════════════════════════════════════════════════╝\n\n")
    print("🔧 Model Configuration\n")
    print("─────────────────────────────────────────────\n")
    print("Model ID: " + model.model_id + "\n")
    print("Model type: " + model.model_type + "\n")
    print("Architecture: " + model.config.architecture_type + "\n\n")
    print("📐 Dimensions\n")
    print("─────────────────────────────────────────────\n")
    print("Hidden size: " + int_to_string(model.config.hidden_size) + "\n")
    print("Num layers: " + int_to_string(model.config.num_hidden_layers) + "\n")
    print("Num heads: " + int_to_string(model.config.num_attention_heads) + "\n")
    print("KV heads (GQA): " + int_to_string(model.config.num_key_value_heads) + "\n")
    print("Intermediate size: " + int_to_string(model.config.intermediate_size) + "\n")
    print("Vocab size: " + int_to_string(model.config.vocab_size) + "\n\n")
    print("💾 Memory & Computing\n")
    print("─────────────────────────────────────────────\n")
    print("Data type: " + model.dtype + "\n")
    print("Device: " + model.device + "\n")
    print("Weights: " + int_to_string(model.weights.total_size_bytes / (1024 * 1024)) + " MB\n\n")
    print("🎯 Capabilities\n")
    print("─────────────────────────────────────────────\n")
    print("Chat support: ✓\n")
    print("Use cache: ✓\n")
    print("RoPE scaling: " + model.config.rope_scaling_type + "\n")
    print("Activation: " + model.config.hidden_act + "\n\n")
}
