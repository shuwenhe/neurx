package neurx.train.industrial_readiness

// ============================================================================
// Industrial GPT Readiness Checker
//
// 训练工业级 GPT 不只是模型代码齐全，还需要配置、数据、分布式、对齐、推理
// 和运维门禁同时达标。本模块把这些条件变成可执行检查，训练前即可知道
// 当前配置缺什么、哪些缺口必须依赖外部资源补齐。
// ============================================================================

use neurx.model.llm.gpt.{gpt_config, gpt_param_count}
use neurx.train.industrial_gpt_stack.{industrial_gpt_stack_config}

struct industrial_readiness_input {
    gpt_config arch
    industrial_gpt_stack_config stack
    int available_gpus
    int pretrain_tokens_b
    int sft_tokens_b
    int preference_pairs_m
    int reasoning_tokens_b
    bool has_real_corpus
    bool has_tokenizer_artifact
    bool has_checkpoint_resume
    bool has_nccl_runtime
    bool has_benchmark_suite
    bool has_serving_runtime
    bool has_safety_eval
}

struct readiness_item {
    string name
    bool passed
    string severity       // "critical" | "high" | "medium" | "low"
    string message
}

struct readiness_report {
    []readiness_item items
    int passed
    int failed
    int critical_failed
    float readiness_score
    bool can_start_pretrain
    bool can_start_sft
    bool can_start_alignment
    bool can_serve_production
}

func evaluate_industrial_readiness(industrial_readiness_input input) readiness_report {
    []readiness_item items = []

    int params = gpt_param_count(input.arch)
    int params_b = params / 1000000000
    int optimal_tokens_b = params_b * 20
    if optimal_tokens_b < 100 { optimal_tokens_b = 100 }

    items = append(items, check_item(
        "architecture_scale",
        params_b >= 7,
        "high",
        "工业 GPT 至少建议 7B 参数；小模型只适合作 smoke test 或蒸馏草稿模型。"
    ))

    items = append(items, check_item(
        "real_corpus",
        input.has_real_corpus,
        "critical",
        "缺真实高质量语料。需要 CommonCrawl/书籍/代码/数学/多语数据，并经过去重、质量过滤和版权合规筛选。"
    ))

    items = append(items, check_item(
        "token_budget",
        input.pretrain_tokens_b >= optimal_tokens_b,
        "critical",
        "预训练 token 不足。Chinchilla 下限约为参数量的 20 倍，工业模型通常需要更高 token 预算。"
    ))

    items = append(items, check_item(
        "tokenizer_artifact",
        input.has_tokenizer_artifact,
        "critical",
        "缺 tokenizer artifact。需要固定 vocab/merges/special tokens，并与训练、SFT、推理完全一致。"
    ))

    items = append(items, check_item(
        "distributed_runtime",
        input.has_nccl_runtime && input.available_gpus > 0,
        "critical",
        "缺可用分布式运行时。需要 NCCL/多机网络/GPU 拓扑检查，以及失败恢复策略。"
    ))

    items = append(items, check_item(
        "flash_attention",
        input.stack.enable_flash_attention,
        "high",
        "缺 Flash Attention。长上下文训练会被 O(N^2) 显存/带宽瓶颈卡住。"
    ))

    items = append(items, check_item(
        "long_context_rope",
        input.stack.target_context_len <= 8192 || input.stack.enable_yarn_rope,
        "high",
        "长上下文模型需要 RoPE scaling，例如 YaRN/NTK-by-Parts，否则外推质量下降。"
    ))

    items = append(items, check_item(
        "checkpoint_resume",
        input.has_checkpoint_resume,
        "critical",
        "缺可恢复 checkpoint。多日/多周训练必须能断点续训，并保存模型、优化器、调度器和数据游标。"
    ))

    items = append(items, check_item(
        "sft_data",
        input.sft_tokens_b >= 1,
        "high",
        "缺 SFT 指令数据。需要高质量多轮对话、工具调用、拒答、安全样本和 loss mask。"
    ))

    items = append(items, check_item(
        "preference_data",
        input.preference_pairs_m >= 1,
        "high",
        "缺偏好数据。DPO/RLHF/GRPO 至少需要百万级 chosen/rejected 或可验证奖励数据。"
    ))

    items = append(items, check_item(
        "grpo_reasoning",
        input.stack.enable_grpo && input.reasoning_tokens_b >= 1,
        "medium",
        "推理能力需要 GRPO/可验证奖励/数学代码课程，否则只能做普通 CoT 蒸馏。"
    ))

    items = append(items, check_item(
        "benchmarks",
        input.has_benchmark_suite,
        "high",
        "缺标准评测门禁。至少需要 MMLU/GSM8K/HumanEval/TruthfulQA/MT-Bench 和回归评测。"
    ))

    items = append(items, check_item(
        "safety_eval",
        input.has_safety_eval,
        "high",
        "缺安全评测。上线前需要越狱、偏见、隐私泄漏、幻觉和危险能力评测。"
    ))

    items = append(items, check_item(
        "serving_runtime",
        input.has_serving_runtime && input.stack.enable_speculative_decoding,
        "medium",
        "缺生产推理路径。需要 paged KV、continuous batching、投机解码、限流和指标监控。"
    ))

    int passed = 0
    int failed = 0
    int critical_failed = 0
    int i = 0
    for i < len(items) {
        if items[i].passed {
            passed = passed + 1
        } else {
            failed = failed + 1
            if items[i].severity == "critical" {
                critical_failed = critical_failed + 1
            }
        }
        i = i + 1
    }

    float score = 0.0
    int total = passed + failed
    if total > 0 {
        score = float_ready(passed) / float_ready(total)
    }

    readiness_report {
        items: items,
        passed: passed,
        failed: failed,
        critical_failed: critical_failed,
        readiness_score: score,
        can_start_pretrain: critical_failed == 0 && input.has_real_corpus && input.has_nccl_runtime,
        can_start_sft: input.has_tokenizer_artifact && input.sft_tokens_b >= 1,
        can_start_alignment: input.preference_pairs_m >= 1 && input.stack.enable_grpo,
        can_serve_production: input.has_serving_runtime && input.has_safety_eval && input.has_benchmark_suite,
    }
}

func check_item(string name, bool passed, string severity, string message) readiness_item {
    readiness_item {
        name: name,
        passed: passed,
        severity: severity,
        message: message,
    }
}

func readiness_summary(readiness_report report) string {
    string s = ""
    s = s + "工业 GPT readiness: " + int_to_ready_s(float_to_ready_int(report.readiness_score * 100.0)) + "%\n"
    s = s + "passed=" + int_to_ready_s(report.passed) + " failed=" + int_to_ready_s(report.failed)
    s = s + " critical_failed=" + int_to_ready_s(report.critical_failed) + "\n"
    if report.can_start_pretrain {
        s = s + "pretrain: ready\n"
    } else {
        s = s + "pretrain: blocked\n"
    }
    if report.can_start_alignment {
        s = s + "alignment: ready\n"
    } else {
        s = s + "alignment: blocked\n"
    }
    if report.can_serve_production {
        s = s + "serving: ready\n"
    } else {
        s = s + "serving: blocked\n"
    }
    s
}

func float_ready(int n) float {
    float v = 0.0
    int i = 0
    for i < n {
        v = v + 1.0
        i = i + 1
    }
    v
}

func float_to_ready_int(float x) int {
    int n = 0
    float v = x
    while v >= 1.0 {
        n = n + 1
        v = v - 1.0
    }
    n
}

func int_to_ready_s(int n) string {
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
