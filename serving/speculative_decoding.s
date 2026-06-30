package neurx.serving.speculative_decoding

// ============================================================================
// Speculative Decoding — 投机解码
//
// 论文: "Fast Inference from Transformers via Speculative Decoding"
//        (Leviathan et al., 2023)
//        "SpecInfer: Accelerating LLM Serving..." (Miao et al., 2023)
//
// 核心思想:
//   用一个小草稿模型 (draft model, ~7B) 快速生成 γ 个 token 候选，
//   再用大目标模型 (target model, ~70B) 并行验证，拒绝不符合目标分布的 token。
//   由于验证可并行而串行生成不能，整体吞吐量提升 2-3×，且输出分布与只用大模型完全相同。
//
// 算法 (标准投机解码):
//   1. 草稿模型自回归生成 γ 个 token: x_{t+1},...,x_{t+γ}
//   2. 目标模型一次前向计算 q(x|prefix+drafts)
//   3. 对每个草稿 token xᵢ:
//      接受概率 α_i = min(1, q(xᵢ|ctx) / p(xᵢ|ctx))
//      以概率 αᵢ 接受，否则从 (q - p)₊ 的归一化分布采样新 token 并停止
//   4. 若全部接受，从目标模型采样第 γ+1 个 token
//
// 变体:
//   • 自投机解码 (Self-speculative): 跳层作为草稿模型
//   • Medusa: 多头并行预测
//   • EAGLE: 特征级草稿
// ============================================================================

// ============================================================================
// 1. 配置
// ============================================================================

struct spec_decode_config {
    int gamma              // 草稿步数 (通常 3-8)
    float acceptance_threshold  // 接受阈值 (0.0 = 原始算法, >0 = 宽松)
    int vocab_size         // 词表大小
    bool use_top_p         // 是否用 nucleus 采样
    float top_p            // nucleus 采样参数
    float temperature      // 采样温度
    int max_seq_len        // 最大序列长度
    string draft_type      // "separate" | "self" | "medusa"
    int medusa_heads       // Medusa 头数 (draft_type="medusa")
    int self_skip_layers   // 自投机跳过的层数
}

func default_spec_decode_config(int vocab_size) spec_decode_config {
    spec_decode_config {
        gamma: 5,
        acceptance_threshold: 0.0,
        vocab_size: vocab_size,
        use_top_p: true,
        top_p: 0.95,
        temperature: 0.8,
        max_seq_len: 4096,
        draft_type: "separate",
        medusa_heads: 4,
        self_skip_layers: 16,
    }
}

// ============================================================================
// 2. 概率分布操作
// ============================================================================

// softmax (数值稳定)
func spec_softmax([]float logits, int V) []float {
    float m = logits[0]
    int i = 0
    for i < V {
        if logits[i] > m { m = logits[i] }
        i = i + 1
    }

    []float probs = []
    float sum = 0.0
    int j = 0
    for j < V {
        float e = spec_exp(logits[j] - m)
        probs = append(probs, e)
        sum = sum + e
        j = j + 1
    }

    if sum < 1e-10 { sum = 1.0 }
    int k = 0
    for k < V {
        probs[k] = probs[k] / sum
        k = k + 1
    }
    probs
}

// 带温度的 softmax
func spec_softmax_temp([]float logits, int V, float temp) []float {
    []float scaled = []
    int i = 0
    for i < V {
        scaled = append(scaled, logits[i] / temp)
        i = i + 1
    }
    spec_softmax(scaled, V)
}

// nucleus (top-p) 采样
func spec_top_p_sample([]float probs, int V, float top_p, int seed) int {
    // 找到 top-p 截断点
    // 简化: 贪心选最高概率 token (seed 预留随机接口)
    int best = 0
    float best_p = probs[0]
    int i = 1
    for i < V {
        if probs[i] > best_p {
            best_p = probs[i]
            best = i
        }
        i = i + 1
    }
    best
}

// 截断差分采样: 从 max(0, q - p) / Z 采样
func spec_residual_sample([]float q, []float p, int V, int seed) int {
    []float diff = []
    float sum = 0.0
    int i = 0
    for i < V {
        float d = q[i] - p[i]
        if d < 0.0 { d = 0.0 }
        diff = append(diff, d)
        sum = sum + d
        i = i + 1
    }

    // 从 diff / sum 采样
    if sum < 1e-10 {
        // 退回 argmax(q)
        return spec_top_p_sample(q, V, 1.0, seed)
    }

    // 随机均匀采样 (简化: 取 sum/2 处的分位点)
    float threshold = sum * 0.5
    float cumsum = 0.0
    int j = 0
    for j < V {
        cumsum = cumsum + diff[j]
        if cumsum >= threshold {
            return j
        }
        j = j + 1
    }
    V - 1
}

// ============================================================================
// 3. 投机解码核心算法
// ============================================================================

struct spec_draft_output {
    []int   token_ids      // [gamma] 草稿 token
    []float log_probs      // [gamma] 草稿 log p(xᵢ|ctx)
    [][]float all_probs    // [gamma][vocab] 草稿完整分布
}

