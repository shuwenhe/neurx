package neurx.model.transformer.moe

// ============================================================================
// Mixture-of-Experts (MoE) — sparse FFN (Mixtral / GPT-4-class scaling)
//
// Replaces the dense FFN in a transformer block with N expert FFNs and a
// router that sends each token to its top-k experts. Only k of N experts run
// per token, so parameter count scales without proportional FLOPs.
//
// Components:
//   • Router (gating network): hidden → expert logits → softmax → top-k
//   • Experts: each a SwiGLU FFN
//   • Dispatch + weighted combine of expert outputs
//   • Load-balancing auxiliary loss (Switch Transformer style)
//   • Capacity factor with token dropping
//
// This is a real, working MoE forward path operating on flat GPT hidden
// vectors [tokens, n_embd], replacing the earlier stub that just routed
// everything through one dense FFN.
// ============================================================================

use neurx.model.llm.gpt.{
    gpt_alloc, gpt_matmul, gpt_swish, gpt_sigmoid, gpt_softmax_row
}

// ============================================================================
// 1. 结构体
// ============================================================================

struct moe_config {
    int hidden_dim          // n_embd
    int expert_dim          // 每个专家 FFN 中间维度
    int num_experts         // 专家总数 (8 / 16 / 64)
    int top_k               // 每 token 激活的专家数 (通常 2)
    float capacity_factor   // 容量因子 (1.0-2.0)，控制每专家最大 token 数
    float aux_loss_weight   // 负载均衡损失权重 (~0.01)
    bool normalize_top_k    // top-k gate 权重是否重归一化
}

func new_moe_config(int hidden_dim, int expert_dim, int num_experts, int top_k) moe_config {
    moe_config {
        hidden_dim: hidden_dim,
        expert_dim: expert_dim,
        num_experts: num_experts,
        top_k: top_k,
        capacity_factor: 1.25,
        aux_loss_weight: 0.01,
        normalize_top_k: true,
    }
}

// 单个专家 (SwiGLU FFN)
struct moe_expert {
    []float gate_weight     // [hidden_dim, expert_dim]
    []float value_weight    // [hidden_dim, expert_dim]
    []float down_weight     // [expert_dim, hidden_dim]
}

struct moe_layer {
    moe_config config
    []float router_weight   // [hidden_dim, num_experts]
    []moe_expert experts
    int hidden_dim
    int expert_dim
    int num_experts
    int top_k
}

struct moe_output {
    []float hidden          // [tokens, hidden_dim] MoE 输出
    float aux_loss          // 负载均衡辅助损失
    []int expert_token_counts  // 每个专家收到的 token 数 (监控)
    float router_entropy    // 路由熵 (越高越均衡)
}

// ============================================================================
// 2. 初始化
// ============================================================================

func moe_fill_ramp(int size, float scale) []float {
    []float v = gpt_alloc(size, 0.0)
    int i = 0
    while i < size {
        float t = (i * 1.0 + 1.0) / (size * 1.0)
        v[i] = (t - 0.5) * scale
        i = i + 1
    }
    v
}

func new_moe_expert(int hidden_dim, int expert_dim, int seed_offset) moe_expert {
    int gate_size = hidden_dim * expert_dim
    int down_size = expert_dim * hidden_dim
    float s = 0.02
    moe_expert {
        gate_weight: moe_fill_ramp(gate_size, s + seed_offset * 0.001),
        value_weight: moe_fill_ramp(gate_size, s * 0.9 + seed_offset * 0.001),
        down_weight: moe_fill_ramp(down_size, s),
    }
}

func new_moe_layer(moe_config cfg) moe_layer {
    []moe_expert experts = []moe_expert{cap: cfg.num_experts}
    int e = 0
    while e < cfg.num_experts {
        experts[e] = new_moe_expert(cfg.hidden_dim, cfg.expert_dim, e)
        e = e + 1
    }
    moe_layer {
        config: cfg,
        router_weight: moe_fill_ramp(cfg.hidden_dim * cfg.num_experts, 0.02),
        experts: experts,
        hidden_dim: cfg.hidden_dim,
        expert_dim: cfg.expert_dim,
        num_experts: cfg.num_experts,
        top_k: cfg.top_k,
    }
}

