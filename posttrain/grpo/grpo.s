package neurx.posttrain.grpo

// ============================================================================
// GRPO — Group Relative Policy Optimization
//
// 论文: GRPO / R1-style reasoning reference implementations
//
// 核心思想:
//   对每个问题 q 采样 G 个输出 {o₁,...,o_G}，用组内相对奖励代替价值函数:
//     Advantage_i = (r_i - mean(r)) / (std(r) + ε)
//   策略梯度目标 (带 PPO clip + KL 惩罚):
//     L_GRPO = -E[ min(ρ_i · A_i, clip(ρ_i, 1-ε, 1+ε) · A_i) ] + β·KL
//   其中 ρ_i = π_θ(o_i|q) / π_ref(o_i|q)  (重要性采样比)
//
// 相比 PPO 的优势:
//   • 无需独立训练价值网络 (节省 2× 显存)
//   • 组内相对奖励方差更小，收敛更稳
//   • 天然适合推理/数学: 同一题多种解法评分
//
// 奖励设计 (R1-style):
//   r_format: <think>...</think><answer>...</answer> 格式正确 +0.1
//   r_accuracy: 答案正确 +1.0
//   r_length: 过长惩罚 -0.01/100token
// ============================================================================

use neurx.posttrain.config

// ============================================================================
// 1. 配置
// ============================================================================

struct grpo_config {
    int group_size          // G: 每题采样输出数 (通常 4-16)
    float clip_eps          // PPO clip ε (通常 0.2)
    float kl_coef           // KL 惩罚系数 β (通常 0.01-0.1)
    float gamma             // 折扣因子 (单步推理用 1.0)
    int max_gen_len         // 最大生成长度
    int min_gen_len         // 最小生成长度
    float temperature       // 采样温度
    float top_p             // nucleus sampling
    int num_iterations      // GRPO 内循环次数 (通常 1-4)
    bool use_format_reward  // 开启格式奖励
    bool use_length_penalty // 开启长度惩罚
    float length_penalty_per_100  // 每100 token 的惩罚
    float advantage_eps     // 优势归一化 ε (防止方差为0)
    string reward_type      // "math" | "code" | "general"
}

func default_grpo_config() grpo_config {
    grpo_config {
        group_size: 8,
        clip_eps: 0.2,
        kl_coef: 0.04,
        gamma: 1.0,
        max_gen_len: 2048,
        min_gen_len: 1,
        temperature: 0.8,
        top_p: 0.95,
        num_iterations: 1,
        use_format_reward: true,
        use_length_penalty: true,
        length_penalty_per_100: 0.01,
        advantage_eps: 1e-6,
        reward_type: "math",
    }
}

func neurx_r1_grpo_config() grpo_config {
    grpo_config {
        group_size: 8,
        clip_eps: 0.2,
        kl_coef: 0.001,
        gamma: 1.0,
        max_gen_len: 8192,
        min_gen_len: 64,
        temperature: 0.6,
        top_p: 0.95,
        num_iterations: 1,
        use_format_reward: true,
        use_length_penalty: true,
        length_penalty_per_100: 0.005,
        advantage_eps: 1e-8,
        reward_type: "math",
    }
}

// ============================================================================
// 2. 单条样本的 GRPO 数据
// ============================================================================

// 一个"组"= 同一问题的 G 条输出
struct grpo_group {
    string question             // 原始问题
    string reference_answer     // 参考答案 (用于评分)
    []string outputs            // [G] 模型采样输出
    []int    output_lengths     // [G] 各输出 token 数
    []float  rewards            // [G] 各输出原始奖励
    []float  advantages         // [G] 归一化优势
    []float  log_probs_policy   // [G] 当前策略 log π_θ(o|q)
    []float  log_probs_ref      // [G] 参考策略 log π_ref(o|q)
}

// ============================================================================
// 3. 奖励函数
// ============================================================================

// 检查答案是否包含正确格式 <think>...</think><answer>...</answer>
func check_format_reward(string output) float {
    bool has_think  = string_contains(output, "<think>") && string_contains(output, "</think>")
    bool has_answer = string_contains(output, "<answer>") && string_contains(output, "</answer>")
    if has_think && has_answer {
        return 0.1
    }
    if has_answer {
        return 0.05
    }
    0.0
}

// 提取 <answer>...</answer> 中的内容并与参考答案对比
func check_accuracy_reward(string output, string reference) float {
    string extracted = extract_answer_tag(output)
    if string_equals(extracted, reference) {
        return 1.0
    }
    // 宽松匹配: 数字类答案去除空格后对比
    string trimmed_out = string_trim(extracted)
    string trimmed_ref = string_trim(reference)
    if string_equals(trimmed_out, trimmed_ref) {
        return 1.0
    }
    // 部分分 (包含正确答案子串)
    if string_contains(trimmed_out, trimmed_ref) {
        return 0.3
    }
    0.0
}

// 长度惩罚: 超过 max_gen_len 的 50% 开始惩罚
func compute_length_penalty(int token_len, int max_len, float penalty_per_100) float {
    int threshold = max_len / 2
    if token_len <= threshold {
        return 0.0
    }
    float excess = float_grpo(token_len - threshold)
    0.0 - (excess / 100.0) * penalty_per_100
}