struct spec_verify_result {
    []int accepted_tokens  // 最终接受的 token 序列 (包括最终 target token)
    int   num_accepted      // 接受了几个草稿 token
    float acceptance_rate  // 接受率 num_accepted / gamma
    bool  all_accepted      // 全部接受
}

// 接受/拒绝一步
func spec_accept_reject(
    float q_prob,   // 目标模型 q(xᵢ|ctx)
    float p_prob,   // 草稿模型 p(xᵢ|ctx)
    int   token_id,
    float alpha_threshold,
    int   seed
) bool {
    if p_prob < 1e-10 {
        // 草稿概率极低，一定接受 (q/p 趋于无穷)
        return true
    }
    float ratio = q_prob / p_prob
    if ratio >= 1.0 {
        return true
    }
    // 以概率 ratio 接受
    // 用 seed 简化: 用固定比较模拟随机
    float rand_val = pseudo_rand(seed)
    rand_val < ratio
}

// 投机解码验证步 (核心)
func spec_verify(
    spec_draft_output draft,     // 草稿模型输出
    [][]float target_probs,      // 目标模型对 gamma 个位置的分布 [gamma][V]
    int V,
    spec_decode_config cfg
) spec_verify_result {
    int gamma = cfg.gamma
    []int accepted = []
    int num_acc = 0
    bool all_ok = true

    int i = 0
    for i < gamma {
        int tok = draft.token_ids[i]
        float p_tok = draft.all_probs[i][tok]
        float q_tok = target_probs[i][tok]

        bool ok = spec_accept_reject(q_tok, p_tok, tok, cfg.acceptance_threshold, i * 12345)
        if ok {
            accepted = append(accepted, tok)
            num_acc = num_acc + 1
        } else {
            // 从残差分布采样一个修正 token
            int fix_tok = spec_residual_sample(target_probs[i], draft.all_probs[i], V, i)
            accepted = append(accepted, fix_tok)
            all_ok = false
            // 停止验证
            i = gamma  // break
        }
        i = i + 1
    }

    // 若全部接受，追加目标模型第 gamma+1 个 token
    if all_ok && len(target_probs) > gamma {
        int bonus_tok = spec_top_p_sample(target_probs[gamma], V, cfg.top_p, 99999)
        accepted = append(accepted, bonus_tok)
    }

    float acc_rate = 0.0
    if gamma > 0 {
        acc_rate = float_spec(num_acc) / float_spec(gamma)
    }

    spec_verify_result {
        accepted_tokens: accepted,
        num_accepted: num_acc,
        acceptance_rate: acc_rate,
        all_accepted: all_ok,
    }
}

// ============================================================================
// 4. 解码循环状态
// ============================================================================

struct spec_decode_state {
    spec_decode_config cfg
    []int  token_buffer      // 当前生成序列
    int    seq_len           // 当前长度
    int    total_tokens_gen  // 总生成 token 数
    int    total_draft_calls // 草稿模型调用次数
    int    total_verify_calls// 目标模型验证次数
    float  avg_acceptance    // 平均接受率
    int    step              // 解码步数
    int    seed_state        // 随机种子状态
}

func new_spec_decode_state([]int prompt_ids, spec_decode_config cfg) spec_decode_state {
    spec_decode_state {
        cfg: cfg,
        token_buffer: prompt_ids,
        seq_len: len(prompt_ids),
        total_tokens_gen: 0,
        total_draft_calls: 0,
        total_verify_calls: 0,
        avg_acceptance: 0.0,
        step: 0,
        seed_state: 42,
    }
}

struct spec_decode_step_result {
    spec_decode_state state
    []int new_tokens          // 本步新增 token
    int   tokens_added        // 新增 token 数
    float step_acceptance_rate
    bool  done                // 遇到 EOS
}

// 单步投机解码
// (在实际系统中, draft_fn 和 target_fn 调用真实模型)
func spec_decode_step(
    spec_decode_state state,
    spec_draft_output draft,     // 外部提供: 草稿模型输出
    [][]float target_probs,      // 外部提供: 目标模型对 gamma+1 位置的分布
    int eos_token_id
) spec_decode_step_result {
    spec_verify_result vr = spec_verify(draft, target_probs, state.cfg.vocab_size, state.cfg)

    spec_decode_state updated = state
    updated.step = state.step + 1
    updated.total_draft_calls  = state.total_draft_calls + 1
    updated.total_verify_calls = state.total_verify_calls + 1
    updated.total_tokens_gen   = state.total_tokens_gen + len(vr.accepted_tokens)

    // 更新平均接受率
    float old_avg = state.avg_acceptance
    float new_acc = vr.acceptance_rate
    updated.avg_acceptance = (old_avg * float_spec(state.step) + new_acc) / float_spec(state.step + 1)

    // 追加新 token 到缓冲区
    bool done = false
    []int new_toks = []
    int i = 0
    for i < len(vr.accepted_tokens) {
        int tok = vr.accepted_tokens[i]
        if tok == eos_token_id {
            done = true
            i = len(vr.accepted_tokens)  // break
            continue
        }
        updated.token_buffer = append(updated.token_buffer, tok)
        updated.seq_len = updated.seq_len + 1
        new_toks = append(new_toks, tok)
        i = i + 1
    }

    spec_decode_step_result {
        state: updated,
        new_tokens: new_toks,
        tokens_added: len(new_toks),
        step_acceptance_rate: new_acc,
        done: done,
    }
}

