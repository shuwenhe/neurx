package neurx.alignment.constitutional_ai

// ============================================================================
// Constitutional AI (CAI) — RLAIF self-critique & revision loop
//
// NeurX-style alignment technique. Instead of relying solely on human
// preference labels, the model critiques and revises its own responses against
// a set of written principles ("a constitution"), then learns from the
// (revised ≻ original) preference pairs (RLAIF — RL from AI Feedback).
//
// Pipeline:
//   1. Generate an initial response to a (potentially harmful) prompt.
//   2. Self-critique: ask the model to identify how the response violates a
//      principle.
//   3. Revise: ask the model to rewrite the response to comply.
//   4. Emit preference pair: revised (chosen) ≻ original (rejected).
//   5. These pairs train the reward model / DPO — no human labels required.
//
// This module operates on the concrete language_model via its generation API and
// produces preference pairs consumable by posttrain.reward.reward_model.
// ============================================================================

use neurx.model.llm.gpt.{
    model_config, language_model,
    gpt_generate_greedy, gpt_generate_topk
}

// ============================================================================
// 1. Constitution (principles)
// ============================================================================

struct constitutional_principle {
    string id
    string critique_request    // 引导模型批判的提示
    string revision_request    // 引导模型修订的提示
    int severity               // 1-5, 违规严重度权重
}

struct constitution {
    []constitutional_principle principles
    int num_principles
}

// Anthropic 风格的核心原则集 (helpful, harmless, honest)
func default_constitution() constitution {
    []constitutional_principle ps = []constitutional_principle{cap: 8}

    ps[0] = constitutional_principle {
        id: "harmlessness",
        critique_request: "找出回复中可能有害、危险或不道德的内容。",
        revision_request: "重写回复，移除有害内容，同时尽量保持有用。",
        severity: 5,
    }
    ps[1] = constitutional_principle {
        id: "honesty",
        critique_request: "指出回复中不真实、误导或编造的部分。",
        revision_request: "重写回复，确保事实准确，对不确定处明确说明。",
        severity: 4,
    }
    ps[2] = constitutional_principle {
        id: "helpfulness",
        critique_request: "找出回复中回避问题或无帮助之处。",
        revision_request: "重写回复，使其更直接、更有帮助地回应用户需求。",
        severity: 3,
    }
    ps[3] = constitutional_principle {
        id: "non_discrimination",
        critique_request: "找出回复中带有偏见、歧视或刻板印象的内容。",
        revision_request: "重写回复，使其公平、包容、无偏见。",
        severity: 5,
    }
    ps[4] = constitutional_principle {
        id: "privacy",
        critique_request: "找出回复中泄露隐私或鼓励侵犯隐私的内容。",
        revision_request: "重写回复，保护隐私，不泄露个人信息。",
        severity: 4,
    }
    ps[5] = constitutional_principle {
        id: "no_illegal_advice",
        critique_request: "找出回复中提供违法行为指导的内容。",
        revision_request: "重写回复，拒绝提供违法指导并解释原因。",
        severity: 5,
    }
    ps[6] = constitutional_principle {
        id: "child_safety",
        critique_request: "找出回复中危害未成年人安全的内容。",
        revision_request: "重写回复，确保完全符合未成年人保护标准。",
        severity: 5,
    }
    ps[7] = constitutional_principle {
        id: "transparency",
        critique_request: "找出回复中假装为人类或隐瞒 AI 身份的内容。",
        revision_request: "重写回复，必要时清晰表明 AI 身份。",
        severity: 2,
    }

    constitution { principles: ps, num_principles: 8 }
}

// ============================================================================
// 2. 偏好对输出
// ============================================================================

// 一条 CAI 生成的偏好样本
struct cai_preference_pair {
    []int prompt_tokens        // 原始提示
    []int chosen_tokens        // 修订后回复 (更优)
    []int rejected_tokens      // 原始回复 (较差)
    string principle_id        // 触发修订的原则
    int severity
    float critique_strength    // 批判信号强度 (0-1)
}

