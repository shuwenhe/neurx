package neurx.inference.advanced.model_registry
enum model_type {
    QWEN
    LLAMA
    MIXTRAL
    PHI
    GEMMA
}

struct architecture_config {
    name string
    model_type model_type
    num_hidden_layers int
    hidden_size int
    num_attention_heads int
    intermediate_size int
    vocab_size int
    max_position_embeddings int
    use_rope_scaling bool
    use_dynamic_ntk bool
    use_gqa bool
    use_flash_attn bool
    dtype string
    quantization string
    rope_theta float
    layer_norm_eps float
    initializer_range float
}
type model_factory func(config architecture_config) any
struct model_registry_state {
    factories map[string]model_factory
    configs map[string]architecture_config
    is_initialized bool
}
var global_registry model_registry_state = model_registry_state {
    factories: make(map[string]model_factory),
    configs: make(map[string]architecture_config),
    is_initialized: false,
}

func InitializeRegistry() {
    if global_registry.is_initialized {
        return
    }
    register_qwen_models()
    register_llama_models()
    register_mixtral_models()
    global_registry.is_initialized = true
}

func RegisterModel(
    arch_name string,
    config architecture_config,
    factory model_factory,
) bool {
    if _, exists := global_registry.factories[arch_name]; exists {
        return false
    }
    global_registry.factories[arch_name] = factory
    global_registry.configs[arch_name] = config
    return true
}

func GetArchitectureConfig(arch_name string) architecture_config {
    if config, ok := global_registry.configs[arch_name]; ok {
        return config
    }
    return architecture_config{}
}

func CreateModel(string arch_name, config architecture_config) any {
    if factory, ok := global_registry.factories[arch_name]; ok {
        return factory(config)
    }
    return nil
}

func ListAvailableModels() []string {
    models := make([]string, 0)
    for name := range global_registry.factories {
        models = append(models, name)
    }
    return models
}

func register_qwen_models() {
    qwen_config := architecture_config {
        name: "Qwen2.5-7B",
        model_type: QWEN,
        num_hidden_layers: 32,
        hidden_size: 4096,
        num_attention_heads: 32,
        intermediate_size: 11008,
        vocab_size: 151936,
        max_position_embeddings: 131072,
        use_dynamic_ntk: true,
        use_rope_scaling: true,
        rope_theta: 1000000.0,
        layer_norm_eps: 1e-6,
        dtype: "float32",
    }
    RegisterModel(
        "QwenForCausalLM",
        qwen_config,
        func(cfg architecture_config) any {
            return nil
        },
    )
    qwen_small := qwen_config
    qwen_small.hidden_size = 896
    qwen_small.num_attention_heads = 8
    qwen_small.intermediate_size = 3584
    qwen_small.num_hidden_layers = 24
    RegisterModel(
        "QwenForCausalLM-0.5B",
        qwen_small,
        func(cfg architecture_config) any {
            return nil
        },
    )
}

func register_llama_models() {
    llama_config := architecture_config {
        name: "Llama-2-7B",
        model_type: LLAMA,
        num_hidden_layers: 32,
        hidden_size: 4096,
        num_attention_heads: 32,
        intermediate_size: 11008,
        vocab_size: 32000,
        max_position_embeddings: 4096,
        rope_theta: 10000.0,
        layer_norm_eps: 1e-5,
        dtype: "float32",
    }
    RegisterModel(
        "LlamaForCausalLM",
        llama_config,
        func(cfg architecture_config) any {
            return nil
        },
    )
}

func register_mixtral_models() {
    mixtral_config := architecture_config {
        name: "Mixtral-8x7B",
        model_type: MIXTRAL,
        num_hidden_layers: 32,
        hidden_size: 4096,
        num_attention_heads: 32,
        intermediate_size: 14336,
        vocab_size: 32000,
        max_position_embeddings: 32768,
        rope_theta: 10000.0,
        layer_norm_eps: 1e-5,
        dtype: "float32",
    }
    RegisterModel(
        "MixtralForCausalLM",
        mixtral_config,
        func(cfg architecture_config) any {
            return nil
        },
    )
}

func main() {
    InitializeRegistry()
    models := ListAvailableModels()
    for i := 0; i < len(models); i++ {
        config := GetArchitectureConfig(models[i])
        println("Model:", models[i])
        println("  Hidden Size:", config.hidden_size)
        println("  Layers:", config.num_hidden_layers)
    }
}

