package neurx.model.model_registry

use std.vec
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
    attention_type: string
    activation: string
    use_flash_attn: bool
    use_paged_attn: bool
    use_kv_cache_quantization: bool
    kv_cache_quantization_bits: int
    enable_rope_scaling: bool
    rope_scaling_factor: f32
}

struct model_adapter {
    model_spec: model_spec
    optimization: model_optimization
    weight_format: string
    quantization_level: int
    distributed_strategy: string
    distributed_world_size: int
    distributed_rank: int
}

struct model_registry {
    models: []model_adapter
}

func create_llama_adapter(spec: model_spec) model_adapter {
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

func create_qwen_adapter(spec: model_spec) model_adapter {
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

func create_deepseek_adapter(spec: model_spec) model_adapter {
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

func create_mistral_adapter(spec: model_spec) model_adapter {
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

func create_default_adapter(spec: model_spec) model_adapter {
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

func create_adapter_for_model(model_name: string) option[model_adapter] {
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
    rope_type: string
    factor: f32
    short_mlen: int
}

func get_rope_params_for_model(model_type: string, seq_len: int) rope_scaling_params {
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
    load_strategy: string
    precision: string
    enable_tensor_parallel: bool
    enable_pipeline_parallel: bool
    tp_degree: int
    pp_degree: int
    enable_zero_optimization: bool
}

func get_weight_loading_config_for_model(
    model_name: string,
    world_size: int,
    rank: int
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
    is_compatible: bool
    warnings: []string
    requirements: []string
}

func check_model_compatibility(
    adapter: *model_adapter,
    target_device: string,
    available_memory_gb: int
) compatibility_report {
    warnings := vec[]()
    requirements := vec[]()
    is_compatible := true

    est_memory_gb := (adapter.model_spec.hidden_size *
                        adapter.model_spec.num_hidden_layers * 4) / 1024

    if est_memory_gb > available_memory_gb {
        is_compatible = false
        msg := f"模型需要 ~{est_memory_gb}GB 显存，但仅有 {available_memory_gb}GB"
        requirements.push(msg)
    }

    if adapter.optimization.use_flash_attn {
        requirements.push("需要 Ampere+ GPU (RTX 30 系或更新)")
    }

    if adapter.distributed_strategy != "none" {
        requirements.push("需要多 GPU 支持和 NCCL")
    }

    if adapter.quantization_level < 16 {
        warnings.push(f"量化到 {adapter.quantization_level}bit，可能影响精度")
    }

    compatibility_report {
        is_compatible: is_compatible,
        warnings: warnings,
        requirements: requirements,
    }
}

struct model_diagnostics {
    model_name: string
    parameter_count: long
    estimated_memory_gb: f32
    attention_type: string
    activation: string
    optimizations_enabled: int
    performance_profile: string
}

func get_model_diagnostics(adapter: *model_adapter) model_diagnostics {
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

func format_attention_type(attn: string) string {
    if attn == ATTENTION_STANDARD { return "Standard Attention" }
    if attn == ATTENTION_FLASH { return "Flash Attention" }
    if attn == ATTENTION_GQA { return "Grouped Query Attention" }
    if attn == ATTENTION_MQA { return "Multi-Query Attention" }
    if attn == ATTENTION_SPARSE { return "Sparse Attention" }
    return "Unknown"
}

func format_activation(act: string) string {
    if act == ACTIVATION_RELU { return "ReLU" }
    if act == ACTIVATION_GELU { return "GELU" }
    if act == ACTIVATION_GELU_APPROX { return "GELU (approx)" }
    if act == ACTIVATION_SILU { return "SiLU" }
    if act == ACTIVATION_SWIGLU { return "SwiGLU" }
    return "Unknown"
}

func main() {
    println("🏢 Model Registry - 模型注册表和适配器系统")
    println("==========================================")
    println("")

    all_models := get_all_models()
    println(f"📦 总模型数: {all_models.len()}")
    println("")

    println("🔧 模型适配器演示:")

    model_names := [
        "llama-7b",
        "qwen2-7b",
        "deepseek-7b",
        "mistral-7b",
    ]

    for name in model_names.iter() {
        if let Some(adapter) = create_adapter_for_model(name) {
            diag := get_model_diagnostics(&adapter)

            println(f"\n✅ {name}:")
            println(f"   参数: {diag.parameter_count / 1e9:.1f}B")
            println(f"   显存: ~{diag.estimated_memory_gb:.1f}GB (fp16)")
            println(f"   Attention: {diag.attention_type}")
            println(f"   激活函数: {diag.activation}")
            println(f"   启用优化: {diag.optimizations_enabled} 项")

            report := check_model_compatibility(&adapter, "cuda", 80)
            if report.is_compatible {
                println("   ✓ 兼容 A100 (80GB)")
            } else {
                println("   ✗ 不兼容当前环境")
            }
        }
    }

    println("")
    println("✅ 核心特性:")
    println("  ✓ 30+ 种模型完整支持")
    println("  ✓ 模型特定优化")
    println("  ✓ 灵活的适配器系统")
    println("  ✓ 自动兼容性检查")
    println("  ✓ 性能诊断工具")
}
