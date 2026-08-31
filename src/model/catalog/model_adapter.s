package models
import (
	"fmt"
	"sync"
)
struct model_adapter_base {
	string model_id
	string model_name
	model_type model_type
	*tokenizer_interface tokenizer
	*inference_engine inference_engine
}

struct qwen_adapter {
	*model_adapter_base base
	string version
	string instruction_format
}

struct llama_adapter {
	*model_adapter_base base
	int32 context_length
	bool flash_attention_enabled
}

struct mixtral_adapter {
	*model_adapter_base base
	int32 num_experts
	int32 expert_capacity
}

struct chatglm_adapter {
	*model_adapter_base base
	string generation_mode
}

struct baichuan_adapter {
	*model_adapter_base base
	string layer_norm_variant
}

struct internlm_adapter {
	*model_adapter_base base
	float32 rope_scaling_factor
}

struct falcon_adapter {
	*model_adapter_base base
	int32 num_heads
	int32 head_dim
}

struct mpt_adapter {
	*model_adapter_base base
	int32 n_layers
	bool alibi_enabled
}

struct model_adapter_registry {
	sync.Mutex mu
	map[string]interface{} adapters
	map[string]map[string]interface{} adapter_configs
	map[string]*model_metadata adapter_metadata
	int32 total_registered
}

func create_model_adapter_registry() *model_adapter_registry {
	return *model_adapter_registry{
		adapters: make(map[string]interface{}),
		adapter_configs: make(map[string]map[string]interface{}),
		adapter_metadata: make(map[string]*model_metadata),
	}
}

func create_qwen_adapter(model_id string, model_name string, version string) *qwen_adapter {
	return *qwen_adapter{
		base: *model_adapter_base{
			model_id: model_id,
			model_name: model_name,
			model_type: TYPE_QWEN,
			tokenizer: create_tokenizer("qwen_tokenizer", model_id, TOKENIZER_SENTENCEPIECE),
			inference_engine: nil,
		},
		version: version,
		instruction_format: "Qwen",
	}
}

func create_llama_adapter(model_id string, model_name string, context_length int32) *llama_adapter {
	return *llama_adapter{
		base: *model_adapter_base{
			model_id: model_id,
			model_name: model_name,
			model_type: TYPE_LLAMA,
			tokenizer: create_tokenizer("llama_tokenizer", model_id, TOKENIZER_BPE),
			inference_engine: nil,
		},
		context_length: context_length,
		flash_attention_enabled: true,
	}
}

func create_mixtral_adapter(model_id string, model_name string, num_experts int32) *mixtral_adapter {
	return *mixtral_adapter{
		base: *model_adapter_base{
			model_id: model_id,
			model_name: model_name,
			model_type: TYPE_MIXTRAL,
			tokenizer: create_tokenizer("mixtral_tokenizer", model_id, TOKENIZER_BPE),
			inference_engine: nil,
		},
		num_experts: num_experts,
		expert_capacity: 16,
	}
}

func create_chatglm_adapter(model_id string, model_name string, generation_mode string) *chatglm_adapter {
	return *chatglm_adapter{
		base: *model_adapter_base{
			model_id: model_id,
			model_name: model_name,
			model_type: TYPE_CHATGLM,
			tokenizer: create_tokenizer("chatglm_tokenizer", model_id, TOKENIZER_SENTENCEPIECE),
			inference_engine: nil,
		},
		generation_mode: generation_mode,
	}
}

func create_baichuan_adapter(model_id string, model_name string) *baichuan_adapter {
	return *baichuan_adapter{
		base: *model_adapter_base{
			model_id: model_id,
			model_name: model_name,
			model_type: TYPE_BAICHUAN,
			tokenizer: create_tokenizer("baichuan_tokenizer", model_id, TOKENIZER_BPE),
			inference_engine: nil,
		},
		layer_norm_variant: "RMSNorm",
	}
}

func create_internlm_adapter(model_id string, model_name string) *internlm_adapter {
	return *internlm_adapter{
		base: *model_adapter_base{
			model_id: model_id,
			model_name: model_name,
			model_type: TYPE_INTERNLM,
			tokenizer: create_tokenizer("internlm_tokenizer", model_id, TOKENIZER_SENTENCEPIECE),
			inference_engine: nil,
		},
		rope_scaling_factor: 1.0,
	}
}