// ============================================================================
// 3. 路由 (Gating Network)
// ============================================================================

struct routing_decision {
    []int expert_ids        // [tokens * top_k] 每 token 选中的专家
    []float gate_weights    // [tokens * top_k] 对应门控权重 (重归一化)
    []float router_probs    // [tokens * num_experts] 完整 softmax 概率 (用于 aux loss)
}

// 计算路由: hidden [tokens, hidden_dim] → top-k 专家选择
func moe_route(moe_layer layer, []float hidden, int tokens) routing_decision {
    int H = layer.hidden_dim
    int E = layer.num_experts
    int K = layer.top_k

    // router logits: [tokens, E]
    []float logits = gpt_matmul(hidden, layer.router_weight, tokens, H, E)

    []int expert_ids = []int{cap: tokens * K}
    []float gate_weights = gpt_alloc(tokens * K, 0.0)
    []float router_probs = gpt_alloc(tokens * E, 0.0)

    int t = 0
    while t < tokens {
        // softmax over experts for this token
        []float row = gpt_alloc(E, 0.0)
        int e = 0
        while e < E {
            row[e] = logits[t * E + e]
            e = e + 1
        }
        []float probs = gpt_softmax_row(row, E)
        e = 0
        while e < E {
            router_probs[t * E + e] = probs[e]
            e = e + 1
        }

        // 选 top-k (选择排序取最大 K 个)
        []bool used = []bool{cap: E}
        int u = 0
        while u < E { used[u] = false; u = u + 1 }

        float gate_sum = 0.0
        int k = 0
        while k < K {
            int best = -1
            float best_p = -1.0
            e = 0
            while e < E {
                if !used[e] && probs[e] > best_p {
                    best_p = probs[e]
                    best = e
                }
                e = e + 1
            }
            if best < 0 { best = 0 }
            used[best] = true
            expert_ids[t * K + k] = best
            gate_weights[t * K + k] = probs[best]
            gate_sum = gate_sum + probs[best]
            k = k + 1
        }

        // top-k 权重重归一化 (Mixtral 做法)
        if layer.config.normalize_top_k && gate_sum > 0.0 {
            k = 0
            while k < K {
                gate_weights[t * K + k] = gate_weights[t * K + k] / gate_sum
                k = k + 1
            }
        }

        t = t + 1
    }

    return routing_decision {
        expert_ids: expert_ids,
        gate_weights: gate_weights,
        router_probs: router_probs,
    }
}

// ============================================================================
// 4. 专家前向 (SwiGLU)
// ============================================================================

// 单 token 通过单个专家
func moe_expert_forward(moe_expert expert, []float token_hidden, int hidden_dim, int expert_dim) []float {
    // gate = token @ gate_weight  [expert_dim]
    // value = token @ value_weight [expert_dim]
    // out = (swish(gate) * value) @ down_weight  [hidden_dim]
    []float gate = gpt_alloc(expert_dim, 0.0)
    []float value = gpt_alloc(expert_dim, 0.0)
    int j = 0
    while j < expert_dim {
        float g = 0.0
        float v = 0.0
        int d = 0
        while d < hidden_dim {
            g = g + token_hidden[d] * expert.gate_weight[d * expert_dim + j]
            v = v + token_hidden[d] * expert.value_weight[d * expert_dim + j]
            d = d + 1
        }
        gate[j] = g
        value[j] = v
        j = j + 1
    }
    // swish(gate) * value
    []float gv = gpt_alloc(expert_dim, 0.0)
    j = 0
    while j < expert_dim {
        gv[j] = gpt_swish(gate[j]) * value[j]
        j = j + 1
    }
    // down projection → hidden_dim
    []float out = gpt_alloc(hidden_dim, 0.0)
    int d = 0
    while d < hidden_dim {
        float s = 0.0
        j = 0
        while j < expert_dim {
            s = s + gv[j] * expert.down_weight[j * hidden_dim + d]
            j = j + 1
        }
        out[d] = s
        d = d + 1
    }
    out
}

// ============================================================================
// 5. 完整 MoE 前向 (路由 → 分发 → 加权合并)
// ============================================================================