// ============================================================================
// 5. Medusa — 多头投机
// ============================================================================

struct medusa_config {
    int num_heads       // 预测头数 (每头预测 t+1, t+2, ...t+k)
    int hidden_dim      // backbone hidden dim
    int vocab_size
    float temperature
    float posterior_threshold  // 树验证阈值 (通常 0.09)
    float posterior_alpha      // 树验证 α (通常 0.3)
}

// Medusa head (简单线性层)
struct medusa_head {
    []float weight      // [vocab_size, hidden_dim]
    []float bias        // [vocab_size]
    int head_idx        // 预测 t+head_idx+1
}

func new_medusa_head(int hidden_dim, int vocab_size, int head_idx) medusa_head {
    medusa_head {
        weight: zeros_spec(vocab_size * hidden_dim),
        bias: zeros_spec(vocab_size),
        head_idx: head_idx,
    }
}

// Medusa 前向: hidden [hidden_dim] → logits [vocab_size]
func medusa_head_forward(medusa_head head, []float hidden, int H, int V) []float {
    []float logits = zeros_spec(V)
    int j = 0
    for j < V {
        float s = head.bias[j]
        int k = 0
        for k < H {
            s = s + head.weight[j*H+k] * hidden[k]
            k = k + 1
        }
        logits[j] = s
        j = j + 1
    }
    logits
}

struct medusa_output {
    [][]float head_logits    // [num_heads][vocab_size] 各头的 logit
    []int     candidates     // 树搜索候选 token 序列
    int       tree_depth     // 实际树深度
}

func medusa_forward([]medusa_head heads, []float last_hidden, int H, int V) medusa_output {
    [][]float all_logits = []
    []int candidates = []

    int h = 0
    for h < len(heads) {
        []float logits = medusa_head_forward(heads[h], last_hidden, H, V)
        all_logits = append(all_logits, logits)
        // Greedy candidate for this head
        int best = argmax_spec(logits, V)
        candidates = append(candidates, best)
        h = h + 1
    }

    medusa_output {
        head_logits: all_logits,
        candidates: candidates,
        tree_depth: len(heads),
    }
}

// ============================================================================
// 6. 性能统计
// ============================================================================

struct spec_perf_stats {
    float speedup_ratio        // 相比标准解码的理论加速比
    float avg_acceptance_rate  // 平均 token 接受率
    int total_tokens
    int total_target_calls     // 目标模型前向次数
    float tokens_per_call      // 平均每次目标模型前向产出 token 数
}

func compute_spec_perf(spec_decode_state state) spec_perf_stats {
    int calls = state.total_verify_calls
    if calls == 0 { calls = 1 }
    float tpc = float_spec(state.total_tokens_gen) / float_spec(calls)

    // 理论加速比 ≈ (gamma+1) * alpha / (1 + alpha*(gamma-1))  近似
    float alpha = state.avg_acceptance
    int gamma = state.cfg.gamma
    float gamma_f = float_spec(gamma)
    float num = (gamma_f + 1.0) * alpha
    float den = 1.0 + alpha * (gamma_f - 1.0)
    float speedup = num
    if den > 0.01 { speedup = num / den }

    spec_perf_stats {
        speedup_ratio: speedup,
        avg_acceptance_rate: state.avg_acceptance,
        total_tokens: state.total_tokens_gen,
        total_target_calls: calls,
        tokens_per_call: tpc,
    }
}

// ============================================================================
// 7. 工具函数
// ============================================================================

func zeros_spec(int n) []float {
    []float out = []
    int i = 0
    for i < n {
        out = append(out, 0.0)
        i = i + 1
    }
    out
}

func float_spec(int n) float {
    float v = 0.0
    int i = 0
    for i < n {
        v = v + 1.0
        i = i + 1
    }
    v
}

func spec_exp(float x) float {
    if x > 20.0  { return 485165195.4 }
    if x < -20.0 { return 0.0 }
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    1.0 + x + x2/2.0 + x3/6.0 + x4/24.0
}

func pseudo_rand(int seed) float {
    int s = (seed * 1664525 + 1013904223) % 2147483647
    if s < 0 { s = 0 - s }
    float_spec(s % 10000) / 10000.0
}

func argmax_spec([]float arr, int n) int {
    int best = 0
    float best_v = arr[0]
    int i = 1
    for i < n {
        if arr[i] > best_v {
            best_v = arr[i]
            best = i
        }
        i = i + 1
    }
    best
}