func create_falcon_adapter(model_id string, model_name string, num_heads int32) *falcon_adapter {
	return *falcon_adapter{
		base: *model_adapter_base{
			model_id: model_id,
			model_name: model_name,
			model_type: TYPE_FALCON,
			tokenizer: create_tokenizer("falcon_tokenizer", model_id, TOKENIZER_BPE),
			inference_engine: nil,
		},
		num_heads: num_heads,
		head_dim: 64,
	}
}

func create_mpt_adapter(model_id string, model_name string, n_layers int32) *mpt_adapter {
	return *mpt_adapter{
		base: *model_adapter_base{
			model_id: model_id,
			model_name: model_name,
			model_type: TYPE_MPT,
			tokenizer: create_tokenizer("mpt_tokenizer", model_id, TOKENIZER_BPE),
			inference_engine: nil,
		},
		n_layers: n_layers,
		alibi_enabled: true,
	}
}

func (model_adapter_registry* registry) register_adapter(model_type model_type, adapter interface{}, metadata *model_metadata) error {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	type_str := fmt.Sprintf("%v", model_type)
	registry.adapters[type_str] = adapter
	registry.adapter_metadata[type_str] = metadata
	registry.total_registered++
	return nil
}

func (model_adapter_registry* registry) get_adapter(model_type model_type) interface{} {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	type_str := fmt.Sprintf("%v", model_type)
	return registry.adapters[type_str]
}

func (model_adapter_registry* registry) set_adapter_config(model_type model_type, config map[string]interface{}) {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	type_str := fmt.Sprintf("%v", model_type)
	registry.adapter_configs[type_str] = config
}

func (model_adapter_registry* registry) get_adapter_config(model_type model_type) map[string]interface{} {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	type_str := fmt.Sprintf("%v", model_type)
	return registry.adapter_configs[type_str]
}

func (model_adapter_registry* registry) get_adapter_metadata(model_type model_type) *model_metadata {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	type_str := fmt.Sprintf("%v", model_type)
	return registry.adapter_metadata[type_str]
}

func (model_adapter_registry* registry) list_registered_adapters() []string {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	adapters := make(string[], 0, len(registry.adapters))
	for key := range registry.adapters {
		adapters = append(adapters, key)
	}
	return adapters
}

func (model_adapter_registry* registry) get_registry_stats() map[string]interface{} {
	registry.mu.Lock()
	defer registry.mu.Unlock()
	stats := make(map[string]interface{})
	stats["total_registered"] = registry.total_registered
	stats["registered_adapters"] = len(registry.adapters)
	stats["configured_adapters"] = len(registry.adapter_configs)
	return stats
}

func (qwen_adapter* adapter) get_instruction_format() string {
	return adapter.instruction_format
}

func (qwen_adapter* adapter) set_instruction_format(format string) {
	adapter.instruction_format = format
}

func (qwen_adapter* adapter) get_model_type() model_type {
	return adapter.base.model_type
}

func (llama_adapter* adapter) get_context_length() int32 {
	return adapter.context_length
}

func (llama_adapter* adapter) set_context_length(length int32) {
	adapter.context_length = length
}

func (llama_adapter* adapter) enable_flash_attention(enabled bool) {
	adapter.flash_attention_enabled = enabled
}

func (mixtral_adapter* adapter) get_num_experts() int32 {
	return adapter.num_experts
}

func (mixtral_adapter* adapter) set_expert_capacity(capacity int32) {
	adapter.expert_capacity = capacity
}

func (chatglm_adapter* adapter) get_generation_mode() string {
	return adapter.generation_mode
}

func (chatglm_adapter* adapter) set_generation_mode(mode string) {
	adapter.generation_mode = mode
}

func (baichuan_adapter* adapter) get_layer_norm_variant() string {
	return adapter.layer_norm_variant
}

func (internlm_adapter* adapter) set_rope_scaling_factor(factor float32) {
	adapter.rope_scaling_factor = factor
}