func moe_forward(moe_layer layer, []float hidden, int tokens) moe_output {
    int H = layer.hidden_dim
    int E = layer.num_experts
    int K = layer.top_k

    routing_decision route = moe_route(layer, hidden, tokens)

    []float output = gpt_alloc(tokens * H, 0.0)
    []int expert_counts = []int{cap: E}
    int ec = 0
    while ec < E { expert_counts[ec] = 0; ec = ec + 1 }

    // 容量: 每专家最多处理的 token 数
    int capacity = moe_capacity(tokens, E, K, layer.config.capacity_factor)

    int t = 0
    while t < tokens {
        // 提取该 token 的 hidden 向量
        []float token_hidden = gpt_alloc(H, 0.0)
        int d = 0
        while d < H {
            token_hidden[d] = hidden[t * H + d]
            d = d + 1
        }

        // 对每个选中专家计算并加权
        int k = 0
        while k < K {
            int eid = route.expert_ids[t * K + k]
            float gate = route.gate_weights[t * K + k]

            // 容量检查: 超容量则丢弃 (token dropping)
            if expert_counts[eid] < capacity {
                expert_counts[eid] = expert_counts[eid] + 1
                moe_expert ex = layer.experts[eid]
                // Inline expert forward to avoid cross-module type resolution issues
                int D = layer.expert_dim
                []float gate = gpt_alloc(D, 0.0)
                []float value = gpt_alloc(D, 0.0)
                int j = 0
                while j < D {
                    float g = 0.0
                    float v = 0.0
                    int dd = 0
                    while dd < H {
                        g = g + token_hidden[dd] * ex.gate_weight[dd * D + j]
                        v = v + token_hidden[dd] * ex.value_weight[dd * D + j]
                        dd = dd + 1
                    }
                    gate[j] = g
                    value[j] = v
                    j = j + 1
                }
                []float gv = gpt_alloc(D, 0.0)
                j = 0
                while j < D {
                    gv[j] = gpt_swish(gate[j]) * value[j]
                    j = j + 1
                }
                []float expert_out = gpt_alloc(H, 0.0)
                int dd = 0
                while dd < H {
                    float s = 0.0
                    j = 0
                    while j < D {
                        s = s + gv[j] * ex.down_weight[j * H + dd]
                        j = j + 1
                    }
                    expert_out[dd] = s
                    dd = dd + 1
                }
                d = 0
                while d < H {
                    output[t * H + d] = output[t * H + d] + gate * expert_out[d]
                    d = d + 1
                }
            }
            k = k + 1
        }
        t = t + 1
    }

    // 负载均衡辅助损失 + 路由熵
    float aux_loss = moe_aux_loss(route.router_probs, route.expert_ids, tokens, E, K)
    aux_loss = aux_loss * layer.config.aux_loss_weight
    float entropy = moe_router_entropy(route.router_probs, tokens, E)

    moe_output {
        hidden: output,
        aux_loss: aux_loss,
        expert_token_counts: expert_counts,
        router_entropy: entropy,
    }
}

// ============================================================================
// 6. 负载均衡辅助损失 (Switch Transformer)
//
//   aux = num_experts * sum_i ( f_i * P_i )
//   f_i = 路由到专家 i 的 token 比例 (基于 top-1 分配)
//   P_i = 专家 i 的平均路由概率
//   理想均衡时 aux ≈ 1; 越不均衡 aux 越大。
// ============================================================================

func moe_aux_loss([]float router_probs, []int expert_ids, int tokens, int num_experts, int top_k) float {
    // P_i: 平均路由概率
    []float mean_prob = gpt_alloc(num_experts, 0.0)
    int t = 0
    while t < tokens {
        int e = 0
        while e < num_experts {
            mean_prob[e] = mean_prob[e] + router_probs[t * num_experts + e]
            e = e + 1
        }
        t = t + 1
    }
    int e = 0
    while e < num_experts {
        mean_prob[e] = mean_prob[e] / (tokens * 1.0)
        e = e + 1
    }

    // f_i: 分配比例 (用 top-1 = 每 token 第一个专家)
    []float frac = gpt_alloc(num_experts, 0.0)
    t = 0
    while t < tokens {
        int top1 = expert_ids[t * top_k]
        frac[top1] = frac[top1] + 1.0
        t = t + 1
    }
    e = 0
    while e < num_experts {
        frac[e] = frac[e] / (tokens * 1.0)
        e = e + 1
    }

    // aux = N * sum(f_i * P_i)
    float aux = 0.0
    e = 0
    while e < num_experts {
        aux = aux + frac[e] * mean_prob[e]
        e = e + 1
    }
    aux * (num_experts * 1.0)
}

