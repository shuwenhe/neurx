package neurx.transformers_utils.compatibility.adapter_registry

struct model_adapter_entry {
    string model_type
    string display_name
    []string supported_model_ids
    string adapter_module
    int popularity_rank
}

func get_model_registry() []model_adapter_entry {
    []model_adapter_entry registry

    registry.append(model_adapter_entry {
        model_type: "llama",
        display_name: "Meta LLaMA",
        supported_model_ids: [
            "meta-llama/Llama-2-7b",
            "meta-llama/Llama-2-13b",
            "meta-llama/Llama-2-70b",
            "meta-llama/Llama-3-8b",
            "meta-llama/Llama-3-70b",
        ],
        adapter_module: "neurx.transformers_utils.model_adapters.llama_adapter",
        popularity_rank: 1,
    })

    registry.append(model_adapter_entry {
        model_type: "qwen",
        display_name: "Alibaba Qwen",
        supported_model_ids: [
            "Qwen/Qwen-7B",
            "Qwen/Qwen-14B",
            "Qwen/Qwen2-7B",
            "Qwen/Qwen2-14B",
            "Qwen/Qwen2.5-7B",
            "Qwen/Qwen2.5-14B",
        ],
        adapter_module: "neurx.transformers_utils.model_adapters.qwen_adapter",
        popularity_rank: 2,
    })

    registry.append(model_adapter_entry {
        model_type: "mistral",
        display_name: "Mistral AI",
        supported_model_ids: [
            "mistralai/Mistral-7B-v0.1",
            "mistralai/Mistral-7B-v0.3",
            "mistralai/Mixtral-8x7B",
            "mistralai/Mixtral-8x22B",
        ],
        adapter_module: "neurx.transformers_utils.model_adapters.mistral_adapter",
        popularity_rank: 3,
    })

    registry.append(model_adapter_entry {
        model_type: "deepseek",
        display_name: "DeepSeek",
        supported_model_ids: [
            "deepseek-ai/deepseek-7b",
            "deepseek-ai/deepseek-33b",
            "deepseek-ai/deepseek-moe-16b",
        ],
        adapter_module: "neurx.transformers_utils.model_adapters.deepseek_adapter",
        popularity_rank: 4,
    })

    registry.append(model_adapter_entry {
        model_type: "phi",
        display_name: "Microsoft Phi",
        supported_model_ids: [
            "microsoft/phi-1",
            "microsoft/phi-2",
            "microsoft/phi-3-mini",
        ],
        adapter_module: "neurx.transformers_utils.model_adapters.phi_adapter",
        popularity_rank: 5,
    })

    registry.append(model_adapter_entry {
        model_type: "chatglm",
        display_name: "ChatGLM",
        supported_model_ids: [
            "THUDM/chatglm-6b",
            "THUDM/chatglm2-6b",
            "THUDM/glm-4-9b",
        ],
        adapter_module: "neurx.transformers_utils.model_adapters.chatglm_adapter",
        popularity_rank: 6,
    })

    registry
}

func get_adapter_by_model_id(string model_id) model_adapter_entry {
    []model_adapter_entry registry = get_model_registry()

    for entry in registry {
        for supported_id in entry.supported_model_ids {
            if supported_id == model_id {
                return entry
            }
        }
    }

    model_adapter_entry {
        model_type: "llama",
        display_name: "Unknown (fallback to LLaMA)",
        supported_model_ids: [],
        adapter_module: "neurx.transformers_utils.model_adapters.llama_adapter",
        popularity_rank: 99,
    }
}

func get_adapter_by_model_type(string model_type) model_adapter_entry {
    []model_adapter_entry registry = get_model_registry()

    for entry in registry {
        if entry.model_type == model_type {
            return entry
        }
    }

    model_adapter_entry {
        model_type: "llama",
        display_name: "Unknown (fallback to LLaMA)",
        supported_model_ids: [],
        adapter_module: "neurx.transformers_utils.model_adapters.llama_adapter",
        popularity_rank: 99,
    }
}

func list_all_supported_models() string {
    []model_adapter_entry registry = get_model_registry()

    string output = ""
    output = output + "╔════════════════════════════════════════════════╗\n"
    output = output + "║  🤗 Supported HuggingFace Models              ║\n"
    output = output + "╚════════════════════════════════════════════════╝\n\n"

    for entry in registry {
        output = output + "📦 " + entry.display_name + " (" + entry.model_type + ")\n"
        output = output + "   Rank: " + int_to_string(entry.popularity_rank) + "\n"
        output = output + "   Models:\n"

        for model_id in entry.supported_model_ids {
            output = output + "     ✓ " + model_id + "\n"
        }

        output = output + "\n"
    }

    output
}

func is_model_supported(string model_id) bool {
    []model_adapter_entry registry = get_model_registry()

    for entry in registry {
        for supported_id in entry.supported_model_ids {
            if supported_id == model_id {
                return true
            }
        }
    }

    false
}

func count_supported_models() int {
    []model_adapter_entry registry = get_model_registry()
    int total = 0

    for entry in registry {
        total = total + len(entry.supported_model_ids)
    }

    total
}

func get_popular_models() []string {
    []model_adapter_entry registry = get_model_registry()
    []string popular

    for entry in registry {
        if entry.popularity_rank <= 5 {
            for model_id in entry.supported_model_ids {
                if len(popular) < 10 {
                    popular.append(model_id)
                }
            }
        }
    }

    popular
}