struct cai_batch {
    []cai_preference_pair pairs
    int num_pairs
    int num_revised            // 实际被修订的数量
}

// ============================================================================
// 3. 控制 token (在真实系统中由 tokenizer 提供; 此处用保留 ID)
// ============================================================================

// 这些是 CAI 模板的"角色"分隔 token。生产环境中由分词器的特殊 token 给出。
func cai_token_prompt_start() int { 50001 }
func cai_token_response_start() int { 50002 }
func cai_token_critique_start() int { 50003 }
func cai_token_revision_start() int { 50004 }
func cai_token_principle_base() int { 50100 }   // + principle index

// 把若干 token 段拼接
func cai_concat([]int a, []int b) []int {
    int n = len(a) + len(b)
    []int out = []int{cap: n}
    int i = 0
    while i < len(a) { out[i] = a[i]; i = i + 1 }
    int j = 0
    while j < len(b) { out[len(a) + j] = b[j]; j = j + 1 }
    out
}

func cai_single(int tok) []int {
    []int out = []int{cap: 1}
    out[0] = tok
    out
}

// ============================================================================
// 4. 单条 CAI 循环: 生成 → 批判 → 修订
// ============================================================================

// 对单个提示执行完整 critique-revise 循环
func cai_critique_revise(
    language_model model,
    []int prompt_tokens,
    constitutional_principle principle,
    int principle_index,
    int max_response_tokens,
    int seed
) cai_preference_pair {
    // 1. 初始回复: prompt → response
    []int gen_input = cai_concat(prompt_tokens, cai_single(cai_token_response_start()))
    []int original_response = gpt_generate_topk(model, gen_input, max_response_tokens, 50, 0.8, seed)

    // 2. 自我批判: [prompt][response][critique_marker][principle] → critique
    []int critique_context = cai_concat(prompt_tokens, original_response)
    critique_context = cai_concat(critique_context, cai_single(cai_token_critique_start()))
    critique_context = cai_concat(critique_context, cai_single(cai_token_principle_base() + principle_index))
    []int critique = gpt_generate_topk(model, critique_context, max_response_tokens / 2, 40, 0.7, seed + 1)

    // 3. 修订: [prompt][response][critique][revision_marker] → revised response
    []int revision_context = cai_concat(critique_context, critique)
    revision_context = cai_concat(revision_context, cai_single(cai_token_revision_start()))
    []int revised_response = gpt_generate_topk(model, revision_context, max_response_tokens, 50, 0.7, seed + 2)

    // 4. 批判强度: 用批判长度归一估计 (越长批判通常表示越多问题)
    float critique_strength = cai_estimate_critique_strength(critique, max_response_tokens / 2)

    cai_preference_pair {
        prompt_tokens: prompt_tokens,
        chosen_tokens: revised_response,
        rejected_tokens: original_response,
        principle_id: principle.id,
        severity: principle.severity,
        critique_strength: critique_strength,
    }
}

// 批判强度估计 (0=无问题, 1=严重问题)
func cai_estimate_critique_strength([]int critique, int max_len) float {
    if max_len <= 0 {
        return 0.0
    }
    float ratio = (len(critique) * 1.0) / (max_len * 1.0)
    if ratio > 1.0 {
        ratio = 1.0
    }
    ratio
}

// ============================================================================
// 5. 批量 CAI: 对一组提示生成偏好数据
// ============================================================================

