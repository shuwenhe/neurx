package neurx.lora.examples.config_presets

use std.slices
use std.map.map
use neurx.lora.lora_config

func preset_lightweight() lora_config {
    config := default()
    config.lora_rank = 4
    config.lora_alpha = 8.0
    config.lora_dropout = 0.01
    config.bias = "none"

    targets := string[]()
    targets = append(targets, "q_proj")
    targets = append(targets, "v_proj")
    config.target_modules = targets

    config
}

func preset_balanced() lora_config {
    config := default()
    config.lora_rank = 16
    config.lora_alpha = 32.0
    config.lora_dropout = 0.05
    config.bias = "lora_only"

    targets := string[]()
    targets = append(targets, "q_proj")
    targets = append(targets, "k_proj")
    targets = append(targets, "v_proj")
    targets = append(targets, "dense")
    config.target_modules = targets

    config
}

func preset_high_quality() lora_config {
    config := default()
    config.lora_rank = 64
    config.lora_alpha = 128.0
    config.lora_dropout = 0.1
    config.bias = "all"

    targets := string[]()
    targets = append(targets, "q_proj")
    targets = append(targets, "k_proj")
    targets = append(targets, "v_proj")
    targets = append(targets, "dense")
    targets = append(targets, "out_proj")
    config.target_modules = targets

    config
}

func preset_text_classification() lora_config {
    config := preset_balanced()
    config.task_type = "SEQUENCE_CLASSIFICATION"
    config.lora_rank = 8

    targets := string[]()
    targets = append(targets, "q_proj")
    targets = append(targets, "v_proj")
    config.target_modules = targets

    config
}

func preset_question_answering() lora_config {
    config := preset_balanced()
    config.task_type = "QUESTION_ANSWERING"
    config.lora_rank = 16

    targets := string[]()
    targets = append(targets, "q_proj")
    targets = append(targets, "k_proj")
    targets = append(targets, "v_proj")
    targets = append(targets, "dense")
    config.target_modules = targets

    config
}

func preset_machine_translation() lora_config {
    config := preset_high_quality()
    config.task_type = "TRANSLATION"
    config.lora_rank = 32
    config.lora_alpha = 64.0

    targets := string[]()
    targets = append(targets, "q_proj")
    targets = append(targets, "k_proj")
    targets = append(targets, "v_proj")
    targets = append(targets, "dense")
    targets = append(targets, "attention")
    config.target_modules = targets

    config
}

func preset_code_generation() lora_config {
    config := preset_high_quality()
    config.task_type = "CAUSAL_LM"
    config.lora_rank = 64
    config.lora_alpha = 128.0

    targets := string[]()
    targets = append(targets, "q_proj")
    targets = append(targets, "v_proj")
    targets = append(targets, "dense")
    config.target_modules = targets

    config
}

func preset_instruction_following() lora_config {
    config := preset_balanced()
    config.task_type = "CAUSAL_LM"
    config.lora_rank = 16
    config.lora_alpha = 32.0

    targets := string[]()
    targets = append(targets, "q_proj")
    targets = append(targets, "v_proj")
    config.target_modules = targets

    config
}

func preset_conversational() lora_config {
    config := preset_balanced()
    config.task_type = "CAUSAL_LM"
    config.lora_rank = 32
    config.lora_alpha = 64.0

    targets := string[]()
    targets = append(targets, "q_proj")
    targets = append(targets, "k_proj")
    targets = append(targets, "v_proj")
    targets = append(targets, "dense")
    config.target_modules = targets

    config
}


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

func load_preset(preset_type preset) lora_config {
    switch preset {
        preset_type_lightweight : preset_lightweight(),
        preset_type_balanced : preset_balanced(),
        preset_type_high_quality : preset_high_quality(),
        preset_type_text_classification : preset_text_classification(),
        preset_type_question_answering : preset_question_answering(),
        preset_type_machine_translation : preset_machine_translation(),
        preset_type_code_generation : preset_code_generation(),
        preset_type_instruction_following : preset_instruction_following(),
        preset_type_conversational : preset_conversational(),
    }
}

func load_preset_by_name(string name) option[lora_config] {
    switch name {
        "lightweight" : some(preset_lightweight()),
        "balanced" : some(preset_balanced()),
        "high_quality" : some(preset_high_quality()),
        "text_classification" : some(preset_text_classification()),
        "question_answering" : some(preset_question_answering()),
        "machine_translation" : some(preset_machine_translation()),
        "code_generation" : some(preset_code_generation()),
        "instruction_following" : some(preset_instruction_following()),
        "conversational" : some(preset_conversational()),
        _ : nil,
    }
}

func get_available_presets() string[] {
    presets := string[]()
    presets = append(presets, "lightweight")
    presets = append(presets, "balanced")
    presets = append(presets, "high_quality")
    presets = append(presets, "text_classification")
    presets = append(presets, "question_answering")
    presets = append(presets, "machine_translation")
    presets = append(presets, "code_generation")
    presets = append(presets, "instruction_following")
    presets = append(presets, "conversational")
    presets
}

