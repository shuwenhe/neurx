package neurx.model.model_registry
use std.slices
use std.map
use std.option
use neurx.model.model_zoo
const ATTENTION_STANDARD = "standard"
const ATTENTION_FLASH = "flash_attention"
const ATTENTION_GQA = "gqa"
const ATTENTION_MQA = "mqa"
const ATTENTION_SPARSE = "sparse"
const ACTIVATION_RELU = "relu"
const ACTIVATION_GELU = "gelu"
const ACTIVATION_GELU_APPROX = "gelu_approx"
const ACTIVATION_SILU = "silu"
const ACTIVATION_SWIGLU = "swiglu"
struct model_optimization {
    string attention_type
    string activation
    bool use_flash_attn
    bool use_paged_attn
    bool use_kv_cache_quantization
    int kv_cache_quantization_bits
    bool enable_rope_scaling
    f32 rope_scaling_factor
}

struct model_adapter {
    model_spec model_spec
    model_optimization optimization
    string weight_format
    int quantization_level
    string distributed_strategy
    int distributed_world_size
    int distributed_rank
}

struct model_registry {
    models: []model_adapter
}

func create_llama_adapter(model_spec spec) model_adapter {
    model_adapter {
        model_spec: spec,
        optimization: model_optimization {
            attention_type: ATTENTION_FLASH,
            activation: ACTIVATION_SILU,
            use_flash_attn: true,
            use_paged_attn: true,
            use_kv_cache_quantization: false,
            kv_cache_quantization_bits: 8,
            enable_rope_scaling: true,
            rope_scaling_factor: 1.0,
        },
        weight_format: "safetensors",
        quantization_level: 16,
        distributed_strategy: "tensor_parallel",
        distributed_world_size: 1,
        distributed_rank: 0,
    }
}

func create_qwen_adapter(model_spec spec) model_adapter {
    model_adapter {
        model_spec: spec,
        optimization: model_optimization {
            attention_type: ATTENTION_FLASH,
            activation: ACTIVATION_SILU,
            use_flash_attn: true,
            use_paged_attn: true,
            use_kv_cache_quantization: false,
            kv_cache_quantization_bits: 8,
            enable_rope_scaling: false,
            rope_scaling_factor: 1.0,
        },
        weight_format: "safetensors",
        quantization_level: 16,
        distributed_strategy: "tensor_parallel",
        distributed_world_size: 1,
        distributed_rank: 0,
    }
}

func create_deepseek_adapter(model_spec spec) model_adapter {
    model_adapter {
        model_spec: spec,
        optimization: model_optimization {
            attention_type: ATTENTION_GQA,
            activation: ACTIVATION_SILU,
            use_flash_attn: true,
            use_paged_attn: true,
            use_kv_cache_quantization: true,
            kv_cache_quantization_bits: 8,
            enable_rope_scaling: true,
            rope_scaling_factor: 1.0,
        },
        weight_format: "safetensors",
        quantization_level: 16,
        distributed_strategy: "tensor_parallel",
        distributed_world_size: 1,
        distributed_rank: 0,
    }
}

func create_mistral_adapter(model_spec spec) model_adapter {
    model_adapter {
        model_spec: spec,
        optimization: model_optimization {
            attention_type: ATTENTION_GQA,
            activation: ACTIVATION_SILU,
            use_flash_attn: true,
            use_paged_attn: true,
            use_kv_cache_quantization: false,
            kv_cache_quantization_bits: 8,
            enable_rope_scaling: true,
            rope_scaling_factor: 1.0,
        },
        weight_format: "safetensors",
        quantization_level: 16,
        distributed_strategy: "tensor_parallel",
        distributed_world_size: 1,
        distributed_rank: 0,
    }
}

