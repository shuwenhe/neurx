
package neurx.lora.examples.config_presets

use std.vec.vec
use std.map.map
use neurx.lora.lora_config::{lora_config}

func preset_lightweight() lora_config {
    let mut config = lora_config::default()
    config.lora_rank = 4
    config.lora_alpha = 8.0
    config.lora_dropout = 0.01
    config.bias = "none"

    let mut targets = vec[string]()
    targets.push("q_proj")
    targets.push("v_proj")
    config.target_modules = targets

    config
}

func preset_balanced() lora_config {
    let mut config = lora_config::default()
    config.lora_rank = 16
    config.lora_alpha = 32.0
    config.lora_dropout = 0.05
    config.bias = "lora_only"

    let mut targets = vec[string]()
    targets.push("q_proj")
    targets.push("k_proj")
    targets.push("v_proj")
    targets.push("dense")
    config.target_modules = targets

    config
}

func preset_high_quality() lora_config {
    let mut config = lora_config::default()
    config.lora_rank = 64
    config.lora_alpha = 128.0
    config.lora_dropout = 0.1
    config.bias = "all"

    let mut targets = vec[string]()
    targets.push("q_proj")
    targets.push("k_proj")
    targets.push("v_proj")
    targets.push("dense")
    targets.push("out_proj")
    config.target_modules = targets

    config
}

func preset_text_classification() lora_config {
    let mut config = preset_balanced()
    config.task_type = "SEQUENCE_CLASSIFICATION"
    config.lora_rank = 8

    let mut targets = vec[string]()
    targets.push("q_proj")
    targets.push("v_proj")
    config.target_modules = targets

    config
}

func preset_question_answering() lora_config {
    let mut config = preset_balanced()
    config.task_type = "QUESTION_ANSWERING"
    config.lora_rank = 16

    let mut targets = vec[string]()
    targets.push("q_proj")
    targets.push("k_proj")
    targets.push("v_proj")
    targets.push("dense")
    config.target_modules = targets

    config
}

func preset_machine_translation() lora_config {
    let mut config = preset_high_quality()
    config.task_type = "TRANSLATION"
    config.lora_rank = 32
    config.lora_alpha = 64.0

    let mut targets = vec[string]()
    targets.push("q_proj")
    targets.push("k_proj")
    targets.push("v_proj")
    targets.push("dense")
    targets.push("attention")
    config.target_modules = targets

    config
}

func preset_code_generation() lora_config {
    let mut config = preset_high_quality()
    config.task_type = "CAUSAL_LM"
    config.lora_rank = 64
    config.lora_alpha = 128.0

    let mut targets = vec[string]()
    targets.push("q_proj")
    targets.push("v_proj")
    targets.push("dense")
    config.target_modules = targets

    config
}

func preset_instruction_following() lora_config {
    let mut config = preset_balanced()
    config.task_type = "CAUSAL_LM"
    config.lora_rank = 16
    config.lora_alpha = 32.0

    let mut targets = vec[string]()
    targets.push("q_proj")
    targets.push("v_proj")
    config.target_modules = targets

    config
}

func preset_conversational() lora_config {
    let mut config = preset_balanced()
    config.task_type = "CAUSAL_LM"
    config.lora_rank = 32
    config.lora_alpha = 64.0

    let mut targets = vec[string]()
    targets.push("q_proj")
    targets.push("k_proj")
    targets.push("v_proj")
    targets.push("dense")
    config.target_modules = targets

    config
}

enum preset_type {
    lightweight,
    balanced,
    high_quality,
    text_classification,
    question_answering,
    machine_translation,
    code_generation,
    instruction_following,
    conversational,
}

func load_preset(preset: preset_type) lora_config {
    switch preset {
        preset_type::lightweight : preset_lightweight(),
        preset_type::balanced : preset_balanced(),
        preset_type::high_quality : preset_high_quality(),
        preset_type::text_classification : preset_text_classification(),
        preset_type::question_answering : preset_question_answering(),
        preset_type::machine_translation : preset_machine_translation(),
        preset_type::code_generation : preset_code_generation(),
        preset_type::instruction_following : preset_instruction_following(),
        preset_type::conversational : preset_conversational(),
    }
}

func load_preset_by_name(name: string) option[lora_config] {
    switch name {
        "lightweight" : option::some(preset_lightweight()),
        "balanced" : option::some(preset_balanced()),
        "high_quality" : option::some(preset_high_quality()),
        "text_classification" : option::some(preset_text_classification()),
        "question_answering" : option::some(preset_question_answering()),
        "machine_translation" : option::some(preset_machine_translation()),
        "code_generation" : option::some(preset_code_generation()),
        "instruction_following" : option::some(preset_instruction_following()),
        "conversational" : option::some(preset_conversational()),
        _ : option::none,
    }
}

func get_available_presets() vec[string] {
    let presets = vec[string]()
    presets.push("lightweight")
    presets.push("balanced")
    presets.push("high_quality")
    presets.push("text_classification")
    presets.push("question_answering")
    presets.push("machine_translation")
    presets.push("code_generation")
    presets.push("instruction_following")
    presets.push("conversational")
    presets
}