func cai_generate_preferences(
    language_model model,
    [][]int prompts,
    constitution consti,
    int max_response_tokens,
    int base_seed
) cai_batch {
    int n = len(prompts)
    []cai_preference_pair pairs = []cai_preference_pair{cap: n}
    int num_revised = 0

    int i = 0
    while i < n {
        // 轮转选择原则 (生产环境可按内容分类选择最相关原则)
        int pidx = i - (i / consti.num_principles) * consti.num_principles
        constitutional_principle principle = consti.principles[pidx]

        cai_preference_pair pair = cai_critique_revise(
            model,
            prompts[i],
            principle,
            pidx,
            max_response_tokens,
            base_seed + i * 7
        )
        pairs[i] = pair

        // 若批判强度超过阈值，记为"已修订"
        if pair.critique_strength > 0.15 {
            num_revised = num_revised + 1
        }

        i = i + 1
    }

    cai_batch {
        pairs: pairs,
        num_pairs: n,
        num_revised: num_revised,
    }
}

// ============================================================================
// 6. 转换为奖励模型可用的扁平偏好批次
//
//   把 cai_preference_pair 的 chosen/rejected 拼成定长 token 序列
//   (prompt + response，padding/truncate 到 seq_len)，供 reward_model 训练。
// ============================================================================

struct cai_flat_batch {
    []int chosen_ids           // [batch * seq_len]
    []int rejected_ids         // [batch * seq_len]
    int batch_size
    int seq_len
}

func cai_pad_sequence([]int prompt, []int response, int seq_len, int pad_id) []int {
    []int seq = []int{cap: seq_len}
    int idx = 0
    // prompt
    int i = 0
    while i < len(prompt) && idx < seq_len {
        seq[idx] = prompt[i]
        idx = idx + 1
        i = i + 1
    }
    // response
    int j = 0
    while j < len(response) && idx < seq_len {
        seq[idx] = response[j]
        idx = idx + 1
        j = j + 1
    }
    // padding
    while idx < seq_len {
        seq[idx] = pad_id
        idx = idx + 1
    }
    seq
}

func cai_to_flat_batch(cai_batch batch, int seq_len, int pad_id) cai_flat_batch {
    int n = batch.num_pairs
    []int chosen_ids = []int{cap: n * seq_len}
    []int rejected_ids = []int{cap: n * seq_len}

    int b = 0
    while b < n {
        cai_preference_pair pair = batch.pairs[b]
        []int chosen_seq = cai_pad_sequence(pair.prompt_tokens, pair.chosen_tokens, seq_len, pad_id)
        []int rejected_seq = cai_pad_sequence(pair.prompt_tokens, pair.rejected_tokens, seq_len, pad_id)

        int t = 0
        while t < seq_len {
            chosen_ids[b * seq_len + t] = chosen_seq[t]
            rejected_ids[b * seq_len + t] = rejected_seq[t]
            t = t + 1
        }
        b = b + 1
    }

    cai_flat_batch {
        chosen_ids: chosen_ids,
        rejected_ids: rejected_ids,
        batch_size: n,
        seq_len: seq_len,
    }
}

// ============================================================================
// 7. CAI 统计 / 报告
// ============================================================================

struct cai_stats {
    int total_prompts
    int revised_count
    float revision_rate
    float avg_critique_strength
    float weighted_severity      // 按 severity 加权的批判强度
}

func cai_compute_stats(cai_batch batch) cai_stats {
    int n = batch.num_pairs
    if n == 0 {
        return cai_stats {
            total_prompts: 0,
            revised_count: 0,
            revision_rate: 0.0,
            avg_critique_strength: 0.0,
            weighted_severity: 0.0,
        }
    }

    float sum_strength = 0.0
    float sum_weighted = 0.0
    int i = 0
    while i < n {
        cai_preference_pair pair = batch.pairs[i]
        sum_strength = sum_strength + pair.critique_strength
        sum_weighted = sum_weighted + pair.critique_strength * (pair.severity * 1.0)
        i = i + 1
    }

    cai_stats {
        total_prompts: n,
        revised_count: batch.num_revised,
        revision_rate: (batch.num_revised * 1.0) / (n * 1.0),
        avg_critique_strength: sum_strength / (n * 1.0),
        weighted_severity: sum_weighted / (n * 1.0),
    }
}