// 路由熵 (监控均衡性，越高越均衡)
func moe_router_entropy([]float router_probs, int tokens, int num_experts) float {
    // 平均概率分布的熵
    []float mean_prob = gpt_alloc(num_experts, 0.0)
    int t = 0
    while t < tokens {
        int e = 0
        while e < num_experts {
            mean_prob[e] = mean_prob[e] + router_probs[t * num_experts + e]
            e = e + 1
        }
        t = t + 1
    }
    float entropy = 0.0
    int e = 0
    while e < num_experts {
        float p = mean_prob[e] / (tokens * 1.0)
        if p > 0.000001 {
            entropy = entropy - p * moe_log(p)
        }
        e = e + 1
    }
    entropy
}

func moe_log(float x) float {
    if x <= 0.0 { return -1000000.0 }
    float v = x
    float adj = 0.0
    float ln2 = 0.6931471805599453
    while v >= 2.0 { v = v * 0.5; adj = adj + ln2 }
    while v < 1.0 { v = v * 2.0; adj = adj - ln2 }
    float z = v - 1.0
    float s = z
    float term = z
    int i = 2
    while i <= 16 {
        term = term * (-z)
        s = s + term / (i * 1.0)
        i = i + 1
    }
    s + adj
}

// ============================================================================
// 7. 容量计算
// ============================================================================

// 每专家容量 = capacity_factor * (tokens * top_k / num_experts)
func moe_capacity(int tokens, int num_experts, int top_k, float capacity_factor) int {
    float ideal = (tokens * 1.0) * (top_k * 1.0) / (num_experts * 1.0)
    float cap_f = ideal * capacity_factor
    int cap = 0
    while cap_f >= 1.0 {
        cap_f = cap_f - 1.0
        cap = cap + 1
    }
    if cap < 1 {
        cap = 1
    }
    cap
}

// ============================================================================
// 8. 参数量 / FLOPs 统计 (展示稀疏扩展优势)
// ============================================================================

struct moe_stats {
    int total_params         // 全部专家参数量
    int active_params        // 每 token 实际激活参数量 (top_k 个专家)
    float sparsity_ratio     // active / total
    int dense_equivalent     // 等效稠密 FFN 参数量
}

func moe_compute_stats(moe_config cfg) moe_stats {
    // 单专家参数: gate + value + down = 3 * H * expert_dim
    int per_expert = 3 * cfg.hidden_dim * cfg.expert_dim
    int total = per_expert * cfg.num_experts + cfg.hidden_dim * cfg.num_experts  // + router
    int active = per_expert * cfg.top_k
    float sparsity = (active * 1.0) / (total * 1.0)
    int dense = 3 * cfg.hidden_dim * cfg.expert_dim   // 单个稠密 FFN

    moe_stats {
        total_params: total,
        active_params: active,
        sparsity_ratio: sparsity,
        dense_equivalent: dense,
    }
}

// 标准 MoE 预设
// Mixtral-8x7B 风格: 8 专家, top-2
func moe_mixtral_config(int hidden_dim) moe_config {
    new_moe_config(hidden_dim, hidden_dim * 4, 8, 2)
}

// GPT-4 风格大规模: 16 专家, top-2
func moe_large_config(int hidden_dim) moe_config {
    new_moe_config(hidden_dim, hidden_dim * 4, 16, 2)
}

// 细粒度 MoE (DeepSeek-V3 风格): 64 专家, top-6
func moe_fine_grained_config(int hidden_dim) moe_config {
    moe_config cfg = new_moe_config(hidden_dim, hidden_dim, 64, 6)
    cfg.capacity_factor = 1.5
    cfg
}