func get_preset_description(name: string) string {
    switch name {
        "lightweight" :
            "轻量级微调\n" +
            "  秩: 4, Alpha: 8.0\n" +
            "  场景: 最低显存占用，最快推理\n" +
            "  模块: q_proj, v_proj",
        "balanced" :
            "平衡配置\n" +
            "  秩: 16, Alpha: 32.0\n" +
            "  场景: 效果与速度的平衡\n" +
            "  模块: q_proj, k_proj, v_proj, dense",
        "high_quality" :
            "高质量微调\n" +
            "  秩: 64, Alpha: 128.0\n" +
            "  场景: 最优效果，较高推理开销\n" +
            "  模块: q_proj, k_proj, v_proj, dense, out_proj",
        "text_classification" :
            "文本分类\n" +
            "  秩: 8, 任务类型: SEQUENCE_CLASSIFICATION\n" +
            "  场景: 文本分类任务\n" +
            "  模块: q_proj, v_proj",
        "question_answering" :
            "问答任务\n" +
            "  秩: 16, 任务类型: QUESTION_ANSWERING\n" +
            "  场景: 机器阅读理解\n" +
            "  模块: q_proj, k_proj, v_proj, dense",
        "machine_translation" :
            "机器翻译\n" +
            "  秩: 32, Alpha: 64.0, 任务类型: TRANSLATION\n" +
            "  场景: 多语言翻译\n" +
            "  模块: q_proj, k_proj, v_proj, dense, attention",
        "code_generation" :
            "代码生成\n" +
            "  秩: 64, Alpha: 128.0, 任务类型: CAUSAL_LM\n" +
            "  场景: 编程语言模型\n" +
            "  模块: q_proj, v_proj, dense",
        "instruction_following" :
            "指令跟随\n" +
            "  秩: 16, Alpha: 32.0, 任务类型: CAUSAL_LM\n" +
            "  场景: 指令跟随和对齐\n" +
            "  模块: q_proj, v_proj",
        "conversational" :
            "对话模型\n" +
            "  秩: 32, Alpha: 64.0, 任务类型: CAUSAL_LM\n" +
            "  场景: 对话和聊天\n" +
            "  模块: q_proj, k_proj, v_proj, dense",
        _ : "未知预设",
    }
}

struct preset_performance {
    name: string
    rank: int
    estimated_memory_mb: int
    estimated_inference_overhead_percent: int
    recommended_batch_size: int
}

func get_performance_info(preset: preset_type) preset_performance {
    switch preset {
        preset_type::lightweight : preset_performance {
            name: "lightweight",
            rank: 4,
            estimated_memory_mb: 16,
            estimated_inference_overhead_percent: 1,
            recommended_batch_size: 128,
        },
        preset_type::balanced : preset_performance {
            name: "balanced",
            rank: 16,
            estimated_memory_mb: 64,
            estimated_inference_overhead_percent: 3,
            recommended_batch_size: 64,
        },
        preset_type::high_quality : preset_performance {
            name: "high_quality",
            rank: 64,
            estimated_memory_mb: 256,
            estimated_inference_overhead_percent: 12,
            recommended_batch_size: 32,
        },
        preset_type::text_classification : preset_performance {
            name: "text_classification",
            rank: 8,
            estimated_memory_mb: 32,
            estimated_inference_overhead_percent: 1,
            recommended_batch_size: 128,
        },
        preset_type::question_answering : preset_performance {
            name: "question_answering",
            rank: 16,
            estimated_memory_mb: 64,
            estimated_inference_overhead_percent: 3,
            recommended_batch_size: 64,
        },
        preset_type::machine_translation : preset_performance {
            name: "machine_translation",
            rank: 32,
            estimated_memory_mb: 128,
            estimated_inference_overhead_percent: 6,
            recommended_batch_size: 32,
        },
        preset_type::code_generation : preset_performance {
            name: "code_generation",
            rank: 64,
            estimated_memory_mb: 256,
            estimated_inference_overhead_percent: 12,
            recommended_batch_size: 16,
        },
        preset_type::instruction_following : preset_performance {
            name: "instruction_following",
            rank: 16,
            estimated_memory_mb: 64,
            estimated_inference_overhead_percent: 3,
            recommended_batch_size: 64,
        },
        preset_type::conversational : preset_performance {
            name: "conversational",
            rank: 32,
            estimated_memory_mb: 128,
            estimated_inference_overhead_percent: 6,
            recommended_batch_size: 32,
        },
    }
}

func demo_presets() {
    println("=== LoRA 预设配置演示 ===\n")

    let presets = get_available_presets()

    for preset_name in presets.iter() {
        println("配置名: " + preset_name)

        switch load_preset_by_name(preset_name) {
            option::some(config) : {
                println("  秩: " + config.lora_rank.to_string())
                println("  Alpha: " + config.lora_alpha.to_string())
                println("  缩放因子: " + config.get_lora_scaling().to_string())
                println("  模块数: " + config.target_modules.len().to_string())
                println("  描述: " + get_preset_description(preset_name))
            },
            option::none : {
                println("  (无法加载)")
            },
        }
        println()
    }
}