func compute_reward(string output, string reference, int token_len, grpo_config cfg) float {
    float r = 0.0
    if cfg.use_format_reward {
        r = r + check_format_reward(output)
    }
    r = r + check_accuracy_reward(output, reference)
    if cfg.use_length_penalty {
        r = r + compute_length_penalty(token_len, cfg.max_gen_len, cfg.length_penalty_per_100)
    }
    r
}

// ============================================================================
// 4. 优势计算 (组内归一化)
// ============================================================================

func compute_group_advantages([]float rewards, float eps) []float {
    int G = len(rewards)

    // mean
    float mean = 0.0
    int i = 0
    for i < G {
        mean = mean + rewards[i]
        i = i + 1
    }
    mean = mean / float_grpo(G)

    // std
    float var = 0.0
    int j = 0
    for j < G {
        float diff = rewards[j] - mean
        var = var + diff * diff
        j = j + 1
    }
    var = var / float_grpo(G)
    float std = sqrt_grpo(var)

    []float adv = []
    int k = 0
    for k < G {
        float a = (rewards[k] - mean) / (std + eps)
        adv = append(adv, a)
        k = k + 1
    }
    adv
}

// ============================================================================
// 5. GRPO 目标函数 (单样本 单token)
// ============================================================================

// 计算单个输出 i 的 GRPO loss 贡献
// log_ratio = log π_θ - log π_ref (单 token)
func grpo_token_loss(float log_prob_policy, float log_prob_ref, float advantage, float clip_eps, float kl_coef) float {
    float log_ratio = log_prob_policy - log_prob_ref
    float ratio = exp_grpo(log_ratio)

    // Clipped surrogate
    float obj1 = ratio * advantage
    float obj2 = clip_grpo(ratio, 1.0 - clip_eps, 1.0 + clip_eps) * advantage
    float policy_loss = 0.0 - min_float(obj1, obj2)   // negative for gradient ascent

    // KL penalty: KL(π_θ || π_ref) ≈ ratio - log_ratio - 1
    float kl = ratio - log_ratio - 1.0

    policy_loss + kl_coef * kl
}

// ============================================================================
// 6. GRPO 步骤 (整组前向)
// ============================================================================

struct grpo_step_result {
    float total_loss          // 总 GRPO loss
    float policy_loss         // 策略目标 loss
    float kl_loss             // KL 惩罚
    float mean_reward         // 组均奖励
    float reward_std          // 奖励标准差
    float mean_advantage      // 均值优势 (应接近 0)
    float clip_fraction       // clip 触发比例
    []float advantages        // [G] 各输出优势值
    int accepted_outputs      // 正奖励输出数
}

func grpo_step(grpo_group group, grpo_config cfg) grpo_step_result {
    int G = len(group.outputs)

    // 计算每个输出的奖励
    []float rewards = []
    int i = 0
    for i < G {
        float r = compute_reward(
            group.outputs[i],
            group.reference_answer,
            group.output_lengths[i],
            cfg
        )
        rewards = append(rewards, r)
        i = i + 1
    }

    // 计算组内优势
    []float adv = compute_group_advantages(rewards, cfg.advantage_eps)

    // 计算 loss
    float total_loss = 0.0
    float kl_total   = 0.0
    float clips      = 0.0
    int j = 0
    for j < G {
        float log_ratio = group.log_probs_policy[j] - group.log_probs_ref[j]
        float ratio = exp_grpo(log_ratio)

        // clip check
        float ratio_clipped = clip_grpo(ratio, 1.0 - cfg.clip_eps, 1.0 + cfg.clip_eps)
        float obj1 = ratio * adv[j]
        float obj2 = ratio_clipped * adv[j]
        float chosen = min_float(obj1, obj2)

        if ratio > 1.0 + cfg.clip_eps || ratio < 1.0 - cfg.clip_eps {
            clips = clips + 1.0
        }

        float kl = ratio - log_ratio - 1.0
        kl_total = kl_total + kl

        total_loss = total_loss + (0.0 - chosen) + cfg.kl_coef * kl
        j = j + 1
    }

    float fG = float_grpo(G)
    total_loss = total_loss / fG
    kl_total   = kl_total / fG

    // 统计
    float mean_r = 0.0
    int k = 0
    for k < G {
        mean_r = mean_r + rewards[k]
        k = k + 1
    }
    mean_r = mean_r / fG

    float var_r = 0.0
    int k2 = 0
    for k2 < G {
        float d = rewards[k2] - mean_r
        var_r = var_r + d * d
        k2 = k2 + 1
    }
    float std_r = sqrt_grpo(var_r / fG)

    int accepted = 0
    int k3 = 0
    for k3 < G {
        if rewards[k3] > 0.0 {
            accepted = accepted + 1
        }
        k3 = k3 + 1
    }

    grpo_step_result {
        total_loss: total_loss,
        policy_loss: total_loss - cfg.kl_coef * kl_total,
        kl_loss: kl_total,
        mean_reward: mean_r,
        reward_std: std_r,
        mean_advantage: 0.0,
        clip_fraction: clips / fG,
        advantages: adv,
        accepted_outputs: accepted,
    }
}