func create_default_adapter(model_spec spec) model_adapter {
    model_adapter {
        model_spec: spec,
        optimization: model_optimization {
            attention_type: ATTENTION_STANDARD,
            activation: ACTIVATION_GELU,
            use_flash_attn: false,
            use_paged_attn: false,
            use_kv_cache_quantization: false,
            kv_cache_quantization_bits: 8,
            enable_rope_scaling: false,
            rope_scaling_factor: 1.0,
        },
        weight_format: "safetensors",
        quantization_level: 16,
        distributed_strategy: "none",
        distributed_world_size: 1,
        distributed_rank: 0,
    }
}

func create_adapter_for_model(string model_name) option[model_adapter] {
    spec_opt := get_model_by_name(model_name)
    if spec_opt == none {
        return none
    }
    spec := match spec_opt {
        Some(s) => s,
        None => return none,
    }
    model_type := spec.model_type
    adapter := if model_type == "llama" || model_type == "llama2" || model_type == "llama3" {
        create_llama_adapter(spec)
    } else if model_type == "qwen" || model_type == "qwen2" || model_type == "qwen2.5" {
        create_qwen_adapter(spec)
    } else if model_type == "deepseek" || model_type == "deepseek_moe" || model_type == "deepseek_v3" {
        create_deepseek_adapter(spec)
    } else if model_type == "mistral" || model_type == "mixtral" {
        create_mistral_adapter(spec)
    } else {
        create_default_adapter(spec)
    }
    return Some(adapter)
}

struct rope_scaling_params {
    string rope_type
    f32 factor
    int short_mlen
}

func get_rope_params_for_model(string model_type, int seq_len) rope_scaling_params {
    if model_type == "llama" || model_type == "mistral" {
        return rope_scaling_params {
            rope_type: "default",
            factor: 1.0,
            short_mlen: 52,
        }
    }
    if model_type == "qwen" || model_type == "qwen2" || model_type == "qwen2.5" {
        return rope_scaling_params {
            rope_type: "dynamic",
            factor: 1.0,
            short_mlen: 52,
        }
    }
    if model_type == "deepseek" {
        factor := if seq_len > 4096 { seq_len as f32 / 4096.0 } else { 1.0 }
        return rope_scaling_params {
            rope_type: "linear",
            factor: factor,
            short_mlen: 52,
        }
    }
    if model_type == "baichuan" || model_type == "baichuan2" {
        factor := if seq_len > 4096 { seq_len as f32 / 4096.0 } else { 1.0 }
        return rope_scaling_params {
            rope_type: "linear",
            factor: factor,
            short_mlen: 52,
        }
    }
    return rope_scaling_params {
        rope_type: "default",
        factor: 1.0,
        short_mlen: 52,
    }
}

struct weight_loading_config {
    string load_strategy
    string precision
    bool enable_tensor_parallel
    bool enable_pipeline_parallel
    int tp_degree
    int pp_degree
    bool enable_zero_optimization
}

func get_weight_loading_config_for_model(
    model_name: string,
    world_size: int,
    int rank
) weight_loading_config {
    weight_loading_config {
        load_strategy: "eager",
        precision: "fp16",
        enable_tensor_parallel: world_size > 1,
        enable_pipeline_parallel: false,
        tp_degree: world_size,
        pp_degree: 1,
        enable_zero_optimization: false,
    }
}

struct compatibility_report {
    bool is_compatible
    warnings: string[]
    requirements: string[]
}

func check_model_compatibility(
    adapter: *model_adapter,
    target_device: string,
    int available_memory_gb
) compatibility_report {
    warnings := []()
    requirements := []()
    is_compatible := true
    est_memory_gb := (adapter.model_spec.hidden_size *
                        adapter.model_spec.num_hidden_layers * 4) / 1024
    if est_memory_gb > available_memory_gb {
        is_compatible = false
        msg := f"modelneed ~{est_memory_gb}GB GPU Memory，but仅有 {available_memory_gb}GB"
        requirements = append(requirements, msg)
    }
    if adapter.optimization.use_flash_attn {
        requirements = append(requirements, "need Ampere+ GPU (RTX 30 系or更new)")
    }
    if adapter.distributed_strategy != "none" {
        requirements = append(requirements, "needmore GPU supportand NCCL")
    }
    if adapter.quantization_level < 16 {
        warnings = append(warnings, f"量ization到 {adapter.quantization_level}bit，possible影响精度")
    }
    compatibility_report {
        is_compatible: is_compatible,
        warnings: warnings,
        requirements: requirements,
    }
}

