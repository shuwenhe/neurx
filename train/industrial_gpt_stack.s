package neurx.train.industrial_gpt_stack

// ============================================================================
// Industrial GPT Stack Planner
//
// 将工业级 GPT 训练/推理必需能力统一成一个可审计的 stack plan，避免
// FlashAttention、RoPE 扩展、QLoRA、GRPO、Chat Template、投机解码等模块
// 只存在于代码库但未进入训练配方。
// ============================================================================

use neurx.model.llm.gpt.{gpt_config, gpt_param_count}
use neurx.model.transformer.flash_attention.{flash_attn_config, new_flash_attn_config}
use neurx.model.transformer.rope_scaling.{rope_config, yarn_rope_config, llama3_rope_config}
use neurx.model.lora.{lora_config, default_lora_config, qlora_config_7b}
use neurx.posttrain.grpo.{grpo_config, deepseek_r1_grpo_config}
use neurx.serving.speculative_decoding.{spec_decode_config, default_spec_decode_config}
use neurx.model.tokenizer.chat_template.{template_config, chatml_config, llama3_config, deepseek_r1_config}

struct industrial_gpt_stack_config {
    bool enable_flash_attention
    bool enable_yarn_rope
    bool enable_qlora
    bool enable_grpo
    bool enable_chat_template
    bool enable_speculative_decoding

    flash_attn_config flash_attention
    rope_config rope
    lora_config lora
    grpo_config grpo
    spec_decode_config speculative
    template_config chat_template

    int target_context_len
    int trainable_adapter_rank
    string alignment_method
    string serving_acceleration
    string precision_policy
}

func build_industrial_gpt_stack(gpt_config arch, bool flash_attention_enabled) industrial_gpt_stack_config {
    int params = gpt_param_count(arch)
    int params_b = params / 1000000000
    int head_dim = arch.n_embd / arch.n_head

    bool large_enough_for_qlora = params_b >= 7
    bool long_context = arch.block_size > 8192

    rope_config rope_cfg = llama3_rope_config(head_dim, arch.block_size)
    if long_context {
        rope_cfg = yarn_rope_config(head_dim, 8192, arch.block_size)
    }

    lora_config lora_cfg = default_lora_config()
    if large_enough_for_qlora {
        lora_cfg = qlora_config_7b()
    }

    template_config chat_cfg = chatml_config()
    if arch.vocab_size >= 128000 {
        chat_cfg = llama3_config()
    }

    industrial_gpt_stack_config {
        enable_flash_attention: flash_attention_enabled,
        enable_yarn_rope: long_context,
        enable_qlora: large_enough_for_qlora,
        enable_grpo: true,
        enable_chat_template: true,
        enable_speculative_decoding: true,

        flash_attention: new_flash_attn_config(head_dim, arch.n_head, arch.n_kv_head, true),
        rope: rope_cfg,
        lora: lora_cfg,
        grpo: deepseek_r1_grpo_config(),
        speculative: default_spec_decode_config(arch.vocab_size),
        chat_template: chat_cfg,

        target_context_len: arch.block_size,
        trainable_adapter_rank: lora_cfg.rank,
        alignment_method: "DPO + GRPO + Constitutional AI",
        serving_acceleration: "Paged KV + continuous batching + speculative decoding",
        precision_policy: "bf16 train + fp8/int8 serving + NF4 QLoRA adapters",
    }
}

func industrial_stack_summary(industrial_gpt_stack_config stack) string {
    string s = ""
    s = s + "║ 工业能力栈:\n"
    if stack.enable_flash_attention {
        s = s + "║   ✓ Flash Attention 2: tiled causal/GQA attention\n"
    } else {
        s = s + "║   - Flash Attention 2: disabled for tiny smoke config\n"
    }
    if stack.enable_yarn_rope {
        s = s + "║   ✓ YaRN RoPE: long-context scaling enabled\n"
    } else {
        s = s + "║   ✓ RoPE: LLaMA-style NTK scaling\n"
    }
    if stack.enable_qlora {
        s = s + "║   ✓ QLoRA: NF4 frozen-base adapters rank=" + int_to_stack_s(stack.trainable_adapter_rank) + "\n"
    } else {
        s = s + "║   ✓ LoRA: adapter fine-tuning available\n"
    }
    if stack.enable_grpo {
        s = s + "║   ✓ GRPO: group-relative reasoning RL\n"
    }
    if stack.enable_chat_template {
        s = s + "║   ✓ Chat Template: training/inference message formatting\n"
    }
    if stack.enable_speculative_decoding {
        s = s + "║   ✓ Speculative Decoding: draft/verify serving path\n"
    }
    s = s + "║   对齐: " + stack.alignment_method + "\n"
    s = s + "║   推理: " + stack.serving_acceleration + "\n"
    s = s + "║   精度: " + stack.precision_policy + "\n"
    s
}

func int_to_stack_s(int n) string {
    if n == 0 { return "0" }
    bool neg = n < 0
    int val = n
    if neg { val = -val }
    string s = ""
    while val > 0 {
        int d = val - (val / 10) * 10
        s = string(d + 48) + s
        val = val / 10
    }
    if neg { s = "-" + s }
    s
}