// ============================================================================
// 7. GRPO 训练循环状态
// ============================================================================

struct grpo_trainer_state {
    grpo_config cfg
    int global_step
    float total_reward
    float total_loss
    int total_groups
    // 移动平均 (用于监控)
    float ema_reward       // 指数移动平均奖励
    float ema_kl           // 指数移动平均 KL
    float ema_clip_frac    // 指数移动平均 clip 率
    float ema_decay        // EMA 衰减系数 (0.98)
}

func new_grpo_trainer(grpo_config cfg) grpo_trainer_state {
    grpo_trainer_state {
        cfg: cfg,
        global_step: 0,
        total_reward: 0.0,
        total_loss: 0.0,
        total_groups: 0,
        ema_reward: 0.0,
        ema_kl: 0.0,
        ema_clip_frac: 0.0,
        ema_decay: 0.98,
    }
}

struct grpo_train_step_result {
    grpo_trainer_state state
    grpo_step_result step_result
}

func grpo_train_step(grpo_trainer_state trainer, grpo_group group) grpo_train_step_result {
    grpo_step_result result = grpo_step(group, trainer.cfg)

    float d = trainer.ema_decay
    grpo_trainer_state updated = trainer
    updated.global_step   = trainer.global_step + 1
    updated.total_groups  = trainer.total_groups + 1
    updated.total_reward  = trainer.total_reward + result.mean_reward
    updated.total_loss    = trainer.total_loss + result.total_loss
    updated.ema_reward    = d * trainer.ema_reward + (1.0 - d) * result.mean_reward
    updated.ema_kl        = d * trainer.ema_kl    + (1.0 - d) * result.kl_loss
    updated.ema_clip_frac = d * trainer.ema_clip_frac + (1.0 - d) * result.clip_fraction

    grpo_train_step_result { state: updated, step_result: result }
}

// ============================================================================
// 8. 课程学习 (Curriculum) — 难度自适应
// ============================================================================

// 根据近期准确率动态调整组大小和温度
struct grpo_curriculum_state {
    float recent_accuracy    // 近 N 步平均准确率
    int adaptive_group_size  // 自适应组大小
    float adaptive_temp      // 自适应采样温度
    int steps_since_update   // 上次更新以来的步数
    int update_interval      // 每 N 步调整一次
}

func new_grpo_curriculum(grpo_config base_cfg) grpo_curriculum_state {
    grpo_curriculum_state {
        recent_accuracy: 0.5,
        adaptive_group_size: base_cfg.group_size,
        adaptive_temp: base_cfg.temperature,
        steps_since_update: 0,
        update_interval: 100,
    }
}

func grpo_curriculum_update(grpo_curriculum_state cur, float step_accuracy, grpo_config base_cfg) grpo_curriculum_state {
    float d = 0.95
    float acc = d * cur.recent_accuracy + (1.0 - d) * step_accuracy
    grpo_curriculum_state updated = cur
    updated.recent_accuracy = acc
    updated.steps_since_update = cur.steps_since_update + 1

    if updated.steps_since_update >= cur.update_interval {
        updated.steps_since_update = 0
        // 准确率高 → 加难 (减小 temperature, 增大 group)
        // 准确率低 → 减难 (增大 temperature, 减小 group)
        if acc > 0.9 {
            // 已经很高，增大温度探索更难问题
            updated.adaptive_temp = min_float(base_cfg.temperature * 1.2, 1.0)
        } else {
            if acc < 0.3 {
                // 太难，降温
                updated.adaptive_temp = base_cfg.temperature * 0.8
            }
        }
    }

    updated
}

// ============================================================================
// 9. 工具函数
// ============================================================================

func float_grpo(int n) float {
    float v = 0.0
    int i = 0
    for i < n {
        v = v + 1.0
        i = i + 1
    }
    v
}

func sqrt_grpo(float x) float {
    if x <= 0.0 { return 0.0 }
    float g = x * 0.5 + 0.5
    g = 0.5 * (g + x / g)
    g = 0.5 * (g + x / g)
    g = 0.5 * (g + x / g)
    g
}

func exp_grpo(float x) float {
    if x > 20.0  { return 485165195.4 }
    if x < -20.0 { return 0.0 }
    float x2 = x * x
    float x3 = x2 * x
    float x4 = x3 * x
    float x5 = x4 * x
    1.0 + x + x2/2.0 + x3/6.0 + x4/24.0 + x5/120.0
}

func clip_grpo(float val, float lo, float hi) float {
    if val < lo { return lo }
    if val > hi { return hi }
    val
}

func min_float(float a, float b) float {
    if a < b { return a }
    b
}

// 字符串工具 (依赖运行时)
func string_contains(string s, string sub) bool {
    // runtime 实现
    false
}

func string_equals(string a, string b) bool {
    // runtime 实现
    false
}

func string_trim(string s) string {
    s
}

func extract_answer_tag(string output) string {
    // 提取 <answer>...</answer> 内容
    // runtime 实现
    output
}