struct model_diagnostics {
    string model_name
    long parameter_count
    f32 estimated_memory_gb
    string attention_type
    string activation
    int optimizations_enabled
    string performance_profile
}

func get_model_diagnostics(*model_adapter adapter) model_diagnostics {
    param_count := adapter.model_spec.hidden_size *
                     adapter.model_spec.num_hidden_layers *
                     adapter.model_spec.vocab_size
    memory_gb := param_count as f32 / (1024 * 1024 * 1024) * 2.0
    opt_count := 0
    if adapter.optimization.use_flash_attn { opt_count += 1 }
    if adapter.optimization.use_paged_attn { opt_count += 1 }
    if adapter.optimization.use_kv_cache_quantization { opt_count += 1 }
    if adapter.optimization.enable_rope_scaling { opt_count += 1 }
    model_diagnostics {
        model_name: adapter.model_spec.name,
        parameter_count: param_count,
        estimated_memory_gb: memory_gb,
        attention_type: format_attention_type(adapter.optimization.attention_type),
        activation: format_activation(adapter.optimization.activation),
        optimizations_enabled: opt_count,
        performance_profile: "balanced",
    }
}

func format_attention_type(string attn) string {
    if attn == ATTENTION_STANDARD { return "Standard Attention" }
    if attn == ATTENTION_FLASH { return "Flash Attention" }
    if attn == ATTENTION_GQA { return "Grouped Query Attention" }
    if attn == ATTENTION_MQA { return "Multi-Query Attention" }
    if attn == ATTENTION_SPARSE { return "Sparse Attention" }
    return "Unknown"
}

func format_activation(string act) string {
    if act == ACTIVATION_RELU { return "ReLU" }
    if act == ACTIVATION_GELU { return "GELU" }
    if act == ACTIVATION_GELU_APPROX { return "GELU (approx)" }
    if act == ACTIVATION_SILU { return "SiLU" }
    if act == ACTIVATION_SWIGLU { return "SwiGLU" }
    return "Unknown"
}

func main() {
    println("🏢 Model Registry - Model Registryand适配器系统")
    println("==========================================")
    println("")
    all_models := get_all_models()
    println(f"📦 Total Models: {len(all_models)}")
    println("")
    println("🔧 Model Adapter Demo:")
    model_names := [
        "llama-7b",
        "qwen2-7b",
        "deepseek-7b",
        "mistral-7b",
    ]
    for name in model_names.iter() {
        adapter_opt := create_adapter_for_model(name)
        match adapter_opt {
            Some(adapter) => {
                diag := get_model_diagnostics(*adapter)
                println(f"\n✅ {name}:")
                println(f"   Parameters: {diag.parameter_count / 1e9:.1f}B")
                println(f"   GPU Memory: ~{diag.estimated_memory_gb:.1f}GB (fp16)")
                println(f"   Attention: {diag.attention_type}")
                println(f"   Activation Function: {diag.activation}")
                println(f"   Optimizations Enabled: {diag.optimizations_enabled} items")
                report := check_model_compatibility(*adapter, "cuda", 80)
                if report.is_compatible {
                    println("   ✓ Compatible A100 (80GB)")
                } else {
                    println("   ✗ 不Compatiblewhenfrontenvironment")
                }
            }
            None => {}
        }
    }
    println("")
    println("✅ Core Features:")
    println("  ✓ 30+ model complete support")
    println("  ✓ Model-specific optimization")
    println("  ✓ Flexible adapter system")
    println("  ✓ 自动Compatibleitycheck")
    println("  ✓ Performance diagnostic tools")
}