func get_preset_description(string name) string {
    switch name {
        "lightweight" :
            "lightweight微调\n" +
            "  rank: 4, Alpha: 8.0\n" +
            "  scenario: 最lowGPU Memory占use，最fastinference\n" +
            "  module: q_proj, v_proj",
        "balanced" :
            "平衡configuration\n" +
            "  rank: 16, Alpha: 32.0\n" +
            "  scenario: 效果与速度of平衡\n" +
            "  module: q_proj, k_proj, v_proj, dense",
        "high_quality" :
            "high质量微调\n" +
            "  rank: 64, Alpha: 128.0\n" +
            "  scenario: 最优效果，较highinference开销\n" +
            "  module: q_proj, k_proj, v_proj, dense, out_proj",
        "text_classification" :
            "文本分class\n" +
            "  rank: 8, task type: SEQUENCE_CLASSIFICATION\n" +
            "  scenario: 文本分class任务\n" +
            "  module: q_proj, v_proj",
        "question_answering" :
            "问答任务\n" +
            "  rank: 16, task type: QUESTION_ANSWERING\n" +
            "  scenario: 机器阅读manage解\n" +
            "  module: q_proj, k_proj, v_proj, dense",
        "machine_translation" :
            "机器翻译\n" +
            "  rank: 32, Alpha: 64.0, task type: TRANSLATION\n" +
            "  scenario: morelanguage翻译\n" +
            "  module: q_proj, k_proj, v_proj, dense, attention",
        "code_generation" :
            "代码generate\n" +
            "  rank: 64, Alpha: 128.0, task type: CAUSAL_LM\n" +
            "  scenario: 编程languagemodel\n" +
            "  module: q_proj, v_proj, dense",
        "instruction_following" :
            "指令跟随\n" +
            "  rank: 16, Alpha: 32.0, task type: CAUSAL_LM\n" +
            "  scenario: 指令跟随andpair齐\n" +
            "  module: q_proj, v_proj",
        "conversational" :
            "pair话model\n" +
            "  rank: 32, Alpha: 64.0, task type: CAUSAL_LM\n" +
            "  scenario: pair话and聊天\n" +
            "  module: q_proj, k_proj, v_proj, dense",
        _ : "未知预设",
    }
}

struct preset_performance {
    string name
    int rank
    int estimated_memory_mb
    int estimated_inference_overhead_percent
    int recommended_batch_size
}

func get_performance_info(preset_type preset) preset_performance {
    switch preset {
        preset_type_lightweight : preset_performance {
            name: "lightweight",
            rank: 4,
            estimated_memory_mb: 16,
            estimated_inference_overhead_percent: 1,
            recommended_batch_size: 128,
        },
        preset_type_balanced : preset_performance {
            name: "balanced",
            rank: 16,
            estimated_memory_mb: 64,
            estimated_inference_overhead_percent: 3,
            recommended_batch_size: 64,
        },
        preset_type_high_quality : preset_performance {
            name: "high_quality",
            rank: 64,
            estimated_memory_mb: 256,
            estimated_inference_overhead_percent: 12,
            recommended_batch_size: 32,
        },
        preset_type_text_classification : preset_performance {
            name: "text_classification",
            rank: 8,
            estimated_memory_mb: 32,
            estimated_inference_overhead_percent: 1,
            recommended_batch_size: 128,
        },
        preset_type_question_answering : preset_performance {
            name: "question_answering",
            rank: 16,
            estimated_memory_mb: 64,
            estimated_inference_overhead_percent: 3,
            recommended_batch_size: 64,
        },
        preset_type_machine_translation : preset_performance {
            name: "machine_translation",
            rank: 32,
            estimated_memory_mb: 128,
            estimated_inference_overhead_percent: 6,
            recommended_batch_size: 32,
        },
        preset_type_code_generation : preset_performance {
            name: "code_generation",
            rank: 64,
            estimated_memory_mb: 256,
            estimated_inference_overhead_percent: 12,
            recommended_batch_size: 16,
        },
        preset_type_instruction_following : preset_performance {
            name: "instruction_following",
            rank: 16,
            estimated_memory_mb: 64,
            estimated_inference_overhead_percent: 3,
            recommended_batch_size: 64,
        },
        preset_type_conversational : preset_performance {
            name: "conversational",
            rank: 32,
            estimated_memory_mb: 128,
            estimated_inference_overhead_percent: 6,
            recommended_batch_size: 32,
        },
    }
}

func demo_presets() {
    println("=== LoRA 预设configuration演示 ===\n")

    presets := get_available_presets()

    for preset_name in presets.iter() {
        println("configuration名: " + preset_name)

        switch load_preset_by_name(preset_name) {
            some(config) : {
                println("  rank: " + config.lora_rank.to_string())
                println("  Alpha: " + config.lora_alpha.to_string())
                println("  缩放because子: " + config.get_lora_scaling().to_string())
                println("  module数: " + len(config.target_modules).to_string())
                println("  描述: " + get_preset_description(preset_name))
            },
            nil : {
                println("  (无法加载)")
            },
        }
        println()
    }
}