func (falcon_adapter* adapter) get_num_heads() int32 {
	return adapter.num_heads
}

func (falcon_adapter* adapter) get_head_dim() int32 {
	return adapter.head_dim
}

func (mpt_adapter* adapter) get_num_layers() int32 {
	return adapter.n_layers
}

func (mpt_adapter* adapter) enable_alibi(enabled bool) {
	adapter.alibi_enabled = enabled
}

func register_all_standard_adapters(model_adapter_registry* registry) {
	qwen_metadata := *model_metadata{
		model_type: TYPE_QWEN,
		vocabulary_size: 32000,
		supported_devices: []model_device_type{DEVICE_CUDA, DEVICE_CPU},
		capabilities: []model_capability{CAP_CHAT, CAP_COMPLETION},
	}
	llama_metadata := *model_metadata{
		model_type: TYPE_LLAMA,
		vocabulary_size: 32000,
		supported_devices: []model_device_type{DEVICE_CUDA, DEVICE_CPU},
		capabilities: []model_capability{CAP_CHAT, CAP_COMPLETION, CAP_CODE_GENERATION},
	}
	mixtral_metadata := *model_metadata{
		model_type: TYPE_MIXTRAL,
		vocabulary_size: 32000,
		supported_devices: []model_device_type{DEVICE_CUDA},
		capabilities: []model_capability{CAP_CHAT, CAP_COMPLETION, CAP_CODE_GENERATION},
	}
	chatglm_metadata := *model_metadata{
		model_type: TYPE_CHATGLM,
		vocabulary_size: 130528,
		supported_devices: []model_device_type{DEVICE_CUDA, DEVICE_CPU},
		capabilities: []model_capability{CAP_CHAT, CAP_COMPLETION},
	}
	baichuan_metadata := *model_metadata{
		model_type: TYPE_BAICHUAN,
		vocabulary_size: 125696,
		supported_devices: []model_device_type{DEVICE_CUDA, DEVICE_CPU},
		capabilities: []model_capability{CAP_CHAT, CAP_COMPLETION},
	}
	registry.register_adapter(TYPE_QWEN, create_qwen_adapter("qwen-7b", "Qwen-7B", "1.0"), qwen_metadata)
	registry.register_adapter(TYPE_LLAMA, create_llama_adapter("llama-7b", "Llama-7B", 4096), llama_metadata)
	registry.register_adapter(TYPE_MIXTRAL, create_mixtral_adapter("mixtral-8x7b", "Mixtral-8x7B", 8), mixtral_metadata)
	registry.register_adapter(TYPE_CHATGLM, create_chatglm_adapter("chatglm-6b", "ChatGLM-6B", "chat"), chatglm_metadata)
	registry.register_adapter(TYPE_BAICHUAN, create_baichuan_adapter("baichuan-7b", "Baichuan-7B"), baichuan_metadata)
	registry.register_adapter(TYPE_INTERNLM, create_internlm_adapter("internlm-7b", "InternLM-7B"), *model_metadata{
		model_type: TYPE_INTERNLM,
		vocabulary_size: 103168,
		supported_devices: []model_device_type{DEVICE_CUDA, DEVICE_CPU},
		capabilities: []model_capability{CAP_CHAT, CAP_COMPLETION},
	})
	registry.register_adapter(TYPE_FALCON, create_falcon_adapter("falcon-7b", "Falcon-7B", 32), *model_metadata{
		model_type: TYPE_FALCON,
		vocabulary_size: 65024,
		supported_devices: []model_device_type{DEVICE_CUDA, DEVICE_CPU},
		capabilities: []model_capability{CAP_CHAT, CAP_COMPLETION},
	})
	registry.register_adapter(TYPE_MPT, create_mpt_adapter("mpt-7b", "MPT-7B", 32), *model_metadata{
		model_type: TYPE_MPT,
		vocabulary_size: 50257,
		supported_devices: []model_device_type{DEVICE_CUDA, DEVICE_CPU},
		capabilities: []model_capability{CAP_CHAT, CAP_COMPLETION},
	})
}
